//
//  Loop Folding Tests.swift
//  PlungeTests
//
//  A loop's chain, over budget, is folded into a counted loop over its seed
//  rather than elided (`CruxCompression.folded`), so a loop may run until
//  `stepLimit` and keep its history (since 2026-11-07).
//

@testable import Plunge
import Testing

@Suite
struct LoopFoldingTests {

    private func run(_ program: [any Item], steps: Int = 40_000) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.config.stepLimit = steps
        inty.load(program: program)
        inty.run(stepLimit: steps)
        return inty
    }

    private func holds(_ item: any Item) -> Bool {
        var settings = Interpreter.recordingProvenance().config
        settings.stepLimit = 1_000
        if case .holds = inspectCrux(of: item, inputs: [:], constants: [:], settings: settings) { return true }
        return false
    }

    private let addOne = CodeItem([IntItem(1), InstructionItem(.intAdd)])

    @Test func `a long loop runs to the end and keeps a folded history`() {
        // 5,000 passes: no clamp by default, and the chain is far deeper than
        // `maxCallDepth`.
        let inty = run([IntItem(0), addOne, IntItem(5_000), InstructionItem(.execDoTimes)])
        let total = topItem(inty, .int)
        #expect(total.pretty() == "5000")
        #expect(total.callDepth <= inty.config.maxCallDepth)
        let crux = total.crux()
        #expect(!crux.contains { $0.exactly(StandInItem.self) != nil }, "nothing elided")
        #expect(CodeItem(Array(crux.prefix(5))).pretty() == "( 0 ( 1 .intAdd ) 4001 .execDoTimes .codePop )")
        #expect(holds(total))
    }

    @Test func `a chain that grows past its fold joins it`() {
        let inty = Interpreter.recordingProvenance()
        inty.config.maxCallDepth = 3
        var item = IntItem(0)
        for value in 1...4 {
            item = IntItem(value, call: [item, InstructionItem(.intInc)])
        }
        inty.push(item, to: .int)
        let folded = inty.stacks[.int]!.removeFirst()
        #expect(CodeItem(folded.crux()).pretty() == "( 0 ( .intInc ) 4 .execDoTimes .codePop )")

        var grown: any Item = folded
        for value in 5...7 {
            grown = IntItem(value, call: [grown, InstructionItem(.intInc)])
        }
        inty.push(grown, to: .int)
        #expect(CodeItem(topItem(inty, .int).crux()).pretty() == "( 0 ( .intInc ) 7 .execDoTimes .codePop )")
    }

    @Test func `levels that alternate are not a loop's chain`() {
        var item = IntItem(0)
        for value in 1...6 {
            item = IntItem(value, call: [item, InstructionItem(value.isMultiple(of: 2) ? .intInc : .intDec)])
        }
        #expect(CruxCompression.folded(item) == nil)
    }

    @Test func `a fold replays in about the steps it says`() {
        let crux: [any Item] = [IntItem(0), addOne, IntItem(1_000), InstructionItem(.execDoTimes),
                                InstructionItem(.codePop)]
        let estimate = CruxCompression.replaySteps(crux)
        let inty = run(crux, steps: 100_000)
        #expect(topItem(inty, .int).pretty() == "1000")
        #expect(inty.counter <= estimate)
        #expect(estimate <= 3 * inty.counter)
    }

    /// The loop hands its body back to `.code` **after** its last pass, so a body
    /// that reads `.code` sees the same `.code` on every pass, and `( B ) K
    /// .execDoTimes` is `B` written `K` times. (Until 2026-11-07 the body landed
    /// on `.code` with the last pass, which a folded `.codePeekNth` chain
    /// replayed one level short.)
    @Test func `a loop's last pass does not see its own body on .code`() {
        let dup = CodeItem([InstructionItem(.codeDup)])
        let looped = run([CodeItem([IntItem(1)]), dup, IntItem(3), InstructionItem(.execDoTimes)])
        let written = run([CodeItem([IntItem(1)])] + Array(repeating: InstructionItem(.codeDup), count: 3))
        #expect(stackString(written, .code) == "[ ( 1 ) ( 1 ) ( 1 ) ( 1 ) ]")
        #expect(stackString(looped, .code) == "[ ( .codeDup ) ( 1 ) ( 1 ) ( 1 ) ( 1 ) ]")
    }
}
