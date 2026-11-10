//
//  FuzzDiagnostics.swift
//  PlungeTests
//
//  Diagnostic profiling for the fuzzer. Steps an interpreter one window at a
//  time so a run that *decelerates* (per-step cost climbing — e.g. the known
//  crux/provenance blow-up on exec-combinators) can be told apart from one that
//  is merely long, and the responsible instructions surfaced.
//
//  Test-only: it reads interpreter internals via `@testable`, and deliberately
//  does NOT touch the production run loop.
//

import Foundation
@testable import Plunge

// `SeededRNG` and `fuzzRNG` now live in the library beside `RandomCode`
// (Sources/Plunge/Generation/RandomCode.swift), which is where the draws
// they serve live. Still a shared global, so fuzz suites must still run alone.

/// One window of a profiled run: how long a block of steps took, what ran, and
/// how big the stacks were at the end.
nonisolated struct WindowSample: Codable, Sendable {
    let firstStep: Int
    let steps: Int
    let seconds: Double
    let stackItemsAtEnd: Int
    let topInstructions: [String: Int]
}

/// The per-run diagnostic record ("profileRun"), serialized beside a
/// reproduction for offline study.
nonisolated struct RunProfile: Codable, Sendable {
    let id: String
    let totalSteps: Int
    let exhausted: Bool          // program ran out (vs. hit the step limit)
    let capped: Bool             // stopped early because it passed the wall-clock cap
    let totalSeconds: Double
    let errorCount: Int
    let hitInvariant: Bool
    let hitSizeLimit: Bool
    let peakStackItems: Int      // largest total item count seen — a cheap structural
                                 // blow-up signal; growing linearly ⇒ a replicating loop
    let runawayMessage: String?  // the RUNAWAY: marker if the guard stopped the run early
    let windows: [WindowSample]

    var hitRunaway: Bool { runawayMessage != nil }

    /// Peak window time / first window time. >1 means the run got slower.
    var slowdownRatio: Double {
        let secs = windows.map(\.seconds)
        guard let first = secs.first, first > 0, let peak = secs.max() else { return 1 }
        return peak / first
    }

    /// Last window's stack size / first window's — distinguishes "more items"
    /// from "same items, each more expensive" (i.e. provenance bloat).
    var itemGrowth: Double {
        guard let first = windows.first?.stackItemsAtEnd, first > 0,
              let last = windows.last?.stackItemsAtEnd else { return 1 }
        return Double(last) / Double(first)
    }

    /// The instruction dominating the window where the stack grew largest — the
    /// qualitative suspect. Chosen structurally (by stack size, with a key
    /// tie-break) rather than by wall-clock, so it's deterministic for a seed.
    var dominantCulprit: String {
        windows.max(by: { $0.stackItemsAtEnd < $1.stackItemsAtEnd })?
            .topInstructions
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .first?.key ?? "—"
    }

    /// A one-line qualitative diagnosis.
    var verdict: String {
        if hitInvariant { return "INVARIANT violation" }
        if let runawayMessage { return "runaway guard stopped it — \(runawayMessage)" }
        if slowdownRatio > 10 || capped {
            let mode = itemGrowth > 3
                ? String(format: "stack items grew %.1fx (count-driven, peak %d)", itemGrowth, peakStackItems)
                : "stack items ~flat (per-item / provenance-driven)"
            return String(
                format: "progressive slowdown %.0fx%@; %@; slowest window dominated by %@",
                slowdownRatio, capped ? " (capped)" : "", mode, dominantCulprit
            )
        }
        if hitSizeLimit {
            return String(format: "hits a size limit; peak stack %d, dominated by %@",
                          peakStackItems, dominantCulprit)
        }
        return "ok"
    }
}

/// Total leaf count of a program, expanding nested code blocks. A program that
/// has simplified down to a single big code block has `count == 1` but many
/// leaves — this makes the real size explicit so the report isn't misread.
nonisolated func programLeafCount(_ items: [any Item]) -> Int {
    items.reduce(0) { $0 + (($1 as? CodeItem).map { programLeafCount($0.value) } ?? 1) }
}

