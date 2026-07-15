//
//  Provenance Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/15/26.
//
//  The provenance law (see Items.swift) and the two things that bound `.call`:
//  `IteratorItem` folding for loop counters, and the `maxCallWeight` backstop for
//  growth that is honestly linear.
//

import DequeModule
import Testing
@testable import PushInterpreter

@Suite @MainActor
struct ProvenanceTests {

    /// Longest chain of `call` references below an item.
    func callDepth(_ item: any Item) -> Int {
        item.call.isEmpty ? 1 : 1 + item.call.map { callDepth($0) }.max()!
    }

    func errors(_ interpreter: Interpreter) -> [String] {
        interpreter.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    /// Runs `item.crux()` on a fresh interpreter and reports the top of `stack`.
    func rerun(_ crux: [any Item], reading stack: PushStack) -> (any Item)? {
        let redo = Interpreter()
        redo.config.stepLimit = 20_000
        redo.load(program: crux)
        redo.run(stepLimit: 20_000)
        return redo.stacks[stack]!.first
    }

    func loopedRange(_ iterations: Int, body: [any Item] = []) -> Interpreter {
        let inty = Interpreter()
        inty.config.stepLimit = 20_000
        inty.load(program: [
            IntItem(0),
            IntItem(iterations),
            InstructionItem(.execDoRange),
            CodeItem(body),
        ])
        inty.run(stepLimit: 20_000)
        return inty
    }


    // MARK: - The counter, which is what used to blow up

    @Test func `a long loop leaves its counter one node deep`() {
        let inty = loopedRange(200)
        let counter = inty.stacks[.int]!.first!

        // Before folding this was one level per iteration, and the recorded
        // source (`y x .execDoRange`) did not even produce the value.
        #expect(counter.call.count == 1)
        #expect(counter.call[0] is IteratorItem)
        #expect(callDepth(counter) == 2)
        #expect(CodeItem(counter.crux()).pretty() == "( 0 199 .intAdd )")
    }

    @Test func `counter provenance does not grow with iteration count`() {
        let short = loopedRange(10).stacks[.int]!.first!
        let long = loopedRange(500).stacks[.int]!.first!
        // The whole point of folding: 50x the iterations, same size record.
        #expect(short.callWeight == long.callWeight)
        #expect(callDepth(short) == callDepth(long))
    }

    @Test func `the counter's crux re-runs to the counter's value`() {
        let inty = loopedRange(200)
        let counter = inty.stacks[.int]!.first! as! IntItem
        #expect(counter.value == 199)

        let reproduced = rerun(counter.crux(), reading: .int) as? IntItem
        #expect(reproduced?.value == counter.value)
    }

    @Test func `a descending loop folds to a negative offset`() {
        let inty = Interpreter()
        inty.config.stepLimit = 20_000
        inty.load(program: [
            IntItem(60), IntItem(10), InstructionItem(.execDoRange), CodeItem([]),
        ])
        inty.run(stepLimit: 20_000)

        let counter = inty.stacks[.int]!.first!
        #expect(counter.call.count == 1)
        #expect(CodeItem(counter.crux()).pretty() == "( 60 -49 .intAdd )")
        #expect((rerun(counter.crux(), reading: .int) as? IntItem)?.value == 11)
    }

    @Test func `an IteratorItem never comes to rest on a stack`() {
        let inty = loopedRange(200)
        // It is provenance-only. If one ever leaked onto a value stack, `push`
        // would refuse it and leave the distinctive marker behind.
        for stack in PushStack.allStacks {
            #expect(inty.stacks[stack]!.allSatisfy { !($0 is IteratorItem) })
        }
        #expect(!errors(inty).contains { $0.contains(Interpreter.invariantMarker) })
        #expect(PushStack.defaultStack(for: IteratorItem(base: IntItem(1), offset: 1)) == nil)
    }


    // MARK: - The backstop, for growth that folding cannot help

    /// `0 N .execDoRange (.intAdd)` over a seeded accumulator: each pass pushes
    /// the loop index and adds it in, so the sum's history really does gain a
    /// level per iteration. Nothing can fold that — it is honest.
    func accumulate(_ iterations: Int, maxCallWeight: Int) -> Interpreter {
        let inty = Interpreter()
        inty.config.stepLimit = 20_000
        inty.config.maxCallWeight = maxCallWeight
        inty.load(program: [
            IntItem(999),
            IntItem(0),
            IntItem(iterations),
            InstructionItem(.execDoRange),
            CodeItem([InstructionItem(.intAdd)]),
        ])
        inty.run(stepLimit: 20_000)
        return inty
    }

    @Test func `honest accumulation really does grow when unbounded`() {
        let small = accumulate(10, maxCallWeight: .max).stacks[.int]!.first!
        let big = accumulate(60, maxCallWeight: .max).stacks[.int]!.first!
        // Unlike the counter, this is not foldable and grows with the loop.
        #expect(big.callWeight > small.callWeight)
    }

    @Test func `the call budget bounds honest accumulation`() {
        let budget = 50
        let inty = accumulate(60, maxCallWeight: budget)
        let sum = inty.stacks[.int]!.first!

        #expect(sum.callWeight <= budget)
        // Elision is not an error — nothing is reported, the item just forgets.
        #expect(errors(inty).isEmpty)
    }

    @Test func `an elided item is still its own runnable crux`() {
        let inty = accumulate(60, maxCallWeight: 50)
        let sum = inty.stacks[.int]!.first! as! IntItem

        // This is what makes eliding safe: whatever survives, the crux still
        // reproduces the value — at worst as a bare literal.
        let reproduced = rerun(sum.crux(), reading: .int) as? IntItem
        #expect(reproduced?.value == sum.value)
    }

    @Test func `eliding costs the explanation, not the value`() {
        let told = accumulate(60, maxCallWeight: .max).stacks[.int]!.first! as! IntItem
        let forgot = accumulate(60, maxCallWeight: 50).stacks[.int]!.first! as! IntItem

        // Same answer either way...
        #expect(told.value == forgot.value)
        // ...but the budgeted one gives up some of the story to stay small.
        #expect(forgot.callWeight < told.callWeight)
    }


    // MARK: - Law 1: combinatory rearrangement records nothing

    @Test func `within-stack combinators leave provenance untouched`() {
        // Fill `.int` with copies of one input, shuffle them, and the survivor on
        // top should still carry nothing but the input's own provenance.
        //
        // `dup` and `yankDup` are the same operation and used to disagree:
        // yankDup recorded a layer per call, dup recorded none.
        let takingAPosition: [PushInstruction] =
            [.intYank, .intYankDup, .intDeepDup, .intShove]
        let takingNoArgument: [PushInstruction] = [.intDup, .intSwap, .intRot]

        for shuffle in takingAPosition + takingNoArgument {
            var program: [any Item] = [
                InstructionItem(.input0),
                InstructionItem(.intDup),
                InstructionItem(.intDup),
            ]
            // Only the first group pops an `.int` position to act on.
            if takingAPosition.contains(shuffle) { program.append(IntItem(0)) }
            program.append(InstructionItem(shuffle))

            let inty = Interpreter()
            inty.load(inputs: [.input0: IntItem(7)], program: program)
            inty.run()

            let top = inty.stacks[.int]!.first!
            #expect((top as! IntItem).value == 7, "\(shuffle) lost the value")
            #expect(CodeItem(top.crux()).pretty() == "( .input0 )",
                    "\(shuffle) recorded a provenance layer for a within-stack move")
        }
    }

