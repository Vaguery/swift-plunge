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
        #expect(callString(topItem(inty, .char)) == "( \"abcdefghij\" .stringFirst )")
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
        // The mouse is a code argument now, so it waits on `.code` as a block.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.intInc)]))
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
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
        // The mouse is a code argument now, so it waits on `.code` as a block.
        inty.stacks[.code]!.prepend(CodeItem([InstructionItem(.intInc)]))

        #expect(stackString(inty, .string) == "[ \"boo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 1 ]")

        // The instruction only builds the iterator; `.iteratorPlay` does the work.
        // The whole string goes in and stays there — where it used to re-push a
        // *shrinking* copy of itself onto `.exec` every single pass.
        doThis(.stringIterate, to: inty)

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .iterator) == "[ «\"boo\" @0 ( .intInc )» ]")
        #expect(stackString(inty, .int) == "[ 1 ]")

        inty.step()   // first pass: 'b', then the mouse

        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ ( .intInc ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        // The character names the instruction that honestly reproduces it, and
        // that record does not depend on how many passes have run. The shrinking
        // remainder — the other derived value, which recorded `.stringRest` and
        // deepened a level per character — does not exist any more.
        #expect(callString(topItem(inty, .char)) == "( \"boo\" 0 .stringNth )")
        // The mouse copy, the `.codeDo` and the continuation record nothing.
        #expect(inty.stacks[.exec]![0].call.isEmpty)   // mouse, to run
        #expect(inty.stacks[.exec]![1].call.isEmpty)   // .codeDo
        #expect(inty.stacks[.exec]![2].call.isEmpty)   // .iteratorPlay

        inty.step()

        #expect(stackString(inty, .exec) == "[ .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .code) == "[ ( .intInc ) ]")

        inty.step()

        #expect(stackString(inty, .exec) == "[ .intInc .iteratorPlay ]")

        inty.step()   // the mouse runs

        #expect(stackString(inty, .exec) == "[ .iteratorPlay ]")
        #expect(stackString(inty, .int) == "[ 2 ]")

        // The loop comes back round in ONE step, where it used to take three: the
        // string and the token no longer travel through `.exec` to be re-supplied.
        inty.step()   // second pass: 'o'

        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ ( .intInc ) .codeDo .iteratorPlay ]")
        #expect(callString(topItem(inty, .char)) == "( \"boo\" 1 .stringNth )")

        for _ in 0..<4 { inty.step() }   // run the mouse, then the last pass

        #expect(stackString(inty, .char) == "[ 'o' 'o' 'b' ]")
        #expect(stackString(inty, .int) == "[ 3 ]")
        // Three characters, so three passes and no continuation.
        #expect(stackString(inty, .exec) == "[ ( .intInc ) .codeDo ]")
        #expect(stackString(inty, .iterator) == "[ ]")
        // The last character costs no more to explain than the first.
        #expect(callString(topItem(inty, .char)) == "( \"boo\" 2 .stringNth )")
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

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar ]")

        inty.step()

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

        inty.step()

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

        inty.step()

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

        inty.step()

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

        inty.step()

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

        inty.step()

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")

        inty.step()

        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
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
        #expect(callString(topItem(inty, .char)) == "( \"abcdefghij\" .stringLast )")
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
        #expect(callString(topItem(inty, .char)) == "( \"abcdefghi\" 2 .stringNth )")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'a' 'c' ]")
        #expect(stackString(inty, .int) == "[ 22 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghi\" ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(callString(topItem(inty, .char)) == "( \"abcdefghi\" -222 .stringNth )")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'e' 'a' 'c' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(callString(topItem(inty, .char)) == "( \"abcdefghi\" 22 .stringNth )")
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

    /// The order is unchanged — front-to-back, so "e" ends up on top — but the
    /// letters arrive one per pass rather than all at once, and each records what
    /// it *is* rather than how far down a pile it landed.
    @Test func stringParseToLetters() {
        loadStrings(inty, strings: ["", "live"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"live\" ]")

        // An empty string yields nothing at all — not even an iterator.
        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"live\" ]")
        #expect(stackString(inty, .iterator) == "[ ]")

        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .string) == "[ \"e\" \"v\" \"i\" \"l\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        // A one-character *string*, so two instructions to reproduce — still O(1),
        // and it names no other letter.
        #expect(callString(topItem(inty, .string))
            == "( \"live\" 3 .stringNth .stringFromChar )")

        doThis(.stringPop, to: inty)
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string))
            == "( \"live\" 2 .stringNth .stringFromChar )")
    }

    @Test func `stringParseToLetters letters each reconstruct`() {
        loadStrings(inty, strings: ["live"])
        doThis(.stringParseToLetters, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .string) == "[ \"e\" \"v\" \"i\" \"l\" ]")

        // Every letter reconstructs on its own, and the deepest costs no more to
        // explain than the top one — where each used to record the *pile* it came
        // out of and how far to dig.
        for (depth, expected) in [(0, "e"), (1, "v"), (2, "i"), (3, "l")] {
            let letter = inty.stacks[.string]![depth]
            let redo = Interpreter()
            redo.load(program: letter.crux())
            redo.run(stepLimit: 10_000)
            #expect(stackString(redo, .string) == "[ \"\(expected)\" ]",
                    "the letter at depth \(depth) did not reconstruct")
        }
        #expect(topItem(inty, .string).callWeight == inty.stacks[.string]![3].callWeight)
    }

    /// The order is unchanged — front-to-back, so 'r' ends up on top — but the
    /// characters arrive one per pass rather than all at once.
    @Test func stringPushAllChars() {
        loadStrings(inty, strings: ["bar", "fizz", ""], contingent: [0])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"bar\" \"fizz\" \"\" ]")

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ ]")   // nothing until it runs
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .char) == "[ 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == true)
        // Each char names its own index. It used to record the discard that
        // surfaced it from a pile — `"bar" .stringPushAllChars 2 .charPopItems`.
        #expect(callString(topItem(inty, .char)) == "( \"bar\" 2 .stringNth )")
        #expect(CodeItem(inty.stacks[.char]![2].crux()).pretty()
            == "( \"bar\" 0 .stringNth )")
        #expect(stackString(inty, .string) == "[ \"fizz\" \"\" ]")

        doThis(.stringPushAllChars, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(callString(topItem(inty, .char)) == "( \"fizz\" 3 .stringNth )")
        #expect(stackString(inty, .string) == "[ \"\" ]")

        // An empty string yields nothing at all — not even an iterator.
        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")
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

    /// The order is unchanged — front-to-back, so the last word ends up on top —
    /// but the words arrive one per pass, and each names itself with the new
    /// `.stringNthWord` rather than recording how far down a pile it landed.
    @Test func stringSplit() {
        loadStrings(inty, strings: [""])
        #expect(stackString(inty, .string) == "[ \"\" ]")

        // No words at all: nothing, not even an iterator.
        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["abcde"], contingent: [0])
        #expect(stackString(inty, .string) == "[ \"abcde\" ]")

        doThis(.stringSplit, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .string) == "[ \"abcde\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        #expect(callString(topItem(inty, .string)) == "( \"abcde\" 0 .stringNthWord )")

        doThis(.stringFlush, to: inty)

        loadStrings(inty, strings: ["ab    cd \ne\tf"])
        #expect(stackString(inty, .string) == "[ \"ab    cd \ne\tf\" ]")

        doThis(.stringSplit, to: inty)
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .string) == "[ \"f\" \"e\" \"cd\" \"ab\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        // A word is not `origin[i]`, so no existing instruction could name one —
        // which is why `.stringNthWord` had to be added for these to have a record
        // at all. "f" is the 4th word; "ab" is the 1st, and says so without
        // reference to the other three.
        #expect(callString(topItem(inty, .string)) == "( \"ab    cd \ne\tf\" 3 .stringNthWord )")
        #expect(CodeItem(inty.stacks[.string]![3].crux()).pretty()
            == "( \"ab    cd \ne\tf\" 0 .stringNthWord )")
    }

    @Test func stringNthWord() {
        loadInts(inty, ints: [1])
        loadStrings(inty, strings: ["one two three"])

        doThis(.stringNthWord, to: inty)
        #expect(stackString(inty, .string) == "[ \"two\" ]")
        #expect(callString(topItem(inty, .string)) == "( \"one two three\" 1 .stringNthWord )")

        // Indexed modulo the word count, like its `stringNth` sibling.
        loadInts(inty, ints: [4])
        loadStrings(inty, strings: ["one two three"])
        doThis(.stringNthWord, to: inty)
        #expect(topItem(inty, .string).pretty() == "\"two\"")

        // A string with no words has no word to give back, and an ErrorItem here
        // would be noise.
        loadInts(inty, ints: [0])
        loadStrings(inty, strings: ["   "])
        doThis(.stringNthWord, to: inty)
        #expect(stackString(inty, .string) == "[ \"two\" \"two\" ]")
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
        #expect(callString(topItem(inty, .string))
            == "( \"lorex ipsum\" 94 72 .stringSubstring )")
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
