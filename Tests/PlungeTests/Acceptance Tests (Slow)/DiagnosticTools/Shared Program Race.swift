//
//  Shared Program Race.swift
//  PlungeTests
//
//  The app's evaluation pattern, under the Thread Sanitizer: one genome's
//  program (the same item instances) run on many concurrent tasks, each with its
//  own interpreter, as `evaluatePairingsStream` does. The dual-mode soak runs
//  each program on one thread only, so it cannot see a race on shared items.
//  Off unless `PUSH_RACE_SEEDS` is set (a count of programs; `PUSH_RACE_FIRST`
//  picks the first seed). Run:
//
//      PUSH_RACE_SEEDS=200 swift test --sanitize=thread --filter SharedProgramRace
//

import Foundation
@testable import Plunge
import Testing

struct SharedProgramRace {

    static let count = ProcessInfo.processInfo.environment["PUSH_RACE_SEEDS"].flatMap(Int.init)
    static let first = ProcessInfo.processInfo.environment["PUSH_RACE_FIRST"].flatMap(UInt64.init) ?? 0

    @Test(.enabled(if: SharedProgramRace.count != nil))
    func `one program shared by concurrent interpreters`() async {
        guard let count = Self.count else { return }
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        let clock = ContinuousClock()
        for seed in Self.first..<(Self.first + UInt64(count)) {
            let c = DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers)
            // The app's regimes are the language defaults; keep the runs short.
            let settings = {
                var settings = Interpreter.defaultSettings
                settings.stepLimit = min(c.settings.stepLimit, 2_000)
                return settings
            }()
            let started = clock.now
            await withTaskGroup(of: Void.self) { group in
                for lane in 0..<12 {
                    group.addTask {
                        let inty = Interpreter()
                        inty.config = settings
                        inty.config.recordsProvenance = lane % 2 == 1
                        inty.load(inputs: c.inputs, constants: c.constants, program: c.program)
                        inty.run()
                    }
                }
            }
            let seconds = (clock.now - started) / .seconds(1)
            if seconds > 5 { print("seed \(seed): \(seconds) s") }
        }
        print("shared-program race: \(count) programs from seed \(Self.first)")
    }
}
