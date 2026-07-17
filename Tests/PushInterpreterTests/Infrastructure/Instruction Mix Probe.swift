//
//  Instruction Mix Probe.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/17/26.
//
//  A diagnostic, not an assertion. **What proportions of constants, inputs,
//  furniture and work make a random program do something?**
//
//  Nobody knows. The Plushy generator's proportions were picked years ago and
//  were not even what they looked like, since constants and inputs live *inside*
//  `Interpreter.language` — its "40% other" was really ~33% other, ~31% constant
//  and ~26% input. This is the first attempt to ask the question on purpose.
//
//  Ten mixes, orthogonal by design: the balanced centre, then each tag
//  **enriched** (a third of the draw) and **depleted** (a ninth) in turn, so a
//  difference can be attributed to the one thing that moved. Plus
//  `language-shaped` as a control — what you get from `language.keys.random()`,
//  which is 34% furniture and nobody's decision.
//
//  Two measures, and the second is the interesting one:
//
//  - **starvation** — how often an instruction wants an argument that is not
//    there. Push's dominant failure mode (Design Principles §5); the companion
//    "Argument Starvation Probe" measures it per instruction, this one per mix.
//  - **crux size** — how big the *explanations* are. This is the proxy for
//    whether anything **composed**: a crux of 1 is a value that was handed over
//    and sat there; a crux of 40 is a value that was computed from other computed
//    values. Since the whole project is aimed at `crux()` producing runnable
//    source that reproduces an evolved item, "did values compose?" is closer to
//    the real question than "did it error?".
//
//  Disabled and run alone, like every fuzz test here: `fuzzRNG` is a shared
//  global and Swift Testing runs suites in parallel, so a concurrent drawer
//  breaks the seed.
//

import Foundation
@testable import PushInterpreter
import Testing

@Suite @MainActor
struct InstructionMixProbe {

    nonisolated static let disabledTests = true

    struct Tally {
        var programs = 0
        var attempts = 0
        /// Attempts by instructions that *could* starve — i.e. that ask for
        /// anything at all.
        ///
        /// **Without this the comparison is rigged.** 127 of 526 instructions need
        /// nothing (constants, inputs, and the combinators that measure or clear),
        /// so a mix carrying more of them scores a lower starvation rate
        /// mechanically, whatever it does to the programs. Half of `equal`'s draw
        /// is environment tokens; only 17% of `language-shaped`'s is. Comparing
        /// their raw rates compares the dilution, not the language.
        var starvable = 0
        var starved = 0
        /// Which stack the plan gave up at, when one did.
        var blamed: [PushStack: Int] = [:]
        var steps = 0
        var errors = 0

        /// Every crux length seen, in items, across every item left standing.
        var cruxes: [Int] = []

        var starvationRate: Double { attempts == 0 ? 0 : Double(starved) / Double(attempts) }
        /// The honest one: of the attempts that could have starved, how many did.
        var conditionalRate: Double { starvable == 0 ? 0 : Double(starved) / Double(starvable) }
        var maxCrux: Int { cruxes.max() ?? 0 }
        var meanCrux: Double {
            cruxes.isEmpty ? 0 : Double(cruxes.reduce(0, +)) / Double(cruxes.count)
        }
        /// The share of surviving items that are more than a bare literal — the
        /// cheapest honest reading of "something composed".
        var composedShare: Double {
            cruxes.isEmpty ? 0 : Double(cruxes.filter { $0 > 1 }.count) / Double(cruxes.count)
        }
    }

