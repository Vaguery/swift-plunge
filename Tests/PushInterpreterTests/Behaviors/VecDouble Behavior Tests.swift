//
//  VecDouble Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/15/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VecDoubleBehaviorTests {

    var inty = Interpreter()

    @Test func vecDoubleButLast() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([1,2,3]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [1.0, 2.0, 3.0] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] .vecDoubleButLast )")

        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 2.0] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [1.0, 2.0, 3.0] .vecDoubleButLast )")
        
        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] .vecDoubleButLast )")
    }
    
    @Test func vecDoubleConcat() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([], isContingent: true),
                         VecDoubleItem([1,2,3], isContingent: false),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])
        
        doThis(.vecDoubleConcat, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 2.0, 3.0] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [1.0, 2.0, 3.0] [] .vecDoubleConcat )")
        
        doThis(.vecDoubleConcat, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 1.0, 2.0, 3.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] [1.0, 2.0, 3.0] .vecDoubleConcat )")
    }

    @Test func vecDoubleConj() {
        loadDoubles(inty, doubles: [-3, 0, 1], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [-3.0] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] -3.0 .vecDoubleConj )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 0.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 0.0 .vecDoubleConj )")

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 0.0, 1.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0, 0.0] 1.0 .vecDoubleConj )")
    }

    @Test func vecDoubleContains() {
        loadDoubles(inty, doubles: [-3, 9, 7777], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])

        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] [9.0, 99.0, 999.0] ]")
        #expect(stackString(inty, .double) == "[ -3.0 9.0 7777.0 ]")

        doThis(.vecDoubleContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [] -3.0 .vecDoubleContains )")

        doThis(.vecDoubleContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [9.0, 99.0, 999.0] 9.0 .vecDoubleContains )")

        doThis(.vecDoubleContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [9.0, 99.0, 999.0] 7777.0 .vecDoubleContains )")
    }

    @Test func vecDoubleDrop() {
        loadInts(inty, ints: [-3, 0, 1], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] -3 .vecDoubleDrop )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 0 .vecDoubleDrop )")

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 1 .vecDoubleDrop )")
    }

    @Test func vecDoubleFirst() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])

        doThis(.vecDoubleFirst, to: inty)
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.vecDoubleFirst, to: inty)
        #expect(stackString(inty, .double) == "[ 9.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] .vecDoubleFirst )")
    }

    @Test func vecDoubleIndexOf() {
        loadDoubles(inty, doubles: [-3, 99, 7777], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999]),
                         VecDoubleItem([9,99,999])
                        ])

        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] [9.0, 99.0, 999.0] ]")
        #expect(stackString(inty, .double) == "[ -3.0 99.0 7777.0 ]")

        doThis(.vecDoubleIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")

        doThis(.vecDoubleIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 -1 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [9.0, 99.0, 999.0] 99.0 .vecDoubleIndexOf )")

        doThis(.vecDoubleIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 1 -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9.0, 99.0, 999.0] 7777.0 .vecDoubleIndexOf )")
    }

    @Test func vecDoubleItemIsEmpty() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [] .vecDoubleItemIsEmpty )")

        doThis(.vecDoubleItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [9.0, 99.0, 999.0] .vecDoubleItemIsEmpty )")
    }

    @Test func `vecDoubleIterate records provenance only for its derived results`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [4.0, 55.0] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ 4.0 ]")

        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo [55.0] ( .boolNot ) .vecDoubleIterate ]")
        // The two mouse copies and the re-pushed iterate token are combinatory,
        // so they record nothing. The shrunken vector is genuinely derived and
        // names `.vecDoubleRest` — an instruction that honestly reproduces it —
        // rather than the iterate instruction, whose crux would re-run the loop.
        // .exec is now: mouse, .codeDo, rest, mouse, iterate — the mouse runs via
        // .codeDo and is re-supplied to .code for the next pass. Only the
        // shrunken vector is derived.
        #expect(inty.stacks[.exec]!.count == 5)
        #expect(inty.stacks[.exec]![0].call.isEmpty)   // mouse, to run
        #expect(inty.stacks[.exec]![1].call.isEmpty)   // .codeDo
        #expect(CodeItem(inty.stacks[.exec]![2].crux()).pretty()
            == "( [4.0, 55.0] .vecDoubleRest )")
        #expect(inty.stacks[.exec]![3].call.isEmpty)   // mouse, re-supplied
        #expect(inty.stacks[.exec]![4].call.isEmpty)   // the iterate token

        // Likewise the extracted element is honestly the vector's first.
        #expect(CodeItem(topItem(inty, .double).crux()).pretty()
            == "( [4.0, 55.0] .vecDoubleFirst )")

    }

    @Test func `vecDoubleIterate works for >1 item`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [4.0, 55.0] ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo [55.0] ( .boolNot ) .vecDoubleIterate ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .codeDo [55.0] ( .boolNot ) .vecDoubleIterate ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [55.0] ( .boolNot ) .vecDoubleIterate ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ [55.0] ( .boolNot ) .vecDoubleIterate ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ [55.0] ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .vecDoubleIterate ]")
        #expect(stackString(inty, .bool) == "[ true ]")

    }

    @Test func `vecDoubleIterate works for empty`() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
    }

    @Test func `vecDoubleIterate works for one item`() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([55]),
                        ])
        // The mouse is a block on `.code` now: an iterate takes its body as a
        // code argument, so it must already be resting there when it fires.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.boolNot)]))

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [55.0] ]")
        #expect(stackString(inty, .exec) == "[ ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ 55.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ( .boolNot ) .codeDo ]")
    }

    @Test func vecDoubleLast() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])

        doThis(.vecDoubleLast, to: inty)
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.vecDoubleLast, to: inty)
        #expect(stackString(inty, .double) == "[ 999.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] .vecDoubleLast )")
    }

    @Test func vecDoubleLength() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [] .vecDoubleLength )")

        doThis(.vecDoubleLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9.0, 99.0, 999.0] .vecDoubleLength )")
    }
    
    @Test func vecDoubleNth() {
        loadInts(inty, ints: [-3, 1, 7776], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999]),
                         VecDoubleItem([9,99,999])
                        ])

        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] [9.0, 99.0, 999.0] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7776 ]")

        doThis(.vecDoubleNth, to: inty)
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.vecDoubleNth, to: inty)
        #expect(stackString(inty, .double) == "[ 99.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] 1 .vecDoubleNth )")

        doThis(.vecDoubleNth, to: inty)
        #expect(stackString(inty, .double) == "[ 9.0 99.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        #expect(callString(topItem(inty, .double)) == "( [9.0, 99.0, 999.0] 7776 .vecDoubleNth )")
    }

    @Test func vecDoubleOccurrencesOf() {
        loadDoubles(inty, doubles: [9, 9, -99], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,9,9,9,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])

        doThis(.vecDoubleOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [] 9.0 .vecDoubleOccurrencesOf )")

        doThis(.vecDoubleOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] 9.0 .vecDoubleOccurrencesOf )")

        doThis(.vecDoubleOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 5 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] -99.0 .vecDoubleOccurrencesOf )")
    }

    @Test func vecDoublePushAll() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([1,22,333], isContingent: true),
                        ])

        doThis(.vecDoublePushAll, to: inty)
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.vecDoublePushAll, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 22.0 333.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        #expect(callString(topItem(inty, .double)) == "( [1.0, 22.0, 333.0] .vecDoublePushAll )")
        doThis(.doublePop, to: inty)
        // Elements are reversed before pushing, so element 0 lands on top and
        // needs no discard; the one below it is surfaced by popping that.
        #expect(CodeItem(topItem(inty, .double).crux()).pretty()
            == "( [1.0, 22.0, 333.0] .vecDoublePushAll 1 .doublePopItems )")
    }

    @Test func vecDoubleRemove() {
        loadDoubles(inty, doubles: [9, 9, -99], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9.0 .vecDoubleRemove )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [8.0, 7.0, 6.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 9.0 .vecDoubleRemove )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] -99.0 .vecDoubleRemove )")
    }

    @Test func vecDoubleReplace() {
        loadDoubles(inty, doubles: [1, 9, 1.0, 9.0, 2, 9], contingent: [4])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9.0,8.0,7.0,6.0,9.0]),
                         VecDoubleItem([9,9,9,9,9])
                        ])

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9.0 1.0 .vecDoubleReplace )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 8.0, 7.0, 6.0, 1.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 9.0 1.0 .vecDoubleReplace )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [2.0, 2.0, 2.0, 2.0, 2.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] 9.0 2.0 .vecDoubleReplace )")
    }

    @Test func vecDoubleReplaceFirst() {
        loadDoubles(inty, doubles: [1, 9, 1.0, 9.0, 3, 9], contingent: [4])
       inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1), DoubleItem(9),
                         DoubleItem(1), DoubleItem(9),
                         DoubleItem(3, isContingent: true), DoubleItem(9),
                        ])

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9.0 1.0 .vecDoubleReplaceFirst )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 9.0 1.0 .vecDoubleReplaceFirst )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [3.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] 9.0 3.0 .vecDoubleReplaceFirst )")
    }

    @Test func vecDoubleRest() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleRest, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] .vecDoubleRest )")
        
        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRest, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] .vecDoubleRest )")
    }
    
    @Test func vecDoubleReverse() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleReverse, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] .vecDoubleReverse )")
        
        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReverse, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [999.0, 99.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] .vecDoubleReverse )")
    }

    @Test func vecDoubleSet() {
        loadDoubles(inty, doubles: [9, 3, -1])
        loadInts(inty, ints: [1, 2222, 2], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])


        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9.0 1 .vecDoubleSet )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 8.0, 3.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 3.0 2222 .vecDoubleSet )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, -1.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] -1.0 2 .vecDoubleSet )")
    }

    @Test func vecDoubleSubVec() {
        loadInts(inty, ints: [1, 9, 3, 2, 2, -1, 1, 1], contingent: [4])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9]),
                         VecDoubleItem([1,11,111,1111])
                        ])

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] 9 1 .vecDoubleSubVec )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [7.0, 6.0] [9.0, 9.0, 9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 8.0, 7.0, 6.0, 9.0] 2 3 .vecDoubleSubVec )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 9.0, 9.0, 9.0, 9.0] -1 2 .vecDoubleSubVec )")

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [11.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [1.0, 11.0, 111.0, 1111.0] 1 1 .vecDoubleSubVec )")
    }

    @Test func vecDoubleTake() {
        loadInts(inty, ints: [-3, 99, 1], contingent: [2])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])

        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [] -3 .vecDoubleTake )")
        
        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 99 .vecDoubleTake )")
        
        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
        #expect(callString(topItem(inty, .vecDouble)) == "( [9.0, 99.0, 999.0] 1 .vecDoubleTake )")
    }

}
