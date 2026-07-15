//
//  String Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/11/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct StringBehaviorTests {

    var inty = Interpreter()

    @Test func stringButLast() {
        loadStrings(inty, strings: ["", "abcd"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringButLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"\" .stringButLast )")

        doThis(.stringPop, to: inty)
        doThis(.stringButLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"abc\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"abcd\" .stringButLast )")
    }

    @Test func stringConcat() {
        loadStrings(inty, strings: ["", "", "abcd", "123"], contingent: [2])
        #expect(stackString(inty, .string) == "[ \"\" \"\" \"abcd\" \"123\" ]")

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"123\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"\" \"\" .stringConcat )")

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd\" \"123\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"abcd\" \"\" .stringConcat )")

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"123abcd\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"123\" \"abcd\" .stringConcat )")
    }

    @Test func stringConjChar() {
        loadChars(inty, chars: ["w", "•"], contingent:[1])
        loadStrings(inty, strings: ["", "abcd"])
        #expect(stackString(inty, .char) == "[ 'w' '•' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringConjChar, to: inty)
        #expect(stackString(inty, .char) == "[ '•' ]")
        #expect(stackString(inty, .string) == "[ \"w\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"\" 'w' .stringConjChar )")

        doThis(.stringConjChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"w•\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"w\" '•' .stringConjChar )")
    }

    @Test func stringContains() {
        loadStrings(inty, strings: ["", "abcd", "bc", "abcd"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"bc\" \"abcd\" ]")

        doThis(.stringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"bc\" \"abcd\" ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( \"abcd\" \"\" .stringContains )")
        
        doThis(.stringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abcd\" \"bc\" .stringContains )")
    }

    @Test func stringContainsChar() {
        loadChars(inty, chars: ["x", "b"])
        loadStrings(inty, strings: ["", "abcd"], contingent:[1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'x' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringContainsChar, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( 'x' \"\" .stringContainsChar )")
        
        doThis(.stringContainsChar, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( 'b' \"abcd\" .stringContainsChar )")
    }

    @Test func stringDrop() {
        loadInts(inty, ints: [3, 0, 4, -14, 99])
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .int) == "[ 3 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringPop, to: inty)
        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 0 \"abcdefghij\" .stringDrop )")

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcdef\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 4 \"abcdefghij\" .stringDrop )")

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcdef\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( -14 \"abcdef\" .stringDrop )")

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 99 \"abcdef\" .stringDrop )")
    }

    @Test func stringFirst() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringFirst, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")

        doThis(.stringFirst, to: inty)
        #expect(stackString(inty, .char) == "[ 'a' ]")
        #expect(stackString(inty, .string) == "[ ]")
    }

    @Test func stringFromBool() {
        loadBools(inty, bools: [false, true], contingent: [1])
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromBool, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"false\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( false .stringFromBool )")

        doThis(.stringFromBool, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"true\" \"false\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( true .stringFromBool )")
    }

    @Test func stringFromChar() {
        loadChars(inty, chars: ["x", "-"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'x' '-' ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromChar, to: inty)
        #expect(stackString(inty, .char) == "[ '-' ]")
        #expect(stackString(inty, .string) == "[ \"x\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( 'x' .stringFromChar )")

        doThis(.stringFromChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"-\" \"x\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( '-' .stringFromChar )")
    }

    @Test func stringFromDouble() {
        loadDoubles(inty, doubles: [1.1, 2.2], contingent: [1])
        #expect(stackString(inty, .double) == "[ 1.1 2.2 ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromDouble, to: inty)
        #expect(stackString(inty, .double) == "[ 2.2 ]")
        #expect(stackString(inty, .string) == "[ \"1.1\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( 1.1 .stringFromDouble )")

        doThis(.stringFromDouble, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"2.2\" \"1.1\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 2.2 .stringFromDouble )")
    }

    @Test func stringFromInt() {
        loadInts(inty, ints: [11, -222], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 -222 ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromInt, to: inty)
        #expect(stackString(inty, .int) == "[ -222 ]")
        #expect(stackString(inty, .string) == "[ \"11\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( 11 .stringFromInt )")

        doThis(.stringFromInt, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"-222\" \"11\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( -222 .stringFromInt )")
    }

    @Test func stringGT() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( \"xyz\" \"abc\" .stringGT )")

        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"abc\" .stringGT )")

        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"xyz\" .stringGT )")
    }

    @Test func stringGTE() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( \"xyz\" \"abc\" .stringGTE )")

        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"abc\" .stringGTE )")

        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"xyz\" .stringGTE )")
    }

    @Test func stringIndexOfChar() {
        loadChars(inty, chars: ["x", "b", "O"])
        loadStrings(inty, strings: ["", "abcd", "abcd"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'x' 'b' 'O' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"abcd\" ]")

        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' 'O' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" \"abcd\" ]")

        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'O' ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( 'b' \"abcd\" .stringIndexOfChar )")
        
        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( 'b' \"abcd\" .stringIndexOfChar )")
    }
    
    @Test func stringItemIsEmpty() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"\" .stringItemIsEmpty )")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( )")


        doThis(.stringItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( \"abcdefghij\" .stringItemIsEmpty )")
    }

    @Test func `stringIterate works for an empty string`() {
        loadInts(inty, ints: [1])
        loadStrings(inty, strings: [""])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
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
        loadInts(inty, ints: [1])
        loadStrings(inty, strings: ["boo"])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
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
        loadStrings(inty, strings: ["boo", "tan"])
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

    @Test func stringLast() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringLast, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")

        doThis(.stringLast, to: inty)
        #expect(stackString(inty, .char) == "[ 'j' ]")
        #expect(stackString(inty, .string) == "[ ]")
   }

    @Test func stringLength() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringLength, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")
        #expect(stackString(inty, .int) == "[ 0 ]")

        doThis(.stringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 10 0 ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( \"abcdefghij\" .stringLength )")
    }

    @Test func stringLT() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( \"xyz\" \"abc\" .stringLT )")

        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"abc\" .stringLT )")

        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"xyz\" .stringLT )")
    }

    @Test func stringLTE() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( \"xyz\" \"abc\" .stringLTE )")

        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"abc\" .stringLTE )")

        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( \"abc\" \"xyz\" .stringLTE )")
    }

    @Test func stringNth() {
        loadInts(inty, ints: [11, 2, -222, 22], contingent: [2])
        loadStrings(inty, strings: ["", "abcdefghi", "abcdefghi", "abcdefghi"], contingent: [3])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 11 2 -222 22 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghi\" \"abcdefghi\" \"abcdefghi\" ]")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 2 -222 22 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghi\" \"abcdefghi\" \"abcdefghi\" ]")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'c' ]")
        #expect(stackString(inty, .int) == "[ -222 22 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghi\" \"abcdefghi\" ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(callString(topItem(inty, .char)) == "( 2 \"abcdefghi\" .stringNth )")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'a' 'c' ]")
        #expect(stackString(inty, .int) == "[ 22 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghi\" ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(callString(topItem(inty, .char)) == "( -222 \"abcdefghi\" .stringNth )")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'e' 'a' 'c' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(callString(topItem(inty, .char)) == "( 22 \"abcdefghi\" .stringNth )")
    }

    @Test func stringOccurrencesOfChar() {
        loadChars(inty, chars: [" ","o","f"])
        loadStrings(inty, strings: ["", "boo", "bee"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ' ' 'o' 'f' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'o' 'f' ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .string) == "[ \"boo\" \"bee\" ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( ' ' \"\" .stringOccurrencesOfChar )")

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'f' ]")
        #expect(stackString(inty, .int) == "[ 2 0 ]")
        #expect(stackString(inty, .string) == "[ \"bee\" ]")
        #expect(topItem(inty, .int).isContingent == true)
        #expect(callString(topItem(inty, .int)) == "( 'o' \"boo\" .stringOccurrencesOfChar )")

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 0 2 0 ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .int).isContingent == false)
        #expect(callString(topItem(inty, .int)) == "( 'f' \"bee\" .stringOccurrencesOfChar )")
    }

    @Test func stringParseToLetters() {
        loadStrings(inty, strings: ["", "live"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"live\" ]")

        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"live\" ]")

        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"e\" \"v\" \"i\" \"l\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"live\" .stringParseToLetters )")

        doThis(.stringPop, to: inty)
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"live\" .stringParseToLetters 1 .stringPopItems )")
    }

    @Test func `stringParseToLetters results reconstruct through PopItems`() {
        loadStrings(inty, strings: ["live"])
        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"e\" \"v\" \"i\" \"l\" ]")

        // The deepest letter needs three pops to surface; the top one needs none.
        let ell = inty.stacks[.string]![3]
        #expect(CodeItem(ell.crux()).pretty()
            == "( \"live\" .stringParseToLetters 3 .stringPopItems )")
        #expect(CodeItem(topItem(inty, .string).crux()).pretty()
            == "( \"live\" .stringParseToLetters )")

        // ...and running that reconstruction really does leave "l" on top.
        let redo = Interpreter()
        redo.load(program: ell.crux())
        redo.run()
        #expect(stackString(redo, .string) == "[ \"l\" ]")
    }

    @Test func stringPushAllChars() {
        loadStrings(inty, strings: ["bar", "fizz", ""], contingent: [0])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"bar\" \"fizz\" \"\" ]")

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(callString(topItem(inty, .char)) == "( \"bar\" .stringPushAllChars )")
        // Each char records the discard that surfaces it. Chars are pushed in
        // reading order, so 'b' went first and sits deepest.
        #expect(CodeItem(topItem(inty, .char).crux()).pretty()
            == "( \"bar\" .stringPushAllChars )")
        #expect(CodeItem(inty.stacks[.char]![2].crux()).pretty()
            == "( \"bar\" .stringPushAllChars 2 .charPopItems )")
        #expect(stackString(inty, .string) == "[ \"fizz\" \"\" ]")

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(callString(topItem(inty, .char)) == "( \"fizz\" .stringPushAllChars )")
        #expect(stackString(inty, .string) == "[ \"\" ]")

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
        #expect(stackString(inty, .string) == "[ ]")
    }

    @Test func stringRemoveChar() {
        loadChars(inty, chars: [" ","o","b"])
        loadStrings(inty, strings: ["", "boo", "bee"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ' ' 'o' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( ' ' \"\" .stringRemoveChar )")

        doThis(.stringPop, to: inty)

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .string) == "[ \"b\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 'o' \"boo\" .stringRemoveChar )")

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 'b' \"b\" .stringRemoveChar )")
    }

    @Test func stringReplace() {
        loadStrings(inty, strings: ["-", "", ""])
        #expect(stackString(inty, .string) == "[ \"-\" \"\" \"\" ]")

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"-\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"\" \"\" \"-\" .stringReplace )")

        loadStrings(inty, strings: [" a","1 ", "00 11 22"], contingent: [2])
        #expect(stackString(inty, .string) == "[ \" a\" \"1 \" \"00 11 22\" \"-\" ]")

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) ==  "[ \"00 1 a22\" \"-\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"00 11 22\" \"1 \" \" a\" .stringReplace )")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["1234", " w", "just write words"])
        #expect(stackString(inty, .string) == "[ \"1234\" \" w\" \"just write words\" ]")

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"just1234rite1234ords\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"just write words\" \" w\" \"1234\" .stringReplace )")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["", "t", "just write words"])
        #expect(stackString(inty, .string) == "[ \"\" \"t\" \"just write words\" ]")

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"jus wrie words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"just write words\" \"t\" \"\" .stringReplace )")
    }

    @Test func stringReplaceChar() {
        loadChars(inty, chars: [" ","o","e", "b"])
        loadStrings(inty, strings: ["", "boo", "bee"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ' ' 'o' 'e' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")

        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'e' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( 'o' ' ' \"\" .stringReplaceChar )")

        doThis(.stringPop, to: inty)

        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"eoo\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 'b' 'e' \"boo\" .stringReplaceChar )")

        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"eoo\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 'b' 'e' \"boo\" .stringReplaceChar )")
    }

    @Test func stringReplaceFirst() {
        loadStrings(inty, strings: ["-", "", ""])
        #expect(stackString(inty, .string) == "[ \"-\" \"\" \"\" ]")

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"-\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"\" \"\" \"-\" .stringReplaceFirst )")

        loadStrings(inty, strings: [" a","1 ", "00 11 22"], contingent: [2])
        #expect(stackString(inty, .string) == "[ \" a\" \"1 \" \"00 11 22\" \"-\" ]")

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) ==  "[ \"00 1 a22\" \"-\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"00 11 22\" \"1 \" \" a\" .stringReplaceFirst )")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["1234", " w", "just write words"])
        #expect(stackString(inty, .string) == "[ \"1234\" \" w\" \"just write words\" ]")

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"just1234rite words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"just write words\" \" w\" \"1234\" .stringReplaceFirst )")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["", "t", "just write words"])
        #expect(stackString(inty, .string) == "[ \"\" \"t\" \"just write words\" ]")

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"jus write words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"just write words\" \"t\" \"\" .stringReplaceFirst )")
    }

    @Test func stringReplaceFirstChar() {
        loadChars(inty, chars: ["-", "2", ".","2", "!"," "])
        loadStrings(inty, strings: ["", "00 11 22"], contingent: [1])
        #expect(stackString(inty, .char) == "[ '-' '2' '.' '2' '!' ' ' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"00 11 22\" ]")

        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .char) == "[ '.' '2' '!' ' ' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"00 11 22\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( '2' '-' \"\" .stringReplaceFirstChar )")

        doThis(.stringPop, to: inty)

        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .char) == "[ '!' ' ' ]")
        #expect(stackString(inty, .string) == "[ \"00 11 .2\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( '2' '.' \"00 11 22\" .stringReplaceFirstChar )")

        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"00!11 .2\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( ' ' '!' \"00 11 .2\" .stringReplaceFirstChar )")
    }

    @Test func stringRest() {
        loadStrings(inty, strings: ["", "abcde"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcde\" ]")

        doThis(.stringRest, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcde\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( \"\" .stringRest )")

        doThis(.stringPop, to: inty)

        doThis(.stringRest, to: inty)
        #expect(stackString(inty, .string) == "[ \"bcde\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"abcde\" .stringRest )")
    }

    @Test func stringReverse() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringReverse, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringPop, to: inty)
        doThis(.stringReverse, to: inty)
        #expect(stackString(inty, .string) == "[ \"jihgfedcba\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"abcdefghij\" .stringReverse )")
    }
    
    @Test func stringSetChar() {
        loadChars(inty, chars: ["-", ".", "?", "+"])
        loadInts(inty, ints: [11, 2, -222, 13], contingent: [2])
        loadStrings(inty, strings: ["", "0123456789"])
        #expect(stackString(inty, .char) == "[ '-' '.' '?' '+' ]")
        #expect(stackString(inty, .int) == "[ 11 2 -222 13 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"0123456789\" ]")

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .char) == "[ '.' '?' '+' ]")
        #expect(stackString(inty, .int) == "[ 2 -222 13 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"0123456789\" ]")

        doThis(.stringPop, to: inty)

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .char) == "[ '?' '+' ]")
        #expect(stackString(inty, .int) == "[ -222 13 ]")
        #expect(stackString(inty, .string) == "[ \"01.3456789\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( '.' 2 \"0123456789\" .stringSetChar )")

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .char) == "[ '+' ]")
        #expect(stackString(inty, .int) == "[ 13 ]")
        #expect(stackString(inty, .string) == "[ \"?1.3456789\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( '?' -222 \"01.3456789\" .stringSetChar )")

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"?1.+456789\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( '+' 13 \"?1.3456789\" .stringSetChar )")
    }

    @Test func stringSplit() {
        loadStrings(inty, strings: [""])
        #expect(stackString(inty, .string) == "[ \"\" ]")

        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["abcde"], contingent: [0])
        #expect(stackString(inty, .string) == "[ \"abcde\" ]")

        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcde\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"abcde\" .stringSplit )")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["ab    cd \ne\tf"])
        #expect(stackString(inty, .string) == "[ \"ab    cd \ne\tf\" ]")

        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ \"f\" \"e\" \"cd\" \"ab\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        // "f" was split off last, so it lands on top and needs no discard.
        #expect(callString(topItem(inty, .string)) == "( \"ab    cd \ne\tf\" .stringSplit )")
        // "ab" was split off first and so sits deepest, under three others.
        #expect(CodeItem(inty.stacks[.string]![3].crux()).pretty()
            == "( \"ab    cd \ne\tf\" .stringSplit 3 .stringPopItems )")
    }

    @Test func `stringSubstring works for empty`() {
        loadInts(inty, ints: [2,2])
        loadStrings(inty, strings: [""])
        #expect(stackString(inty, .int) == "[ 2 2 ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")

        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
    }

    @Test func `stringSubstring works for nonempty with 2 huge indices`() {
        loadInts(inty, ints: [72, 94])
        loadStrings(inty, strings: ["lorex ipsum"])
        #expect(stackString(inty, .int) == "[ 72 94 ]")
        #expect(stackString(inty, .string) == "[ \"lorex ipsum\" ]")

        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"m\" ]")
     }

    @Test func `stringSubstring works for nonempty with 2 negative indices`() {
        loadInts(inty, ints: [-22, -5])
        loadStrings(inty, strings: ["lorem ipsum"])
        #expect(stackString(inty, .int) == "[ -22 -5 ]")
        #expect(stackString(inty, .string) == "[ \"lorem ipsum\" ]")

        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"l\" ]")
    }

    @Test func `stringSubstring works for nonempty with basic indices`() {
        loadInts(inty, ints: [4, 2])
        loadStrings(inty, strings: ["lorem ipsum"])
        #expect(stackString(inty, .int) == "[ 4 2 ]")
        #expect(stackString(inty, .string) == "[ \"lorem ipsum\" ]")

        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"rem\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with identical indices`() {
        loadInts(inty, ints: [3, 3])
        loadStrings(inty, strings: ["lorem ipsum"])
        #expect(stackString(inty, .int) == "[ 3 3 ]")
        #expect(stackString(inty, .string) == "[ \"lorem ipsum\" ]")

        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"e\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with weird indices`() {
        loadInts(inty, ints: [90, -5])
        loadStrings(inty, strings: ["lorem ipsum"])
        #expect(stackString(inty, .int) == "[ 90 -5 ]")
        #expect(stackString(inty, .string) == "[ \"lorem ipsum\" ]")

        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"lorem ipsum\" ]")
    }

    @Test func `stringSubstring works for silly indices on empty strings`() {
        loadInts(inty, ints: [-3, 22])
        loadStrings(inty, strings: [""])
        #expect(stackString(inty, .int) == "[ -3 22 ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")

        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
    }

    @Test func stringTake() {
        loadInts(inty, ints: [3, 0, 4, -14, 99])
        loadStrings(inty, strings: ["", "abcdefghij", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .int) == "[ 3 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" \"abcdefghij\" ]")

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" \"abcdefghij\" ]")

        doThis(.stringPop, to:inty)
        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( 0 \"abcdefghij\" .stringTake )")

        doThis(.stringPop, to:inty)
        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( 4 \"abcdefghij\" .stringTake )")

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( -14 \"abcd\" .stringTake )")

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(callString(topItem(inty, .string)) == "( 99 \"\" .stringTake )")
    }
}
