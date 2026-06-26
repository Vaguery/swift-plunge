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

    @Test func stringParseToLetters() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("01234", isContingent: true),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"01234\" ]")
        
        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"01234\" ]")
        
        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"4\" \"3\" \"2\" \"1\" \"0\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(topItem(inty, .string).index == 4)
        doThis(.stringPop, to: inty)
        #expect(topItem(inty, .string).index == 3)

    }

    @Test func stringOccurrencesOfChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("00 11 22", isContingent: true),
                         StringItem("00 11 22"),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("2")),
                         CharItem(Character("2")),
                         CharItem(Character(" ")),
                        ])
        
        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .int) == "[ 2 0 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .int) == "[ 2 2 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
    }

    @Test func stringRemoveChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("00 11 22", isContingent: true),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("2")),
                         CharItem(Character("2")),
                         CharItem(Character(" ")),
                        ])
        
        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"00 11 22\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00 11 \" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"0011\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringReplaceChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("00 11 22", isContingent: true),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("-")),CharItem(Character("2")),
                         CharItem(Character(".")),CharItem(Character("2")),
                         CharItem(Character("!")),CharItem(Character(" ")),
                        ])
        
        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"00 11 22\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)

        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00 11 ..\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00!11!..\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringReplaceFirstChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("00 11 22", isContingent: true),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("-")),CharItem(Character("2")),
                         CharItem(Character(".")),CharItem(Character("2")),
                         CharItem(Character("!")),CharItem(Character(" ")),
                        ])
        
        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"00 11 22\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)

        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00 11 .2\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00!11 .2\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringReplace() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("-"), StringItem(""), StringItem("")
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"-\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(" a"),StringItem("1 "),StringItem("00 11 22", isContingent: true),
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) ==  "[ \"00 1 a22\" \"-\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("1234"),StringItem(" w"),StringItem("just write words"),
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"just1234rite1234ords\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),StringItem("t"),StringItem("just write words"),
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"jus wrie words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }

    @Test func stringReplaceFirst() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("-"), StringItem(""), StringItem("")
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"-\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(" a"),StringItem("1 "),StringItem("00 11 22", isContingent: true),
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) ==  "[ \"00 1 a22\" \"-\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("1234"),StringItem(" w"),StringItem("just write words"),
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"just1234rite words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),StringItem("t"),StringItem("just write words"),
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"jus write words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }
    
    @Test func stringRest() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("abcde", isContingent: true)
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"abcde\" ]")

        doThis(.stringRest, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcde\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)
        
        doThis(.stringRest, to: inty)
        #expect(stackString(inty, .string) == "[ \"bcde\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    
    @Test func stringSetChar() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(2),
                         IntItem(-222, isContingent: true),
                         IntItem(13),
                        ])
        
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("0123456789"),
                        ])
        
        inty.stacks[.char]!.prepend(
            contentsOf: [
                        CharItem(Character("-")),
                        CharItem(Character(".")),
                        CharItem(Character("?")),
                        CharItem(Character("+")),
                        ])
        
        #expect(stackString(inty, .int) == "[ 11 2 -222 13 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"0123456789\" ]")

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"0123456789\" ]")
        
        doThis(.stringPop, to: inty)

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"01.3456789\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"?1.3456789\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"?1.+456789\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringSplit() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" ]")
        
        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [
                         StringItem("abcde", isContingent: true),
                        ])
        
        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcde\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringFlush, to: inty)

        
        inty.stacks[.string]!.prepend(
            contentsOf: [
                         StringItem("ab    cd \ne\tf")
                        ])
        
        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ \"f\" \"e\" \"cd\" \"ab\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(topItem(inty, .string).index == 3)
    }
    
    @Test func `stringSubstring works for empty`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(2),
                         IntItem(2),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" ]")
    }

    @Test func `stringSubstring works for silly indices on empty strings`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(22),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" ]")
    }

    @Test func `stringSubstring works for nonempty with basic indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(4),
                         IntItem(2),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"ori\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with identical indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(4),
                         IntItem(4),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"i\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with weird indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(88),
                         IntItem(-11),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"gloria\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with 2 negative indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-22),
                         IntItem(-11),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"g\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with 2 huge indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(88),
                         IntItem(99),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"a\" ]")
    }

    @Test func `stringIterate works for an empty string`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .int) == "[ 1 ]")

        doThis(.stringIterate, to: inty)
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
    }
        
    @Test func `stringIterate works for a nonempty string`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("boo"),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"boo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        
        doThis(.stringIterate, to: inty)
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ .intInc \"oo\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
       
        inty.step()
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ \"oo\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 2 ]")
       
        inty.step()

        #expect(stackString(inty, .string) == "[ \"oo\" ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 2 ]")
       
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ .intInc \"o\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 2 ]")
       
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ \"o\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 3 ]")
        
        inty.step()

        #expect(stackString(inty, .string) == "[ \"o\" ]")
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 3 ]")
        
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .int) == "[ 3 ]")
        
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 4 ]")
        
        
    }

    
    @Test func `stringIterate might be weird when recursive`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("boo"), StringItem("tan"),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.stringConjChar),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar ]")
        
        doThis(.stringIterate, to: inty)
        
        #expect(stackString(inty, .string) == "[ \"tan\" ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar \"oo\" .stringIterate .stringConjChar ]")
        
        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanb\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ \"oo\" .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"oo\" \"tanb\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanb\" ]")
        #expect(stackString(inty, .char) == "[ 'o' ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar \"o\" .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanbo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ \"o\" .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"o\" \"tanbo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanbo\" ]")
        #expect(stackString(inty, .char) == "[ 'o' ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar ]")
        
        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanboo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
    }
    
    @Test func stringPushAllChars() {
        inty.stacks[.string]!.prepend(StringItem("", isContingent: false))
        inty.stacks[.string]!.prepend(StringItem("fizz"))
        inty.stacks[.string]!.prepend(StringItem("bar", isContingent: true))
        
        #expect(stackString(inty, .string) == "[ \"bar\" \"fizz\" \"\" ]")

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(topItem(inty, .char).index == 2)

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(topItem(inty, .char).index == 3)

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
    }
    


}
