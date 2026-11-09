//
//  Instruction Mix Probe.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/17/26.
//
//  A diagnostic, not an assertion. **What proportions of constants, inputs,
//  furniture and work make a random program do something — and does the answer
//  depend on how long the program is?**
//
//  Nobody knows. The Plushy generator's proportions were picked years ago and
//  were not even what they looked like, since constants and inputs live *inside*
//  `Interpreter.language` — its "40% other" was really ~33% other, ~31% constant
//  and ~26% input. This asks the question on purpose.
//
//  Ten mixes × four genome lengths (50, 100, 250, 500 — the range people set as
//  initial GP arguments). The mixes are orthogonal by design: the balanced
//  centre, then each tag **enriched** (a third of the draw) and **depleted** (a
//  ninth) in turn, so a difference can be attributed to the one thing that moved.
//  Plus `language-shaped` as a control — what `language.keys.random()` gives you,
//  which is 34% furniture and nobody's decision.
//
//  ## Run it in tranches
//
//  **No single process needs to be big.** The sound sample size is large — random
//  sampling misses what evolution catches, so a real estimate wants thousands of
//  programs per cell — but a process holding all of them at once is what filled
//  12 GB and got killed. So the state that accumulates is a handful of **mergeable
//  sufficient statistics per cell** (a count, a sum, a sum of squares, two small
//  histograms), persisted to a JSON file. Each run does one bounded tranche, loads
//  what earlier tranches left, merges, saves, and prints the pooled result.
//
//  Run tranche `k` by setting `MIX_TRANCHE=k` in the environment; each tranche
//  seeds from `baseSeed &+ k`, so tranches cover *different* random draws rather
//  than re-measuring the same programs. `MIX_DATA` overrides the file; delete it
//  to start over. A process's memory is flat in the number of tranches, because
//  the accumulator never grows — only the counts inside it do.
//
//  ## Two measures, and the second is the interesting one
//
//  - **starvation** — how often an instruction wants an argument that is not
//    there. Push's dominant failure mode.
//  - **composition** — the share of surviving items whose crux is bigger than a
//    bare literal: computed from something, rather than handed over and left
//    alone. Measured with `callWeight`, the size of an item's provenance tree,
//    which is maintained on assignment and so free — where `crux()` materializes
//    the whole explanation and, at tens of millions of items, is the difference
//    between a run that finishes and one that does not. Since the whole project is
//    aimed at `crux()` reproducing an evolved item, "did values compose?" is
//    nearer the real question than "did it error?".
//
//  ## Three things that make the numbers sound, all learned the hard way
//
//  **The rate is conditional.** 127 of 526 instructions can never starve, so a
//  mix heavy in them scores a low raw rate for free, whatever it does to the
//  programs — half of `equal`'s draw is environment tokens against 17% of
//  `language-shaped`'s. A raw rate compares the dilution, not the language.
//
//  **Refusals are counted off `.error`, not by re-planning every step.** A
//  refusal names the stack it gave up at, so the error stack is an exact record
//  of what starved and where. Asking `plan(on:)` before every instruction cost
//  ~3x the interpretation it was measuring, for the same answer.
//
//  **The unit is the program, not the attempt.** Attempts inside one program are
//  not independent: a loop fires the same instruction hundreds of times, so
//  pooling attempts invents a denominator and shrinks the error bars to nothing.
//  Each program contributes ONE rate, and the interval is computed across
//  programs, which are genuinely independent. This is the same warning the
//  argument-starvation probe carries about its own two denominators.
//
//  Disabled and run alone: `fuzzRNG` is a shared global and Swift Testing runs
//  suites in parallel, so a concurrent drawer breaks the seed.
//

import Foundation
@testable import PushInterpreter
import Testing

@Suite @MainActor
struct InstructionMixProbe {

    nonisolated static let disabledTests = true

    nonisolated static let baseSeed: UInt64 = 20_260_717

    /// Genome lengths to sweep — the range GP practitioners set as initial
    /// arguments.
    ///
    /// **These confound length with code fraction**, and it cannot be helped
    /// without abandoning the Fibonacci rule. Its blocks consume the first sum of
    /// 1,1,2,3,5… past a third of the genome, and where that lands depends on the
    /// length: 50 → 40% code, 100 → **54%**, 250 → **35%**, 500 → 46%. So a
    /// difference between 100 and 250 may be length, or may be that one program is
    /// half blocks and the other a third. Reported rather than solved.
    nonisolated static let lengths = [50, 100, 250, 500]

