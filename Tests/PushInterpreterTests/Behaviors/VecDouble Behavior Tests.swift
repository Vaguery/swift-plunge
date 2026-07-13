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

        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 2.0] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        
        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleButLast, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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
        
        doThis(.vecDoubleConcat, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 1.0, 2.0, 3.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 0.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)

        doThis(.vecDoubleConj, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0, 0.0, 1.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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

        doThis(.vecDoubleContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecDoubleContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
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

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)

        doThis(.vecDoubleDrop, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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

        doThis(.vecDoubleIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 1 -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func vecDoubleItemIsEmpty() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecDoubleItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func `vecDoubleIterate produces valid index numbers for results`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [4.0, 55.0] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(topItem(inty, .double).index == 0)

        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [55.0] .vecDoubleIterate .boolNot ]")
        #expect(topItem(inty, .exec).index == 4)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 3)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 2)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 1)

    }

    @Test func `vecDoubleIterate works for >1 item`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [4.0, 55.0] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [55.0] .vecDoubleIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ [55.0] .vecDoubleIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ [55.0] ]")
        #expect(stackString(inty, .exec) == "[ .vecDoubleIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 55.0 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .double) == "[ 55.0 4.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

    }

    @Test func `vecDoubleIterate works for empty`() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
    }

    @Test func `vecDoubleIterate works for one item`() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .vecDouble) == "[ [55.0] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecDoubleIterate, to: inty)
        #expect(stackString(inty, .double) == "[ 55.0 ]")
        #expect(stackString(inty, .vecDouble) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
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
    }

    @Test func vecDoubleLength() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecDoubleLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
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

        doThis(.vecDoubleNth, to: inty)
        #expect(stackString(inty, .double) == "[ 9.0 99.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
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

        doThis(.vecDoubleOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecDoubleOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 5 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
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
        #expect(topItem(inty, .double).index == 0)
        doThis(.doublePop, to: inty)
        #expect(topItem(inty, .double).index == 1)
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

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [8.0, 7.0, 6.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRemove, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 8.0, 7.0, 6.0, 1.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplace, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [2.0, 2.0, 2.0, 2.0, 2.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [1.0, 8.0, 7.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReplaceFirst, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [3.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
    }

    @Test func vecDoubleRest() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleRest, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        
        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleRest, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
    }
    
    @Test func vecDoubleReverse() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleReverse, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [] [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        
        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleReverse, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [999.0, 99.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 8.0, 3.0, 6.0, 9.0] [9.0, 9.0, 9.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSet, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, -1.0, 9.0, 9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
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

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [7.0, 6.0] [9.0, 9.0, 9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 9.0, 9.0] [1.0, 11.0, 111.0, 1111.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)

        doThis(.vecDoublePop, to: inty)

        doThis(.vecDoubleSubVec, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [11.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
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
        
        doThis(.vecDoublePop, to: inty)
        
        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0, 99.0, 999.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == false)
        
        doThis(.vecDoubleTake, to: inty)
        #expect(stackString(inty, .vecDouble) == "[ [9.0] ]")
        #expect(topItem(inty, .vecDouble).isContingent == true)
    }

}
