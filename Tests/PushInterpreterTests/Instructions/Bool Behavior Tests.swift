//
//  Bool Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/1/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
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
    
    func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> any Item {
        interpreter.stacks[stack]!.first!
    }

    func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }
    
    var inty = Interpreter()
    
    @Test func boolNot() {
        inty.stacks[.bool]!.prepend(BoolItem(false, isContingent: true))
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    
    @Test func boolAnd() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolNand() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolNotP() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolNotQ() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    

    @Test func boolOr() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)

    }

    @Test func boolNor() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolIfPThenQ() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolIfQThenP() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolP() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolQ() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    @Test func boolXnor() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    

    @Test func boolXor() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)

    }
    

    @Test func boolNotPandQ() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    

    @Test func boolPandNotQ() {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false , isContingent: true),
        ])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }
    
    
    @Test func boolFromDouble() {
        inty.stacks[.double]!.prepend(contentsOf: [DoubleItem(0.0), DoubleItem(1.1), DoubleItem(-1.1, isContingent: true)])
        #expect(stackString(inty, .double) == "[ 0.0 1.1 -1.1 ]")

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }
    
    
    @Test func boolFromInt() {
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(0), IntItem(1), IntItem(-1, isContingent: true)])
        #expect(stackString(inty, .int) == "[ 0 1 -1 ]")

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }
    

    
    
}
