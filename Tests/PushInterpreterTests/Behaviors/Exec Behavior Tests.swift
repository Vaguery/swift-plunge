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
        inty.stacks[.exec]!.prepend(
            contentsOf: [BoolItem(false)])

        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 3456 ]")

        doThis(.execDoCount, to: inty)
        #expect(stackString(inty, .exec) == "[ 0 3456 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 3456 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 3456 0 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 0 false 1 3456 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")
    }

    @Test func `execDoCount doesn't loop if the index < 1`() {
        loadInts(inty, ints: [0])
        inty.stacks[.exec]!.prepend(
            contentsOf: [BoolItem(false)])

        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .int) == "[ 0 ]")

        doThis(.execDoCount, to: inty)
        #expect(stackString(inty, .exec) == "[ 0 false ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `execDoRange doesn't loop if the counters are the same`() {
        loadInts(inty, ints: [3, 4])
        inty.stacks[.exec]!.prepend(
            contentsOf: [BoolItem(false)])

        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .int) == "[ 3 4 ]")

        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .exec) == "[ 4 false ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `execDoRange handles extreme bounds without trapping`() {
        // start - end overflows (and abs would trap on Int.min); the guard must
        // treat the counters as far apart and take the looping branch, not crash
        loadInts(inty, ints: [Int.min, Int.max])   // end = Int.min, start = Int.max
        inty.stacks[.exec]!.prepend(contentsOf: [BoolItem(false)])

        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .exec).contains(".execDoRange"))
    }

    @Test func `execDoRange loops if the start and end are different by 2+`() {
        loadInts(inty, ints: [4, 7])
        inty.stacks[.exec]!.prepend(
            contentsOf: [BoolItem(false)])

        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 4 7 ]")

        doThis(.execDoRange, to: inty)
        #expect(stackString(inty, .exec) == "[ 7 false 6 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false 6 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 6 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 4 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 6 false 5 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false 5 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 5 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 4 .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 5 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execDoRange false ]")
        #expect(stackString(inty, .int) == "[ 4 5 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 5 false ]")
        #expect(stackString(inty, .int) == "[ 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .int) == "[ 5 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 5 6 7 ]")
        #expect(stackString(inty, .bool) == "[ false false false ]")
    }

    @Test func `execDoTimes doesn't loop if the counter is not positive`() {
        loadInts(inty, ints: [-5, 0])
        inty.stacks[.exec]!.prepend(
            contentsOf: [BoolItem(false)])

        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .int) == "[ -5 0 ]")

        doThis(.execDoTimes, to: inty)
        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .int) == "[ 0 ]")

        doThis(.execDoTimes, to: inty)
        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `execDoTimes loops if the counter is positive`() {
        loadInts(inty, ints: [33])
        inty.stacks[.exec]!.prepend(
            contentsOf: [BoolItem(false)])

        #expect(stackString(inty, .exec) == "[ false ]")
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ 33 ]")

        // The continuation is now pushed as four separate items rather than one
        // CodeItem that `.exec` unwraps on the following step, so the same
        // sequence arrives one step earlier per iteration.
        doThis(.execDoTimes, to: inty)
        #expect(stackString(inty, .exec) == "[ false 32 .execDoTimes false ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 32 .execDoTimes false ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execDoTimes false ]")
        #expect(stackString(inty, .int) == "[ 32 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ false 31 .execDoTimes false ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        // The counter is the one derived result, and its provenance folds to a
        // single node rather than deepening once per pass.
        let counter = inty.stacks[.exec]![1]
        #expect(counter.call.count == 1)
        #expect(counter.call[0] is IteratorItem)
    }

    @Test func `execDoWhile acts once even if a false is found`() {
        loadBools(inty, bools: [false, true, false], contingent: [1])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])

        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")

        doThis(.execDoWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        // The body copy is a duplication that stays on `.exec`, so it records no
        // provenance (law 1). It used to be tagged `index: 2`.
        #expect(topItem(inty, .exec).call.isEmpty)
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
    }

    @Test func `execDoWhile is a lot like execWhile when a true is found`() {
        loadBools(inty, bools: [true, true, false], contingent: [1])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])

        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.execDoWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
        // All three results are combinatory — two body copies and a freshly
        // minted continuation token — so none records provenance. They used to
        // be tagged `index:` 0, 1, 2.
        #expect(inty.stacks[.exec]!.prefix(3).allSatisfy { $0.call.isEmpty })

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).call.isEmpty)

        inty.step()
        #expect(stackString(inty, .exec) == "[ 44 .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .exec).isContingent == true)
        #expect(callString(topItem(inty, .exec)) == "( )")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ ]")
    }

    @Test func execIf() {
        loadBools(inty, bools: [true])
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))

        #expect(stackString(inty, .exec) == "[ 3.4 44 ]")

        doThis(.execIf, to: inty)
        #expect(stackString(inty, .exec) == "[ 3.4 ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")

        doThis(.execFlush, to: inty)

        inty.stacks[.bool]!.prepend(BoolItem(false, isContingent: false))
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))

        doThis(.execIf, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
    }

    @Test func execK() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))

        #expect(stackString(inty, .exec) == "[ 3.4 true 44 ]")

        doThis(.execK, to: inty)
        #expect(stackString(inty, .exec) == "[ 3.4 44 ]")
    }

    @Test func execS() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(DoubleItem(3.4))

        #expect(stackString(inty, .exec) == "[ 3.4 true 44 ]")

        // The `(y z)` continuation is emitted as two separate `.exec` items now
        // rather than a CodeItem unwrapped on a later step. The contingency the
        // wrapper used to spread onto its children is applied to them directly.
        doThis(.execS, to: inty)
        #expect(stackString(inty, .exec) == "[ 3.4 44 true 44 ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
        #expect(inty.stacks[.exec]![2].isContingent == true)
    }

    @Test func execWhen() {
        loadBools(inty, bools: [true, false], contingent: [0])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])
        
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        
        doThis(.execWhen, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(topItem(inty, .exec).isContingent == true)
        #expect(callString(topItem(inty, .exec)) == "( )")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.execWhen, to: inty)
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
        #expect(stackString(inty, .bool) == "[ ]")
    }

    @Test func `execWhile doesn't act if a false is found`() {
        loadBools(inty, bools: [false, true, false], contingent: [1])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])

        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")

        doThis(.execWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
    }

    @Test func `execWhile pushes several items back to .exec when true is found`() {
        loadBools(inty, bools: [true, true, false], contingent: [1])
        inty.stacks[.exec]!.prepend(
            contentsOf: [IntItem(44), IntItem(33), IntItem(22)])

        #expect(stackString(inty, .exec) == "[ 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.execWhile, to: inty)
        #expect(stackString(inty, .exec) == "[ 44 .execWhile 44 33 22 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .exec).isContingent == false)
        #expect(callString(topItem(inty, .exec)) == "( )")
        // Combinatory results record no provenance (laws 1 and 4). These used to
        // be tagged `index:` 0, 1, 2.
        #expect(inty.stacks[.exec]!.prefix(3).allSatisfy { $0.call.isEmpty })
    }

    @Test func execY() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(IntItem(1))
        
        #expect(stackString(inty, .exec) == "[ 1 true 44 ]")
        
        // The `(.execY x)` continuation is pushed as two separate `.exec` items
        // rather than a CodeItem unwrapped on a later step, so each cycle of the
        // Y combinator now takes two steps instead of three.
        doThis(.execY, to: inty)
        #expect(stackString(inty, .exec) == "[ 1 .execY 1 true 44 ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execY 1 true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 1 .execY 1 true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .execY 1 true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 1 ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ 1 .execY 1 true 44 ]")
        #expect(stackString(inty, .int) == "[ 1 1 ]")
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
