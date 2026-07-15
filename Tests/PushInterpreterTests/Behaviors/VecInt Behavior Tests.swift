//
//  VecInt Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/12/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VecIntBehaviorTests {

    var inty = Interpreter()
    
    
    @Test func vecIntButLast() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([1,2,3]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [1, 2, 3] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] .vecIntButLast )")

        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [1, 2, 3] .vecIntButLast )")
        
        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] .vecIntButLast )")
    }
    
    @Test func vecIntConcat() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([], isContingent: true),
                         VecIntItem([1,2,3], isContingent: false),
                         VecIntItem([9,99,999], isContingent: false)
                        ])
        
        doThis(.vecIntConcat, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 3] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [1, 2, 3] [] .vecIntConcat )")
        
        doThis(.vecIntConcat, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 1, 2, 3] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] [1, 2, 3] .vecIntConcat )")
    }

    @Test func vecIntConj() {
        loadInts(inty, ints: [-3, 0, 1], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false)
                        ])

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [-3] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] -3 .vecIntConj )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 0] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 0 .vecIntConj )")

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 0, 1] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999, 0] 1 .vecIntConj )")
    }

    @Test func vecIntContains() {
        loadInts(inty, ints: [-3, 9, 7777], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false),
                         VecIntItem([9,99,999], isContingent: false)
                        ])

        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] [9, 99, 999] ]")
        #expect(stackString(inty, .int) == "[ -3 9 7777 ]")

        doThis(.vecIntContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [] -3 .vecIntContains )")

        doThis(.vecIntContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [9, 99, 999] 9 .vecIntContains )")

        doThis(.vecIntContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [9, 99, 999] 7777 .vecIntContains )")
    }

    @Test func vecIntDrop() {
        loadInts(inty, ints: [-3, 0, 1], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false)
                        ])

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] -3 .vecIntDrop )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 0 .vecIntDrop )")

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 1 .vecIntDrop )")
    }

    @Test func vecIntFirst() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])

        doThis(.vecIntFirst, to: inty)
        #expect(stackString(inty, .int) == "[ ]")

        doThis(.vecIntFirst, to: inty)
        #expect(stackString(inty, .int) == "[ 9 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] .vecIntFirst )")
    }

    @Test func vecIntIndexOf() {
        loadInts(inty, ints: [-3, 99, 7777], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999]),
                         VecIntItem([9,99,999])
                        ])

        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] [9, 99, 999] ]")
        #expect(stackString(inty, .int) == "[ -3 99 7777 ]")

        doThis(.vecIntIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 99 7777 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [] -3 .vecIntIndexOf )")

        doThis(.intPop, to: inty)

        doThis(.vecIntIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 7777 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] 99 .vecIntIndexOf )")

        doThis(.intPop, to: inty)

        doThis(.vecIntIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] 7777 .vecIntIndexOf )")
    }

    @Test func vecIntItemIsEmpty() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( [] .vecIntItemIsEmpty )")

        doThis(.vecIntItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( [9, 99, 999] .vecIntItemIsEmpty )")
    }

    @Test func `vecIntIterate records provenance only for its derived results`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [4, 55] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .int) == "[ 4 ]")

        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [55] .vecIntIterate .boolNot ]")
        // The two mouse copies and the re-pushed iterate token are combinatory,
        // so they record nothing. The shrunken vector is genuinely derived and
        // names `.vecIntRest` — an instruction that honestly reproduces it —
        // rather than the iterate instruction, whose crux would re-run the loop.
        #expect(inty.stacks[.exec]![0].call.isEmpty)
        #expect(CodeItem(inty.stacks[.exec]![1].crux()).pretty()
            == "( [4, 55] .vecIntRest )")
        #expect(inty.stacks[.exec]![2].call.isEmpty)
        #expect(inty.stacks[.exec]![3].call.isEmpty)

        // Likewise the extracted element is honestly the vector's first.
        #expect(CodeItem(topItem(inty, .int).crux()).pretty()
            == "( [4, 55] .vecIntFirst )")

    }

    @Test func `vecIntIterate works for >1 item`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [4, 55] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [55] .vecIntIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ [55] .vecIntIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(stackString(inty, .vecInt) == "[ [55] ]")
        #expect(stackString(inty, .exec) == "[ .vecIntIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 55 4 ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .int) == "[ 55 4 ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

    }

    @Test func `vecIntIterate works for empty`() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

    }

    @Test func `vecIntIterate works for one item`() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([88]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .vecInt) == "[ [88] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecIntIterate, to: inty)
        #expect(stackString(inty, .int) == "[ 88 ]")
        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
    }

    @Test func vecIntLast() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])

        doThis(.vecIntLast, to: inty)
        #expect(stackString(inty, .int) == "[ ]")

        doThis(.vecIntLast, to: inty)
        #expect(stackString(inty, .int) == "[ 999 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] .vecIntLast )")
    }

    @Test func vecIntLength() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [] .vecIntLength )")

        doThis(.vecIntLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] .vecIntLength )")
    }

    @Test func vecIntNth() {
        loadInts(inty, ints: [-3, 1, 7777], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999]),
                         VecIntItem([9,99,999])
                        ])

        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] [9, 99, 999] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7777 ]")

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 1 7777 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( )")

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 99 7777 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] 1 .vecIntNth )")

        doThis(.intPop, to: inty)

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 99 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9, 99, 999] 7777 .vecIntNth )")
    }

    @Test func `vecIntNth handles Int.min index without trapping`() {
        // abs(Int.min) traps; .magnitude does not. magnitude(Int.min) % 3 == 2
        loadInts(inty, ints: [Int.min])
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([9, 99, 999])])

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 999 ]")
    }

    @Test func `vecIntSet handles Int.min index without trapping`() {
        // position is popped first (top), replacement second.
        // magnitude(Int.min) % 5 == 3
        loadInts(inty, ints: [Int.min, 42])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([9, 99, 999, 9999, 99999])])

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 42, 99999] ]")
    }

    @Test func vecIntOccurrencesOf() {
        loadInts(inty, ints: [9, 9, -99], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,9,9,9,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 9 -99 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [] 9 .vecIntOccurrencesOf )")

        doThis(.intPop, to: inty)

        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 -99 ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( [9, 9, 9, 9, 9] 9 .vecIntOccurrencesOf )")

        doThis(.intPop, to: inty)

        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [9, 9, 9, 9, 9] -99 .vecIntOccurrencesOf )")
    }

    @Test func vecIntPushAll() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([1,22,333], isContingent: true),
                        ])

        doThis(.vecIntPushAll, to: inty)
        #expect(stackString(inty, .int) == "[ ]")

        doThis(.vecIntPushAll, to: inty)
        #expect(stackString(inty, .int) == "[ 1 22 333 ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( [1, 22, 333] .vecIntPushAll )")
        doThis(.intPop, to: inty)
        // Elements are reversed before pushing, so element 0 lands on top and
        // needs no discard; the one below it is surfaced by popping that.
        #expect(CodeItem(topItem(inty, .int).crux()).pretty()
            == "( [1, 22, 333] .vecIntPushAll 1 .intPopItems )")
    }

    @Test func vecIntRemove() {
        loadInts(inty, ints: [9, 9, -99], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 .vecIntRemove )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [8, 7, 6] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 9 .vecIntRemove )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] -99 .vecIntRemove )")
    }

    @Test func vecIntReplace() {
        loadInts(inty, ints: [1, 9, 1, 9, 2, 9], contingent: [4])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntReplace )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 8, 7, 6, 1] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 9 1 .vecIntReplace )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [2, 2, 2, 2, 2] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] 9 2 .vecIntReplace )")
    }

    @Test func vecIntReplaceFirst() {
        loadInts(inty, ints: [1, 9, 1, 9, 3, 9], contingent: [4])
       inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntReplaceFirst )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 9 1 .vecIntReplaceFirst )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [3, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] 9 3 .vecIntReplaceFirst )")
    }

    @Test func vecIntRest() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntRest, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] .vecIntRest )")
        
        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRest, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] .vecIntRest )")
    }

    @Test func vecIntReverse() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntReverse, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] .vecIntReverse )")
        
        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReverse, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [999, 99, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] .vecIntReverse )")
    }

    @Test func vecIntSet() {
        loadInts(inty, ints: [1, 9, 3, 2222, 7, -1], contingent: [4])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntSet )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 8, 7, 2222, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 2222 3 .vecIntSet )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, -1, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] -1 7 .vecIntSet )")
    }

    @Test func vecIntSubVec() {
        loadInts(inty, ints: [1, 9, 3, 2, 2, -1, 1, 1], contingent: [4])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9]),
                         VecIntItem([1,11,111,1111])
                        ])

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 8, 7, 6, 9] [9, 9, 9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] 9 1 .vecIntSubVec )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [7, 6] [9, 9, 9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 8, 7, 6, 9] 2 3 .vecIntSubVec )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 9, 9, 9, 9] -1 2 .vecIntSubVec )")

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [11] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [1, 11, 111, 1111] 1 1 .vecIntSubVec )")
    }

    @Test func vecIntTake() {
        loadInts(inty, ints: [-3, 99, 1], contingent: [2])
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false)
                        ])

        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [] -3 .vecIntTake )")
        
        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 99 .vecIntTake )")
        
        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
        #expect(callString(topItem(inty, .vecInt)) == "( [9, 99, 999] 1 .vecIntTake )")
    }
    
}
