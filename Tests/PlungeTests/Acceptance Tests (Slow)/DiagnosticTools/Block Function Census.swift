//
//  Block Function Census.swift
//  PlungeTests
//
//  What functions do the blocks random programs make yield, if every block is
//  turned into the crux functions of what it leaves (`Block Functions.swift`)?
//  How many, how varied, and what would converting them cost: every code item
//  as it is made, or only the block a map, filter or reduce consumes?
//
//  Run solo; it writes `block-function-census.md` to $TMPDIR:
//
//      PUSH_FUNCTION_PROBE=1 swift test --filter BlockFunctionCensus
//
//  `PUSH_FUNCTION_PROBE_PROGRAMS` sets the programs per regime (default 300).
//

import Foundation
import Testing
@testable import Plunge

@Suite @MainActor
struct BlockFunctionCensus {

    typealias Probe = FunctionOutcome

    static let elementStacks: [PushStack] = [.int, .double, .bool, .char, .string]
    static let valueStacks: [PushStack] = elementStacks + [.vecInt, .vecDouble, .vecBool, .vecString]

    /// What the census counts over one regime.
    @MainActor struct Tally {
        var programs = 0, programSteps = 0, firings = 0, births = 0
        var programTime = Duration.zero, conversionTime = Duration.zero
        var distinctBlocks: Set<String> = []
        var conversionSteps = 0, maxSteps = 0, exceeded = 0, holesMade = 0, unboundInputs = 0
        var pushes = 0, bareHoles = 0, constants = 0, constantRefOnly = 0, tooLong = 0, incomplete = 0
        var functions = 0, responsive = 0, bodyLength = 0
        var perBlock: [Int: Int] = [:], holeCounts: [Int: Int] = [:]
        var shapes: [String: Int] = [:], skeletons: [String: Int] = [:], signatures: [String: Int] = [:]
        var outputs: [String: Int] = [:], offers: [String: Int] = [:]
        var examples: [String] = []
        /// Functions repeating a body already yielded by the same conversion; the
        /// most copies of one body in one conversion; births repeating a block the
        /// same program already made.
        var repeatsInBlock = 0, maxCopiesInBlock = 0, repeatBirths = 0
        /// Consuming each block as it lands (what `codePushAllFunctions` would
        /// do): runs where the final top of some value stack changed, and where
        /// some value stack changed at all.
        var consumedTopsChanged = 0, consumedStacksChanged = 0

        mutating func add(_ c: Probe.Conversion, block: CodeItem, in s: Probe.Situation) {
            births += 1
            distinctBlocks.insert(Probe.render(block))
            maxSteps = max(maxSteps, c.steps)
            exceeded += c.exceeded ? 1 : 0
            holesMade += c.holesMade
            unboundInputs += c.unboundInputs
            pushes += c.pushes
            bareHoles += c.bareHoles
            constants += c.constants
            constantRefOnly += c.constantRefOnly
            tooLong += c.tooLong
            incomplete += c.incomplete
            functions += c.functions.count
            var copies: [String: Int] = [:]
            for f in c.functions { copies[f.shape, default: 0] += 1 }
            repeatsInBlock += copies.values.reduce(0) { $0 + $1 - 1 }
            maxCopiesInBlock = max(maxCopiesInBlock, copies.values.max() ?? 0)
            perBlock[min(c.functions.count, 10), default: 0] += 1
            let steps = Probe.sandboxSteps
            for f in c.functions {
                count(f)
                if Probe.responds(f, in: s) { responsive += 1 }
            }
            Probe.sandboxSteps = steps
            for stack in BlockFunctionCensus.elementStacks {
                for family in Probe.Family.allCases
                where c.functions.contains(where: { Probe.sieves($0, family, stack) }) {
                    offers["\(stack) \(family)", default: 0] += 1
                }
            }
        }

        mutating func count(_ f: Probe.BlockFunction) {
            let shape = f.shape
            if shapes[shape] == nil, examples.count < 40, f.skeleton.split(separator: " ").count >= 2 {
                examples.append("`\(f.signature)`: `\(shape)`")
            }
            shapes[shape, default: 0] += 1
            skeletons[f.skeleton, default: 0] += 1
            signatures[f.signature, default: 0] += 1
            outputs["\(f.output)", default: 0] += 1
            holeCounts[min(f.holes.count, 4), default: 0] += 1
            bodyLength += f.body.count
        }
    }

    static func makesCode(_ next: any Item) -> Bool {
        if next is CodeItem { return true }
        guard let token = (next as? InstructionItem)?.value else { return false }
        return Probe.runner.signature(of: token)?.produces.valueStacks.contains(.code) ?? false
    }

