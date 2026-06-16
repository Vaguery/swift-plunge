//
//  VecString Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/16/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct VecStringBehaviorTests {
    
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
    
    
    @Test func vecStringButLast() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b", "c"]),
                         VecStringItem(["z"], isContingent: true)
                        ])
        
        doThis(.vecStringButLast, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"a\", \"b\", \"c\"] [\"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)
        
        doThis(.vecStringButLast, to: inty)
        #expect(stackString(inty, .vecString) ==  "[ [\"a\", \"b\"] [\"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringPop, to: inty)
        
        doThis(.vecStringButLast, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    @Test func vecStringConcat() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([], isContingent: true),
                         VecStringItem(["a","b"], isContingent: false),
                         VecStringItem(["x","y"], isContingent: false)
                        ])
        
        doThis(.vecStringConcat, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\"] [\"x\", \"y\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
        
        doThis(.vecStringConcat, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\", \"y\", \"a\", \"b\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    
    @Test func vecStringIsEmpty() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b"], isContingent: true)
                        ])
        
        doThis(.vecStringIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecStringIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }
    
    @Test func vecStringLength() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c"], isContingent: true)
                        ])
        
        doThis(.vecStringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecStringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 3 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func vecStringRest() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c"], isContingent: true)
                        ])
        
        doThis(.vecStringRest, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"a\", \"b\", \"c\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringPop, to: inty)

        doThis(.vecStringRest, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"b\", \"c\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    
    @Test func vecStringReverse() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","bc"], isContingent: true)
                        ])
        
        doThis(.vecStringReverse, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"a\", \"bc\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReverse, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"bc\", \"a\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }

    
    @Test func vecStringTake() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x","y","z"], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(99),
                         IntItem(1, isContingent: true)
                        ])
        
        doThis(.vecStringTake, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"x\", \"y\", \"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringPop, to: inty)
        
        doThis(.vecStringTake, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\", \"y\", \"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringTake, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    @Test func vecStringDrop() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x","y","z"], isContingent: false)
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(0),
                         IntItem(1, isContingent: true)
                        ])
        
        doThis(.vecStringDrop, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"x\", \"y\", \"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringPop, to: inty)
        
        doThis(.vecStringDrop, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\", \"y\", \"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringDrop, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"y\", \"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    @Test func vecStringConj() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b"], isContingent: false)
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("x"),
                         StringItem("y"),
                         StringItem("z", isContingent: true)
                        ])
        
        doThis(.vecStringConj, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"x\"] [\"a\", \"b\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringPop, to: inty)
        
        doThis(.vecStringConj, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"y\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
        
        doThis(.vecStringConj, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"y\", \"z\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    @Test func vecStringContains() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c"], isContingent: false),
                         VecStringItem(["a","b","c"], isContingent: false)
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("x"),
                         StringItem("a"),
                         StringItem("-", isContingent: true)
                        ])
        
        #expect(stackString(inty, .vecString) == "[ [] [\"a\", \"b\", \"c\"] [\"a\", \"b\", \"c\"] ]")
        #expect(stackString(inty, .string) == "[ \"x\" \"a\" \"-\" ]")

        doThis(.vecStringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)
                
        doThis(.vecStringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.vecStringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    
    @Test func vecStringFirst() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b"], isContingent: true)
                        ])
        
        doThis(.vecStringFirst, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        
        doThis(.vecStringFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"a\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func vecStringLast() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b"], isContingent: true)
                        ])
        
        doThis(.vecStringLast, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        
        doThis(.vecStringLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"b\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    
    @Test func vecStringNth() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x","y","z"]),
                         VecStringItem(["aa","bb","cc"])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(1),
                         IntItem(7776, isContingent: true)
                        ])
        
        #expect(stackString(inty, .vecString) == "[ [] [\"x\", \"y\", \"z\"] [\"aa\", \"bb\", \"cc\"] ]")
        #expect(stackString(inty, .int) == "[ -3 1 7776 ]")

        doThis(.vecStringNth, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
                
        doThis(.vecStringNth, to: inty)
        #expect(stackString(inty, .string) == "[ \"y\" ]")
        #expect(topItem(inty, .string).isContingent == false)
                
        doThis(.vecStringNth, to: inty)
        #expect(stackString(inty, .string) == "[ \"aa\" \"y\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    
    @Test func vecStringIndexOf() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c"]),
                         VecStringItem(["x","y","z"])
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("-"),
                         StringItem("b"),
                         StringItem("7", isContingent: true)
                        ])
        
        #expect(stackString(inty, .vecString) == "[ [] [\"a\", \"b\", \"c\"] [\"x\", \"y\", \"z\"] ]")
        #expect(stackString(inty, .string) == "[ \"-\" \"b\" \"7\" ]")

        doThis(.vecStringIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")
                
        doThis(.vecStringIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ 1 -1 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.vecStringIndexOf, to: inty)
        #expect(stackString(inty, .int) == "[ -1 1 -1 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    
    @Test func vecStringOccurrencesOf() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["o","o","o","o","o"]),
                         VecStringItem(["o","o","o","o","o"])
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("o"),
                         StringItem("o"),
                         StringItem("x", isContingent: true)
                        ])
        
        doThis(.vecStringOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.vecStringOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 5 0 ]")
        #expect(topItem(inty, .int).isContingent == false)
        
        doThis(.vecStringOccurrencesOf, to: inty)
        #expect(stackString(inty, .int) == "[ 0 5 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func vecStringRemove() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f","l","u","f","f"]),
                         VecStringItem(["f","l","o","o","f"])
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("f"),
                         StringItem("f"),
                         StringItem("u", isContingent: true)
                        ])
        
        doThis(.vecStringRemove, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"f\", \"l\", \"u\", \"f\", \"f\"] [\"f\", \"l\", \"o\", \"o\", \"f\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringRemove, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"l\", \"u\"] [\"f\", \"l\", \"o\", \"o\", \"f\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringRemove, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"f\", \"l\", \"o\", \"o\", \"f\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    

    @Test func vecStringReplace() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f","a","f"]),
                         VecStringItem(["f","l","o"])
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("f"), StringItem("g"),
                         StringItem("-"), StringItem("f"),
                         StringItem("x", isContingent: true), StringItem("u"),
                        ])
        
        doThis(.vecStringReplace, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"f\", \"a\", \"f\"] [\"f\", \"l\", \"o\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplace, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"-\", \"a\", \"-\"] [\"f\", \"l\", \"o\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplace, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"f\", \"l\", \"o\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    @Test func vecStringReplaceFirst() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f","a","f"]),
                         VecStringItem(["f","l","o"])
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("f"), StringItem("g"),
                         StringItem("-"), StringItem("f"),
                         StringItem("x", isContingent: true), StringItem("u"),
                        ])
        
        doThis(.vecStringReplaceFirst, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"f\", \"a\", \"f\"] [\"f\", \"l\", \"o\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplaceFirst, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"-\", \"a\", \"f\"] [\"f\", \"l\", \"o\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringReplaceFirst, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"f\", \"l\", \"o\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    @Test func vecStringSet() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c","d","e"]),
                         VecStringItem(["a","b"])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1),
                         IntItem(2222),
                         IntItem(2, isContingent: true),
                        ])
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("-"),
                         StringItem("-"),
                         StringItem("-"),
                        ])
        
        doThis(.vecStringSet, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"a\", \"b\", \"c\", \"d\", \"e\"] [\"a\", \"b\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSet, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"-\", \"d\", \"e\"] [\"a\", \"b\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSet, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"-\", \"b\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
    }
    
    @Test func vecStringSubVec() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c","d","e"]),
                         VecStringItem(["z", "y", "x", "w"]),
                         VecStringItem(["1","11","111","1111"])
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1), IntItem(9),
                         IntItem(3), IntItem(2),   // (vec 2 3 instruction)
                         IntItem(2, isContingent: true), IntItem(-1),
                         IntItem(1), IntItem(1),
                        ])
        
        doThis(.vecStringSubVec, to: inty)
        #expect(stackString(inty, .vecString) == "[ [] [\"a\", \"b\", \"c\", \"d\", \"e\"] [\"z\", \"y\", \"x\", \"w\"] [\"1\", \"11\", \"111\", \"1111\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSubVec, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"c\", \"d\"] [\"z\", \"y\", \"x\", \"w\"] [\"1\", \"11\", \"111\", \"1111\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)

        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSubVec, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"z\", \"y\", \"x\"] [\"1\", \"11\", \"111\", \"1111\"] ]")
        #expect(topItem(inty, .vecString).isContingent == true)
        
        doThis(.vecStringPop, to: inty)

        doThis(.vecStringSubVec, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"11\"] ]")
        #expect(topItem(inty, .vecString).isContingent == false)
    }

    
    @Test func vecStringPushAll() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["1","22","333"], isContingent: true),
                        ])
        
        doThis(.vecStringPushAll, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        
        doThis(.vecStringPushAll, to: inty)
        #expect(stackString(inty, .string) == "[ \"1\" \"22\" \"333\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(topItem(inty, .string).index == 0)
        doThis(.stringPop, to: inty)
        #expect(topItem(inty, .string).index == 1)
    }

    
    @Test func `vecStringIterate works for empty`() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
    }
    
    @Test func `vecStringIterate works for one item`() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["joe"]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [\"joe\"] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .string) == "[ \"joe\" ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
    }
    
    @Test func `vecStringIterate produces valid index numbers for results`() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["1","2"]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false),
                        ])
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [\"1\", \"2\"] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .string) == "[ \"1\" ]")
        #expect(topItem(inty, .string).index == 0)
        
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [\"2\"] .vecStringIterate .boolNot ]")
        #expect(topItem(inty, .exec).index == 4)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 3)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 2)
        doThis(.execPop, to: inty)
        #expect(topItem(inty, .exec).index == 1)

    }
    
    @Test func `vecStringIterate works for >1 item`() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["skunk", "badger"]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])
        inty.stacks[.bool]!.prepend(
            contentsOf: [BoolItem(false),
                        ])
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [\"skunk\", \"badger\"] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .string) == "[ \"skunk\" ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [\"badger\"] .vecStringIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        inty.step()
        #expect(stackString(inty, .string) == "[ \"skunk\" ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ [\"badger\"] .vecStringIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .string) == "[ \"skunk\" ]")
        #expect(stackString(inty, .vecString) == "[ [\"badger\"] ]")
        #expect(stackString(inty, .exec) == "[ .vecStringIterate .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .string) == "[ \"badger\" \"skunk\" ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ true ]")

        inty.step()
        #expect(stackString(inty, .string) == "[ \"badger\" \"skunk\" ]")
        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false ]")

    }
}