    /// Programs per cell **per tranche**. Bounded on purpose: this fixes one
    /// process's work and memory (~90 MB flat, whatever the total sample). The
    /// sample grows by running more tranches, not by making one bigger.
    /// 100 × 40 cells = 4000 programs a tranche, a handful of seconds at the
    /// smaller lengths; six tranches gave 600 programs per cell with ±2-point
    /// intervals. Lower it if a length-500 tranche runs long.
    nonisolated static let casesPerTranche = 100

    /// Wall-clock budget for one program.
    ///
    /// **The runtime of a random program is heavy-tailed**, and it is not the step
    /// limit that lets it be: `stepLimit` bounds *steps*, and a step is not O(1)
    /// work. `.codeFromIterator` and `.vecFromIterator` can each collect up to a
    /// thousand values in a single step (which is fine in principle —
    /// they produce one Item — and it is, semantically), so a loop around one costs
    /// millions of item constructions while the step counter reads 2000.
    ///
    /// **It biases the sample** — the excluded programs are exactly the busiest —
    /// so the count is reported rather than swallowed.
    nonisolated static let maxSecondsPerProgram = 0.5


    /// One cell's accumulated statistics — everything **mergeable**, so tranches
    /// pool by addition and no process ever holds more than sufficient statistics.
    ///
    /// The per-program rates are kept as `(n, sum, sumSq)` rather than as a list:
    /// that is all a mean and a 95% interval need, it merges by adding, and it does
    /// not grow with the sample. The histograms merge the same way, and are bounded
    /// by the number of *distinct* values (`maxCallWeight` bounds crux sizes).
    struct Cell: Codable {
        var programs = 0

        // starvation rate: sufficient statistics over per-program rates
        var starveN = 0
        var starveSum = 0.0
        var starveSumSq = 0.0

        // composition share: same
        var composeN = 0
        var composeSum = 0.0
        var composeSumSq = 0.0

        var cruxHistogram: [Int: Int] = [:]
        /// Keyed by stack rawValue, to sidestep any question of encoding an
        /// enum-keyed dictionary.
        var blamed: [String: Int] = [:]
        var itemsLeft = 0
        var hitStepLimit = 0
        var timedOut = 0

        mutating func recordStarvation(_ rate: Double) {
            starveN += 1; starveSum += rate; starveSumSq += rate * rate
        }
        mutating func recordComposition(_ share: Double) {
            composeN += 1; composeSum += share; composeSumSq += share * share
        }

        mutating func merge(_ other: Cell) {
            programs += other.programs
            starveN += other.starveN; starveSum += other.starveSum; starveSumSq += other.starveSumSq
            composeN += other.composeN; composeSum += other.composeSum; composeSumSq += other.composeSumSq
            for (k, v) in other.cruxHistogram { cruxHistogram[k, default: 0] += v }
            for (k, v) in other.blamed { blamed[k, default: 0] += v }
            itemsLeft += other.itemsLeft
            hitStepLimit += other.hitStepLimit
            timedOut += other.timedOut
        }

        /// Mean and 95% half-width of the starvation rate, in percent, from the
        /// sufficient statistics.
        var starvationCI: (mean: Double, ci: Double) { Self.meanCI(starveN, starveSum, starveSumSq) }
        var compositionCI: (mean: Double, ci: Double) { Self.meanCI(composeN, composeSum, composeSumSq) }

        static func meanCI(_ n: Int, _ sum: Double, _ sumSq: Double) -> (Double, Double) {
            guard n > 1 else { return (n == 1 ? sum * 100 : 0, 0) }
            let count = Double(n)
            let mean = sum / count
            let variance = max(0, (sumSq - sum * sum / count) / (count - 1))
            return (mean * 100, 1.96 * (variance / count).squareRoot() * 100)
        }

        var maxCrux: Int { cruxHistogram.keys.max() ?? 0 }
        var p99Crux: Int {
            let total = cruxHistogram.values.reduce(0, +)
            guard total > 0 else { return 0 }
            let target = Int(Double(total) * 0.99)
            var seen = 0
            for length in cruxHistogram.keys.sorted() {
                seen += cruxHistogram[length]!
                if seen >= target { return length }
            }
            return maxCrux
        }
        var meanCrux: Double {
            let total = cruxHistogram.values.reduce(0, +)
            guard total > 0 else { return 0 }
            return Double(cruxHistogram.reduce(0) { $0 + $1.key * $1.value }) / Double(total)
        }
    }

    /// The whole accumulated dataset: mix name → length → cell. Keyed by a
    /// `"mix|length"` string so it is a plain `[String: Cell]` on disk.
    struct Dataset: Codable {
        var tranchesRun = 0
        var cells: [String: Cell] = [:]

