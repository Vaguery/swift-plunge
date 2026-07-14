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
    let totalSeconds: Double
    let errorCount: Int
    let hitInvariant: Bool
    let hitSizeLimit: Bool
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
        guard slowdownRatio > 10 else { return "ok" }
        let mode = itemGrowth > 3
            ? String(format: "stack items grew %.1fx (count-driven)", itemGrowth)
            : "stack items ~flat (per-item / provenance-driven)"
        return String(
            format: "progressive slowdown %.0fx; %@; slowest window dominated by %@",
            slowdownRatio, mode, slowestWindowCulprit
        )
    }
}

/// Duration → seconds as a Double.
func fuzzSeconds(_ d: Duration) -> Double {
    let (s, atto) = d.components
    return Double(s) + Double(atto) * 1e-18
}

/// Builds a loaded interpreter for one case. Test-only.
func buildInterpreter(
    program: [any Item],
    constants: [PushInstruction: any Item],
    inputs: [PushInstruction: any Item],
    stepLimit: Int
) -> Interpreter {
    let interpreter = Interpreter()
    interpreter.config.stepLimit = stepLimit
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

/// Steps `interpreter` to its step limit (or exhaustion), one window at a time,
/// recording per-window wall time, the instruction histogram, and total stack
/// size. Reads interpreter internals, so it lives in the test target and does
/// not alter the production run loop.
func profiledRun(id: String, interpreter: Interpreter, windowSize: Int) -> RunProfile {
    let clock = ContinuousClock()
    var windows: [WindowSample] = []
    var histogram: [PushInstruction: Int] = [:]
    var windowFirstStep = 0
    var windowStart = clock.now
    var step = 0
    let limit = interpreter.config.stepLimit

    func closeWindow() {
        let now = clock.now
        let items = interpreter.stacks.values.reduce(0) { $0 + $1.count }
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
        if step - windowFirstStep >= windowSize { closeWindow() }
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
        totalSeconds: windows.reduce(0) { $0 + $1.seconds },
        errorCount: errors.count,
        hitInvariant: hitInvariant,
        hitSizeLimit: hitSizeLimit,
        windows: windows
    )
}
