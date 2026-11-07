//
//  RunawayGuard.swift
//  PushInterpreter
//
//  A cheap guard against runaway loops. The per-dimension size caps (see
//  SizeLimits) bound how large a single item or stack may get, but a tight
//  loop that piles items still burns time and memory right up to the cap on
//  every run. This guard catches that pattern *early* and stops the run with a
//  diagnosable `RUNAWAY:` marker, so a genetic-programming search gets an error
//  result instead of a slow near-OOM crawl.
//
//  It fires only on two signals together:
//    • data side    — a size-limited stack is deep and its recent top is
//                     dominated by repeats, a short cycle, or a monotone counter
//                     (the shape a loop leaves when it pumps items onto a stack);
//    • control side — a looping instruction (`PushInstruction.iterators`) is
//                     pending on `.exec`, i.e. a loop is genuinely in flight.
//
//  Requiring both keeps false positives down: a large but terminating one-shot
//  computation trips neither the "repeats" test nor leaves a looper on `.exec`.
//  A miss just falls through to the ordinary size caps, so the guard fails safe.
//
//  It does NOT catch the provenance (`.call`/`crux`) blow-up: that grows an
//  item's history while stack *counts* stay small, so no stack crosses the
//  trigger. That pathology is handled separately.
//

nonisolated extension Interpreter {

    static let runawayMarker = "RUNAWAY:"
    static let memoryMarker  = "MEMORY:"
    static let provenanceMarker = "PROVENANCE:"

    /// The global memory bound the local size caps do not compose into: the total
    /// `Item.weight` live across all stacks. Checked every step, but only weighed
    /// when a stack is deep enough to matter (cheap count gate otherwise). A run
    /// over `maxLiveWeight` is stopped like a runaway — an error marker and an
    /// unwound `.exec` — so a search gets a diagnosable result, not an OOM.
    func enforceMemoryGuard() {
        guard config.maxLiveWeight < Int.max else { return }
        // O(1): `liveWeight` is maintained incrementally by the stack-mutation helpers
        // (`place`/`take…`/`clear`) and anchored at run start, so the guard no longer
        // re-sums every stack every step — the dominant per-step cost it used to be.
        guard liveWeight > config.maxLiveWeight else { return }

        place(
            ErrorItem("\(Interpreter.memoryMarker) live weight \(liveWeight) exceeds maxLiveWeight \(config.maxLiveWeight)",
                      kind: .guardStop).observed(by: nil, recording),
            on: .error
        )
        clear(.exec)   // unwind: the run loop exits once .exec is empty
    }

    // Tunables. Kept here (not in InterpreterSettings) to avoid a knob
    // explosion; promote any that prove worth configuring. The trigger itself
    // scales with `maxStackDepth`, which *is* configurable.
    static let runawayFloor            = 512   // min stack depth before we bother looking
    static let runawayWindow           = 256   // recent top-of-stack items sampled
    static let runawayDistinctFraction = 0.1   // ≤10% distinct in the window ⇒ piling
    static let runawayMaxPeriod        = 8      // cycle periods probed
    static let runawayExecScan         = 256   // how deep into .exec we look for a live loop
    static let runawayExamineEvery     = 256   // steps between examinations while a stack stays deep

    /// Called once per step. Cheap in the common case: a handful of integer
    /// comparisons unless a stack is genuinely deep, and even then the O(window)
    /// examination is throttled to once per `runawayExamineEvery` steps.
    func enforceRunawayGuard() {
        guard config.runawayGuardEnabled else { return }

        // Throttle: don't re-examine on every step while a stack stays deep.
        guard lastRunawayCheck < 0 || counter - lastRunawayCheck >= Interpreter.runawayExamineEvery
        else { return }

        // Cheap gate: is any homogeneous stack past the observation trigger?
        // Iterate in sorted order so which stack we report is deterministic.
        let trigger = max(Interpreter.runawayFloor, config.maxStackDepth / 10)
        guard let stack = stacks.firstLimitedStack(deeperThan: trigger) else { return }
        lastRunawayCheck = counter

        // Data side: does the recent top look like a loop is pumping it?
        guard let symptom = runawaySymptom(on: stack) else { return }
        // Control side: is a loop actually in flight on `.exec`?
        guard let looper = liveLooper() else { return }

        place(
            ErrorItem("\(Interpreter.runawayMarker) .\(stack) \(symptom); \(looper) active",
                  kind: .guardStop).observed(by: nil, recording),
            on: .error
        )
        clear(.exec)   // unwind: the run loop exits once .exec is empty
    }

    /// A short description of the pathology if the top `runawayWindow` items of
    /// `stack` look loop-driven — dominated by a few values, cycling a small
    /// period, or a monotone counter — else nil.
    func runawaySymptom(on stack: PushStack) -> String? {
        guard let deque = stacks[stack] else { return nil }
        let w = min(Interpreter.runawayWindow, deque.count)
        guard w >= 8 else { return nil }
        // Index 0 is the top (pushes prepend), so this is the most-recent slice.
        let window = deque.prefix(w).map { $0.pretty() }

        // Piling: few distinct values dominate the recent window.
        let distinct = Set(window).count
        if distinct <= max(1, Int(Double(w) * Interpreter.runawayDistinctFraction)) {
            return "piling ≤\(distinct) distinct value(s) (e.g. \(window[0]))"
        }

        // Tight cycle: the window repeats with some small period p.
        for p in 1...min(Interpreter.runawayMaxPeriod, w - 1) {
            var periodic = true
            var i = p
            while i < w { if window[i] != window[i - p] { periodic = false; break }; i += 1 }
            if periodic { return "cycling with period \(p)" }
        }

        // Counter: a numeric stack whose recent window climbs monotonically —
        // distinct values, so the tests above miss it, but still unbounded growth.
        if let nums = numericWindow(of: stack, count: w) {
            let deltas = zip(nums.dropFirst(), nums).map { $0 - $1 }
            if deltas.allSatisfy({ $0 > 0 }) || deltas.allSatisfy({ $0 < 0 }) {
                return "counting monotonically (e.g. \(window[0]))"
            }
        }
        return nil
    }

    /// The first looping instruction found within the top `runawayExecScan`
    /// items of `.exec` — evidence a loop is mid-flight, since those instructions
    /// re-push a continuation of themselves each pass. nil if none is pending.
    func liveLooper() -> PushInstruction? {
        guard let exec = stacks[.exec] else { return nil }
        for item in exec.prefix(Interpreter.runawayExecScan) {
            if let instr = item as? InstructionItem, PushInstruction.iterators.contains(instr.value) {
                return instr.value
            }
        }
        return nil
    }

    /// The top `count` items of a numeric stack as Doubles, or nil if the stack
    /// isn't numeric (only `.int` and `.double` qualify).
    private func numericWindow(of stack: PushStack, count: Int) -> [Double]? {
        guard stack == .int || stack == .double, let deque = stacks[stack] else { return nil }
        var out: [Double] = []
        out.reserveCapacity(count)
        for item in deque.prefix(count) {
            if let i = item as? IntItem { out.append(Double(i.value)) }
            else if let d = item as? DoubleItem { out.append(d.value) }
            else { return nil }
        }
        return out
    }
}
