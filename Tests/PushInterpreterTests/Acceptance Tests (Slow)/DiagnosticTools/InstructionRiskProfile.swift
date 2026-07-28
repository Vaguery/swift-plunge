//
//  InstructionRiskProfile.swift
//  PushInterpreterTests — DiagnosticTools
//
//  **Does a program containing this instruction end badly more often than one that
//  does not?**
//
//  The instrument behind the `.risky` tag. Before it existed, `.risky` was purely
//  inherited — "Clojush and Push3 say so" — which is honest but unfalsifiable, and
//  unfalsifiable judgments accrete. This is how one gets checked.
//
//  ## Why it was written
//
//  PlungeGP quarantined `.execY` **and `.execS`** behind a confirmation dialog, on
//  a comment reading "the Y and S combinators can recurse or duplicate the exec
//  stack without bound". That sentence is true of Y and half-true of S: S does
//  duplicate, but duplication without re-entry terminates. Measured over 2,500
//  random programs:
//
//      bucket       programs  step-limit   RUNAWAY   MEMORY
//      neither          2052       32.2%      0.6%      0.0%
//      execS only        222       35.6%      0.5%      0.0%
//      execY only        206       76.2%      0.5%      0.0%
//
//      execS  +3.4 pp vs baseline,  z =  1.0   — noise
//      execY +44.0 pp vs baseline,  z = 14.0   — overwhelming
//
//  So `.execS` is tagged nothing and `.execY` is `.risky`, and the number is now
//  the reason rather than the reputation.
//
//  ## What it can and cannot show
//
//  It measures **correlation between presence and a bad ending** in random
//  programs. That is not the same as "destabilises an evolving population", which
//  is what `.risky` is finally about and which only a long search can answer. Read
//  a large z as grounds for the tag, and a small one as grounds for withholding it
//  — not as proof either way.
//
//  Note the RUNAWAY rate barely moves even for `.execY`. Its loops exhaust the step
//  limit rather than tripping the guard, which is worth knowing about the guard as
//  much as about `.execY`.
//

import Foundation
import Testing
@testable import PushInterpreter


@Suite @MainActor
struct InstructionRiskProfile {

    nonisolated static let disabled = true

    /// How a bucket of programs ended.
    struct Ending {
        var programs = 0
        var hitStepLimit = 0
        var runaway = 0
        var memory = 0

        var stepLimitRate: Double { programs == 0 ? 0 : Double(hitStepLimit) / Double(programs) }

        /// Standard normal deviate against a baseline bucket — how many standard
        /// errors the difference is. Under 2 is noise; over 5 is not.
        func z(against baseline: Ending) -> Double {
            guard programs > 0, baseline.programs > 0 else { return 0 }
            let p = stepLimitRate, q = baseline.stepLimitRate
            let se = ((p * (1 - p) / Double(programs))
                      + (q * (1 - q) / Double(baseline.programs))).squareRoot()
            return se == 0 ? 0 : (p - q) / se
        }
    }

    /// Run a corpus and split it by whether each program contains `subject`,
    /// anywhere including inside nested blocks.
    func profile(_ subject: PushInstruction,
                 seeds: Int = 50,
                 casesPerSeed: Int = 50) -> (with: Ending, without: Ending) {
        var settings = InterpreterSettings()
        settings.stepLimit = 3_000
        var with = Ending(), without = Ending()

        for seed in CruxSweep.spacedSeeds(seeds) {
            fuzzRNG = SeededRNG(seed: seed)
            for _ in 0..<casesPerSeed {
                let program = FibonacciGenome.translate(RandomCode.randomProgram(150))

                var present = false
                func scan(_ items: [any Item]) {
                    for item in items {
                        if (item as? InstructionItem)?.value == subject { present = true }
                        if let block = item as? CodeItem { scan(block.value) }
                    }
                }
                scan(program)

                let inty = Interpreter()
                inty.config = settings
                inty.load(program: program)
                RandomCode.setRandomInputs(in: inty)
                RandomCode.setRandomConstants(in: inty)
                inty.run(stepLimit: settings.stepLimit)

                var bucket = present ? with : without
                bucket.programs += 1
                if !inty.stacks[.exec]!.isEmpty { bucket.hitStepLimit += 1 }
                let messages = inty.stacks[.error]!.map { ($0 as? ErrorItem)?.value ?? "" }
                if messages.contains(where: { $0.contains(Interpreter.runawayMarker) }) { bucket.runaway += 1 }
                if messages.contains(where: { $0.contains(Interpreter.memoryMarker) }) { bucket.memory += 1 }
                if present { with = bucket } else { without = bucket }
            }
        }
        return (with, without)
    }


    /// **The evidence behind `.risky`.** Run it before tagging anything, and before
    /// trusting a tag someone else added.
    ///
    /// Every currently-`.risky` instruction is profiled, plus `.execS` as the
    /// control — the one that looks like it belongs and does not.
    @Test(.disabled(if: InstructionRiskProfile.disabled))
    func `profile the risky candidates`() {
        let candidates = Interpreter.instructions(declaring: .risky)
            .union([.execS, .execK])
            .sorted { $0.rawValue < $1.rawValue }

        print("=== RISK PROFILE (2500 programs each) ===")
        print("instruction     tagged   n(with)  step-limit   baseline        z")
        for name in candidates {
            let (with, without) = profile(name)
            let tagged = Interpreter.declaredTags(of: name).contains(.risky) ? "risky " : "  --  "
            print(String(format: "%@ %@ %8d %10.1f%% %10.1f%% %8.1f",
                         name.rawValue.padding(toLength: 15, withPad: " ", startingAt: 0),
                         tagged, with.programs,
                         100 * with.stepLimitRate, 100 * without.stepLimitRate,
                         with.z(against: without)))
        }
        fflush(stdout)
    }
}
