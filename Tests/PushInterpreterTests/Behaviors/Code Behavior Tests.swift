//
//  Code Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/17/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeBehaviorTests {

    let inty = Interpreter()

    @Test func codeAppend() {
        loadCode(inty, code: [1, [false, 2], ["abc",[false, 1.1]]], contingent: [1])
        #expect(stackString(inty, .code) == "[ ( 1 ) ( false 2 ) ( \"abc\" ( false 1.1 ) ) ]")

        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( false 2 1 ) ( \"abc\" ( false 1.1 ) ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( ( false 2 ) ( 1 ) .codeAppend )")

        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( \"abc\" ( false 1.1 ) false 2 1 ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( ( \"abc\" ( false 1.1 ) ) ( false 2 1 ) .codeAppend )")

        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( \"abc\" ( false 1.1 ) false 2 1 ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( ( \"abc\" ( false 1.1 ) ) ( false 2 1 ) .codeAppend )")
    }

    @Test func `codeItemIsEmpty works with empty code`() {
        loadCode(inty, code: [CodeItem([]) ] )
        #expect(stackString(inty, .code) == "[ ( ) ]")

        doThis(.codeItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( ( ) .codeItemIsEmpty )")
    }

    @Test func `codeItemIsEmpty works with non-empty code`() {
        loadCode(inty, code: [ 1 ] )
        #expect(stackString(inty, .code) == "[ ( 1 ) ]")

        doThis(.codeItemIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( ( 1 ) .codeItemIsEmpty )")
    }

    @Test func `codeLengthRoot only measures in the code root`() {
        loadCode(inty, code: [1, [false, 2], ["abc",[false, 1.1]]] )
        #expect(stackString(inty, .code) == "[ ( 1 ) ( false 2 ) ( \"abc\" ( false 1.1 ) ) ]")

        doThis(.codeLengthRoot, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(callString(topItem(inty, .int)) == "( ( 1 ) .codeLengthRoot )")

        doThis(.codeLengthRoot, to: inty)
        #expect(stackString(inty, .int) == "[ 2 1 ]")

        doThis(.codeLengthRoot, to: inty)
        #expect(stackString(inty, .int) == "[ 2 2 1 ]")
    }

    @Test func `codeLengthRoot works with empty code`() {
        loadCode(inty, code: [CodeItem([]) ] )
        #expect(stackString(inty, .code) == "[ ( ) ]")

        doThis(.codeLengthRoot, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(callString(topItem(inty, .int)) == "( ( ) .codeLengthRoot )")
    }

    @Test func `codeWrapRoot works with empty code`() {
        loadCode(inty, code: [CodeItem([]) ] )
        #expect(stackString(inty, .code) == "[ ( ) ]")

        doThis(.codeWrapRoot, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( ) ) ]")
        #expect(callString(topItem(inty, .code)) == "( ( ) .codeWrapRoot )")
    }

    @Test func `codeWrapRoot works with non-empty code`() {
        loadCode(inty, code: [ [1, [2.2, [3] ] ] ] )
        #expect(stackString(inty, .code) == "[ ( 1 ( 2.2 [3] ) ) ]")

        doThis(.codeWrapRoot, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( 1 ( 2.2 [3] ) ) ) ]")
    }

    @Test func execQuote() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(CodeItem([]))

        #expect(stackString(inty, .exec) == "[ ( ) true 44 ]")

        doThis(.execQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( ) ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        #expect(callString(topItem(inty, .code)) == "( .execQuote ( ) )")

        doThis(.execQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( true ) ( ( ) ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( .execQuote true )")

        doThis(.execQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 44 ) ( true ) ( ( ) ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        #expect(callString(topItem(inty, .code)) == "( .execQuote 44 )")
    }


    @Test func intQuote() {
        loadInts(inty, ints: [55, 44], contingent: [0])

        #expect(stackString(inty, .int) == "[ 55 44 ]")

        doThis(.intQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 55 ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( 55 .intQuote )")

        doThis(.intQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 44 ) ( 55 ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        #expect(callString(topItem(inty, .code)) == "( 44 .intQuote )")
    }

    @Test func doubleQuote() {
        loadDoubles(inty, doubles: [1.1, 2.2], contingent: [0])

        #expect(stackString(inty, .double) == "[ 1.1 2.2 ]")

        doThis(.doubleQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1.1 ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( 1.1 .doubleQuote )")

        doThis(.doubleQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 2.2 ) ( 1.1 ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        #expect(callString(topItem(inty, .code)) == "( 2.2 .doubleQuote )")
    }

    @Test func boolQuote() {
        loadBools(inty, bools: [true , false], contingent: [0])

        #expect(stackString(inty, .bool) == "[ true false ]")

        doThis(.boolQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( true ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( true .boolQuote )")

        doThis(.boolQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( false ) ( true ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        #expect(callString(topItem(inty, .code)) == "( false .boolQuote )")
    }

    @Test func charQuote() {
        loadChars(inty, chars: ["a" , "b"], contingent: [0])

        #expect(stackString(inty, .char) == "[ 'a' 'b' ]")

        doThis(.charQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 'a' ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( 'a' .charQuote )")

        doThis(.charQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 'b' ) ( 'a' ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        #expect(callString(topItem(inty, .code)) == "( 'b' .charQuote )")
    }

    @Test func stringQuote() {
        loadStrings(inty, strings: ["aaa" , "bcd"], contingent: [0])

        #expect(stackString(inty, .string) == "[ \"aaa\" \"bcd\" ]")

        doThis(.stringQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( \"aaa\" ) ]")
        #expect(topItem(inty, .code).isContingent == true)
        #expect(callString(topItem(inty, .code)) == "( \"aaa\" .stringQuote )")

        doThis(.stringQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( \"bcd\" ) ( \"aaa\" ) ]")
        #expect(topItem(inty, .code).isContingent == false)
        #expect(callString(topItem(inty, .code)) == "( \"bcd\" .stringQuote )")
    }

}
