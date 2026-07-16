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
                         VecBoolItem([true], isContingent: true)
                        ])
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, true, false] [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] .vecBoolButLast )")

        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true] [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, true, false] .vecBoolButLast )")
        
        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolButLast, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true] .vecBoolButLast )")
    }
    
    @Test func vecBoolConcat() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([], isContingent: true),
                         VecBoolItem([false, false], isContingent: false),
                         VecBoolItem([true, true], isContingent: false)
                        ])
        
        doThis(.vecBoolConcat, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] [true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] [] .vecBoolConcat )")
        
        doThis(.vecBoolConcat, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true] [false, false] .vecBoolConcat )")
    }

    @Test func vecBoolConj() {
        loadBools(inty, bools: [true, true, true], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false], isContingent: false)
                        ])

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] true .vecBoolConj )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] true .vecBoolConj )")

        doThis(.vecBoolConj, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false, true] true .vecBoolConj )")
    }

    @Test func vecBoolContains() {
        loadBools(inty, bools: [true, true, false], contingent: [1,2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true]),
                         VecBoolItem([false, true])
                        ])

        #expect(stackString(inty, .vecBool) == "[ [] [true, true] [false, true] ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.vecBoolContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [] true .vecBoolContains )")

        doThis(.boolPop, to: inty)

        doThis(.vecBoolContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [true, true] true .vecBoolContains )")

        doThis(.boolPop, to: inty)

        doThis(.vecBoolContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [false, true] false .vecBoolContains )")
    }

    @Test func vecBoolDrop() {
        loadInts(inty, ints: [-3, 0, 1, -2], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false], isContingent: false)
                        ])

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] -3 .vecBoolDrop )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 0 .vecBoolDrop )")

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 1 .vecBoolDrop )")

        doThis(.vecBoolDrop, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] -2 .vecBoolDrop )")
    }

    @Test func vecBoolFirst() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false], isContingent: true)
                        ])

        doThis(.vecBoolFirst, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolFirst, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [true, false] .vecBoolFirst )")
    }

    @Test func vecBoolIndexOf() {
        loadBools(inty, bools: [true, false, false], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false]),
                         VecBoolItem([true, false])
                        ])

        #expect(stackString(inty, .vecBool) == "[ [] [false, false] [true, false] ]")
        #expect(stackString(inty, .bool) == "[ true false false ]")

        doThis(.vecBoolIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]") // returns -1

        doThis(.vecBoolIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 -1 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [false, false] false .vecBoolIndexOf )")

        doThis(.vecBoolIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [true, false] false .vecBoolIndexOf )")
    }

    @Test func vecBoolItemIsEmpty() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false], isContingent: true)
                        ])
        
        doThis(.vecBoolItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [] .vecBoolItemIsEmpty )")

        doThis(.vecBoolItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [false] .vecBoolItemIsEmpty )")
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
                         VecBoolItem([false, false, true], isContingent: true)
                        ])

        doThis(.vecBoolLast, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")

        doThis(.vecBoolLast, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [false, false, true] .vecBoolLast )")
    }

    @Test func vecBoolLength() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, false], isContingent: true)
                        ])
        
        doThis(.vecBoolLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [] .vecBoolLength )")

        doThis(.vecBoolLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [false, false, false] .vecBoolLength )")
    }
    
    @Test func vecBoolNth() {
        loadInts(inty, ints: [-3, 1, 7777], contingent: [2])
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
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [true, false, true] 1 .vecBoolNth )")

        doThis(.vecBoolNth, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [false, false, true] 7777 .vecBoolNth )")
    }

    @Test func vecBoolOccurrencesOf() {
        loadBools(inty, bools: [true, false, false], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, true, true, ]),
                         VecBoolItem([true, true, true, false])
                        ])

        doThis(.vecBoolOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [] true .vecBoolOccurrencesOf )")

        doThis(.vecBoolOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [true, true, true, true] false .vecBoolOccurrencesOf )")

        doThis(.vecBoolOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [true, true, true, false] false .vecBoolOccurrencesOf )")
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
                         VecBoolItem([true, false, true, true], isContingent: true),
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
        #expect(topItem(inty, .bool).isContingent == true)
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
        loadBools(inty, bools: [false, false, false], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, true, false]),
                         VecBoolItem([true, true, true])
                        ])

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, true, false] [true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] false .vecBoolRemove )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] [true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, true, false] false .vecBoolRemove )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRemove, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true] false .vecBoolRemove )")
    }

    @Test func vecBoolReplace() {
        loadBools(inty, bools: [false, true, true, false, false, true],contingent: [4])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false, true]),
                         VecBoolItem([true, false, true])
                        ])

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, false, true] [true, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] true false .vecBoolReplace )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true] [true, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false, true] false true .vecBoolReplace )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplace, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, true] true false .vecBoolReplace )")
    }

    @Test func vecBoolReplaceFirst() {
        loadBools(inty, bools: [false, true, true, false, false, true],contingent: [4])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([false, false]),
                         VecBoolItem([true, true])
                        ])

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [false, false] [true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] true false .vecBoolReplaceFirst )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false] [true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [false, false] false true .vecBoolReplaceFirst )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReplaceFirst, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true] true false .vecBoolReplaceFirst )")
    }

    @Test func vecBoolRest() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false], isContingent: true)
                        ])
        
        doThis(.vecBoolRest, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] .vecBoolRest )")
        
        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolRest, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] .vecBoolRest )")
    }
    
    @Test func vecBoolReverse() {
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, false], isContingent: true)
                        ])
        
        doThis(.vecBoolReverse, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] .vecBoolReverse )")
        
        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolReverse, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false] .vecBoolReverse )")
    }

    @Test func vecBoolSet() {
        loadBools(inty, bools: [false, false, false, false])
        loadInts(inty, ints: [1, 2, -8, 43])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true,true,true,true]),
                         VecBoolItem([true,true,true,true,]),
                         VecBoolItem([true,true,true,true,], isContingent: true),
                        ])

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, true, true] [true, true, true, true] [true, true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] false 1 .vecBoolSet )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false, true] [true, true, true, true] [true, true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true, true] false 2 .vecBoolSet )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [false, true, true, true] [true, true, true, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true, true] false -8 .vecBoolSet )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSet, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, true, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, true, true] false 43 .vecBoolSet )")
    }

    @Test func vecBoolSubVec() {
        loadInts(inty, ints: [1,9,2,1,2,-1,1,1], contingent: [4])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, true, false, false, true]),
                         VecBoolItem([true, true, false, false, true]),
                         VecBoolItem([true, true, false, false, true])
                        ])

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, true, false, false, true] [true, true, false, false, true] [true, true, false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] 9 1 .vecBoolSubVec )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false] [true, true, false, false, true] [true, true, false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false, false, true] 1 2 .vecBoolSubVec )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, true, false] [true, true, false, false, true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false, false, true] -1 2 .vecBoolSubVec )")

        doThis(.vecBoolPop, to: inty)

        doThis(.vecBoolSubVec, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, true, false, false, true] 1 1 .vecBoolSubVec )")
    }

    @Test func vecBoolTake() {
        loadInts(inty, ints: [-3, 99, 1, -1], contingent: [2])
        inty.stacks[.vecBool]!.prepend(
            contentsOf: [VecBoolItem([]),
                         VecBoolItem([true, false, false], isContingent: false)
                        ])
       
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [] -3 .vecBoolTake )")
        
        doThis(.vecBoolPop, to: inty)
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true, false, false] ]")
        #expect(topItem(inty, .vecBool).isContingent == false)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 99 .vecBoolTake )")
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [true] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true, false, false] 1 .vecBoolTake )")
        
        doThis(.vecBoolTake, to: inty)
        #expect(stackString(inty, .vecBool) == "[ [] ]")
        #expect(topItem(inty, .vecBool).isContingent == true)
        #expect(callString(topItem(inty, .vecBool)) == "( [true] -1 .vecBoolTake )")
    }

}
