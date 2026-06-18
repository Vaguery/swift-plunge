//
//  Code Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/17/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct CodeBehaviorTests {
    
    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }
    
    func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> (any Item)? {
        interpreter.stacks[stack]!.first
    }

    func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }
    
    var inty = Interpreter()
    
    @Test func codeAppend() {
        inty.stacks[.code]!.prepend(
            contentsOf: [
                CodeItem([IntItem(4)]),
                CodeItem([DoubleItem(8.8)]),
                CodeItem([CharItem(Character("-"))], isContingent: true),
                CodeItem([]),
            ]
        )
        #expect(stackString(inty, .code) == "[ ( 4 ) ( 8.8 ) ( '-' ) ( ) ]")
        
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( 8.8 4 ) ( '-' ) ( ) ]")
        #expect(topItem(inty, .code)!.isContingent == false)
        
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( '-' 8.8 4 ) ( ) ]")
        #expect(topItem(inty, .code)!.isContingent == true)
        
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( '-' 8.8 4 ) ]")
        #expect(topItem(inty, .code)!.isContingent == true)
    }
}
