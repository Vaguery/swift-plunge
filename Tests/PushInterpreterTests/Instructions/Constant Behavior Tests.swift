//
//  Constant Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct ConstantBehaviorTests {
    
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
    
    @MainActor
    @Test func constantWorksWhenUndefined() {
        #expect(stackString(inty, .exec) == "[ ]")
        Interpreter.language[.vecBool8]!.act(on: inty)
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .error).contains("No constant assigned") )
    }
    
    @MainActor
    @Test func constantHistoryIsNotContingent() {
        inty.constants[.int]![2] = IntItem(17)
        Interpreter.language[.int2]!.act(on: inty)
        let result = inty.stacks[.exec]!.popFirst()! as! IntItem
        #expect(result.call.isEmpty)
        #expect(result.isContingent == false)
        #expect(result.value == 17)
    }
    
}
