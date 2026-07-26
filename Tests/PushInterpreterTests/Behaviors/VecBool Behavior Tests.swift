//
//  VecBool Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/15/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VecBoolBehaviorTests {
    
    var inty = Interpreter()
    
    @Test func vecBoolButLast() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, true, false]),
                         VecBoolItem([true])
                        ])
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, true, false] [true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] .vecBoolButLast )")

        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true] [true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, true, false] .vecBoolButLast )")
        
        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true] .vecBoolButLast )")
    }
    
    @Test func vecBoolConcat() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false]),
                         VecBoolItem([true, true])
                        ])
        
        doThis(.vecBoolConcat, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] [true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] [] .vecBoolConcat )")
        
        doThis(.vecBoolConcat, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true] [false, false] .vecBoolConcat )")
    }

    @Test func vecBoolConj() {
        loadBools(inty, bools: [true, true, true])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false])
                        ])

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] [false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] true .vecBoolConj )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] true .vecBoolConj )")

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false, true] true .vecBoolConj )")
    }

    @Test func vecBoolContains() {
        // The needle and the result are both bools, so the result lands on .bool
        // atop the surviving needle — the crux swaps it up past the needle to clean
        // up, rather than a PopItems that would discard the result.
        loadBools(inty, bools: [false])
        inty.stacks[.vecBool]!.prepend(VecBoolItem([false, true]))
        doThis(.vecBoolContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]", "the result, atop the surviving needle")
        #expect(stackString(inty, .vecBool) == "[ [false, true] ]", "the vector survives")
        #expect(callString(topItem(inty, .bool)) == "( [false, true] false .vecBoolContains .boolSwap .boolPop 1 .vecBoolPopItems )")

        // A miss.
        let miss = Interpreter()
        miss.stacks[.vecBool]!.prepend(VecBoolItem([true, true]))
        miss.stacks[.bool]!.prepend(BoolItem(false))
        doThis(.vecBoolContains, to: miss)
        #expect(stackString(miss, .bool) == "[ false false ]", "result false, needle false survives")
    }

    @Test func vecBoolDrop() {
        loadInts(inty, ints: [-3, 0, 1, -2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false])
                        ])

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] -3 .vecBoolDrop )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 0 .vecBoolDrop )")

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 1 .vecBoolDrop )")

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] -2 .vecBoolDrop )")
    }

    @Test func vecBoolFirst() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false])
                        ])

        doThis(.vecBoolFirst, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolFirst, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( [true, false] .vecBoolFirst )")
    }

    @Test func vecBoolIndexOf() {
        // The index lands on .int, a different stack from the .bool needle, so a
        // plain PopItems cleans up each read stack.
        loadBools(inty, bools: [false])
        inty.stacks[.vecBool]!.prepend(VecBoolItem([true, false]))
        doThis(.vecBoolIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]", "index of false")
        #expect(stackString(inty, .vecBool) == "[ [true, false] ]", "the vector survives")
        #expect(stackString(inty, .bool) == "[ false ]", "the needle survives")
        #expect(callString(topItem(inty, .int)) == "( [true, false] false .vecBoolIndexOf 1 .boolPopItems 1 .vecBoolPopItems )")

        let absent = Interpreter()
        absent.stacks[.vecBool]!.prepend(VecBoolItem([true, true]))
        absent.stacks[.bool]!.prepend(BoolItem(false))
        doThis(.vecBoolIndexOf, to: absent)
        #expect(stackString(absent, .int) == "[ -1 ]")
    }

    @Test func vecBoolItemIsEmpty() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false])
                        ])
        
        doThis(.vecBoolItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .vecBool) == "[ [] [false] ]", "the vector survives")
        #expect(callString(topItem(inty, .bool)) == "( [] .vecBoolItemIsEmpty 1 .vecBoolPopItems )")

        doThis(.vecBoolPop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecBoolItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( [false] .vecBoolItemIsEmpty 1 .vecBoolPopItems )")
    }

    @Test func `vecBoolIterate records provenance only for its derived results`() {
        loadInts(inty, ints: [0])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([false, true]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.intInc)]))

        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .vecBool) == "[ [false, true] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        // The instruction only builds the iterator; `.iteratorPlay` does the work.
        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «[false, true] @0 ( .intInc )» ]")

        // The whole vector goes INTO the iterator and stays there. It used to
        // re-push a *shrunken* copy every pass, which was the one derived value
        // here and recorded `[previous, .vecBoolRest]` — a level deeper per
        // element, O(n) in the vector's length. There is no shrinking now, so
        // there is nothing to record: `.vecBoolRest` is named by nothing.
        inty.step()
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(inty.stacks[.exec]!.count == 3)
        #expect(inty.stacks[.exec]![0].call.isEmpty)   // mouse, to run
        #expect(inty.stacks[.exec]![1].call.isEmpty)   // .codeDo
        #expect(inty.stacks[.exec]![2].call.isEmpty)   // .iteratorPlay

        // The element is honestly the vector's 1st, and says so without depending
        // on how many passes have run.
        #expect(CodeItem(topItem(inty, .bool).crux()).pretty()
            == "( [false, true] 0 .vecBoolNth )")
    }

    @Test func `vecBoolIterate works for >1 item`() {
        loadInts(inty, ints: [17])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([false, true, false]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.intInc)]))

        #expect(stackString(inty, .int) == "[ 17 ]")
        #expect(stackString(inty, .vecBool) == "[ [false, true, false] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .int) == "[ 17 ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ ]")

        inty.step()   // first pass: element false, then the mouse
        #expect(stackString(inty, .int) == "[ 17 ]")
        #expect(stackString(inty, .exec) == "[ ( .intInc ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")

        inty.step()
        #expect(stackString(inty, .exec) == "[ .intInc .iteratorPlay ]")

        inty.step()   // the mouse runs
        #expect(stackString(inty, .int) == "[ 18 ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        // The loop comes back round in one step, not three: the vector and the
        // token no longer have to travel through `.exec` to be re-supplied.
        inty.step()   // second pass: element true
        #expect(stackString(inty, .exec) == "[ ( .intInc ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .bool) == "[ true false ]")

        for _ in 0..<3 { inty.step() }
        #expect(stackString(inty, .int) == "[ 19 ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        inty.step()   // third and last pass: element false, and the loop is done
        #expect(stackString(inty, .exec) == "[ ( .intInc ) .codeDo ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func `vecBoolIterate works for empty`() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                        ])
        // The mouse is a code argument now, so it waits on `.code` as a block.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

    }

    @Test func `vecBoolIterate works for one item`() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([false]),
                        ])
        // The mouse is a code argument now, so it waits on `.code` as a block.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .vecBool) == "[ [false] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecBoolIterate, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        // One element, so one pass and no continuation: the iterator is spent as
        // soon as it is played, and never comes to rest.
        inty.step()
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .vecBool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func vecBoolLast() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, true])
                        ])

        doThis(.vecBoolLast, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolLast, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( [false, false, true] .vecBoolLast )")
    }

    @Test func vecBoolLength() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, false])
                        ])
        
        // Non-destructive: the vector is read, not consumed. It stays on .vecBool,
        // and the crux pops what it read so it reproduces only the count.
        doThis(.vecBoolLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .vecBool) == "[ [] [false, false, false] ]")   // both survive
        #expect(callString(topItem(inty, .int)) == "( [] .vecBoolLength 1 .vecBoolPopItems )")

        doThis(.vecBoolPop, to: inty)   // discard the empty to reach the next vector

        doThis(.vecBoolLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(stackString(inty, .vecBool) == "[ [false, false, false] ]")   // still there
        #expect(callString(topItem(inty, .int)) == "( [false, false, false] .vecBoolLength 1 .vecBoolPopItems )")
    }
    
    @Test func vecBoolNth() {
        loadInts(inty, ints: [-3, 1, 7777])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, true]),
                         VecBoolItem([false, false, true])
                        ])

        #expect(stackString(inty, .vecBool) == "[ [] [true, false, true] [false, false, true] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7777 ]")

        doThis(.vecBoolNth, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolNth, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( [true, false, true] 1 .vecBoolNth )")

        doThis(.vecBoolNth, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(callString(topItem(inty, .bool)) == "( [false, false, true] 7777 .vecBoolNth )")
    }

    @Test func vecBoolOccurrencesOf() {
        loadBools(inty, bools: [true])
        inty.stacks[.vecBool]!.prepend(VecBoolItem([true, true, true, false]))
        doThis(.vecBoolOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 3 ]", "three trues")
        #expect(stackString(inty, .vecBool) == "[ [true, true, true, false] ]", "the vector survives")
        #expect(stackString(inty, .bool) == "[ true ]", "the needle survives")
        #expect(callString(topItem(inty, .int)) == "( [true, true, true, false] true .vecBoolOccurrencesOf 1 .boolPopItems 1 .vecBoolPopItems )")

        let none = Interpreter()
        none.stacks[.vecBool]!.prepend(VecBoolItem([true, true]))
        none.stacks[.bool]!.prepend(BoolItem(false))
        doThis(.vecBoolOccurrencesOf, to: none)
        #expect(stackString(none, .int) == "[ 0 ]")
    }

    /// **The order changed here, deliberately.** This used to reverse before
    /// pushing, so element 0 landed on top; it now walks front to back like
    /// everything else, so the LAST element lands on top. See "Collections are
    /// walked front-to-back" in "Notes on Push/Design Principles.md".
    ///
    /// It also emits one element per pass rather than exploding, so the elements
    /// do not appear until the loop runs.
    @Test func vecBoolPushAll() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, true, true]),
                        ])

        // An empty vector yields nothing at all — not even an iterator.
        doThis(.vecBoolPushAll, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")

        doThis(.vecBoolPushAll, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")

        inty.run(stepLimit: 10_000)
        // Front to back: element 3 was pushed last, so it is on top.
        #expect(stackString(inty, .bool) == "[ true true false true ]")
        #expect(stackString(inty, .iterator) == "[ ]")

        // Each element names its own index rather than how far down a pile it
        // landed — so this record says nothing about the other three.
        #expect(callString(topItem(inty, .bool))
            == "( [true, false, true, true] 3 .vecBoolNth )")
        doThis(.boolPop, to: inty)
        #expect(CodeItem(topItem(inty, .bool).crux()).pretty()
            == "( [true, false, true, true] 2 .vecBoolNth )")
    }

    @Test func vecBoolRemove() {
        loadBools(inty, bools: [false, false, false])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, true, false]),
                         VecBoolItem([true, true, true])
                        ])

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, true, false] [true, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] false .vecBoolRemove )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] [true, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, true, false] false .vecBoolRemove )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true] false .vecBoolRemove )")
    }

    @Test func vecBoolReplace() {
        loadBools(inty, bools: [false, true, true, false, false, true])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, true]),
                         VecBoolItem([true, false, true])
                        ])

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, false, true] [true, false, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] true false .vecBoolReplace )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true] [true, false, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false, true] false true .vecBoolReplace )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, true] true false .vecBoolReplace )")
    }

    @Test func vecBoolReplaceFirst() {
        loadBools(inty, bools: [false, true, true, false, false, true])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false]),
                         VecBoolItem([true, true])
                        ])

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, false] [true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] true false .vecBoolReplaceFirst )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false] [true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] false true .vecBoolReplaceFirst )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true] true false .vecBoolReplaceFirst )")
    }

    @Test func vecBoolRest() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false])
                        ])
        
        doThis(.vecBoolRest, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] .vecBoolRest )")
        
        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRest, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] .vecBoolRest )")
    }
    
    @Test func vecBoolReverse() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, false])
                        ])
        
        doThis(.vecBoolReverse, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] .vecBoolReverse )")
        
        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReverse, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false] .vecBoolReverse )")
    }

    @Test func vecBoolSet() {
        loadBools(inty, bools: [false, false, false, false])
        loadInts(inty, ints: [1, 2, -8, 43])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true,true,true,true]),
                         VecBoolItem([true,true,true,true,]),
                         VecBoolItem([true,true,true,true,]),
                        ])

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, true, true] [true, true, true, true] [true, true, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] false 1 .vecBoolSet )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false, true] [true, true, true, true] [true, true, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true, true] false 2 .vecBoolSet )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true, true, true] [true, true, true, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true, true] false -8 .vecBoolSet )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true, true] false 43 .vecBoolSet )")
    }

    @Test func vecBoolSubVec() {
        loadInts(inty, ints: [1,9,2,1,2,-1,1,1])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, false, false, true]),
                         VecBoolItem([true, true, false, false, true]),
                         VecBoolItem([true, true, false, false, true])
                        ])

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, false, false, true] [true, true, false, false, true] [true, true, false, false, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] 9 1 .vecBoolSubVec )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false] [true, true, false, false, true] [true, true, false, false, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false, false, true] 1 2 .vecBoolSubVec )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false] [true, true, false, false, true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false, false, true] -1 2 .vecBoolSubVec )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false, false, true] 1 1 .vecBoolSubVec )")
    }

    @Test func vecBoolTake() {
        loadInts(inty, ints: [-3, 99, 1, -1])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false])
                        ])
       
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [] -3 .vecBoolTake )")
        
        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false, false] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 99 .vecBoolTake )")
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 1 .vecBoolTake )")
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(callString(topItem(inty, .vecBool)) == "( [true] -1 .vecBoolTake )")
    }

}
