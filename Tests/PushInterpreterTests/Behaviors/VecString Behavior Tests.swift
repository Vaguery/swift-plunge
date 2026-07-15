//
//  VecString Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/16/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VecStringBehaviorTests {
    
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
    
    @Test func vecStringConj() {
        loadStrings(inty, strings: ["x", "y", "z"], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b"], isContingent: false)
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
        loadStrings(inty, strings: ["x", "a", "-"], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c"], isContingent: false),
                         VecStringItem(["a","b","c"], isContingent: false)
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

    @Test func vecStringDrop() {
        loadInts(inty, ints: [-3, 0, 1], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x","y","z"], isContingent: false)
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

    @Test func vecStringIndexOf() {
        loadStrings(inty, strings: ["-", "b", "7"], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c"]),
                         VecStringItem(["x","y","z"])
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

    @Test func vecStringIsEmpty() {
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b"], isContingent: true)
                        ])
        
        doThis(.vecStringItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.vecStringItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func `vecStringIterate records provenance only for its derived results`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["1","2"]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
                        ])

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .vecString) == "[ [\"1\", \"2\"] ]")
        #expect(stackString(inty, .exec) == "[ .boolNot ]")
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.vecStringIterate, to: inty)
        #expect(stackString(inty, .string) == "[ \"1\" ]")

        #expect(stackString(inty, .vecString) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .boolNot [\"2\"] .vecStringIterate .boolNot ]")
        // The two mouse copies and the re-pushed iterate token are combinatory,
        // so they record nothing. The shrunken vector is genuinely derived and
        // names `.vecStringRest` — an instruction that honestly reproduces it —
        // rather than the iterate instruction, whose crux would re-run the loop.
        #expect(inty.stacks[.exec]![0].call.isEmpty)
        #expect(CodeItem(inty.stacks[.exec]![1].crux()).pretty()
            == "( [\"1\", \"2\"] .vecStringRest )")
        #expect(inty.stacks[.exec]![2].call.isEmpty)
        #expect(inty.stacks[.exec]![3].call.isEmpty)

        // Likewise the extracted element is honestly the vector's first.
        #expect(CodeItem(topItem(inty, .string).crux()).pretty()
            == "( [\"1\", \"2\"] .vecStringFirst )")

    }

    @Test func `vecStringIterate works for >1 item`() {
        loadBools(inty, bools: [false])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem(["skunk", "badger"]),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.boolNot),
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

    @Test func vecStringNth() {
        loadInts(inty, ints: [-3, 1, 7776], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x","y","z"]),
                         VecStringItem(["aa","bb","cc"])
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

    @Test func vecStringOccurrencesOf() {
        loadStrings(inty, strings: ["o", "o", "x"], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["o","o","o","o","o"]),
                         VecStringItem(["o","o","o","o","o"])
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
        doThis(.stringPop, to: inty)
        // Elements are reversed before pushing, so element 0 lands on top and
        // needs no discard; the one below it is surfaced by popping that.
        #expect(CodeItem(topItem(inty, .string).crux()).pretty()
            == "( [\"1\", \"22\", \"333\"] .vecStringPushAll 1 .stringPopItems )")
    }

    @Test func vecStringRemove() {
        loadStrings(inty, strings: ["f", "f", "u"], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f","l","u","f","f"]),
                         VecStringItem(["f","l","o","o","f"])
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
        loadStrings(inty, strings: ["f", "g", "-", "f", "x", "u"], contingent: [4])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f","a","f"]),
                         VecStringItem(["f","l","o"])
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
       loadStrings(inty, strings: ["f", "g", "-", "f", "x", "u"], contingent: [4])
       inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["f","a","f"]),
                         VecStringItem(["f","l","o"])
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

    @Test func vecStringSet() {
        loadInts(inty, ints: [1, 2222, 2], contingent: [2])
        loadStrings(inty, strings: ["-","-","-"])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c","d","e"]),
                         VecStringItem(["a","b"])
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
        loadInts(inty, ints: [1, 9, 3, 2, 2, -1, 1, 1], contingent:[4])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["a","b","c","d","e"]),
                         VecStringItem(["z", "y", "x", "w"]),
                         VecStringItem(["1","11","111","1111"])
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

    @Test func vecStringTake() {
        loadInts(inty, ints: [-3, 99, 1], contingent: [2])
        inty.stacks[.vecString]!.prepend(
            contentsOf: [VecStringItem([]),
                         VecStringItem(["x","y","z"], isContingent: false)
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
}
