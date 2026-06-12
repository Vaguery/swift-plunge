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
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(true), BoolItem(false, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ true true false ]")

        doThis(.boolAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    

    @Test func boolOr() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(false), BoolItem(false), BoolItem(true, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ false false true ]")

        doThis(.boolOr, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolOr, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    

    @Test func boolXor() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(true), BoolItem(true, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ true true true ]")

        doThis(.boolXor, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolXor, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }
    

    @Test func boolInvertFirstThenAnd() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(false), BoolItem(true, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ true false true ]")

        doThis(.boolInvertFirstThenAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ true true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolInvertFirstThenAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }
    

    @Test func boolInvertSecondThenAnd() {
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(false), BoolItem(true, isContingent: true)])
        #expect(stackString(inty, .bool) == "[ true false true ]")

        doThis(.boolInvertSecondThenAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolInvertSecondThenAnd, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
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
