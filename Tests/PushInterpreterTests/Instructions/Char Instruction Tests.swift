//
//  Char Instruction Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/2/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

struct CharInstructionTests {
    
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
    
    @Test func charAllFromString() {
        inty.stacks[.string]!.prepend(StringItem("", isContingent: false))
        inty.stacks[.string]!.prepend(StringItem("fizz"))
        inty.stacks[.string]!.prepend(StringItem("bar", isContingent: true))
        
        #expect(stackString(inty, .string) == "[ \"bar\" \"fizz\" \"\" ]")

        doThis(.charAllFromString, to: inty)
        #expect(stackString(inty, .char) == "[ 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char)!.isContingent == true)
        #expect(topItem(inty, .char)!.index == 2)

        doThis(.charAllFromString, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char)!.isContingent == false)
        #expect(topItem(inty, .char)!.index == 3)

        doThis(.charAllFromString, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")

        
    }
    

    
}
