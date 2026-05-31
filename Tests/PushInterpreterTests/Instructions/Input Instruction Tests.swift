//
//  Input Instruction Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

struct InputInstructionTests {
    
    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }

    
    let inty = Interpreter()
    
    @MainActor
    @Test func inputsWorksWhenDefined() {
        inty.inputs[.input3] = Item<Int>(17)
        
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.input3]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ 17 ]")

    }
    
    @MainActor
    @Test func inputsWorksWhenUndefined() {
        
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.input3]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .error) ==
                "[ Error: \"WARN: no input for input3\" ]")

    }
    
    
    @MainActor
    @Test func inputHistoryIsContingent() {
        inty.inputs[.input2] = Item<Int>(17)
        Interpreter.language[.input2]!.act(on: inty)
        let result = inty.stacks[.exec]!.popFirst()! as! Item<Int>
        #expect(!result.call.isEmpty) // no
        #expect(result.isContingent == true)
        #expect(result.value == 17)
        #expect(result.index == 0)
    }

}
