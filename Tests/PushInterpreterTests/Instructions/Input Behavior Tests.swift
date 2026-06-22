//
//  Input Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct InputBehaviorTests {
    
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
    
    @Test func inputsWorksWhenDefined() {
        inty.inputs[.input3] = IntItem(17)
        
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.input3]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ 17 ]")

    }
    
    @Test func inputsWorksWhenUndefined() {
        
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.input3]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .error).contains("No input for") )

    }
    
    
    @Test func inputHistoryIsContingent() {
        inty.inputs[.input2] = IntItem(17)
        Interpreter.language[.input2]!.act(on: inty)
        let result = inty.stacks[.exec]!.popFirst()! as! IntItem
        #expect(!result.call.isEmpty)
        #expect(result.isContingent == true)
        #expect(result.value == 17)
        #expect(result.index == 0)
        #expect(result.pretty() == "17")
    }

}