        static func key(_ mix: String, _ length: Int) -> String { "\(mix)|\(length)" }

        mutating func cell(_ mix: String, _ length: Int, _ apply: (inout Cell) -> Void) {
            var c = cells[Self.key(mix, length)] ?? Cell()
            apply(&c)
            cells[Self.key(mix, length)] = c
        }

        mutating func merge(_ other: Dataset) {
            tranchesRun += other.tranchesRun
            for (k, v) in other.cells {
                var c = cells[k] ?? Cell()
                c.merge(v)
                cells[k] = c
            }
        }
    }

    nonisolated static var dataURL: URL {
        if let override = ProcessInfo.processInfo.environment["MIX_DATA"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("instruction-mix-dataset.json")
    }

    nonisolated static var tranche: Int {
        Int(ProcessInfo.processInfo.environment["MIX_TRANCHE"] ?? "0") ?? 0
    }


    @Test(.disabled(if: InstructionMixProbe.disabledTests))
    func `what does each instruction mix produce`() {
        let tranche = Self.tranche
        let seed = Self.baseSeed &+ UInt64(tranche)
        var settings = InterpreterSettings()
        settings.stepLimit = 2_000

        // This tranche's own results, then merged into whatever is on disk.
        var fresh = Dataset(tranchesRun: 1)

        for length in Self.lengths {
            for (name, mix) in InstructionMix.standardSweep {
                fuzzRNG = SeededRNG(seed: seed)
                fresh.cell(name, length) { cell in
                    for _ in 0..<Self.casesPerTranche {
                        runOne(into: &cell, mix: mix, length: length, settings: settings)
                    }
                }
            }
        }

        var pooled = load() ?? Dataset()
        pooled.merge(fresh)
        save(pooled)

        report(pooled)
        #expect(pooled.cells.count == InstructionMix.standardSweep.count * Self.lengths.count)
    }


    /// Run one program and fold its outcome into `cell`.
    func runOne(into cell: inout Cell, mix: InstructionMix, length: Int, settings: InterpreterSettings) {
        let inty = Interpreter.recordingProvenance()
        inty.config = settings
        inty.load(program: FibonacciGenome.translate(RandomCode.randomProgram(length, mix: mix)))
        RandomCode.setRandomConstants(in: inty)
        cell.programs += 1

        var starvable = 0
        let started = ContinuousClock().now
        var timedOut = false

        // `run()`'s loop, opened up just far enough to count the attempts that
        // COULD starve — the conditional-rate denominator. Refusals themselves are
        // read off `.error` afterwards, since a refusal names the stack it gave up
        // at, which is cheaper than asking `plan(on:)` before every step.
        while inty.counter < inty.config.stepLimit && !inty.stacks[.exec]!.isEmpty {
            if let next = inty.stacks[.exec]!.first as? InstructionItem,
               inty.behaviors[next.value] != nil,
               !Interpreter.alwaysSatisfied.contains(next.value) {
                starvable += 1
            }
            inty.step()

            // Checked every 64 steps; reading the clock every step would itself
            // distort what is being measured.
            if inty.counter & 63 == 0,
               ContinuousClock().now - started > .seconds(Self.maxSecondsPerProgram) {
                timedOut = true
                break
            }
        }

        var starved = 0
        for case let error as ErrorItem in inty.stacks[.error]! {
            guard let mark = error.value.range(of: "missing args: .") else { continue }
            starved += 1
            cell.blamed[String(error.value[mark.upperBound...]), default: 0] += 1
        }

        if timedOut { cell.timedOut += 1 }
        if inty.counter >= settings.stepLimit { cell.hitStepLimit += 1 }
        if starvable > 0 { cell.recordStarvation(Double(starved) / Double(starvable)) }

        // `.code` is skipped: a Fibonacci program's unconsumed blocks are still
        // sitting there, each its own literal crux, and counting them would swamp
        // composition with genome artifacts.
        var here = 0
        var composed = 0
        for stack in PushStack.allCases
        where stack != .error && stack != .exec && stack != .code {
            for item in inty.stacks[stack]! {
                // `callWeight` is the crux's size, maintained on assignment and so
                // free, where `crux()` would materialize the whole tree.
                let size = item.callWeight
                cell.cruxHistogram[size, default: 0] += 1
                here += 1
                if size > 1 { composed += 1 }
            }
        }
        cell.itemsLeft += here
        if here > 0 { cell.recordComposition(Double(composed) / Double(here)) }
    }


    // MARK: - persistence

    func load() -> Dataset? {
        guard let data = try? Data(contentsOf: Self.dataURL) else { return nil }
        return try? JSONDecoder().decode(Dataset.self, from: data)
    }

    func save(_ dataset: Dataset) {
        guard let data = try? JSONEncoder().encode(dataset) else { return }
        try? data.write(to: Self.dataURL)
    }


    // MARK: - report

    func report(_ data: Dataset) {
        let names = InstructionMix.standardSweep.map(\.name)
        func cell(_ name: String, _ length: Int) -> Cell { data.cells[Dataset.key(name, length)] ?? Cell() }
        let perCell = Self.lengths.map { l in names.reduce(0) { $0 + cell($1, l).programs } / max(1, names.count) }

        print("\n=== instruction mixes × genome length ===")
        print("\(data.tranchesRun) tranche(s) pooled, ~\(perCell.first ?? 0)–\(perCell.last ?? 0) programs per cell")
        print("file: \(Self.dataURL.path)")
        print("""

        The unit is the PROGRAM, not the attempt, so each contributes one rate and
        the ±95% interval is over programs, which are independent. Run more tranches
        (MIX_TRANCHE=1, 2, …) to tighten the intervals; each pools into the file.

        NOTE these lengths confound length with code fraction — the Fibonacci rule
        gives 50 -> 40% code, 100 -> 54%, 250 -> 35%, 500 -> 46%.
        """)

        func table(_ title: String, _ note: String, _ value: @escaping (Cell) -> (Double, Double)) {
            print("\n--- \(title) ---")
            print(note)
            var header = "mix".padding(toLength: 18, withPad: " ", startingAt: 0)
            for length in Self.lengths {
                header += "n=\(length)".padding(toLength: 15, withPad: " ", startingAt: 0)
            }
            print(header)
            print(String(repeating: "-", count: header.count))
            for name in names {
                var line = name.padding(toLength: 18, withPad: " ", startingAt: 0)
                for length in Self.lengths {
                    let (mean, ci) = value(cell(name, length))
                    line += String(format: "%5.1f ±%-4.1f    ", mean, ci)
                }
                print(line)
            }
        }

        table("conditional starvation: of the attempts that COULD starve, how many did (%)",
              "lower looks better — but read it beside composition: a mix can buy a good\nrate by attempting nothing.") {
            $0.starvationCI
        }

        table("composition: share of surviving items whose crux is > 1 item (%)",
              "higher is better — it means values were computed from other values.") {
            $0.compositionCI
        }

        print("\n--- crux size: mean / p99 / max ---")
        print("p99 is stable where max is an anecdote (one program's luck)")
        var header = "mix".padding(toLength: 18, withPad: " ", startingAt: 0)
        for length in Self.lengths {
            header += "n=\(length)".padding(toLength: 20, withPad: " ", startingAt: 0)
        }
        print(header)
        print(String(repeating: "-", count: header.count))
        for name in names {
            var line = name.padding(toLength: 18, withPad: " ", startingAt: 0)
            for length in Self.lengths {
                let c = cell(name, length)
                line += String(format: "%4.1f/%4d/%-6d    ", c.meanCrux, c.p99Crux, c.maxCrux)
            }
            print(line)
        }

        print("\n--- busiest-tail programs excluded by the \(Self.maxSecondsPerProgram)s guard, and step-limit hits ---")
        var slow = "timed out".padding(toLength: 18, withPad: " ", startingAt: 0)
        var limits = "hit stepLimit".padding(toLength: 18, withPad: " ", startingAt: 0)
        for length in Self.lengths {
            let cells = names.map { cell($0, length) }
            let total = max(1, cells.reduce(0) { $0 + $1.programs })
            slow += String(format: "n=%-4d %5.2f%%     ", length,
                           Double(cells.reduce(0) { $0 + $1.timedOut }) / Double(total) * 100)
            limits += String(format: "n=%-4d %4.1f%%     ", length,
                             Double(cells.reduce(0) { $0 + $1.hitStepLimit }) / Double(total) * 100)
        }
        print(slow)
        print(limits)

        print("\n--- which stack was empty when a plan gave up? (pooled over lengths) ---")
        for name in names {
            var blamed: [String: Int] = [:]
            for length in Self.lengths {
                for (stack, count) in cell(name, length).blamed { blamed[stack, default: 0] += count }
            }
            let total = max(1, blamed.values.reduce(0, +))
            let top = blamed.sorted { $0.value > $1.value }.prefix(4)
                .map { "\($0.key):\(Int(Double($0.value) / Double(total) * 100))%" }
                .joined(separator: " ")
            print("\(name.padding(toLength: 18, withPad: " ", startingAt: 0))\(top)")
        }
        print("")
    }
}