    @Test func `quoting across stacks IS recorded`() {
        // The counterpart to law 1: `.intQuote` moves the value to `.code`, so a
        // crux that dropped it would leave an int where a code item belongs.
        let inty = Interpreter()
        inty.load(program: [
            IntItem(2), IntItem(3), InstructionItem(.intAdd),
            InstructionItem(.intQuote),
        ])
        inty.run()
        let quoted = inty.stacks[.code]!.first!
        #expect(CodeItem(quoted.crux()).pretty() == "( 2 3 .intAdd .intQuote )")
        #expect(rerun(quoted.crux(), reading: .code)?.pretty() == quoted.pretty())
    }


    // MARK: - Law 5: selecting one of several results on one stack

    @Test func `each of several results on one stack reconstructs itself`() {
        let inty = Interpreter()
        inty.load(program: [
            VecIntItem([10, 20, 30]), InstructionItem(.vecIntPushAll),
        ])
        inty.run()
        #expect(inty.stacks[.int]!.count == 3)

        // Elements are reversed before pushing, so 10 lands on top.
        for (depth, expected) in [(0, 10), (1, 20), (2, 30)] {
            let item = inty.stacks[.int]![depth]
            #expect((item as! IntItem).value == expected)
            let reproduced = rerun(item.crux(), reading: .int) as? IntItem
            #expect(reproduced?.value == expected,
                    "result at depth \(depth) did not reconstruct")
        }

        #expect(CodeItem(inty.stacks[.int]![2].crux()).pretty()
            == "( [10, 20, 30] .vecIntPushAll 2 .intPopItems )")
    }

    @Test func `a selected result composes into a later computation`() {
        // The composition property: each crux fragment leaves its value on top,
        // so fragments concatenate postfix without interfering.
        let inty = Interpreter()
        inty.load(program: [
            VecIntItem([10, 20, 30]), InstructionItem(.vecIntPushAll),
            InstructionItem(.intAdd),
        ])
        inty.run()
        let sum = inty.stacks[.int]!.first! as! IntItem
        #expect(sum.value == 30)   // 10 + 20

        let reproduced = rerun(sum.crux(), reading: .int) as? IntItem
        #expect(reproduced?.value == 30)
    }
}
