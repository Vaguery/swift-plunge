//
//  Input Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 5/31/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct InputBehaviorTests {
    
   let inty = Interpreter.recordingProvenance()

    @Test func `input records its history`() {
        inty.inputs[.input2] = IntItem(17)
        Interpreter.language[.input2]!.act(on: inty)
        let result = inty.stacks[.exec]!.popFirst()! as! IntItem
        #expect(!result.call.isEmpty)
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
        // The unbound error records what the bound path would have: re-running
        // `.input3` against the same environment reproduces this error.
        #expect(callString(topItem(inty, .error)) == "( .input3 )")
    }
}
