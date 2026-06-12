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
    
}