    /// Runs `programs` programs of `regime`, converting every code item each
    /// one makes.
    static func census(_ regime: Probe.Regime, programs: Int) -> Tally {
        var tally = Tally()
        let clock = ContinuousClock()
        for seed in 0..<programs {
            let drawn = withFuzzSeed(UInt64(seed)) { Probe.draw(regime) }
            func fresh() -> Interpreter {
                let inty = Interpreter()
                inty.config.stepLimit = Probe.budget
                inty.config.recordsProvenance = true
                inty.load(inputs: drawn.inputs, constants: drawn.constants, program: drawn.program)
                return inty
            }
            let plain = fresh()
            tally.programTime += clock.measure { plain.run() }
            tally.programSteps += plain.counter
            tally.programs += 1

            let inty = fresh()
            var births: [CodeItem] = []
            var birthSteps: [Int] = []
            while inty.counter < inty.config.stepLimit, let next = inty.stacks[.exec]!.first {
                if let token = (next as? InstructionItem)?.value, Probe.functionInstructions[token] != nil {
                    tally.firings += 1
                }
                let made = makesCode(next)
                let before = made ? inty.stacks[.code]!.first.map(Probe.render) : nil
                inty.step()
                if made, let top = inty.stacks[.code]!.first as? CodeItem, Probe.render(top) != before {
                    births.append(top)
                    birthSteps.append(inty.counter)
                }
            }
            countConsumption(at: birthSteps, against: plain, rerun: fresh, into: &tally)
            var seen: Set<String> = []
            for block in births where !seen.insert(Probe.render(block)).inserted { tally.repeatBirths += 1 }
            for block in births {
                let s = Probe.Situation(natural: false, collection: VecIntItem([]), block: block,
                                        inputs: drawn.inputs, constants: drawn.constants, stacks: [:])
                let before = Probe.sandboxSteps
                var conversion = Probe.Conversion()
                tally.conversionTime += clock.measure { conversion = Probe.convert(block, in: s) }
                tally.conversionSteps += Probe.sandboxSteps - before
                tally.add(conversion, block: block, in: s)
            }
        }
        return tally
    }

    /// For each step at which a block landed: re-runs the program from
    /// `rerun()`, removes that block from `.code` at that step, as
    /// `codePushAllFunctions` would, runs on, and compares the value stacks
    /// with `plain`'s.
    static func countConsumption(at steps: [Int], against plain: Interpreter, rerun: () -> Interpreter,
                                 into tally: inout Tally) {
        let finals = valueStacks.map { (plain.stacks[$0] ?? []).map(Probe.render) }
        for step in steps {
            let consumed = rerun()
            while consumed.counter < step { consumed.step() }
            _ = consumed.takeFirst(from: .code)
            consumed.run()
            let after = valueStacks.map { (consumed.stacks[$0] ?? []).map(Probe.render) }
            if after != finals { tally.consumedStacksChanged += 1 }
            if zip(after, finals).contains(where: { $0.first != $1.first }) { tally.consumedTopsChanged += 1 }
        }
    }

    @Test(.enabled(if: FunctionOutcomeProbe.enabled))
    func `what functions do random blocks yield`() throws {
        let programs = Int(ProcessInfo.processInfo.environment["PUSH_FUNCTION_PROBE_PROGRAMS"] ?? "") ?? 300
        var report = "# Block function census\n\n\(programs) programs per regime, as in the function outcome probe. "
        report += "Each program binds `.input0` up to a uniform 1–10 slots to random values of random types, "
        report += "and sets every constant. Every code item a program makes is converted: stepped with a fresh "
        report += "hole supplied for every argument an instruction is missing (any stack but `.exec` and "
        report += "`.error`), and every item pushed to one of those stacks read as the crux function of the holes "
        report += "it uses, each time it is pushed. A block that runs out of steps is refused. Whether a "
        report += "function's value responds to its holes is checked separately, by running its body with two "
        report += "other sets of placeholders, and not charged.\n"
        for regime in Probe.Regime.allCases {
            report += "\n## \(regime.rawValue)\n" + Self.render(Self.census(regime, programs: programs))
        }
        let directory = FileManager.default.temporaryDirectory
        try report.write(to: directory.appending(path: "block-function-census.md"), atomically: true, encoding: .utf8)
        print(report)
        print("written to \(directory.path())")
    }

    static func mean(_ total: Int, _ count: Int) -> String {
        (Double(total) / Double(max(count, 1))).formatted(.number.precision(.fractionLength(1)))
    }

