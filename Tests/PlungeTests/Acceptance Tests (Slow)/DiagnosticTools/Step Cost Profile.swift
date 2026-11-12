//
//  Step Cost Profile.swift
//  PlungeTests
//
//  Where a slow soak program's time goes: runs one `DualModeStress` seed step by
//  step and totals the time by the instruction on top of `.exec`, with the
//  sizes it met. Off unless `PUSH_PROFILE_SEED` is set (optionally
//  `PUSH_PROFILE_RECORDING=0`). Run in release:
//
//      PUSH_PROFILE_SEED=17218 swift test -c release -Xswiftc -enable-testing --filter StepCostProfile
//

import Foundation
@testable import Plunge
import Testing

struct StepCostProfile {

    static let seed = ProcessInfo.processInfo.environment["PUSH_PROFILE_SEED"].flatMap(UInt64.init)

    @Test(.enabled(if: StepCostProfile.seed != nil))
    func `one soak program's time by instruction`() async {
        guard let seed = Self.seed else { return }
        let recording = ProcessInfo.processInfo.environment["PUSH_PROFILE_RECORDING"] != "0"
        let report = await Task.detached { Self.profile(seed: seed, recording: recording) }.value
        print(report)
    }

    static func profile(seed: UInt64, recording: Bool) -> String {
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        let c = DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers)
        let inty = Interpreter()
        inty.config = c.settings
        inty.config.recordsProvenance = recording
        inty.load(inputs: c.inputs, constants: c.constants, program: c.program)
        inty.recomputeLiveWeight()

        struct Tally { var count = 0; var seconds = 0.0; var worst = 0.0; var worstAt = 0; var depths = "" }
        var tallies: [String: Tally] = [:]
        let clock = ContinuousClock()
        let start = clock.now
        while inty.counter < inty.config.stepLimit && !inty.stacks[.exec]!.isEmpty {
            let top = inty.stacks[.exec]!.first
            let name = top?.exactly(InstructionItem.self).map { "\($0.value)" } ?? "\(type(of: top!))"
            let before = clock.now
            inty.step()
            let elapsed = clock.now - before
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            var tally = tallies[name, default: Tally()]
            tally.count += 1
            tally.seconds += seconds
            if seconds > tally.worst {
                tally.worst = seconds
                tally.worstAt = inty.counter
                tally.depths = PushStack.allStacks.compactMap { stack in
                    let n = inty.stacks[stack]?.count ?? 0
                    return n > 100 ? "\(stack) \(n)" : nil
                }.joined(separator: ", ")
            }
            tallies[name] = tally
        }
        let total = clock.now - start
        var lines = ["seed \(seed) (\(c.regime)), recording \(recording): \(inty.counter) steps in \(total), "
                     + "live weight \(inty.liveWeight)"]
        for (name, tally) in tallies.sorted(by: { $0.value.seconds > $1.value.seconds }).prefix(25) {
            lines.append(String(format: "%9.2f s  %8d×  worst %7.3f s at step %d  %@  [%@]", tally.seconds,
                                tally.count, tally.worst, tally.worstAt, name, tally.depths))
        }
        return lines.joined(separator: "\n")
    }
}
