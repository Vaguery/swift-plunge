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

    @Test func `execDoCount creates an execDoRange continuation when counter > 0`() {
        loadInts(inty, ints: [3456])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 3456 ]")

        doThis(.execDoCount, to: inty)
        #expect(stackString(inty, .exec) == "[ 0 3456 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 3456 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 3456 0 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 3456 0 ]")
        #expect(stackString(inty, .bool) == "[ ]")
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

        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .exec) == "[ 4 ( false ) .codeDo ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `execDoRange handles extreme bounds without trapping`() {
        // start - end overflows (and abs would trap on Int.min); the guard must
        // treat the counters as far apart and take the looping branch, not crash
        loadInts(inty, ints: [Int.min, Int.max])   // end = Int.min, start = Int.max
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .exec).contains(".execDoRange"))
    }

    @Test func `execDoRange loops if the start and end are different by 2+`() {
        loadInts(inty, ints: [4, 7])
        // The body is a code argument now, so it waits on `.code`.
        inty.stacks[.code]!.prepend(CodeItem([BoolItem(false)]))

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 4 7 ]")

        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .exec) == "[ 7 ( false ) .codeDo 6 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo 6 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo 6 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false 6 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 6 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 4 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 4 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 6 ( false ) .codeDo 5 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo 5 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo 5 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false 5 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 5 4 ( false ) .execDoRange ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false false ]")
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

        // The continuation is `body .codeDo count-1 body .execDoTimes`: the body
        // lands on `.code`, `.codeDo` spreads it to run it, and the second copy
        // re-supplies `.code` for the next pass.
        doThis(.execDoTimes, to: inty)
        #expect(stackString(inty, .exec) == "[ ( false ) .codeDo 32 ( false ) .execDoTimes ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo 32 ( false ) .execDoTimes ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false 32 ( false ) .execDoTimes ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 32 ( false ) .execDoTimes ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()   // the counter comes to rest on .int
        #expect(stackString(inty, .exec) == "[ ( false ) .execDoTimes ]")
        #expect(stackString(inty, .int) == "[ 32 ]")

        // The counter is the one derived result here, and its provenance folds to
        // a single node rather than deepening once per pass. `.first` rather than
        // `[0]` so a miss reports instead of trapping the whole suite.
        let counter = inty.stacks[.int]!.first
        #expect(counter?.call.count == 1)
        #expect(counter?.call.first is IteratorItem)
        #expect(CodeItem(counter!.crux()).pretty() == "( 33 -1 .intAdd )")

        inty.step()   // the re-supplied body comes to rest on .code, ready again
        #expect(stackString(inty, .exec) == "[ .execDoTimes ]")
        #expect(stackString(inty, .code) == "[ ( false ) ]")
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
