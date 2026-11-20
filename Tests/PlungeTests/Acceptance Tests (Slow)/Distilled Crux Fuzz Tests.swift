//
//  Distilled Crux Fuzz Tests.swift
//  PlungeTests
//
//  The distilled crux's promises, over random programs (2026-11-15). For the
//  top item of every stack after a recording run:
//
//  1. replaying its distilled crux with the same inputs and constants gives its
//     value, whenever replaying its crux does;
//  2. on other inputs, the distilled crux and the crux give the same value;
//  3. the distilled crux is never longer than the crux;
//  4. distilling the replayed item gives the same distilled crux;
//  5. its abstract, skeleton and tunable cruxes, in either reading, filled with
//     what was there (controls neutral), give the value too;
//  6. its crux with its loops minimized on this case and another gives the
//     value.
//
//  `PUSH_DISTILL_FUZZ` sets the number of programs (default 150).
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct DistilledCruxFuzzTests {

    nonisolated static let programs =
        ProcessInfo.processInfo.environment["PUSH_DISTILL_FUZZ"].flatMap(Int.init) ?? 150

    struct Tally {
        var items = 0, changed = 0, cruxLeaves = 0, distilledLeaves = 0
        var sameValue = 0, otherInputs = 0, fixedPoints = 0, inconclusive = 0, abstracted = 0, overLimit = 0
        var withLoops = 0, loopsShortened = 0, passesSaved = 0
        var failures: [String] = []
    }

    static func replay(_ program: [any Item], inputs: [PushInstruction: any Item],
                       constants: [PushInstruction: any Item], settings: InterpreterSettings,
                       on stack: PushStack) -> (any Item)? {
        // Sized by the work the program will do: a rolled crux replays every pass
        // of its loops, which can take more steps than the program that made the
        // value (swift-plunge #70).
        let room = max(settings.stepLimit, CruxCompression.replaySteps(program) * 2 + program.count)
        let redo = Interpreter.recordingProvenance()
        redo.config = settings.reconstructing
        redo.config.recordsProvenance = true
        redo.config.stepLimit = room
        redo.load(inputs: inputs, constants: constants, program: program)
        redo.run(stepLimit: room)
        guard redo.stacks[.exec]!.isEmpty else { return nil }
        return redo.stacks[stack]!.first
    }

    @Test func `distilled cruxes keep their promises on random programs`() {
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        var tally = Tally()
        for seed in (1...UInt64(Self.programs)).map({ $0 &+ FuzzSeed.shift }) {
            let made = DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers)
            let other = DualModeStress.makeCase(seed: seed &+ 7_777, instructions: instructions, loopers: loopers)
            var settings = made.settings
            settings.stepLimit = min(settings.stepLimit, 3_000)
            settings.recordsProvenance = true
            let inty = Interpreter.recordingProvenance()
            inty.config = settings
            inty.load(inputs: made.inputs, constants: made.constants, program: Array(made.program.prefix(400)))
            inty.run(stepLimit: settings.stepLimit)
            for stack in PushStack.allStacks where stack != .error && stack != .exec {
                guard let item = inty.stacks[stack]!.first, !item.call.isEmpty, item.weight < 100_000 else { continue }
                Self.check(item, on: stack, Setting(made: made, other: other.inputs, settings: settings), into: &tally)
            }
        }
        let ratio = Double(tally.distilledLeaves) / Double(max(tally.cruxLeaves, 1))
        print("""
            Distilled cruxes over \(Self.programs) programs: \(tally.items) items, \(tally.changed) changed; \
            leaves \(tally.cruxLeaves) → \(tally.distilledLeaves) (\(String(format: "%.1f%%", 100 * ratio))); \
            same value \(tally.sameValue), on other inputs \(tally.otherInputs), fixed points \(tally.fixedPoints), \
            inconclusive \(tally.inconclusive); abstract, skeleton and tunable cruxes refilled \(tally.abstracted), \
            over the size limit \(tally.overLimit); items with loops \(tally.withLoops), loops shortened \
            \(tally.loopsShortened), passes saved \(tally.passesSaved)
            """)
        #expect(tally.failures.isEmpty, "\(tally.failures.prefix(10).joined(separator: "\n"))")
        #expect(tally.changed > 0)
    }

    /// One run's case, the inputs of another, and the settings both replay under.
    struct Setting {
        let made: DualModeStress.Case
        let other: [PushInstruction: any Item]
        let settings: InterpreterSettings
    }

    static func check(_ item: any Item, on stack: PushStack, _ setting: Setting, into tally: inout Tally) {
        let (made, other, settings) = (setting.made, setting.other, setting.settings)
        let crux = item.crux()
        let distilled = item.distilledCrux()
        let label = "seed \(made.seed) .\(stack)"
        tally.items += 1
        tally.cruxLeaves += crux.count
        tally.distilledLeaves += distilled.program.count
        if distilled.isChanged { tally.changed += 1 }
        if distilled.program.count > crux.count {
            tally.failures.append("\(label): distilled \(distilled.program.count) > crux \(crux.count)")
        }
        func run(_ program: [any Item], _ inputs: [PushInstruction: any Item]) -> (any Item)? {
            replay(program, inputs: inputs, constants: made.constants, settings: settings, on: stack)
        }
        // 1. The same value, whenever the crux itself reproduces it.
        guard let original = run(crux, made.inputs), original.pretty() == item.pretty() else {
            tally.inconclusive += 1
            return
        }
        guard let again = run(distilled.program, made.inputs) else {
            tally.failures.append("\(label): the distilled crux didn't finish")
            return
        }
        if again.pretty() == item.pretty() {
            tally.sameValue += 1
        } else {
            tally.failures.append("\(label): \(item.pretty().prefix(60)) ← distilled gave \(again.pretty().prefix(60))")
        }
        // 4. A fixed point.
        if CodeItem(again.distilledCrux().program).pretty() == CodeItem(distilled.program).pretty() {
            tally.fixedPoints += 1
        } else {
            tally.failures.append("\(label): distilling the replay changed the distilled crux")
        }
        checkForms(of: distilled, value: item.pretty(), label: label, run: { run($0, made.inputs) }, into: &tally)
        checkLoops(of: (item, stack), setting, label: label, run: { run($0, made.inputs) }, into: &tally)
        // 2. Other inputs.
        if let theirs = run(crux, other), let ours = run(distilled.program, other) {
            if theirs.pretty() == ours.pretty() {
                tally.otherInputs += 1
            } else {
                tally.failures.append("\(label) other inputs: crux \(theirs.pretty().prefix(50)) ≠ "
                                      + "distilled \(ours.pretty().prefix(50))")
            }
        }
    }

    /// 5. The abstract, skeleton and tunable cruxes, refilled, give the value.
    static func checkForms(of distilled: DistilledCrux, value: String, label: String,
                           run: ([any Item]) -> (any Item)?, into tally: inout Tally) {
        let forms: [(String, (AbstractCrux.Reading) -> AbstractCrux?)] = [
            ("abstract", { distilled.abstracted($0) }), ("skeleton", { distilled.skeleton($0) }),
            ("tunable", { distilled.tunable($0, sites: [.inputs, .output]) })
        ]
        for (form, make) in forms {
          for reading in [AbstractCrux.Reading.perDistinct, .perUse] {
            guard let abstract = make(reading), let fillers = abstract.originalFillers else {
                tally.overLimit += 1
                continue
            }
            let refilled = run(abstract.program(filling: fillers))
            if refilled?.pretty() == value {
                tally.abstracted += 1
            } else {
                tally.failures.append("\(label) \(form) \(reading): refilled gave "
                                      + "\(refilled.map { String($0.pretty().prefix(50)) } ?? "nothing")")
            }
          }
        }
    }

    /// 6. The crux with its loops minimized on this case and another gives the value.
    static func checkLoops(of found: (item: any Item, stack: PushStack), _ setting: Setting, label: String,
                           run: ([any Item]) -> (any Item)?, into tally: inout Tally) {
        let (made, other, settings) = (setting.made, setting.other, setting.settings)
        let (item, stack) = found
        if let minimized = item.minimizingLoops(on: [(made.inputs, made.constants), (other, made.constants)],
                                                settings: settings, stack: stack) {
            if minimized.loops > 0 { tally.withLoops += 1 }
            tally.loopsShortened += minimized.changes.count
            tally.passesSaved += minimized.changes.reduce(0) { $0 + $1.from - $1.to }
            if run(minimized.program)?.pretty() != item.pretty() {
                tally.failures.append("\(label): the loop-minimized crux lost the value")
            }
        }
    }
}
