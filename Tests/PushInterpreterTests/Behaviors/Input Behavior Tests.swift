//
//  Input Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 5/31/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct InputBehaviorTests {
    
   let inty = Interpreter()

    @Test func `input history is contingent`() {
        inty.inputs[.input2] = IntItem(17)
        Interpreter.language[.input2]!.act(on: inty)
        let result = inty.stacks[.exec]!.popFirst()! as! IntItem
        #expect(!result.call.isEmpty)
        #expect(result.isContingent == true)
        #expect(result.value == 17)
        #expect(result.pretty() == "17")
    }

    @Test func `inputs works when defined`() {
        inty.inputs[.input3] = IntItem(17)
        
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.input3]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ 17 ]")
    }
    
    @Test func `inputs works when undefined`() {

        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.input3]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .error).contains("No input for") )
        #expect(callString(topItem(inty, .error)) == "( )")
    }
}
