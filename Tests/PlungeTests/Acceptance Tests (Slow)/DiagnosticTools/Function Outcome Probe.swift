//
//  Function Outcome Probe.swift
//  PlungeTests
//
//  How often would map, filter and reduce do something useful in the programs
//  a search actually makes, under today's rules and under the alternatives
//  being considered (`Open directions.md` §3.5, "Making functions findable and
//  applicable")? The findings are in `Notes on Push/Function application
//  variants.md`.
//
//  **Harvest, then compare offline.** The alternatives are not instructions
//  yet, so the probe does not need them to be. It runs random programs and,
//  at each moment a function could be applied, takes a *situation*: the
//  collection, the block on top of `.code`, the environment and a snapshot of
//  the stacks. Every variant is then applied to that same situation, as a
//  test-side function, and its outcome classified. The variants are compared
//  on identical, realistic material before anything in the language changes.
//
//  Situations come from two places:
//  - **natural**: one of the 15 function instructions is next on `.exec`;
//  - **opportunity**: every 100 steps, if `.code` holds a block and some
//    collection stack holds a collection. The instructions are rare, so this
//    shows what a function *would* meet if one fired.
//
//  The variants (`FunctionOutcome.Variant`):
//  - V0  `.input0`/`.input1` holes, per element, last push (today's rule)
//  - V1  the lowest-numbered `.inputN` in the block → the element, the next →
//        the accumulator; per element, last push
//  - V2  stack-fed: the element is run first, so it lands on its stack; last
//        push (`Interpreter.apply(_:after:in:)`, what `vecFromIterator` does)
//  - V3  stack-fed; the result is the top of the element's own stack (`.bool`
//        for filter)
//  - V4  as V3, over a copy of the parent's stacks rather than empty ones
//  - V5  one sandbox: every element pushed, the block run once, the element
//        type's whole stack harvested (map, reduce)
//  - V6  one sandbox: `vecXIterate` (or `stringIterate`) runs the block per
//        element in that sandbox, so state carries between elements; the
//        element type's stack harvested (map, reduce)
//  - V7  crux-to-function: the item on top of the element type's stack, its
//        crux with the first element-typed argument (and for reduce the
//        second) replaced by `.input0` (`.input1`), applied as V0
//
//  The rest aim at the cause the first eight exposed: a random block rarely
//  touches the element's type, and a binary operation starves on an element
//  alone.
//  - V8  every block on `.code`, top down, under V3; the first that depends on
//        the element. An upper bound for a lookup that finds a working block.
//  - V9  V3 over the block's *typed projection*: only its instructions whose
//        signature touches the element's stack, and its values and bound
//        tokens of that type.
//  - V10 V3 with the element type's constants under the element, so a binary
//        operation has a second argument.
//  - V11 V9 and V10 together.
//  - V12 the first block on `.code`, top down, holding an instruction that
//        takes (consumes or reads) the element's type, found by signature
//        rather than by trial, under V10. The cheap version of V8.
//  - V13 hybrid: stack-fed *and* the block's holes bound by order (for reduce,
//        the accumulator then the element), typed result, so a block written
//        with `.input0` still works.
//  - V14 V13 with V12's lookup and V10's typed context: the full package.
//
//  Each outcome is one of: refused (by reason); trivial (identity, empty,
//  reshaped or rearranged for map; empty or all for filter; the first or last
//  element for reduce); constant (unchanged when every element is perturbed);
//  or element-dependent, the class that matters.
//
//  Run solo; it writes `function-outcome-probe.md` and `.tsv` to $TMPDIR:
//
//      PUSH_FUNCTION_PROBE=1 swift test --filter FunctionOutcomeProbe
//
//  `PUSH_FUNCTION_PROBE_PROGRAMS` sets the programs per regime (default 300).
//  The pinning tests (`Function Outcome Pins.swift`) run in the ordinary suite.
//

import Foundation
import Testing
@testable import Plunge

@Suite @MainActor
struct FunctionOutcomeProbe {

    typealias Probe = FunctionOutcome

    nonisolated static let enabled = ProcessInfo.processInfo.environment["PUSH_FUNCTION_PROBE"] != nil

    static func percent(_ count: Int, of total: Int) -> String {
        let share = 100 * Double(count) / Double(max(total, 1))
        return share.formatted(.number.precision(.fractionLength(1))) + "%"
    }