    static func microseconds(_ duration: Duration, per count: Int) -> String {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) * 1e-18
        return (seconds * 1e6 / Double(max(count, 1))).formatted(.number.precision(.fractionLength(0))) + " µs"
    }

    static func top(_ counts: [String: Int], _ n: Int, of total: Int) -> String {
        counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(n)
            .map { "| `\($0.key)` | \($0.value) | \(FunctionOutcomeProbe.percent($0.value, of: total)) |" }
            .joined(separator: "\n")
    }

    /// The repeats and the cost of consuming blocks.
    static func renderRepeats(_ t: Tally) -> String {
        let percent = FunctionOutcomeProbe.percent
        var text = "\n**Repeats.** \(t.repeatsInBlock) functions repeat a body their own block already yielded "
        text += "(most copies of one body in one block: \(t.maxCopiesInBlock)); \(t.repeatBirths) code items "
        text += "(\(percent(t.repeatBirths, t.births))) repeat a block their program already made.\n"
        text += "\n**Consuming blocks.** Removing each code item from `.code` the moment it lands, as "
        text += "`codePushAllFunctions` would, and running on: the final top of some value stack changed in "
        text += "\(t.consumedTopsChanged) of \(t.births) runs (\(percent(t.consumedTopsChanged, t.births))); "
        text += "some value stack changed at all in \(t.consumedStacksChanged) "
        text += "(\(percent(t.consumedStacksChanged, t.births))).\n"
        return text
    }

    static func render(_ t: Tally) -> String {
        let percent = FunctionOutcomeProbe.percent
        var text = "\n**Cost.** \(t.programs) programs, \(mean(t.programSteps, t.programs)) steps and "
        text += "\(microseconds(t.programTime, per: t.programs)) each. They made \(t.births) code items "
        text += "(\(mean(t.births, t.programs)) per program, \(t.distinctBlocks.count) distinct) and fired a function "
        text += "instruction \(t.firings) times (\(mean(t.firings, t.programs)) per program).\n"
        text += "Converting one block: \(mean(t.conversionSteps, t.births)) sandbox steps "
        text += "(longest \(t.maxSteps)), \(microseconds(t.conversionTime, per: t.births)).\n"
        let eager = t.conversionTime / t.programTime
        let lazy = eager * Double(t.firings) / Double(max(t.births, 1))
        let ratio = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
        text += "Converting every code item as it is made costs \(eager.formatted(ratio))× "
        text += "the programs' own run time; converting only the block each firing consumes, about "
        text += "\(lazy.formatted(.number.precision(.fractionLength(3))))×. In sandbox steps, eager conversion adds "
        text += "\(mean(t.conversionSteps, t.programs)) steps per program to its \(mean(t.programSteps, t.programs)); "
        text += "lazy, about \(mean(t.conversionSteps * t.firings / max(t.births, 1), t.programs)).\n"
        text += "\(t.exceeded) blocks ran out of steps and were refused. Holes made: "
        text += "\(mean(t.holesMade, t.births)) per block. Unbound input tokens run: \(t.unboundInputs).\n"

        text += "\n**What was pushed.** \(t.pushes) items pushed: \(t.bareHoles) holes "
        text += "moved unchanged, \(t.constants) values using no hole, \(t.constantRefOnly) using only the block's own "
        text += "constants, \(t.tooLong) with cruxes over 300 items. **\(t.functions) used a hole** "
        text += "(\(mean(t.functions, t.births)) per block, repeats kept; \(t.incomplete) with an elided history); "
        text += "\(t.responsive) of them (\(percent(t.responsive, t.functions))) changed value with other "
        text += "placeholders.\n"
        text += "\nFunctions per block: "
        text += (0...10).map { "\($0 == 10 ? "10+" : "\($0)"): \(percent(t.perBlock[$0] ?? 0, t.births))" }
            .joined(separator: ", ")
        text += ". Holes per function: "
        text += (1...4).map { "\($0 == 4 ? "4+" : "\($0)"): \(percent(t.holeCounts[$0] ?? 0, t.functions))" }
            .joined(separator: ", ")
        text += ". Mean body length \(mean(t.bodyLength, t.functions)) items.\n"
        text += renderRepeats(t)

        let once = t.shapes.values.filter { $0 == 1 }.count
        text += "\n**Diversity.** \(t.shapes.count) distinct function bodies (\(percent(once, t.shapes.count)) seen "
        text += "once), \(t.skeletons.count) distinct instruction sequences, \(t.signatures.count) distinct "
        text += "signatures.\n"
        text += "\nOutput types: " + t.outputs.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { "\($0.key) \(percent($0.value, t.functions))" }.joined(separator: ", ") + ".\n"

        text += "\n| element | blocks offering a map | a filter | a reduce |\n|---|---:|---:|---:|\n"
        for stack in elementStacks {
            let cells = Probe.Family.allCases.map { percent(t.offers["\(stack) \($0)"] ?? 0, t.births) }
            text += "| \(stack) | " + cells.joined(separator: " | ") + " |\n"
        }
        text += "\n| signature | functions | share |\n|---|---:|---:|\n" + top(t.signatures, 15, of: t.functions)
        text += "\n\n| body | functions | share |\n|---|---:|---:|\n" + top(t.shapes, 20, of: t.functions)
        text += "\n\nThe first 40 distinct bodies with two or more instructions:\n\n"
        text += t.examples.map { "- " + $0 }.joined(separator: "\n") + "\n"
        return text
    }
}
