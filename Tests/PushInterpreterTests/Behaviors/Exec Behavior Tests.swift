//
//  Exec Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/15/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct ExecBehaviorTests {

    var inty = Interpreter()

    /// `.execDoCount` used to rewrite itself into an `.execDoRange` continuation
    /// and let that do the counting, re-pushing both bounds onto `.int` every
    /// pass. It now builds an iterator that holds the bounds and hands it to
    /// `.iteratorPlay` — the counting is Swift's job, and none of it is expressed
    /// in Push.
    @Test func `execDoCount builds an iterator and plays it when counter > 0`() {
        loadInts(inty, ints: [3456])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 3456 ]")

        doThis(.execDoCount, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «0→3456 by 1 @0 ( false )» ]")
        // The bounds are inside the iterator now, not loose on `.int`.
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()   // one pass: the index, the body, and the loop's next copy
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «0→3456 by 1 @1 ( false )» ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()   // the body comes to rest on .code, data until asked for
        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .code) == "[ ( false ) ]")

        inty.step()   // .codeDo spreads it, so this pass's body runs
        #expect(stackString(inty, .exec) == "[ false .iteratorPlay ]")
        #expect(stackString(inty, .code) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
    }

    /// Counting 0 toward `x` is exactly `x` passes, because the range stops one
    /// short of its destination.
    @Test func `execDoCount runs its body exactly count times`() {
        let inty = Interpreter()
        inty.load(program: [
            IntItem(5),
            CodeItem([BoolItem(true)]),
            InstructionItem(.execDoCount),
        ])
        inty.run(stepLimit: 10_000)

        #expect(inty.stacks[.bool]!.count == 5)
        // …and each pass left its index behind for the body to have read.
        #expect(stackString(inty, .int) == "[ 4 3 2 1 0 ]")
        #expect(inty.stacks[.iterator]!.isEmpty)
    }

    @Test func `execDoCount doesn't loop if the index < 1`() {
        loadInts(inty, ints: [0])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 0 ]")

        doThis(.execDoCount, to: inty)
        #expect(stackString(inty, .exec) == "[ 0 ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `execDoRange doesn't loop if the counters are the same`() {
        loadInts(inty, ints: [3, 4])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 3 4 ]")

        // Building the iterator and running a pass are separate now: the
        // instruction only builds, and `.iteratorPlay` does the work.
        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «4→3 by -1 @0 ( false )» ]")
        #expect(stackString(inty, .int) == "[ ]")

        // One pass, and no continuation: 4 and 3 are within a stride of each
        // other, so this loop was over before it began. The index goes straight to
        // `.int` rather than travelling via `.exec` as it used to, and the spent
        // iterator is consumed rather than coming to rest.
        inty.step()
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo ]")
        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func `execDoRange handles extreme bounds without trapping`() {
        // The difference between the bounds overflows (and abs would trap on
        // Int.min); `hasNextPass` must read that as "as far apart as possible" and
        // keep looping, not crash.
        loadInts(inty, ints: [Int.min, Int.max])   // end = Int.min, start = Int.max
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .exec).contains(".iteratorPlay"))

        inty.step()
        #expect(stackString(inty, .int) == "[ 9223372036854775807 ]")
        #expect(stackString(inty, .exec).contains(".iteratorPlay"))
        #expect(stackString(inty, .iterator).contains("@1"))
    }

    @Test func `execDoRange loops if the start and end are different by 2+`() {
        loadInts(inty, ints: [4, 7])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 4 7 ]")

        // Counting DOWN from 7 toward 4, since start > end. The whole loop is one
        // `.iteratorPlay` and one iterator; the bounds never touch `.int` again.
        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «7→4 by -1 @0 ( false )» ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()   // first pass: index 7, the body, and the loop's next copy
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «7→4 by -1 @1 ( false )» ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .code) == "[ ( false ) ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false .iteratorPlay ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()   // second pass: index 6
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «7→4 by -1 @2 ( false )» ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")

        for _ in 0..<3 { inty.step() }   // run the body again
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false false ]")

        inty.step()   // third pass: index 5, and the loop ends there
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo ]")
        #expect(stackString(inty, .int) == "[ 5 6 7 ]")
        // The destination is EXCLUDED: 4 is never emitted, and the iterator is
        // spent rather than resting. This preserves the pre-iterator behavior
        // exactly — see `hasNextPass`.
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// The loop index is genuinely derived, and its record names its origin and
    /// its offset — bounded, and independent of how many passes have run.
    @Test func `execDoRange indices record origin and offset`() {
        let inty = Interpreter()
        inty.load(program: [
            IntItem(7), IntItem(4), CodeItem([]), InstructionItem(.execDoRange),
        ])
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .int) == "[ 5 6 7 ]")
        let last = inty.stacks[.int]!.first!
        #expect(CodeItem(last.crux()).pretty() == "( 7 -2 .intAdd )")
    }

    @Test func `execDoTimes doesn't loop if the counter is not positive`() {
        loadInts(inty, ints: [-5, 0])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ -5 0 ]")

        doThis(.execDoTimes, to: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 0 ]")

        doThis(.execDoTimes, to: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `execDoTimes loops if the counter is positive`() {
        loadInts(inty, ints: [33])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 33 ]")

        // Identical to `.execDoCount`'s iterator but `silent`: the index is the
        // loop's own business and is never shown to the body. That flag is now the
        // whole of the difference between the two instructions.
        doThis(.execDoTimes, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «0→33 by 1 @0 silent ( false )» ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()   // a pass emits the body and the loop's next copy — no index
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «0→33 by 1 @1 silent ( false )» ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .code) == "[ ( false ) ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false .iteratorPlay ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        // Nothing about the count is visible in Push while the loop runs.
        #expect(stackString(inty, .int) == "[ ]")
    }

    /// "Do the body, x times" — and the count never leaks onto `.int`.
    @Test func `execDoTimes runs its body exactly count times, silently`() {
        let inty = Interpreter()
        inty.load(program: [
            IntItem(33),
            CodeItem([BoolItem(true)]),
            InstructionItem(.execDoTimes),
        ])
        inty.run(stepLimit: 10_000)

        #expect(inty.stacks[.bool]!.count == 33)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(inty.stacks[.iterator]!.isEmpty)
    }

    @Test func `execDoWhile acts once even if a false is found`() {
        loadBools(inty, bools: [false, true, false], contingent: [1])
        // 44 was the body — a code argument now, so it waits on `.code`. 33 and
        // 22 stay pending on `.exec` behind the instruction, as before.
        inty.stacks[.exec]!.prepend(contentsOf: [IntItem(33), IntItem(22)])
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))

        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")

        doThis(.execDoWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        // The body copy is a duplication that stays on `.exec`, so it records no
        // provenance (law 1). It used to be tagged `index: 2`.
        #expect(topItem(inty, .exec).call.isEmpty)
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
    }

    @Test func `execDoWhile is a lot like execWhile when a true is found`() {
        loadBools(inty, bools: [true, true, false], contingent: [1])
        // 44 was the body — a code argument now, so it waits on `.code`. 33 and
        // 22 stay pending on `.exec` behind the instruction, as before.
        inty.stacks[.exec]!.prepend(contentsOf: [IntItem(33), IntItem(22)])
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))

        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")

        // The continuation runs the body once and re-supplies it for the retest:
        // body, .codeDo, body, .execWhile.
        doThis(.execDoWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo ( 44 ) .execWhile 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        // The guard consumed was the FIRST `true`, which is not contingent.
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
        // All four results are combinatory — two body copies and two freshly
        // minted tokens — so none records provenance.
        #expect(inty.stacks[.exec]!.prefix(4).allSatisfy { $0.call.isEmpty })

        inty.step()   // the body comes to rest on .code
        #expect(stackString(inty, .exec) == "[ .codeDo ( 44 ) .execWhile 33 22 ]")
        #expect(stackString(inty, .code) == "[ ( 44 ) ]")
        #expect(topItem(inty, .exec).call.isEmpty)

        inty.step()   // .codeDo spreads it back out, so it runs
        #expect(stackString(inty, .exec) == "[ 44 ( 44 ) .execWhile 33 22 ]")
        #expect(stackString(inty, .code) == "[ ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")

        inty.step()   // 44 → .int
        inty.step()   // the second copy re-supplies .code
        #expect(stackString(inty, .exec) == "[ .execWhile 33 22 ]")
        #expect(stackString(inty, .code) == "[ ( 44 ) ]")
        #expect(stackString(inty, .bool) == "[ true false ]")

        inty.step()   // .execWhile retests — this time on the CONTINGENT true
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo ( 44 ) .execWhile 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        // ...so this pass's body copy is contingent, where the first was not.
        // Contingency follows the guard through the loop, as it always did.
        #expect(topItem(inty, .exec).isContingent == true)
        #expect(callString(topItem(inty, .exec)) == "( )")
    }

    @Test func execIf() {
        loadBools(inty, bools: [true])
        // Both branches are code arguments now, so they wait on `.code`. Written
        // 44 then 3.4, i.e. `( 44 ) ( 3.4 ) .execIf`.
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))
        inty.stacks[.code]!.prepend(CodeItem([DoubleItem(3.4)]))

        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.execIf, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")

        doThis(.execFlush, to: inty)

        inty.stacks[.bool]!.prepend(BoolItem(false, isContingent: false))
        // Both branches are code arguments now, so they wait on `.code`. Written
        // 44 then 3.4, i.e. `( 44 ) ( 3.4 ) .execIf`.
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))
        inty.stacks[.code]!.prepend(CodeItem([DoubleItem(3.4)]))

        doThis(.execIf, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 3.4 ) .codeDo ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
    }

    @Test func execK() {
        // All three were code arguments read off `.exec`; they are blocks on
        // `.code` now. Written 44, true, 3.4 — so 3.4 ends up on top.
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(true)], isContingent: true))
        inty.stacks[.code]!.prepend(CodeItem([DoubleItem(3.4)]))

        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.execK, to: inty)
        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo ]")
    }

    @Test func execS() {
        // All three were code arguments read off `.exec`; they are blocks on
        // `.code` now. Written 44, true, 3.4 — so 3.4 ends up on top.
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(true)], isContingent: true))
        inty.stacks[.code]!.prepend(CodeItem([DoubleItem(3.4)]))

        #expect(stackString(inty, .exec) == "[ ]")

        // The `(y z)` continuation is emitted as two separate `.exec` items now
        // rather than a CodeItem unwrapped on a later step. The contingency the
        // wrapper used to spread onto its children is applied to them directly.
        doThis(.execS, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo ( 3.4 ) .codeDo ( true ) .codeDo ( 3.4 ) .codeDo ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
        // The contingent argument is `( true )`, now at [4] rather than [2]:
        // a `.codeDo` sits between each block, since each has to be unwrapped
        // to run. Both copies of it carry the net contingency of all three
        // arguments, as they did when unwrapping spread it onto the children.
        #expect(inty.stacks[.exec]![4].pretty() == "( true )")
        #expect(inty.stacks[.exec]![4].isContingent == true)
        #expect(inty.stacks[.exec]![6].isContingent == true)   // the (y z) copy of z
    }

    @Test func execWhen() {
        loadBools(inty, bools: [true, false], contingent: [0])
        // 44 was the body — a code argument now, so it waits on `.code`. 33 and
        // 22 stay pending on `.exec` behind the instruction, as before.
        inty.stacks[.exec]!.prepend(contentsOf: [IntItem(33), IntItem(22)])
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))
        
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        
        doThis(.execWhen, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo 33 22 ]")
        #expect(topItem(inty, .exec).isContingent == true)
        #expect(callString(topItem(inty, .exec)) == "( )")
        #expect(stackString(inty, .bool) == "[ false ]")

        // A guard of false discards its block, so give the second call one of its
        // own: the first call consumed what was on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([IntItem(99)]))
        doThis(.execWhen, to: inty)
        // ...and it is gone, leaving only the first call's continuation.
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo 33 22 ]")
        #expect(stackString(inty, .code) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")
    }

    @Test func `execWhile doesn't act if a false is found`() {
        loadBools(inty, bools: [false, true, false], contingent: [1])
        // 44 was the body — a code argument now, so it waits on `.code`. 33 and
        // 22 stay pending on `.exec` behind the instruction, as before.
        inty.stacks[.exec]!.prepend(contentsOf: [IntItem(33), IntItem(22)])
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))

        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")

        doThis(.execWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
    }

    @Test func `execWhile pushes several items back to .exec when true is found`() {
        loadBools(inty, bools: [true, true, false], contingent: [1])
        // 44 was the body — a code argument now, so it waits on `.code`. 33 and
        // 22 stay pending on `.exec` behind the instruction, as before.
        inty.stacks[.exec]!.prepend(contentsOf: [IntItem(33), IntItem(22)])
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))

        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.execWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 44 ) .codeDo ( 44 ) .execWhile 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
        // Combinatory results record no provenance (laws 1 and 4). These used to
        // be tagged `index:` 0, 1, 2.
        #expect(inty.stacks[.exec]!.prefix(3).allSatisfy { $0.call.isEmpty })
    }

    @Test func execY() {
        // Code arguments live on `.code` now. Written 44, true, 1.
        inty.stacks[.code]!.prepend(CodeItem([IntItem(44)]))
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(true)], isContingent: true))
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1)]))
        
        #expect(stackString(inty, .exec) == "[ ]")
        
        // The `(.execY x)` continuation is pushed as two separate `.exec` items
        // rather than a CodeItem unwrapped on a later step, so each cycle of the
        // Y combinator now takes two steps instead of three.
        doThis(.execY, to: inty)
        #expect(stackString(inty, .exec) == "[ ( 1 ) .codeDo ( 1 ) .execY ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo ( 1 ) .execY ]")
        #expect(stackString(inty, .int) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 1 ( 1 ) .execY ]")
        #expect(stackString(inty, .int) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ ( 1 ) .execY ]")
        #expect(stackString(inty, .int) == "[ 1 ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execY ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
    }

    @Test func `execEq works with inputs (bug fix)`() {
        inty.stacks[.exec]!.prepend(InstructionItem(.input0))
        inty.stacks[.exec]!.prepend(InstructionItem(.input0))
        inty.stacks[.exec]!.prepend(InstructionItem(.execEq))

        #expect(stackString(inty, .exec) == "[ .execEq .input0 .input0 ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ true ]")
    }

}