/// Renders a program as pretty() tokens wrapped to `width`, expanding nested
/// code blocks into `(` … `)` tokens so even a single large block breaks across
/// lines. Continuation lines are indented. For pasting into a chat or issue —
/// note the program alone omits the inputs/constants (those are in the JSON).
nonisolated func renderProgram(_ program: [any Item], width: Int = 96, indent: String = "       ") -> String {
    func tokens(_ items: [any Item]) -> [String] {
        var out: [String] = []
        for item in items {
            if let code = item as? CodeItem {
                out.append("(")
                out.append(contentsOf: tokens(code.value))
                out.append(")")
            } else {
                out.append(item.pretty())
            }
        }
        return out
    }
    var lines: [String] = []
    var line = indent
    for tok in tokens(program) {
        if line != indent && line.count + 1 + tok.count > width {
            lines.append(line)
            line = indent
        }
        line += (line == indent ? "" : " ") + tok
    }
    if line != indent { lines.append(line) }
    return lines.isEmpty ? "\(indent)(empty)" : lines.joined(separator: "\n")
}

/// Every instruction token a program mentions, recursing into code blocks.
nonisolated func referencedInstructions(_ items: [any Item]) -> Set<PushInstruction> {
    var out: Set<PushInstruction> = []
    for item in items {
        if let instr = item as? InstructionItem {
            out.insert(instr.value)
        } else if let code = item as? CodeItem {
            out.formUnion(referencedInstructions(code.value))
        }
    }
    return out
}

/// The transitive set of instruction tokens a program depends on: those it
/// mentions directly, plus (recursively) those mentioned by any code-valued
/// binding it reaches. This is what surfaces a payload hidden in an input — the
/// program names `.input2`, whose bound code names `.char5`, and so on.
nonisolated func referencedClosure(program: [any Item], bindings: [PushInstruction: any Item]) -> Set<PushInstruction> {
    var seen = referencedInstructions(program)
    var frontier = seen
    while !frontier.isEmpty {
        var next: Set<PushInstruction> = []
        for name in frontier {
            guard let value = bindings[name] else { continue }
            // Treat the bound value as a one-item program: a code block expands to
            // its leaves, an instruction-valued binding (an input alias) to itself.
            for instr in referencedInstructions([value]) where !seen.contains(instr) {
                next.insert(instr); seen.insert(instr)
            }
        }
        frontier = next
    }
    return seen
}

/// Renders `names` (sorted) that have a binding, as `.name = value` lines. Code
/// values are wrapped like a program; scalars use pretty().
nonisolated func renderBindings(_ names: Set<PushInstruction>, from bindings: [PushInstruction: any Item], indent: String = "       ") -> [String] {
    names.sorted { $0.rawValue < $1.rawValue }.compactMap { name in
        guard let item = bindings[name] else { return nil }
        if item is CodeItem {
            return "\(indent).\(name) =\n" + renderProgram([item], indent: indent + "  ")
        }
        return "\(indent).\(name) = \(item.pretty())"
    }
}

/// Duration → seconds as a Double.
nonisolated func fuzzSeconds(_ d: Duration) -> Double {
    let (s, atto) = d.components
    return Double(s) + Double(atto) * 1e-18
}

/// Builds a loaded interpreter for one case under the given settings. Test-only.
nonisolated func buildInterpreter(
    program: [any Item],
    constants: [PushInstruction: any Item],
    inputs: [PushInstruction: any Item],
    settings: InterpreterSettings
) -> Interpreter {
    let interpreter = Interpreter()
    interpreter.config = settings
    interpreter.load(inputs: inputs, constants: constants, program: program)
    return interpreter
}

/// Mutates a program to (usually) make it bigger and more repetitive, so a
/// hill-climb can amplify whatever symptom made a case a suspect. Biased toward
/// growth — duplicating segments raises the frequency of loop/recursion
/// instructions, which is exactly what worsens the crux blow-up — and capped so
/// the result stays loadable.
nonisolated func mutate(program: [any Item]) -> [any Item] {
    guard !program.isEmpty else { return [InstructionItem(RandomCode.randomInstruction())] }
    var p = program
    switch Int.random(in: 0..<10, using: &fuzzRNG) {
    case 0...3:  // duplicate a random contiguous segment (amplifies repetition)
        let start = Int.random(in: 0..<p.count, using: &fuzzRNG)
        let length = Int.random(in: 1...(p.count - start), using: &fuzzRNG)
        p.insert(contentsOf: Array(p[start..<(start + length)]), at: start + length)
    case 4...5:  // duplicate the whole program
        p += p
    case 6...7:  // insert a random item
        p.insert(RandomCode.randomPushItem(), at: Int.random(in: 0...p.count, using: &fuzzRNG))
    case 8:      // replace a random item
        p[Int.random(in: 0..<p.count, using: &fuzzRNG)] = RandomCode.randomPushItem()
    default:     // occasional shrink, for variety
        p.remove(at: Int.random(in: 0..<p.count, using: &fuzzRNG))
    }
    return p.count > 20_000 ? Array(p.prefix(20_000)) : p
}

