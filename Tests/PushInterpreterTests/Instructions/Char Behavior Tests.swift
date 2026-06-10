//
//  Char Behavior Tests.swift
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
    

    @Test func charIsWhitespace() {
        inty.stacks[.char]!.prepend(contentsOf: [CharItem(Character("g")), CharItem(Character(" "), isContingent: true), CharItem(Character("\n")), CharItem(Character("\t"))])
        
        #expect(stackString(inty, .char) == "[ 'g' ' ' '\n' '\t' ]")
        
        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool)!.isContingent == false)
        
        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool)!.isContingent == true)
        
        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool)!.isContingent == false)
        
        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true true false ]")
        #expect(topItem(inty, .bool)!.isContingent == false)

    }
    
    
    @Test func charIsDigit() {
        inty.stacks[.char]!.prepend(contentsOf: [CharItem(Character("1")), CharItem(Character("q"), isContingent: true), CharItem(Character("2️⃣")), CharItem(Character("७"))])
        
        #expect(stackString(inty, .char) == "[ '1' 'q' '2️⃣' '७' ]")
        
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool)!.isContingent == false)
        
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool)!.isContingent == true)
        
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool)!.isContingent == false)
        
        // note that digits in other languages count!
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false true ]")
        #expect(topItem(inty, .bool)!.isContingent == false)

    }
    
    
    
    @Test func charIsLetter() {
        inty.stacks[.char]!.prepend(contentsOf: [CharItem(Character("1")), CharItem(Character("q"), isContingent: true), CharItem(Character("-")), CharItem(Character("ϴ"))])
        
        #expect(stackString(inty, .char) == "[ '1' 'q' '-' 'ϴ' ]")
        
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool)!.isContingent == false)
        
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool)!.isContingent == true)
        
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool)!.isContingent == false)
        
        // note that letters in other languages count!
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true false ]")
        #expect(topItem(inty, .bool)!.isContingent == false)

    }

    
    @Test func charFromDouble() {
        inty.stacks[.double]!.prepend(contentsOf: [DoubleItem(0), DoubleItem(1111111.11, isContingent: true), DoubleItem(66.6), DoubleItem(-33)])
        
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 66.6 -33.0 ]")
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == false)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ 'v' ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == true)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == false)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ 'A' 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == false)
    }
    
    
    @Test func charFromInt() {
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(0), IntItem(1111111, isContingent: true), IntItem(66), IntItem(-33)])
        
        #expect(stackString(inty, .int) == "[ 0 1111111 66 -33 ]")
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == false)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ 'v' ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == true)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == false)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ 'A' 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char)!.isContingent == false)
    }


}
