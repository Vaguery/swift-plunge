//
//  Int Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/3/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct IntBehaviorTests {
    
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
    
    @Test func intAdd() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(11), IntItem(7, isContingent: true)])
        
        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ 20 7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ 27 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func `intAdd handles overflow`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1000), IntItem(Int.max)
                        ])
        
        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        
        #expect(stackString(inty, .error) == "[ «Overflow in .intAdd: 9223372036854775807 + 1000» ]")
    }
    
    @Test func intSubtract() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(11), IntItem(-7, isContingent: true)])
        
        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ 2 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ -9 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func `intSubtract handles overflow`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1000), IntItem(-Int.max)
                        ])
        
        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        
        #expect(stackString(inty, .error) == "[ «Overflow in .intSubtract: -9223372036854775807 - 1000» ]")
    }

    
    @Test func intMultiply() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(11), IntItem(-7, isContingent: true)])
        
        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ 99 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ -693 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func `intMultiply doesn't overflow`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(Int.max - 1), IntItem(Int.max - 1)]
        )
        
        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow")  )
    }
    
    @Test func intMax() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(11), IntItem(-7, isContingent: true)])
        
        doThis(.intMax, to: inty)
        #expect(stackString(inty, .int) == "[ 11 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intMax, to: inty)
        #expect(stackString(inty, .int) == "[ 11 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    
    @Test func intMin() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(11), IntItem(-7, isContingent: true)])
        
        doThis(.intMin, to: inty)
        #expect(stackString(inty, .int) == "[ 9 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intMin, to: inty)
        #expect(stackString(inty, .int) == "[ -7 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    
    @Test func intQuot() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(37), IntItem(-7, isContingent: true)])
        
        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(0)])
        
        #expect(stackString(inty, .int) == "[ 0 -1 ]")
        
        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(topItem(inty, .error).isContingent == true)
    }
    
    @Test func `intQuot doesn't overflow`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-1), IntItem(Int.min)]
        )
        
        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow")  )
    }
    
    
    @Test func `intQuot doesn't divide by zero`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(0), IntItem(999)]
        )
        
        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error) == "" )
    }


    
    @Test func intMod() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(38), IntItem(-7, isContingent: true)])
        
        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ 2 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(0)])
        
        #expect(stackString(inty, .int) == "[ 0 -1 ]")
        
        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
    }
    
    @Test func `intMod doesn't overflow`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-1), IntItem(Int.min)]
        )
        
        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error) == "[ «Overflow in .intMod: -9223372036854775808 % -1» ]"   )
    }
    
    
    @Test func `intMod doesn't divide by zero`() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(0), IntItem(999)]
        )
        
        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error) == "[ «Overflow in .intMod: 999 % 0» ]"   )
    }

    
    @Test func intGT() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(38),
                         IntItem(-7, isContingent: true), IntItem(-33),
                        IntItem(4), IntItem(4)])
        
        #expect(stackString(inty, .int) == "[ 9 38 -7 -33 4 4 ]")

        doThis(.intGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        

        doThis(.intGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func intGTE() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(38),
                         IntItem(-7, isContingent: true), IntItem(-33),
                        IntItem(4), IntItem(4)])
        
        #expect(stackString(inty, .int) == "[ 9 38 -7 -33 4 4 ]")

        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func intLTE() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(38),
                         IntItem(-7, isContingent: true), IntItem(-33),
                        IntItem(4), IntItem(4)])
        
        #expect(stackString(inty, .int) == "[ 9 38 -7 -33 4 4 ]")

        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func intLT() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(38),
                         IntItem(-7, isContingent: true), IntItem(-33),
                        IntItem(4), IntItem(4)])
        
        #expect(stackString(inty, .int) == "[ 9 38 -7 -33 4 4 ]")

        doThis(.intLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func intEq() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(38),
                         IntItem(-7, isContingent: true), IntItem(-33),
                        IntItem(4), IntItem(4)])
        
        #expect(stackString(inty, .int) == "[ 9 38 -7 -33 4 4 ]")

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intEq, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    
    @Test func intInc() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(9), IntItem(38, isContingent: true),])
        
        #expect(stackString(inty, .int) == "[ 9 38 ]")
        
        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ 10 38 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        // mix in contingency
        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ 48 ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ 49 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func intFromBool() {
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false), BoolItem(true, isContingent: true),])
        
        #expect(stackString(inty, .bool) == "[ false true ]")
        
        doThis(.intFromBool, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intFromBool, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    
    @Test func intFromChar() {
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("W")),
                         CharItem(Character("W"), isContingent: true),
                         CharItem(Character("😍"), isContingent: true)
                         ])
        
        #expect(stackString(inty, .char) == "[ 'W' 'W' '😍' ]")
        
        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 87 ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        // not ASCII therefore no result
        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 87 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func intFromString() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("-172"),
                         StringItem("0", isContingent: true),
                         StringItem("00001"),
                         StringItem("1_000_000", isContingent: false),
                         StringItem(" 172"),
                         StringItem("1 7 2"),
                         ])
        
        #expect(stackString(inty, .string) == "[ \"-172\" \"0\" \"00001\" \"1_000_000\" \" 172\" \"1 7 2\" ]")
        
        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ -172 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == false)
    }
    
    
    @Test func intFromDouble() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.23),
                         DoubleItem(1.2e5, isContingent: true),
                         DoubleItem(-100.0),
                         DoubleItem(Double.pi),
                        ])
        
        #expect(stackString(inty, .double) == "[ 1.23 120000.0 -100.0 3.141592653589793 ]")
        
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 120000 1 ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ -100 120000 1 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 3 -100 120000 1 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
    }
    
}
