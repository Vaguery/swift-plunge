//
//  Deep Structure Safety Tests.swift
//  PushInterpreterTests
//
//  Walking or releasing a nested structure costs a stack frame per level, and a
//  concurrency worker thread's stack is small (512 KB) — the thread every Runner
//  evaluation, and every server-side run, uses. The dual-mode stress run killed
//  the process twice this way: `crux()` recursing through a 2,463-deep call tree,
//  and then the release of that same tree. These pin the fixes: `crux()` is
//  iterative; provenance deeper than `maxCallDepth` is elided at push; a block
//  nested deeper than `maxCodeDepth` is refused at push. Each deep case runs on a
//  detached task, so a regression crashes here rather than in a long run.
//

@testable import PushInterpreter
import Testing

@Suite
struct DeepStructureSafetyTests {

    /// The recursive definition `crux()` used to have, for comparison.
    func recursiveCrux(_ item: any Item) -> [any Item] {
        item.call.isEmpty ? [item] : item.call.flatMap(recursiveCrux)
    }

    @Test func `the iterative crux matches the recursive definition`() {
        // A small tree with branching, nesting and shared nodes.
        let a = IntItem(1)
        let b = IntItem(2, call: [a, InstructionItem(.intInc)])
        let c = IntItem(3, call: [b, a, InstructionItem(.intAdd)])
        let d = IntItem(6, call: [c, c, InstructionItem(.intAdd)])
        let e = BoolItem(true, call: [d, b, InstructionItem(.intGT)])
        for item in [a, b, c, d, e] as [any Item] {
            #expect(CodeItem(item.crux()).pretty() == CodeItem(recursiveCrux(item)).pretty())
        }
    }

    @Test func `call measure tracks weight and depth`() {
        let leaf = IntItem(1)
        let one = IntItem(2, call: [leaf, InstructionItem(.intInc)])
        let two = IntItem(3, call: [one, InstructionItem(.intInc)])
        #expect(leaf.callDepth == 0)
        #expect(one.callDepth == 1)
        #expect(two.callDepth == 2)
        #expect(two.callWeight == 1 + one.callWeight + 1)
    }

    /// Small items must stay within the three words an `any Item` stores inline;
    /// one more stored field and every one of them is boxed on the heap. This is
    /// why `callWeight` and `callDepth` share one `CallMeasure`.
    @Test func `small items still fit inline in an existential`() {
        #expect(MemoryLayout<IntItem>.size <= 24)
        #expect(MemoryLayout<BoolItem>.size <= 24)
        #expect(MemoryLayout<DoubleItem>.size <= 24)
        #expect(MemoryLayout<InstructionItem>.size <= 24)
    }

    @Test func `provenance deeper than maxCallDepth is elided at push`() {
        let inty = Interpreter.recordingProvenance()
        inty.config.maxCallDepth = 3
        var item = IntItem(0)
        for i in 1...5 { item = IntItem(i, call: [item, InstructionItem(.intInc)]) }   // depth 5
        inty.push(item, to: .int)
        #expect(inty.stacks[.int]!.first!.call.isEmpty, "over-deep provenance is dropped, as over-weight is")
        #expect((inty.stacks[.int]!.first as? IntItem)?.value == 5, "the value is kept")
    }

    /// A loop whose counter-like accumulator would record a chain 5,000 deep, run
    /// with recording on, on a worker thread, and released there.
    @Test func `a long recording run on a worker thread stays shallow and survives`() async {
        let (value, deepest, bound) = await Task.detached {
            let inty = Interpreter()
            inty.config.recordsProvenance = true
            inty.config.stepLimit = 100_000
            inty.config.maxIterations = 10_000
            inty.load(program: [IntItem(0), CodeItem([IntItem(1), InstructionItem(.intAdd)]),
                                IntItem(5_000), InstructionItem(.execDoTimes)])
            inty.run()
            let deepest = PushStack.allStacks.flatMap { inty.stacks[$0]! }.map(\.callDepth).max() ?? 0
            return ((inty.stacks[.int]!.first as? IntItem)?.value, deepest, inty.config.maxCallDepth)
        }.value
        #expect(value == 5_000)
        #expect(deepest <= bound)
    }

    /// A loop that wraps a block once per pass. Wrapping adds a level and no
    /// points or weight, so before `maxCodeDepth` was enforced this built a block
    /// thousands deep that crashed the thread that released or printed it.
    @Test func `endless wrapping is refused at maxCodeDepth, on a worker thread`() async {
        let (deepest, refusals, bound) = await Task.detached {
            let inty = Interpreter()
            inty.config.stepLimit = 100_000
            inty.config.maxIterations = 10_000
            inty.load(program: [CodeItem([IntItem(7)]), CodeItem([InstructionItem(.codeWrapRoot)]),
                                IntItem(5_000), InstructionItem(.execDoTimes)])
            inty.run()
            let deepest = inty.stacks[.code]!.compactMap { ($0 as? CodeItem)?.nestingDepth }.max() ?? 0
            let refusals = inty.stacks[.error]!.filter { $0.pretty().contains("maxCodeDepth") }.count
            return (deepest, refusals, inty.config.maxCodeDepth)
        }.value
        #expect(deepest <= bound)
        #expect(refusals > 0, "the over-deep wrap is refused, not silently built")
    }
}