    @Test(.disabled(if: InstructionMixProbe.disabledTests))
    func `what does each instruction mix produce`() {
        let seed: UInt64 = 20_260_717
        let cases = 300
        let genomeSize = 120

        var settings = InterpreterSettings()
        settings.stepLimit = 2_000

        var results: [(name: String, tally: Tally)] = []

        for (name, mix) in InstructionMix.standardSweep {
            // Every mix meets the same seed, so they differ by the mix and not by
            // the luck of the draw.
            fuzzRNG = SeededRNG(seed: seed)
            var tally = Tally()

            for _ in 0..<cases {
                let inty = Interpreter()
                inty.config = settings
                inty.load(program: FibonacciGenome.translate(
                    RandomCode.randomProgram(genomeSize, mix: mix)
                ))
                RandomCode.setRandomConstants(in: inty)
                RandomCode.setRandomInputs(in: inty)
                tally.programs += 1

                // `run()`'s loop, opened up so the plan can be asked before each
                // instruction fires — the same technique the starvation probe uses.
                while inty.counter < inty.config.stepLimit && !inty.stacks[.exec]!.isEmpty {
                    if let next = inty.stacks[.exec]!.first as? InstructionItem,
                       let behavior = inty.behaviors[next.value] {
                        tally.attempts += 1
                        if !Interpreter.alwaysSatisfied.contains(next.value) {
                            tally.starvable += 1
                        }
                        let token = inty.stacks[.exec]!.removeFirst()
                        let plan = behavior.plan(on: inty)
                        inty.stacks[.exec]!.prepend(token)
                        if case .short(let stack) = plan {
                            tally.starved += 1
                            tally.blamed[stack, default: 0] += 1
                        }
                    }
                    inty.step()
                }

                tally.steps += inty.counter
                tally.errors += inty.stacks[.error]!.count

                // `.code` is skipped: a Fibonacci program's unconsumed blocks are
                // still sitting there, each its own literal crux, and counting them
                // would swamp the composition measure with genome artifacts.
                for stack in PushStack.allCases
                where stack != .error && stack != .exec && stack != .code {
                    for item in inty.stacks[stack]! {
                        tally.cruxes.append(item.crux().count)
                    }
                }
            }
            results.append((name, tally))
        }

        report(results, seed: seed, cases: cases, genomeSize: genomeSize)
        #expect(results.count == InstructionMix.standardSweep.count)
    }


    func report(_ results: [(name: String, tally: Tally)], seed: UInt64, cases: Int, genomeSize: Int) {
        print("\n=== instruction mixes (seed \(seed), \(cases) programs × \(genomeSize) genes, Fibonacci) ===")
        print("starved:     share of ALL attempts wanting an argument that wasn't there")
        print("ofStarvable: share of attempts BY INSTRUCTIONS THAT ASK FOR ANYTHING —")
        print("             127 of 526 can never starve, and a mix heavy in them scores")
        print("             a low raw rate for free. This is the comparable number.")
        print("crux:    size of the explanation of a surviving item, in items —")
        print("         max is the deepest thing anything built; >1 is the share that")
        print("         are more than a bare literal, i.e. that COMPOSED\n")

        let header = "mix".padding(toLength: 18, withPad: " ", startingAt: 0)
            + "  starved  ofStarvable   maxCrux  meanCrux    >1  steps/prog"
        print(header)
        print(String(repeating: "-", count: header.count))

        for (name, t) in results {
            var line = name.padding(toLength: 18, withPad: " ", startingAt: 0)
            line += String(format: "  %6.1f%%", t.starvationRate * 100)
            line += String(format: "  %10.1f%%", t.conditionalRate * 100)
            line += String(format: "  %8d", t.maxCrux)
            line += String(format: "  %8.1f", t.meanCrux)
            line += String(format: "  %4.0f%%", t.composedShare * 100)
            line += String(format: "  %10.0f", Double(t.steps) / Double(t.programs))
            print(line)
        }

        print("\n--- which stack was empty when a plan gave up? (share of starved attempts) ---")
        for (name, t) in results {
            let total = max(1, t.starved)
            let top = t.blamed.sorted { $0.value > $1.value }.prefix(4)
                .map { "\($0.key):\(Int(Double($0.value) / Double(total) * 100))%" }
                .joined(separator: " ")
            print("\(name.padding(toLength: 18, withPad: " ", startingAt: 0))\(top)")
        }
        print("")
    }
}
