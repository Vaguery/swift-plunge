//
//  Argument Starvation Probe.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/16/26.
//
//  A diagnostic, not an assertion. It runs a lot of random programs and asks:
//  **how often does each instruction fail for want of arguments, and which stack
//  was empty when it did?**
//
//  Argument starvation — an instruction wants an argument, the stack is empty,
//  nothing happens — is one of Push's real design flaws (Design Principles, §5),
//  and much of the iterator work is aimed at it. This measures it.
//
//  It does not read the `.error` stack. An error only says "`intAdd` missing
//  args"; it does not say *which* of the stacks was short, and it says nothing
//  about the attempts that succeeded — so a raw error count tells you which
//  instructions are common, not which are starved. Instead this steps the
//  interpreter by hand and inspects it in the instant **before** each instruction
//  fires, which gives an exact denominator (every attempt) and exact blame (every
//  stack that was short).
//
//  **This reads `behavior.needs`, so it can only see what an instruction declares.**
//  That used to hide a great deal: five combinator families reached into a stack
//  they never named in `takes:`, so `needs` could not see it, so this probe
//  under-reported sixty behaviors — and `isSatisfied` answered `true` in the very
//  act of failing. The measure and the bug had the same blind spot. `alsoNeeds:`
//  fixed it at the source, which is the right place: `needs` is now honest, so this
//  is too.
//
//  **One blind spot remains, and it is narrow: a dynamic requirement.**
//  `.vecXConstruct` wants N scalars where N is the *length of its other argument*,
//  which no static declaration can express. It keeps the all-or-nothing bargain by
//  hand instead — the only Behavior that has to — so its starvation is still
//  under-reported here. If a second such instruction ever appears, that is the
//  moment to make `needs` a function of the interpreter rather than a constant.
//
//  Disabled and run alone, like every fuzz test here: `fuzzRNG` is a shared
//  global and Swift Testing runs suites in parallel, so a concurrent drawer breaks
//  the seed. See `CruxFuzzTests.disabledTests`.
//
//  Companion to "Notes on Push/Stack economics.md", which measures the same
//  problem from the other end — which stacks the *language* fills and drains.
//

import Foundation
@testable import PushInterpreter
import Testing

@Suite @MainActor
struct ArgumentStarvationProbe {

    nonisolated static let disabledTests = true

    /// What one instruction did across every random program.
    ///
    /// Two denominators, because they answer different questions and disagree
    /// wildly:
    ///
    /// - **attempts** counts every firing. An instruction inside a loop body fires
    ///   once per pass, so this is dominated by whichever programs happened to
    ///   loop: `boolPop` starving 123 times can be one program going round 123
    ///   times with an empty `.bool`, not 123 programs.
    /// - **programs** counts each instruction once per program, at its *first*
    ///   firing. That asks the unweighted question — when a random program reaches
    ///   this instruction, is anything there for it? — and is the one to trust for
    ///   starvation.
    struct Tally {
        var attempts = 0
        var starved = 0
        var programs = 0
        var starvedFirst = 0
        /// Which of its stacks were empty when it failed, and how often.
        var blamed: [PushStack: Int] = [:]
        var rate: Double { attempts == 0 ? 0 : Double(starved) / Double(attempts) }
        var programRate: Double { programs == 0 ? 0 : Double(starvedFirst) / Double(programs) }
    }

