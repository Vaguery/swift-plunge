//
//  VecDouble Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/15/26.
//

@testable import PropellerWithStructs
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
    
    
    @Test func vecDoubleIsEmpty() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecDoubleIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecDoubleIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
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

    
    @Test func vecDoubleTake() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(99),
                         IntItem(1, isContingent: true)
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
    
    @Test func vecDoubleDrop() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(0),
                         IntItem(1, isContingent: true)
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
    
    @Test func vecDoubleConj() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(-3),
                         DoubleItem(0),
                         DoubleItem(1, isContingent: true)
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
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999], isContingent: false),
                         VecDoubleItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(-3),
                         DoubleItem(9),
                         DoubleItem(7777, isContingent: true)
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

    
    @Test func vecDoubleNth() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999]),
                         VecDoubleItem([9,99,999])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(1),
                         IntItem(7776, isContingent: true)
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

    
    
    @Test func vecDoubleIndexOf() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,99,999]),
                         VecDoubleItem([9,99,999])
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(-3),
                         DoubleItem(99),
                         DoubleItem(7777, isContingent: true)
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
    
    
    @Test func vecDoubleOccurrencesOf() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,9,9,9,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(9),
                         DoubleItem(9),
                         DoubleItem(-88, isContingent: true)
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
    
    @Test func vecDoubleRemove() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(9),
                         DoubleItem(9),
                         DoubleItem(-88, isContingent: true)
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
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9.0,8.0,7.0,6.0,9.0]),
                         VecDoubleItem([9,9,9,9,9])
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1), DoubleItem(9),
                         DoubleItem(1.0), DoubleItem(9.0),
                         DoubleItem(2, isContingent: true), DoubleItem(9),
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
    
    @Test func vecDoubleSet() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1),
                         IntItem(2222),
                         IntItem(2, isContingent: true),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(9),
                         DoubleItem(3),
                         DoubleItem(-1),
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
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([]),
                         VecDoubleItem([9,8,7,6,9]),
                         VecDoubleItem([9,9,9,9,9]),
                         VecDoubleItem([1,11,111,1111])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1), IntItem(9),
                         IntItem(3), IntItem(2),   // (vec 2 3 instruction)
                         IntItem(2, isContingent: true), IntItem(-1),
                         IntItem(1), IntItem(1),
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
    
    @Test func `vecDoubleIterate produces valid index numbers for results`() {
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false),
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
        inty.stacks[.vecDouble]!.prepend(
            contentsOf: [VecDoubleItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false),
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
}
