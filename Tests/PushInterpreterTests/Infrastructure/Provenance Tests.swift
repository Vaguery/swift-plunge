//
//  Provenance Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/15/26.
//
//  The provenance law (see Items.swift) and the two things that bound `.call`:
//  a loop counter naming its origin and offset directly, and the `maxCallWeight`
//  backstop for growth that is honestly linear.
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

    func sampleIterator(cursor: Int = 0) -> IteratorItem {
        IteratorItem(
            kind: .counting(stride: 1),
            origin: IntItem(1),
            destination: IntItem(9),
            body: CodeItem([]),
            emits: true,
            cursor: cursor
        )
    }

    /// Runs `item.crux()` on a fresh interpreter and reports the top of `stack`.
    func rerun(_ crux: [any Item], reading stack: PushStack) -> (any Item)? {
        let redo = Interpreter.recordingProvenance()
        redo.config.stepLimit = 20_000
        redo.load(program: crux)
        redo.run(stepLimit: 20_000)
        return redo.stacks[stack]!.first
    }

    func loopedRange(_ iterations: Int, body: [any Item] = []) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.config.stepLimit = 20_000
        inty.load(program: [
            IntItem(0),
            // `.execDoRange` stops short of its end (since 2026-11-09), so `0 n` is
            // n passes, 0 through n − 1.
            IntItem(iterations),
            CodeItem(body),                    // lands on .code, waiting
            InstructionItem(.execDoRange),
        ])
        inty.run(stepLimit: 20_000)
        return inty
    }


    // MARK: - The counter, which is what used to blow up

    @Test func `a long loop leaves its counter one node deep`() {
        let inty = loopedRange(200)
        let counter = inty.stacks[.int]!.first!

        // Before this was bounded it grew one level per iteration, and the
        // recorded source (`y x .execDoRange`) did not even produce the value.
        //
        // The counter now names its origin and its offset outright — the iterator
        // holds both, so there is nothing to fold and no folding node to find.
        #expect(counter.call.count == 3)
        #expect(counter.call.first is IntItem)
        #expect(counter.call.last as? InstructionItem == InstructionItem(.intAdd))
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
        let inty = Interpreter.recordingProvenance()
        inty.config.stepLimit = 20_000
        inty.load(program: [
            IntItem(60), IntItem(10), CodeItem([]), InstructionItem(.execDoRange),
        ])
        inty.run(stepLimit: 20_000)

        let counter = inty.stacks[.int]!.first!
        #expect(counter.call.count == 3)
        // Exclusive (since 2026-11-09): the last index is 11, one short of 10.
        #expect(CodeItem(counter.crux()).pretty() == "( 60 -49 .intAdd )")
        #expect((rerun(counter.crux(), reading: .int) as? IntItem)?.value == 11)
    }

    /// `IteratorItem` is first-class now: it rests on `.iterator`, and its state
    /// is its own for the loop's duration rather than being spread across `.int`.
    ///
    /// This test used to assert the exact opposite — that an iterator never comes
    /// to rest anywhere — back when it was a provenance-only node that lived
    /// inside `call`. It is inverted deliberately.
    @Test func `an iterator rests on its own stack and is gone when the loop ends`() {
        let inty = loopedRange(200)

        // The loop ran to completion, so its iterator has been consumed.
        #expect(inty.stacks[.iterator]!.isEmpty)
        #expect(!errors(inty).contains { $0.contains(Interpreter.invariantMarker) })
        #expect(PushStack.defaultStack(for: sampleIterator()) == .iterator)

        // Mid-flight it is on `.iterator`, and nowhere else.
        let running = midLoop()
        #expect(running.stacks[.iterator]!.count == 1)
        for stack in PushStack.allStacks where stack != .iterator {
            #expect(running.stacks[stack]!.allSatisfy { !($0 is IteratorItem) })
        }
    }

    /// Four steps into `0 200 () .execDoRange`: the three literals land, then the
    /// instruction builds the iterator. One more step would run the first pass.
    ///
    /// Stepped by hand because `run(stepLimit:)` ignores its argument and reads
    /// `config.stepLimit` instead.
    func midLoop() -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(0), IntItem(200), CodeItem([]), InstructionItem(.execDoRange),
        ])
        for _ in 0..<4 { inty.step() }
        return inty
    }

    /// The loop's bounds are inside the iterator, not loose on `.int`. Before this
    /// change `execDoRange` re-pushed both of them onto `.int` every pass.
    @Test func `a running loop keeps its state encapsulated`() {
        let inty = midLoop()

        let iterator = inty.stacks[.iterator]!.first as? IteratorItem
        #expect((iterator?.origin as? IntItem)?.value == 0)
        // 200 itself: the range stops short of its end, as the engine does.
        #expect((iterator?.destination as? IntItem)?.value == 200)
        #expect(iterator?.stride == 1)
        #expect(iterator?.value == 0)          // the cursor
        // Neither bound is loose anywhere.
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        inty.step()   // one pass: only the index escapes
        #expect(stackString(inty, .int) == "[ 0 ]")
    }


    // MARK: - The backstop, for growth that folding cannot help

    /// `0 N .execDoRange (.intAdd)` over a seeded accumulator: each pass pushes
    /// the loop index and adds it in, so the sum's history really does gain a
    /// level per iteration. Nothing can fold that — it is honest.
    func accumulate(_ iterations: Int, maxCallWeight: Int) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.config.stepLimit = 20_000
        inty.config.maxCallWeight = maxCallWeight
        inty.load(program: [
            IntItem(999),
            IntItem(0),
            IntItem(iterations),
            CodeItem([InstructionItem(.intAdd)]),   // lands on .code, waiting
            InstructionItem(.execDoRange),
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

            let inty = Interpreter.recordingProvenance()
            inty.load(inputs: [.input0: IntItem(7)], program: program)
            inty.run()

            let top = inty.stacks[.int]!.first!
            #expect((top as! IntItem).value == 7, "\(shuffle) lost the value")
            #expect(CodeItem(top.crux()).pretty() == "( .input0 )",
                    "\(shuffle) recorded a provenance layer for a within-stack move")
        }
    }

    @Test func `an unbound input's error records what would reproduce it`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [InstructionItem(.input3)])   // nothing bound
        inty.run()
        let failed = inty.stacks[.error]!.first!
        #expect(CodeItem(failed.crux()).pretty() == "( .input3 )")

        // The error is reproducible, like any other result: an environment
        // binding outlives the run and is re-supplied, so naming the instruction
        // reproduces the failure. (Law 4b's counterpart: `.boolStackDepth` reads
        // *transient* state and so records nothing instead.)
        let again = Interpreter.recordingProvenance()
        again.load(program: failed.crux())
        again.run()
        #expect(again.stacks[.error]!.first?.pretty() == failed.pretty())

        // And that is the point of naming the dependency rather than freezing the
        // outcome: the same source against a bound environment yields the value.
        let bound = Interpreter.recordingProvenance()
        bound.load(inputs: [.input3: IntItem(42)], program: failed.crux())
        bound.run()
        #expect((bound.stacks[.int]!.first as? IntItem)?.value == 42)
        #expect(bound.stacks[.error]!.isEmpty)
    }

    @Test func `quoting across stacks IS recorded`() {
        // The counterpart to law 1: `.intQuote` moves the value to `.code`, so a
        // crux that dropped it would leave an int where a code item belongs.
        let inty = Interpreter.recordingProvenance()
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
    //
    // **Nothing in the language emits a law-5 record any more.** Its four users —
    // `stringPushAllChars`, `stringParseToLetters`, `stringSplit` and the generic
    // `vecXPushAll` — all became iterators, and an iterator never puts several
    // results on a stack at once: it emits one per pass, and each says what it is
    // (`v 2 .vecIntNth`) rather than which of a pile it was.
    //
    // The law and its machinery are kept, because the obligation still holds for
    // any future Behavior that does produce several results on one stack. So these
    // test the mechanism directly rather than through a caller — which they should
    // arguably have done all along, since it turns out `<stack>PopItems` had no
    // unit test of its own.

    @Test func `selecting records the pops that surface each result`() {
        let source: [any Item] = [VecIntItem([10, 20, 30]), InstructionItem(.vecIntPushAll)]

        // Of N results on one stack, the one at position i clears N-1-i siblings
        // above it (a plain PopItems) and i siblings below it (swap-and-pop each,
        // since a pop cannot reach under the result). The first produced is the
        // deepest, because `distribute` prepends each in turn.
        //
        // Every one of these leaves exactly one item on `.int`. The top result
        // used to record nothing extra, which reproduced its own value but
        // stranded its siblings — see `a selected result leaves nothing behind`.
        #expect(CodeItem(Behavior.selecting(2, of: 3, on: .int, from: source)).pretty()
            == "( [10, 20, 30] .vecIntPushAll .intSwap .intPop .intSwap .intPop )")
        #expect(CodeItem(Behavior.selecting(1, of: 3, on: .int, from: source)).pretty()
            == "( [10, 20, 30] .vecIntPushAll 1 .intPopItems .intSwap .intPop )")
        #expect(CodeItem(Behavior.selecting(0, of: 3, on: .int, from: source)).pretty()
            == "( [10, 20, 30] .vecIntPushAll 2 .intPopItems )")

        // A lone result needs no selection at all.
        #expect(CodeItem(Behavior.selecting(0, of: 1, on: .int, from: source)).pretty()
            == "( [10, 20, 30] .vecIntPushAll )")
    }

    /// The half the text assertions above cannot state: each selector must leave
    /// **exactly one** item on the stack, or the fragment is not composable as an
    /// argument.
    ///
    /// This is the check that was missing. `selecting` used to give the topmost
    /// result `source` unchanged — correct in isolation, since the wanted value
    /// was on top, but it stranded every sibling. Embedded in a larger crux the
    /// debris shifted the enclosing instruction's arguments, which is how a
    /// `.vecDoubleCut` pair silently fed the wrong operands to
    /// `.vecDoubleReplaceSubVec`.
    @Test func `a selected result leaves nothing behind`() {
        let source: [any Item] = [VecIntItem([10, 20, 30]), InstructionItem(.vecIntPushAll)]

        for produced in 0..<3 {
            let crux = Behavior.selecting(produced, of: 3, on: .int, from: source)
            let redo = Interpreter.recordingProvenance()
            redo.load(program: crux)
            redo.run()
            #expect(redo.stacks[.int]!.count == 1,
                    "selecting(\(produced), of: 3) left \(stackString(redo, .int)) on .int")
            // `pushAll` lands front-to-back, so 10 is
            // deepest — and the deepest is `producedAt` 0, the first produced.
            #expect((redo.stacks[.int]!.first as? IntItem)?.value == [10, 20, 30][produced],
                    "selecting(\(produced), of: 3) surfaced the wrong one")
        }
    }

    /// The instruction a law-5 record leans on. It had no test of its own.
    @Test func `PopItems discards that many items from its stack`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(10), IntItem(20), IntItem(30), IntItem(2),
            InstructionItem(.intPopItems),
        ])
        inty.run()
        #expect(stackString(inty, .int) == "[ 10 ]")

        // Clamped rather than an error, like its DupItems/Yank siblings: a count
        // past the bottom empties the stack, and a negative one does nothing.
        let deep = Interpreter.recordingProvenance()
        deep.load(program: [IntItem(10), IntItem(999), InstructionItem(.intPopItems)])
        deep.run()
        #expect(stackString(deep, .int) == "[ ]")

        let negative = Interpreter.recordingProvenance()
        negative.load(program: [IntItem(10), IntItem(-4), InstructionItem(.intPopItems)])
        negative.run()
        #expect(stackString(negative, .int) == "[ 10 ]")
    }

    /// A hand-built law-5 record round-trips: this is what a future multi-result
    /// Behavior would be relying on.
    @Test func `a law 5 record reconstructs the result it selects`() {
        let vector = VecIntItem([10, 20, 30])
        for (position, expected) in [(0, 10), (1, 20), (2, 30)] {
            let record = Behavior.selecting(
                position, of: 3, on: .int,
                from: [vector, InstructionItem(.vecIntPushAll)]
            )
            // `.vecIntPushAll` is an iterator now, so re-running this needs the
            // loop to finish before the pops fire — which it does, since a crux is
            // run to completion like any other program.
            let item = IntItem(expected, call: record)
            #expect((rerun(item.crux(), reading: .int) as? IntItem)?.value == expected,
                    "the result at position \(position) did not reconstruct")
        }
    }

    @Test func `a result composes into a later computation`() {
        // The composition property: each crux fragment leaves its value on top,
        // so fragments concatenate postfix without interfering.
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            VecIntItem([10, 20, 30]), InstructionItem(.vecIntPushAll),
            InstructionItem(.intAdd),
        ])
        inty.run()
        let sum = inty.stacks[.int]!.first! as! IntItem
        // Front-to-back now, so 30 lands on top and 20 beneath it.
        #expect(sum.value == 50)

        let reproduced = rerun(sum.crux(), reading: .int) as? IntItem
        #expect(reproduced?.value == 50)
        #expect(CodeItem(sum.crux()).pretty()
            == "( [10, 20, 30] 1 .vecIntNth [10, 20, 30] 2 .vecIntNth .intAdd )")
    }
}
