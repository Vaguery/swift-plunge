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

        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        
        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntButLast, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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
        
        doThis(.vecIntConcat, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 1, 2, 3] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 0] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)

        doThis(.vecIntConj, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999, 0, 1] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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

        doThis(.vecIntContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecIntContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
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

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)

        doThis(.vecIntDrop, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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

        doThis(.intPop, to: inty)

        doThis(.vecIntIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 7777 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intPop, to: inty)

        doThis(.vecIntIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func vecIntItemIsEmpty() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecIntItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func `vecIntIterate produces valid index numbers for results`() {
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
        #expect(topItem(inty, .int).index == 0)

        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [55] .vecIntIterate .boolNot ]")
        #expect(topItem(inty, .exec).index == 4)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 3)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 2)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 1)

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
    }

    @Test func vecIntLength() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecIntLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
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

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 99 7777 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intPop, to: inty)

        doThis(.vecIntNth, to: inty)
        #expect(stackString(inty, .int) == "[ 99 ]")
        #expect(topItem(inty, .int).isContingent == true)
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

        doThis(.intPop, to: inty)

        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 -99 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intPop, to: inty)

        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
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
        #expect(topItem(inty, .int).index == 0)
        doThis(.intPop, to: inty)
        #expect(topItem(inty, .int).index == 1)
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

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [8, 7, 6] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRemove, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 8, 7, 6, 1] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplace, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [2, 2, 2, 2, 2] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 8, 7, 6, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReplaceFirst, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [3, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
    }

    @Test func vecIntRest() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntRest, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        
        doThis(.vecIntPop, to: inty)

        doThis(.vecIntRest, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
    }

    @Test func vecIntReverse() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntReverse, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [] [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        
        doThis(.vecIntPop, to: inty)

        doThis(.vecIntReverse, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [999, 99, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 8, 7, 2222, 9] [9, 9, 9, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSet, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, -1, 9, 9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
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

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [7, 6] [9, 9, 9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9] [1, 11, 111, 1111] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)

        doThis(.vecIntPop, to: inty)

        doThis(.vecIntSubVec, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [11] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
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
        
        doThis(.vecIntPop, to: inty)
        
        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9, 99, 999] ]")
        #expect(topItem(inty, .vecInt).isContingent == false)
        
        doThis(.vecIntTake, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [9] ]")
        #expect(topItem(inty, .vecInt).isContingent == true)
    }
    
}
