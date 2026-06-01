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

    func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }
    
    var inty = Interpreter()
    
    @Test func boolNot() {
        inty.stacks[.bool]!.prepend(BoolItem(false))
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
    }
    

    @Test func boolAnd() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(true), BoolItem(false)])
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.boolAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        doThis(.boolAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
    }
    

    @Test func boolOr() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(false), BoolItem(false), BoolItem(true)])
        #expect(stackString(inty, .bool) == "[ false false true ]")

        doThis(.boolOr, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        doThis(.boolOr, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
    }
    

    @Test func boolXor() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(true), BoolItem(true)])
        #expect(stackString(inty, .bool) == "[ true true true ]")

        doThis(.boolXor, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        doThis(.boolXor, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
    }
    

    
}
