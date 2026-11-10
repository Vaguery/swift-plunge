//
//  Stack Family Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/7/26.
//

@testable import Plunge
import Testing
import DequeModule

@Suite @MainActor
struct StackFamilyBehaviorTests {

    let inty = Interpreter.recordingProvenance()

    @Test func `combinator DeepDup works`() {
        loadInts(inty, ints: [2, 10, 0, -4, 4])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ 2 10 0 -4 4 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 2.2 3.3 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 3.3 4.4 ]")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 3.3 4.4 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 3.3 4.4 4.4 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")

        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 2.2 2.2 3.3 4.4 4.4 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")
    }

    @Test func `combinator Dup works`() {
        // MARK: verify this is what is expected
        loadInts(inty, ints: [11, 22])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intDup, to: inty)
        #expect(stackString(inty, .int) == "[ 11 11 22 ]")
    }

    /// The outcomes are exactly what they were; the copies simply arrive one per
    /// pass rather than all at once, so the loop has to run.
    @Test func `combinator DupItems works`() {
        loadInts(inty, ints: [2, 0, -5, 9])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ 2 0 -5 9 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleDupItems, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 1.1 2.2 3.3 4.4 ]")
        // A dup changes no value, so the copies keep their own (empty) record.
        #expect(callString(topItem(inty, .double)) == "( )")

        // A count of 0 copies nothing and builds no iterator.
        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 1.1 2.2 3.3 4.4 ]")
        // …and so does a negative one.
        doThis(.doubleDupItems, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 1.1 2.2 3.3 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")
    }

    /// The count is clamped to the whole stack, as `PopItems` clamps it.
    @Test func `DupItems can copy the whole stack`() {
        loadDoubles(inty, doubles: [1.1, 2.2])
        inty.stacks[.int] = [IntItem(99)]
        doThis(.doubleDupItems, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 1.1 2.2 ]")

        let single = Interpreter()
        single.load(program: [DoubleItem(3.5), IntItem(1), InstructionItem(.doubleDupItems)])
        single.run(stepLimit: 100)
        #expect(stackString(single, .double) == "[ 3.5 3.5 ]", "one item, copied")
    }

    @Test func `combinator DupTimes works`() {
        loadInts(inty, ints: [2, 0, -5])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ 2 0 -5 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleDupTimes, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 2.2 3.3 4.4 ]")

        // A count of 0 copies nothing and builds no iterator.
        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 2.2 3.3 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")

        // …and so does a negative one.
        doThis(.doubleDupTimes, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 2.2 3.3 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")
    }

    /// **This test used to assert that DupTimes refuses a large count.** It had
    /// its own `maxStackDepth` check — the only bespoke size guard in the
    /// language — and errored rather than doing any of the work.
    ///
    /// That guard is gone, and nothing bespoke replaced it: a count of three
    /// billion builds a loop like any other count, and the ordinary limits
    /// (`stepLimit`, the runaway guard, `maxStackDepth`) bound the work it does.
    /// (`maxIterations`, which held such a loop to 100 passes, was deleted
    /// 2026-11-08.)
    @Test func `combinator DupTimes no longer needs its own size guard`() {
        loadInts(inty, ints: [3_000_000_000])
        loadDoubles(inty, doubles: [1.1])
        #expect(stackString(inty, .int) == "[ 3000000000 ]")
        #expect(stackString(inty, .double) == "[ 1.1 ]")

        doThis(.doubleDupTimes, to: inty)
        // It builds a loop rather than refusing outright.
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(!errorStrings(inty).contains { $0.contains("overflow") })
    }

    /// A count the run can afford finishes, and leaves nothing behind.
    @Test func `a DupTimes loop within budget finishes`() {
        loadInts(inty, ints: [100])
        loadDoubles(inty, doubles: [1.1])
        doThis(.doubleDupTimes, to: inty)
        inty.config.stepLimit = 20_000
        inty.run()

        #expect(inty.stacks[.double]!.count == 101)   // the original, plus 100
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(errorStrings(inty).isEmpty)
    }

    /// Raise the budget past what the run can afford and the *other* two limits
    /// take over — no bespoke guard needed for that either. A piling stack fed by
    /// an active loop is exactly the shape the runaway guard exists to catch, and
    /// `.iteratorPlay` on `.exec` is the control-side signal it looks for. It could
    /// see none of that when the copies arrived in a single step.
    @Test func `a DupTimes loop too big for its budget is caught by the runaway guard`() {
        loadInts(inty, ints: [3_000_000_000])
        loadDoubles(inty, doubles: [1.1])
        inty.config.stepLimit = 20_000

        doThis(.doubleDupTimes, to: inty)
        inty.run()

        #expect(errorStrings(inty).contains { $0.hasPrefix(Interpreter.runawayMarker) })
        #expect(inty.counter < 20_000)
        #expect(stackString(inty, .exec) == "[ ]")   // unwound
    }

    /// The whole point of the change: the work is bounded by the ordinary budgets,
    /// so a full stack reports being full rather than being refused in advance.
    @Test func `DupTimes fills a stack and says so`() {
        let inty = Interpreter.recordingProvenance()
        inty.config.maxStackDepth = 20
        inty.load(program: [DoubleItem(1.1), IntItem(500), InstructionItem(.doubleDupTimes)])
        inty.run(stepLimit: 10_000)

        #expect(inty.stacks[.double]!.count == 20)
        #expect(errorStrings(inty).contains { $0.contains("is full at maxStackDepth") })
    }

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    /// **The all-or-nothing bargain, for the five families that reach into a stack
    /// they never declared.**
    ///
    /// `takes:` used to conflate "what I consume" with "what I need". `doubleYank`
    /// takes an `.int` index and *reorders* `.double` — it cannot declare `.double`
    /// in `takes:`, which would pop the very item it means to move — so it declared
    /// only the int, popped it, discovered the empty stack, and errored **having
    /// already eaten the argument**. Sixty behaviors did this, and `.int` is the
    /// scarcest channel in the language.
    ///
    /// `alsoNeeds:` lets them say it, so the plan comes up short before anything pops
    /// anything. Nothing keeps the bargain by hand.
    ///
    /// Untested until now, which is exactly why it survived: `isSatisfied` read
    /// `needs`, and `needs` could not see the requirement — the measure and the bug
    /// shared a blind spot.
    @Test func `a combinator that cannot run consumes nothing`() {
        // These five reach into their own stack without declaring it in `takes:`.
        for instruction in [PushInstruction.doubleDeepDup, .doubleDupTimes,
                            .doubleShove, .doubleYank, .doubleYankDup] {
            let inty = Interpreter.recordingProvenance()
            inty.stacks[.int]!.prepend(IntItem(5))     // an index…
            // …and .double is empty, so there is nothing to act on.

            #expect(Interpreter.language[instruction]!.isSatisfied(by: inty) == false,
                    "\(instruction) claims it can run with an empty .double")
            doThis(instruction, to: inty)

            #expect(stackString(inty, .int) == "[ 5 ]",
                    "\(instruction) ate its index and achieved nothing")
            #expect(errorStrings(inty).contains { $0.contains("missing args") })
        }
    }

    /// Yank, YankDup and DeepDup want *two*, not one: they guard on
    /// `count - 1 > 0`, because with a single item there is nothing to reach past.
    /// Declaring one would have left them eating the index in exactly the case
    /// this exists to prevent.
    @Test func `the reaching combinators declare what they really need`() {
        #expect(Interpreter.language[.doubleDupTimes]!.staticNeeds == [.int: 1, .double: 1])
        #expect(Interpreter.language[.doubleShove]!.staticNeeds == [.int: 1, .double: 1])
        #expect(Interpreter.language[.doubleYank]!.staticNeeds == [.int: 1, .double: 2])
        #expect(Interpreter.language[.doubleYankDup]!.staticNeeds == [.int: 1, .double: 2])
        #expect(Interpreter.language[.doubleDeepDup]!.staticNeeds == [.int: 1, .double: 2])

        // When the index and the target share a stack, the counts ADD.
        #expect(Interpreter.language[.intYank]!.staticNeeds == [.int: 3])
        #expect(Interpreter.language[.intDupTimes]!.staticNeeds == [.int: 2])

        // A single item is not enough to yank: one int for the index, two to work on.
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(0), IntItem(7)] as [any Item])
        #expect(Interpreter.language[.intYank]!.isSatisfied(by: inty) == false)
        doThis(.intYank, to: inty)
        #expect(stackString(inty, .int) == "[ 0 7 ]")   // untouched
    }

    @Test func `combinator Empty works`() {
        loadBools(inty, bools: [])
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.boolStackIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        // Law 4b: a stand-in, the observed literal marked as such.
        #expect(callString(topItem(inty, .bool)) == "( .boolStackIsEmpty_actuallyWas_true )")

        doThis(.boolStackIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( .boolStackIsEmpty_actuallyWas_false )")
    }

    @Test func `combinator Eq works`() {
        // `xEq` is now a non-destructive query: it reads both operands and leaves
        // them, so the crux pops the two it read to reproduce just the bool.
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7])   // 9 on top

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")   // 9 == 38? no
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]", "both operands survive")
        #expect(callString(topItem(inty, .bool)) == "( 38 9 .intEq 2 .intPopItems )")

        doThis(.intPop, to: inty)   // discard 9 and 38 to reach the next pair
        doThis(.intPop, to: inty)

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")   // 4 == -4? no
        #expect(callString(topItem(inty, .bool)) == "( -4 4 .intEq 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false ]")   // -7 == -7? yes
        #expect(callString(topItem(inty, .bool)) == "( -7 -7 .intEq 2 .intPopItems )")
    }

    @Test func `combinator Flush works`() {
        loadInts(inty, ints: [11, 22])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intFlush, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `combinator Pop works`() {
        loadInts(inty, ints: [11, 22])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 22 ]")
        #expect(callString(topItem(inty, .int)) == "( )")
    }

    @Test func `combinator Rot works`() {

        loadInts(inty, ints: [11, 55, 999])
        #expect(stackString(inty, .int) == "[ 11 55 999 ]")

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 999 11 55 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 55 999 11 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 11 55 999 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

    }

    @Test func `combinator Shove works`() {
        loadInts(inty, ints: [-3, 2, 17, 0, 2])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 2.2 3.3 1.1 4.4 ]")

        // 17 clamps to the bottom: with 2.2 taken, three remain and there are
        // four places to put it. (It used to clamp one short of the bottom.)
        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 0 2 ]")
        #expect(stackString(inty, .double) == "[ 3.3 1.1 4.4 2.2 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ 2 ]")
        #expect(stackString(inty, .double) == "[ 3.3 1.1 4.4 2.2 ]")

        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .double) == "[ 1.1 4.4 3.3 2.2 ]")
        #expect(callString(topItem(inty, .double)) == "( )")
    }

    /// `n .xShove` undoes `n .xYank`, and on two items it is a swap — it used to
    /// clamp one short of the bottom, which made it a no-op there.
    @Test func `shove reaches the bottom and undoes yank`() {
        loadDoubles(inty, doubles: [1.1, 2.2])
        loadInts(inty, ints: [1])
        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .double) == "[ 2.2 1.1 ]")

        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4, 5.5])
        for depth in [0, 1, 3, 4] {
            let before = stackString(inty, .double)
            loadInts(inty, ints: [depth])
            doThis(.doubleYank, to: inty)
            loadInts(inty, ints: [depth])
            doThis(.doubleShove, to: inty)
            #expect(stackString(inty, .double) == before, "depth \(depth)")
        }
    }

    @Test func `combinator StackDepth works`() {
        loadInts(inty, ints: [11, 22])
        #expect(stackString(inty, .int) == "[ 11 22 ]")

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 2 11 22 ]")
        // Law 4b: a stand-in, the observed literal marked as such.
        #expect(callString(topItem(inty, .int)) == "( .intStackDepth_actuallyWas_2 )")

        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 3 2 11 22 ]")
        #expect(callString(topItem(inty, .int)) == "( .intStackDepth_actuallyWas_3 )")
    }

    @Test func `combinator Swap works`() {
        loadInts(inty, ints: [11, 22])
        #expect(stackString(inty, .int) == "[ 11 22 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

        doThis(.intSwap, to: inty)
        #expect(stackString(inty, .int) == "[ 22 11 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

        loadStrings(inty, strings: ["", "abcd", "efgh"])
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"efgh\" ]")

        doThis(.stringSwap, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd\" \"\" \"efgh\" ]")
        #expect(callString(topItem(inty, .string)) == "( )")

        doThis(.stringPop, to: inty)
        doThis(.stringSwap, to: inty)
        #expect(stackString(inty, .string) == "[ \"efgh\" \"\" ]")
        #expect(callString(topItem(inty, .string)) == "( )")
    }

    @Test func `combinator Yank works`() {
        loadInts(inty, ints: [-3, 2, 17, 0, 2])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 3.3 1.1 2.2 4.4 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 3.3 1.1 2.2 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 3.3 1.1 2.2 ]")

        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 4.4 3.3 2.2 ]")
        #expect(callString(topItem(inty, .double)) == "( )")
    }

    @Test func `combinator YankDup works`() {
        loadInts(inty, ints: [-3, 2, 17, 0, 2])
        loadDoubles(inty, doubles: [1.1, 2.2, 3.3, 4.4])
        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
        #expect(stackString(inty, .double) == "[ 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.2 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 2.2 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4 4.4 2.2 1.1 1.1 2.2 3.3 4.4 ]")

        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.2 4.4 4.4 2.2 1.1 1.1 2.2 3.3 4.4 ]")
        #expect(callString(topItem(inty, .double)) == "( )")
    }

}
