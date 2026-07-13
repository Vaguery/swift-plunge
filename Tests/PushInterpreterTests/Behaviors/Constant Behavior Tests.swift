//
//  Constant Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 5/31/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct ConstantBehaviorTests {

    let inty = Interpreter()

    @Test func constantHistoryIsNotContingent() {
        inty.constants[.int]![2] = IntItem(17)
        Interpreter.language[.int2]!.act(on: inty)
        let result = probeItemOnStack(inty,.exec,index:0) as! IntItem
        #expect(result.call.contains(where: {($0 as! InstructionItem).value == .int2}))
        #expect(result.isContingent == false)
        #expect(result.value == 17)
    }

    @Test func constantWorksWhenDefined() {
        inty.constants[.int]![2] = IntItem(17)
        inty.constants[.vecBool]![8] = VecBoolItem([false, false, true])
        let constantInstruction = Interpreter.language[.int2]
        
        #expect(stackString(inty, .exec) == "[ ]")
        constantInstruction!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ 17 ]")
        Interpreter.language[.vecBool8]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ [false, false, true] 17 ]")
    }
    
    @Test func constantWorksWhenUndefined() {
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.vecBool8]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .error).contains("No constant assigned") )
    }

}