/// Removes a random contiguous chunk from a program — the deletion step of
/// auto-simplification. Amplified programs are highly repetitive (grown by
/// duplication), so chunk deletion peels off the redundant copies quickly and
/// converges toward the minimal core that still exhibits the pathology.
nonisolated func removeRandomChunk(_ program: [any Item]) -> [any Item] {
    guard program.count > 1 else { return program }
    let start = Int.random(in: 0..<program.count, using: &fuzzRNG)
    let length = Int.random(in: 1...max(1, min(program.count - start, program.count / 3)), using: &fuzzRNG)
    var p = program
    p.removeSubrange(start..<(start + length))
    return p
}

/// Steps `interpreter` to its step limit (or exhaustion), one window at a time,
/// recording per-window wall time, the instruction histogram, and total stack
/// size. Reads interpreter internals, so it lives in the test target and does
/// not alter the production run loop.
/// `maxSeconds` is a total wall-clock budget: the run stops once cumulative time
/// passes it (checked at window boundaries). Because fast programs reach the step
/// limit well under any real budget, the cap only ever fires on a genuinely slow
/// (blowing-up) run — including one that stays cheap for a long prefix and only
/// then decelerates. Simplify/amplify use it to avoid running a proven-slow
/// candidate to completion.
nonisolated func profiledRun(id: String, interpreter: Interpreter, windowSize: Int, maxSeconds: Double = .infinity) -> RunProfile {
    let clock = ContinuousClock()
    let runStart = clock.now
    var windows: [WindowSample] = []
    var histogram: [PushInstruction: Int] = [:]
    var windowFirstStep = 0
    var windowStart = clock.now
    var step = 0
    var peakStackItems = 0
    var capped = false
    let limit = interpreter.config.stepLimit

    func closeWindow() {
        let now = clock.now
        let items = interpreter.stacks.values.reduce(0) { $0 + $1.count }
        peakStackItems = max(peakStackItems, items)
        let top = histogram.sorted { $0.value > $1.value }.prefix(6)
        windows.append(WindowSample(
            firstStep: windowFirstStep,
            steps: step - windowFirstStep,
            seconds: fuzzSeconds(now - windowStart),
            stackItemsAtEnd: items,
            topInstructions: Dictionary(uniqueKeysWithValues: top.map { ($0.key.rawValue, $0.value) })
        ))
        windowFirstStep = step
        windowStart = now
        histogram.removeAll(keepingCapacity: true)
    }

    while step < limit && !interpreter.stacks[.exec]!.isEmpty {
        // Peek the instruction about to run so the histogram attributes cost.
        if let instruction = (interpreter.stacks[.exec]!.first as? InstructionItem)?.value {
            histogram[instruction, default: 0] += 1
        }
        interpreter.step()
        step += 1
        if step - windowFirstStep >= windowSize {
            closeWindow()
            if fuzzSeconds(clock.now - runStart) > maxSeconds { capped = true; break }
        }
    }
    if step > windowFirstStep { closeWindow() }

    let errors = interpreter.stacks[.error] ?? []
    let errorValues = errors.compactMap { ($0 as? ErrorItem)?.value }
    let hitInvariant = errorValues.contains { $0.contains(Interpreter.invariantMarker) }
    let sizeMarkers = ["maxVectorLength", "maxStringLength", "maxCodePoints", "maxItemWeight", "maxStackDepth"]
    let hitSizeLimit = errorValues.contains { value in sizeMarkers.contains { value.contains($0) } }
    let runawayMessage = errorValues.first { $0.hasPrefix(Interpreter.runawayMarker) }

    return RunProfile(
        id: id,
        totalSteps: step,
        exhausted: interpreter.stacks[.exec]!.isEmpty,
        capped: capped,
        totalSeconds: windows.reduce(0) { $0 + $1.seconds },
        errorCount: errors.count,
        hitInvariant: hitInvariant,
        hitSizeLimit: hitSizeLimit,
        peakStackItems: peakStackItems,
        runawayMessage: runawayMessage,
        windows: windows
    )
}