    @Test(.enabled(if: enabled))
    func `how often would a function do something useful`() throws {
        let programs = Int(ProcessInfo.processInfo.environment["PUSH_FUNCTION_PROBE_PROGRAMS"] ?? "") ?? 300
        var counts: [String: Int] = [:]
        var report = "# Function outcome probe\n\n\(programs) programs per regime, 150 genes, permuted Fibonacci "
        report += "packing, step limit \(Probe.budget); collections cut to \(Probe.maxElements) elements.\n"
        report += "\nHow much of the language (\(RandomCode.allInstructions.count) instructions) could be a "
        report += "function body, by element type (a stack-family instruction like `intDup` counts as touching):\n\n"
        report += Self.densities()

        for regime in Probe.Regime.allCases {
            let harvest = Probe.harvest(regime, programs: programs)
            let natural = harvest.situations.filter { $0.0.natural }.count
            report += "\n## \(regime.rawValue)\n\n"
            report += "Natural firings: \(harvest.naturalFirings), of which \(harvest.naturalStarved) had no "
            report += "collection or no block; \(natural) natural situations and "
            report += "\(harvest.situations.count - natural) opportunities harvested.\n"
            for family in Probe.Family.allCases {
                let relevant: [Probe.Situation] = harvest.situations.filter { $0.1.contains(family) }.map { $0.0 }
                guard !relevant.isEmpty else { continue }
                report += Self.table(family, over: relevant, regime: regime, counts: &counts)
            }
        }

        var tsv = "regime\tsource\tfamily\tvariant\toutcome\tcount\n"
        for key in counts.keys.sorted() { tsv += "\(key)\t\(counts[key]!)\n" }
        let directory = FileManager.default.temporaryDirectory
        try report.write(to: directory.appending(path: "function-outcome-probe.md"), atomically: true, encoding: .utf8)
        try tsv.write(to: directory.appending(path: "function-outcome-probe.tsv"), atomically: true, encoding: .utf8)
        print(report)
        print("written to \(directory.path())")
    }

    /// One family's table: each variant's share of each outcome over
    /// `situations`, and its average sandbox steps. Adds each outcome to
    /// `counts`, keyed by the TSV's columns.
    static func table(_ family: Probe.Family, over situations: [Probe.Situation], regime: Probe.Regime,
                      counts: inout [String: Int]) -> String {
        var table: [Probe.Variant: [String: Int]] = [:]
        var cost: [Probe.Variant: Int] = [:]
        for variant in Probe.Variant.allCases where variant.applies(to: family) {
            for situation in situations {
                let before = Probe.sandboxSteps
                let outcome = Probe.classify(variant, family, situation)
                cost[variant, default: 0] += Probe.sandboxSteps - before
                table[variant, default: [:]][outcome.label, default: 0] += 1
                let source = situation.natural ? "natural" : "opportunity"
                let key = [regime.rawValue, source, family.rawValue, variant.rawValue, outcome.label]
                counts[key.joined(separator: "\t"), default: 0] += 1
            }
        }
        let labels: [String] = Set(table.values.flatMap { $0.keys }).sorted()
        var text = "\n### \(family.rawValue) (\(situations.count) situations)\n\n"
        text += "| variant | " + labels.joined(separator: " | ") + " | steps |\n"
        text += "|---|" + labels.map { _ in "---:" }.joined(separator: "|") + "|---:|\n"
        for variant in Probe.Variant.allCases {
            guard let row = table[variant] else { continue }
            let total = row.values.reduce(0, +)
            let cells: [String] = labels.map { percent(row[$0] ?? 0, of: total) }
            let steps = (cost[variant] ?? 0) / situations.count
            text += "| \(variant.rawValue) | " + cells.joined(separator: " | ") + " | \(steps) |\n"
        }
        return text
    }

    /// How much of the language could serve as a function body over each
    /// type: maps (take it, give it back), predicates (take it, give a bool)
    /// and folds (take two, give one), taking by consuming or reading.
    static func densities() -> String {
        let language = RandomCode.allInstructions
        let signatures = language.compactMap { Probe.runner.signature(of: $0) }
        func share(_ n: Int) -> String { "\(n) (" + percent(n, of: language.count) + ")" }
        var text = "| element stack | touch it | map T→T | predicate T→bool | fold T,T→T |\n"
        text += "|---|---:|---:|---:|---:|\n"
        for stack in [PushStack.int, .double, .bool, .char, .string] {
            func count(taking least: Int, giving given: PushStack) -> Int {
                signatures.filter {
                    Probe.arguments($0, from: stack) >= least && $0.produces.valueStacks.contains(given)
                }.count
            }
            let touching = signatures.filter { $0.touches(stack) }.count
            let cells = [touching, count(taking: 1, giving: stack), count(taking: 1, giving: .bool),
                         count(taking: 2, giving: stack)].map(share)
            text += "| \(stack.rawValue) | " + cells.joined(separator: " | ") + " |\n"
        }
        return text
    }
}
