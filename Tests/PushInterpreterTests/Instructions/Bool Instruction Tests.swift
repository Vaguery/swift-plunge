//
//  Bool Instruction Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/1/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

struct BoolInstructionTests {
    
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
    
    @Test func boolNot() {
        inty.stacks[.bool]!.prepend(BoolItem(false, isContingent: true))
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    

    @Test func boolAnd() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(true), BoolItem(false, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.boolAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    

    @Test func boolOr() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(false), BoolItem(false), BoolItem(true, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ false false true ]")

        doThis(.boolOr, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolOr, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    

    @Test func boolXor() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(true), BoolItem(true, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ true true true ]")

        doThis(.boolXor, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolXor, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    

    
}
