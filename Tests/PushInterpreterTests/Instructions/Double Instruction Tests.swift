//
//  Double Instruction Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/3/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite
struct DoubleInstructionTests {
    
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
    
    @Test func doubleAdd() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25), DoubleItem(4.25), DoubleItem(-6.25, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 7.5 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 1.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }
    
    
    @Test func doubleQuot() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(5.0), DoubleItem(10.0), DoubleItem(-20.0, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 5.0 10.0 -20.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ 2.0 -20.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -10.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.append(contentsOf: [DoubleItem(21.0), DoubleItem(17.0)])
        
        #expect(stackString(inty, .double) == "[ -10.0 21.0 17.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -2.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -8.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        inty.stacks[.double]!.prepend(contentsOf: [DoubleItem(0.0)])

        #expect(stackString(inty, .double) == "[ 0.0 -8.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }
    
    
}