    @Test(.disabled(if: ArgumentStarvationProbe.disabledTests))
    func `how often does each instruction starve`() {
        let seed: UInt64 = 20_260_716
        fuzzRNG = SeededRNG(seed: seed)
        let cases = 2_000
        let programItems = 120

        var settings = InterpreterSettings()
        settings.stepLimit = 2_000

        var tallies: [PushInstruction: Tally] = [:]
        /// How often each stack was empty-when-wanted, across all instructions.
        var shortfall: [PushStack: Int] = [:]
        /// How often each stack was *asked for* at all, so shortfall has a rate.
        var demand: [PushStack: Int] = [:]
        var totalAttempts = 0
        var totalStarved = 0

        for _ in 0..<cases {
            let inty = Interpreter()
            inty.config = settings
            inty.load(program: Plushy.plushy2push(RandomCode.randomPlushy(programItems)))
            RandomCode.setRandomInputs(in: inty)
            RandomCode.setRandomConstants(in: inty)

            var seenHere: Set<PushInstruction> = []

            // `run()`'s loop, opened up so we can look between steps.
            while inty.counter < inty.config.stepLimit && !inty.stacks[.exec]!.isEmpty {
                if let next = inty.stacks[.exec]!.first as? InstructionItem,
                   let behavior = inty.behaviors[next.value] {
                    var tally = tallies[next.value] ?? Tally()
                    tally.attempts += 1
                    totalAttempts += 1
                    let firstHere = seenHere.insert(next.value).inserted
                    if firstHere { tally.programs += 1 }

                    // The instant before it fires: which of the stacks it wants
                    // cannot supply what it wants?
                    //
                    // `.exec` is counted one short, because the instruction we are
                    // about to run is still sitting on it and `step` pops it before
                    // the Behavior gathers anything. Without this, every
                    // `.exec`-taking instruction looks better fed than it is.
                    var short: [PushStack] = []
                    for (stack, wanted) in behavior.needs {
                        demand[stack, default: 0] += 1
                        let available = (inty.stacks[stack]?.count ?? 0) - (stack == .exec ? 1 : 0)
                        if available < wanted { short.append(stack) }
                    }
                    if !short.isEmpty {
                        tally.starved += 1
                        totalStarved += 1
                        if firstHere { tally.starvedFirst += 1 }
                        for stack in short {
                            tally.blamed[stack, default: 0] += 1
                            shortfall[stack, default: 0] += 1
                        }
                    }
                    tallies[next.value] = tally
                }
                inty.step()
            }
        }

        func log(_ s: String) { print(s); fflush(stdout) }
        // `String(format:)` with `%s` takes a C string, not a Swift one, and
        // silently prints nothing useful — hence plain padding.
        func pad(_ s: String, _ w: Int) -> String {
            s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
        }
        func rpad(_ s: String, _ w: Int) -> String {
            s.count >= w ? s : String(repeating: " ", count: w - s.count) + s
        }
        func pct(_ n: Int, _ d: Int) -> String {
            d == 0 ? "—" : String(format: "%.1f%%", 100 * Double(n) / Double(d))
        }

        log("=== argument starvation (seed \(seed), \(cases) programs × \(programItems) tokens) ===")
        log("\(totalAttempts) instruction attempts, \(totalStarved) starved "
            + "(\(pct(totalStarved, totalAttempts)))")
        // The aggregate is loop-weighted and so nearly meaningless on its own: an
        // instruction inside a body runs once per pass, one outside runs once per
        // program. Show who dominates, so the per-instruction rates below are read
        // as the real answer.
        let busiest = tallies.sorted { $0.value.attempts > $1.value.attempts }.prefix(3)
        log("busiest: " + busiest.map { "\($0.key.rawValue) \($0.value.attempts)" }.joined(separator: ", ")
            + "  — the aggregate above is dominated by whatever runs inside loops")
        log("")

        log("--- which stack is empty when something wants it? ---")
        log(pad("stack", 12) + rpad("asked", 10) + rpad("empty", 10) + rpad("rate", 9))
        for stack in PushStack.allStacks {
            let asked = demand[stack] ?? 0
            guard asked > 0 else { continue }
            let empty = shortfall[stack] ?? 0
            log(pad("\(stack)", 12) + rpad("\(asked)", 10) + rpad("\(empty)", 10)
                + rpad(pct(empty, asked), 9))
        }
        log("")

        // Only instructions that actually want something: a constant or an input
        // takes no arguments and can never starve, so listing them is noise.
        let hungry = tallies.filter { !(Interpreter.language[$0.key]?.parameters.isEmpty ?? true) }
        let ranked = hungry
            .filter { $0.value.programs >= 12 }
            .sorted {
                ($0.value.programRate, Double($0.value.programs))
                    > ($1.value.programRate, Double($1.value.programs))
            }

        log("--- hungriest instructions (seen in ≥12 programs, by per-program rate) ---")
        log("`progs`/`hungry` count each instruction ONCE per program, at its first")
        log("firing — the unweighted question. `tried`/`starved` count every firing,")
        log("so they are inflated by whichever programs happened to loop.")
        log("")
        log(pad("instruction", 26) + rpad("progs", 6) + rpad("hungry", 7) + rpad("rate", 8)
            + rpad("tried", 8) + rpad("starved", 9) + "   blamed stacks")
        for (name, tally) in ranked.prefix(28) {
            let blame = tally.blamed
                .sorted { $0.value > $1.value }
                .map { "\($0.key):\($0.value)" }
                .joined(separator: " ")
            log(pad(name.rawValue, 26) + rpad("\(tally.programs)", 6)
                + rpad("\(tally.starvedFirst)", 7)
                + rpad(pct(tally.starvedFirst, tally.programs), 8)
                + rpad("\(tally.attempts)", 8) + rpad("\(tally.starved)", 9)
                + "   " + blame)
        }
        log("")

        log("--- best fed (seen in ≥12 programs) ---")
        for (name, tally) in ranked.suffix(10).reversed() {
            log(pad(name.rawValue, 26) + rpad("\(tally.programs)", 6)
                + rpad("\(tally.starvedFirst)", 7)
                + rpad(pct(tally.starvedFirst, tally.programs), 8))
        }

        // Guards the probe itself, not the language: a generator change that
        // stopped producing instructions would make all of the above vacuous.
        #expect(totalAttempts > 1_000, "only \(totalAttempts) attempts — is the generator still working?")
        #expect(!tallies.isEmpty)
    }
}
