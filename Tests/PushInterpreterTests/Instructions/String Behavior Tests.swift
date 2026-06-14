//
//  String Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/11/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct StringBehaviorTests {

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

    
    @Test func stringButLast() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""), StringItem("abcd", isContingent: true)]
        )
        
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringButLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringPop, to: inty)

        doThis(.stringButLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"abc\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    
    @Test func stringConcat() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem(""),
                         StringItem("abcd", isContingent: true),
                         StringItem("123", isContingent: false),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"\" \"abcd\" \"123\" ]")

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"123\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd\" \"123\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"123abcd\" ]")
        #expect(topItem(inty, .string).isContingent == true)

    }
    
    
    @Test func stringConjChar() {
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("w")),
                         CharItem(Character("•")),
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("abcd", isContingent: true),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")
        #expect(stackString(inty, .char) == "[ 'w' '•' ]")

        doThis(.stringConjChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"w\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringSwap, to: inty)
        
        doThis(.stringConjChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd•\" \"w\" ]")
        #expect(topItem(inty, .string).isContingent == true)

    }
    
    
    @Test func stringContains() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("abcd", isContingent: true),
                         StringItem("bc", isContingent: false),
                         StringItem("abcd", isContingent: false),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"bc\" \"abcd\" ]")

        doThis(.stringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        
        doThis(.stringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    
    @Test func stringContainsChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("abcd", isContingent: true),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("x")),
                         CharItem(Character("b")),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringContainsChar, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringContainsChar, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }
    
    @Test func stringIndexOfChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("abcd", isContingent: true),
                         StringItem("abcd", isContingent: false),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("x")),
                         CharItem(Character("b")),
                         CharItem(Character("O")),
                        ])
        
        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        
        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    
    @Test func stringDrop() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("1234567890", isContingent: true),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(3),
                         IntItem(0),
                         IntItem(4),
                         IntItem(-14),
                         IntItem(99)
                        ])
        
        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"1234567890\" ]")
        
        doThis(.stringPop, to: inty)
        #expect(stackString(inty, .string) == "[ \"1234567890\" ]")

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .string) == "[ \"1234567890\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .string) == "[ \"123456\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .string) == "[ \"123456\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        
        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringTake() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("1234567890", isContingent: true),
                         StringItem("1234567890", isContingent: false),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(3),
                         IntItem(99),
                         IntItem(4),
                         IntItem(0),
                         IntItem(-14),

                        ])
        
        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"1234567890\" \"1234567890\" ]")
        
        doThis(.stringPop, to: inty)
        #expect(stackString(inty, .string) == "[ \"1234567890\" \"1234567890\" ]")

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .string) == "[ \"1234567890\" \"1234567890\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .string) == "[ \"1234\" \"1234567890\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"1234567890\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        
        doThis(.stringPop, to: inty)

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }
    
    @Test func stringIsEmpty() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("1234567890", isContingent: true),
                        ])
        
        doThis(.stringIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        
        doThis(.stringIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
    }
    
    @Test func stringFirst() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("1234567890", isContingent: true),
                        ])
        
        doThis(.stringFirst, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        
        doThis(.stringFirst, to: inty)
        #expect(stackString(inty, .char) == "[ '1' ]")
    }
    
    @Test func stringLast() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("1234567890", isContingent: true),
                        ])
        
        doThis(.stringLast, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        
        doThis(.stringLast, to: inty)
        #expect(stackString(inty, .char) == "[ '0' ]")
    }
    
    
    @Test func stringLTE() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("abc"),
                         StringItem("xyz", isContingent: true),
                         StringItem("abc"),
                         StringItem("abc"),
                         StringItem("xyz"),
                         StringItem("abc"),
                        ])
        
        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        
        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func stringLT() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("abc"),
                         StringItem("xyz", isContingent: true),
                         StringItem("abc"),
                         StringItem("abc"),
                         StringItem("xyz"),
                         StringItem("abc"),
                        ])
        
        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        
        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func stringGT() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("abc"),
                         StringItem("xyz", isContingent: true),
                         StringItem("abc"),
                         StringItem("abc"),
                         StringItem("xyz"),
                         StringItem("abc"),
                        ])
        
        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        
        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func stringGTE() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("abc"),
                         StringItem("xyz", isContingent: true),
                         StringItem("abc"),
                         StringItem("abc"),
                         StringItem("xyz"),
                         StringItem("abc"),
                        ])
        
        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        
        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    
    @Test func stringReverse() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("1234567890", isContingent: true),
                        ])
        
        doThis(.stringReverse, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"1234567890\" ]")
        
        doThis(.stringPop, to: inty)

        doThis(.stringReverse, to: inty)
        #expect(stackString(inty, .string) == "[ \"0987654321\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringLength() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("1234567890", isContingent: true),
                        ])
        
        doThis(.stringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        
        doThis(.stringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 10 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func stringFromBool() {
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false),
                         BoolItem(true, isContingent: true)
                        ])
        
        doThis(.stringFromBool, to: inty)
        #expect(stackString(inty, .string) == "[ \"false\" ]")
        
        doThis(.stringFromBool, to: inty)
        #expect(stackString(inty, .string) == "[ \"true\" \"false\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringFromChar() {
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("x")),
                         CharItem(Character("-"), isContingent: true)
                        ])
        
        doThis(.stringFromChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"x\" ]")
        
        doThis(.stringFromChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"-\" \"x\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringFromDouble() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.11),
                         DoubleItem(2.2, isContingent: true)
                        ])
        
        doThis(.stringFromDouble, to: inty)
        #expect(stackString(inty, .string) == "[ \"1.11\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringFromDouble, to: inty)
        #expect(stackString(inty, .string) == "[ \"2.2\" \"1.11\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringFromInt() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(-222, isContingent: true)
                        ])
        
        doThis(.stringFromInt, to: inty)
        #expect(stackString(inty, .string) == "[ \"11\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringFromInt, to: inty)
        #expect(stackString(inty, .string) == "[ \"-222\" \"11\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringNth() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(2),
                         IntItem(-222, isContingent: true),
                         IntItem(22),
                        ])
        
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("0123456789"),
                         StringItem("0123456789"),
                         StringItem("0123456789", isContingent: true),
                        ])
        
        #expect(stackString(inty, .int) == "[ 11 2 -222 22 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"0123456789\" \"0123456789\" \"0123456789\" ]")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ ]")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ '2' ]")
        #expect(topItem(inty, .char).isContingent == false)

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ '0' '2' ]")
        #expect(topItem(inty, .char).isContingent == true)

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ '2' '0' '2' ]")
        #expect(topItem(inty, .char).isContingent == true)
    }

    @Test func stringParseToChars() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("01234", isContingent: true),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"01234\" ]")
        
        doThis(.stringParseToChars, to: inty)
        #expect(stackString(inty, .string) == "[ \"01234\" ]")
        
        doThis(.stringParseToChars, to: inty)
        #expect(stackString(inty, .string) == "[ \"0\" \"1\" \"2\" \"3\" \"4\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(topItem(inty, .string).index == 0)
        doThis(.stringPop, to: inty)
        #expect(topItem(inty, .string).index == 1)

    }
}
