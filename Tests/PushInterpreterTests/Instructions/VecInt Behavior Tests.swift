//
//  VecInt Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/12/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct VecIntBehaviorTests {
    
    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }
    
    func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> any Item {
        interpreter.stacks[stack]!.first!
    }

    func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }
    
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
    
    
    @Test func vecIntIsEmpty() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: true)
                        ])
        
        doThis(.vecIntIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecIntIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
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

    
    @Test func vecIntTake() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(99),
                         IntItem(1, isContingent: true)
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
    
    @Test func vecIntDrop() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(0),
                         IntItem(1, isContingent: true)
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
    
    @Test func vecIntConj() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(0),
                         IntItem(1, isContingent: true)
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
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999], isContingent: false),
                         VecIntItem([9,99,999], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(9),
                         IntItem(7777, isContingent: true)
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

    
    @Test func vecIntNth() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999]),
                         VecIntItem([9,99,999])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(1),
                         IntItem(7777, isContingent: true)
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

    
    
    @Test func vecIntIndexOf() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,99,999]),
                         VecIntItem([9,99,999])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(99),
                         IntItem(7777, isContingent: true)
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
    
    
    @Test func vecIntOccurrencesOf() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,9,9,9,9]),
                         VecIntItem([9,9,9,9,9])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9),
                         IntItem(9),
                         IntItem(-88, isContingent: true)
                        ])
        
        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 9 -88 ]")
        #expect(topItem(inty, .int).isContingent == false)
                
        doThis(.intPop, to: inty)

        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 -88 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intPop, to: inty)

        doThis(.vecIntOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func vecIntRemove() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9),
                         IntItem(9),
                         IntItem(-88, isContingent: true)
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
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1), IntItem(9),
                         IntItem(1), IntItem(9),
                         IntItem(2, isContingent: true), IntItem(9),
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
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1), IntItem(9),
                         IntItem(1), IntItem(9),
                         IntItem(3, isContingent: true), IntItem(9),
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
    
    @Test func vecIntSet() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1), IntItem(9),
                         IntItem(3), IntItem(2222),
                         IntItem(7, isContingent: true), IntItem(-1),
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
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([]),
                         VecIntItem([9,8,7,6,9]),
                         VecIntItem([9,9,9,9,9]),
                         VecIntItem([1,11,111,1111])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1), IntItem(9),
                         IntItem(3), IntItem(2),   // (vec 2 3 instruction)
                         IntItem(2, isContingent: true), IntItem(-1),
                         IntItem(1), IntItem(1),
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
    
    @Test func `vecIntIterate produces valid index numbers for results`() {
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false),
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
        inty.stacks[.vecInt]!.prepend(
            contentsOf: [VecIntItem([4, 55]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false),
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
}
