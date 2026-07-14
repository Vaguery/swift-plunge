//
//  FuzzDiagnostics.swift
//  PushInterpreterTests
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
@testable import PushInterpreter

/// One window of a profiled run: how long a block of steps took, what ran, and
/// how big the stacks were at the end.
struct WindowSample: Codable, Sendable {
    let firstStep: Int
    let steps: Int
    let seconds: Double
    let stackItemsAtEnd: Int
    let topInstructions: [String: Int]
}

/// The per-run diagnostic record ("profileRun"), serialized beside a
/// reproduction for offline study.
struct RunProfile: Codable, Sendable {
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
    let windows: [WindowSample]

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

    /// The instruction dominating the slowest window — the qualitative suspect.
    var slowestWindowCulprit: String {
        windows.max(by: { $0.seconds < $1.seconds })?
            .topInstructions.max(by: { $0.value < $1.value })?.key ?? "—"
    }

    /// A one-line qualitative diagnosis.
    var verdict: String {
        if hitInvariant { return "INVARIANT violation" }
        guard slowdownRatio > 10 || capped else { return "ok" }
        let mode = itemGrowth > 3
            ? String(format: "stack items grew %.1fx (count-driven, peak %d)", itemGrowth, peakStackItems)
            : "stack items ~flat (per-item / provenance-driven)"
        return String(
            format: "progressive slowdown %.0fx%@; %@; slowest window dominated by %@",
            slowdownRatio, capped ? " (capped)" : "", mode, slowestWindowCulprit
        )
    }
}

/// Duration → seconds as a Double.
func fuzzSeconds(_ d: Duration) -> Double {
    let (s, atto) = d.components
    return Double(s) + Double(atto) * 1e-18
}

/// Builds a loaded interpreter for one case under the given settings. Test-only.
func buildInterpreter(
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
func mutate(program: [any Item]) -> [any Item] {
    guard !program.isEmpty else { return [InstructionItem(RandomCode.randomInstruction())] }
    var p = program
    switch Int.random(in: 0..<10) {
    case 0...3:  // duplicate a random contiguous segment (amplifies repetition)
        let start = Int.random(in: 0..<p.count)
        let length = Int.random(in: 1...(p.count - start))
        p.insert(contentsOf: Array(p[start..<(start + length)]), at: start + length)
    case 4...5:  // duplicate the whole program
        p += p
    case 6...7:  // insert a random item
        p.insert(RandomCode.randomPushItem(), at: Int.random(in: 0...p.count))
    case 8:      // replace a random item
        p[Int.random(in: 0..<p.count)] = RandomCode.randomPushItem()
    default:     // occasional shrink, for variety
        p.remove(at: Int.random(in: 0..<p.count))
    }
    return p.count > 20_000 ? Array(p.prefix(20_000)) : p
}

/// Removes a random contiguous chunk from a program — the deletion step of
/// auto-simplification. Amplified programs are highly repetitive (grown by
/// duplication), so chunk deletion peels off the redundant copies quickly and
/// converges toward the minimal core that still exhibits the pathology.
func removeRandomChunk(_ program: [any Item]) -> [any Item] {
    guard program.count > 1 else { return program }
    let start = Int.random(in: 0..<program.count)
    let length = Int.random(in: 1...max(1, min(program.count - start, program.count / 3)))
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
func profiledRun(id: String, interpreter: Interpreter, windowSize: Int, maxSeconds: Double = .infinity) -> RunProfile {
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
        windows: windows
    )
}
