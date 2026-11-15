//
//  Distillation Experiment.swift
//  PlungeTests
//
//  How much of a random program's crux is constant work, and what distilling it
//  saves (2026-11-15). For the top item of every stack after a recording run of
//  each soak program:
//
//  - the crux's length and the distilled crux's, and the derived constants;
//  - the steps and time to replay each;
//  - what keeps work from distilling: the observed stand-ins left, by source;
//  - side-by-side examples, chosen among items that still read an input.
//
//  Programs are cut to 1,000 tokens and 3,000 steps, as in the fuzz test.
//
//  Off unless `PUSH_DISTILL` is set to the number of programs. Run:
//
//      PUSH_DISTILL=500 swift test -c release -Xswiftc -enable-testing \
//          --filter DistillationExperiment
//
//  The report goes to `PUSH_ATTRIBUTION_DIR` (or the temporary directory) as
//  `distillation.txt`.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct DistillationExperiment {

    nonisolated static let programs: Int? = ProcessInfo.processInfo.environment["PUSH_DISTILL"].flatMap(Int.init)

    struct Example {
        let label: String, crux: [any Item], distilled: [any Item], derived: Int
    }

    struct Totals {
        var items = 0, changed = 0, wholeConstant = 0, readsInput = 0
        var cruxLeaves = 0, distilledLeaves = 0, derived = 0, derivedFromSlots = 0
        var cruxSteps = 0, distilledSteps = 0
        var cruxTime = Duration.zero, distilledTime = Duration.zero
        var observedLeft: [String: Int] = [:]
        /// Items by how much of their crux is left: tenths of the original length.
        var keptTenths = [Int](repeating: 0, count: 11)
        var examples: [Example] = []
    }

    @Test(.enabled(if: DistillationExperiment.programs != nil))
    func `how much of a crux is constant work`() throws {
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        var totals = Totals()
        for seed in 1...UInt64(Self.programs ?? 0) {
            let made = DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers)
            // Bounded as the fuzz test is: whole soak programs at server-scale
            // limits ran this machine out of memory (2026-11-15).
            var settings = made.settings
            settings.recordsProvenance = true
            settings.stepLimit = min(settings.stepLimit, 3_000)
            let inty = Interpreter()
            inty.config = settings
            inty.load(inputs: made.inputs, constants: made.constants, program: Array(made.program.prefix(1_000)))
            inty.run(stepLimit: settings.stepLimit)
            for stack in PushStack.allStacks where stack != .error && stack != .exec {
                guard let item = inty.stacks[stack]!.first, !item.call.isEmpty, item.weight < 100_000 else { continue }
                Self.measure(item, label: "seed \(seed) .\(stack)", made, settings: settings, into: &totals)
            }
        }
        let report = Self.report(totals)
        let dir = ProcessInfo.processInfo.environment["PUSH_ATTRIBUTION_DIR"].map { URL(fileURLWithPath: $0) }
            ?? URL.temporaryDirectory
        try report.write(to: dir.appending(path: "distillation.txt"), atomically: true, encoding: .utf8)
        print(report)
    }

    static func measure(_ item: any Item, label: String, _ made: DualModeStress.Case,
                        settings: InterpreterSettings, into totals: inout Totals) {
        let crux = item.crux()
        let distilled = item.distilledCrux()
        totals.items += 1
        if distilled.isChanged { totals.changed += 1 }
        if distilled.program.count == 1 && distilled.isChanged { totals.wholeConstant += 1 }
        if item.cruxDependence.contains(.input) { totals.readsInput += 1 }
        totals.cruxLeaves += crux.count
        totals.distilledLeaves += distilled.program.count
        totals.derived += distilled.derived.count
        totals.derivedFromSlots += distilled.derived.count { !$0.slotsRead.isEmpty }
        totals.keptTenths[min(10, distilled.program.count * 10 / max(crux.count, 1))] += 1
        for leaf in distilled.program {
            guard let standIn = leaf.exactly(StandInItem.self), standIn.reason == .observed else { continue }
            totals.observedLeft[standIn.source.map { ".\($0.rawValue)" } ?? "interpreter", default: 0] += 1
        }
        let (steps, time) = replayCost(crux, made, settings)
        let (dSteps, dTime) = replayCost(distilled.program, made, settings)
        totals.cruxSteps += steps
        totals.distilledSteps += dSteps
        totals.cruxTime += time
        totals.distilledTime += dTime
        let legible = crux.count <= 120 && crux.count >= 3 * distilled.program.count
        if item.cruxDependence.contains(.input), distilled.isChanged, legible {
            totals.examples.append(Example(label: label, crux: crux, distilled: distilled.program,
                                           derived: distilled.derived.count))
        }
    }

    static func replayCost(_ program: [any Item], _ made: DualModeStress.Case,
                           _ settings: InterpreterSettings) -> (steps: Int, time: Duration) {
        let room = max(settings.stepLimit, program.count * 20)
        let redo = Interpreter()
        redo.config = settings.reconstructing
        redo.config.recordsProvenance = false
        redo.config.stepLimit = room
        let clock = ContinuousClock()
        let start = clock.now
        redo.load(inputs: made.inputs, constants: made.constants, program: program)
        redo.run(stepLimit: room)
        return (redo.counter, clock.now - start)
    }

    static func report(_ t: Totals) -> String {
        func pct(_ a: Int, _ b: Int) -> String { String(format: "%.1f%%", 100 * Double(a) / Double(max(b, 1))) }
        let seconds = { (d: Duration) in Double(d.components.seconds) + Double(d.components.attoseconds) * 1e-18 }
        var lines = [
            "Distillation over \(programs ?? 0) soak programs: \(t.items) items (the top of each stack)",
            "",
            "items changed: \(t.changed) (\(pct(t.changed, t.items))); "
                + "distilled to a single value: \(t.wholeConstant); "
                + "reading an input: \(t.readsInput)",
            "crux leaves \(t.cruxLeaves) → \(t.distilledLeaves) (\(pct(t.distilledLeaves, t.cruxLeaves)) kept)",
            "derived constants \(t.derived), of which \(t.derivedFromSlots) read constant slots",
            "replay steps \(t.cruxSteps) → \(t.distilledSteps) (\(pct(t.distilledSteps, t.cruxSteps)))",
            String(format: "replay time %.3f s → %.3f s", seconds(t.cruxTime), seconds(t.distilledTime)),
            "",
            "items by the share of their crux kept (tenths: 0 = under 10%, 10 = all of it):",
            "  " + t.keptTenths.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "  "),
            "",
            "what blocks distilling: observed stand-ins left in distilled cruxes, by source",
            "  " + t.observedLeft.sorted { $0.value > $1.value }.prefix(15).map { "\($0.key) \($0.value)" }
                .joined(separator: ", "),
            "",
            "examples (items that read an input, cut to a third or less):"
        ]
        for example in t.examples.sorted(by: { $0.crux.count > $1.crux.count }).prefix(12) {
            lines += [
                "",
                "── \(example.label): \(example.crux.count) → \(example.distilled.count) leaves, "
                    + "\(example.derived) derived constants",
                "  crux:      \(CodeItem(example.crux).pretty())",
                "  distilled: \(CodeItem(example.distilled).pretty())"
            ]
        }
        return lines.joined(separator: "\n")
    }
}
