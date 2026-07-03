//
//  Code Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/17/26.
//

@testable import PropellerWithStructs
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

        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( \"abc\" ( false 1.1 ) false 2 1 ) ]")
        #expect(topItem(inty, .code).isContingent == true)

        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( \"abc\" ( false 1.1 ) false 2 1 ) ]")
        #expect(topItem(inty, .code).isContingent == true)
    }

    @Test func `codeLengthRoot only measures in the code root`() {
        loadCode(inty, code: [1, [false, 2], ["abc",[false, 1.1]]] )
        #expect(stackString(inty, .code) == "[ ( 1 ) ( false 2 ) ( \"abc\" ( false 1.1 ) ) ]")

        doThis(.codeLengthRoot, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")

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
    }

    @Test func `codeWrapRoot works with empty code`() {
        loadCode(inty, code: [CodeItem([]) ] )
        #expect(stackString(inty, .code) == "[ ( ) ]")

        doThis(.codeWrapRoot, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( ) ) ]")
    }

    @Test func `codeWrapRoot works with non-empty code`() {
        loadCode(inty, code: [ [1, [2.2, [3] ] ] ] )
        #expect(stackString(inty, .code) == "[ ( 1 ( 2.2 [3] ) ) ]")

        doThis(.codeWrapRoot, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( 1 ( 2.2 [3] ) ) ) ]")
    }

    @Test func `codeIsEmpty works with empty code`() {
        loadCode(inty, code: [CodeItem([]) ] )
        #expect(stackString(inty, .code) == "[ ( ) ]")

        doThis(.codeIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
    }

    @Test func `codeIsEmpty works with non-empty code`() {
        loadCode(inty, code: [ 1 ] )
        #expect(stackString(inty, .code) == "[ ( 1 ) ]")

        doThis(.codeIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
    }


    @Test func execQuote() {
        inty.stacks[.exec]!.prepend(IntItem(44))
        inty.stacks[.exec]!.prepend(BoolItem(true, isContingent: true))
        inty.stacks[.exec]!.prepend(CodeItem([]))

        #expect(stackString(inty, .exec) == "[ ( ) true 44 ]")

        doThis(.execQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( ) ) ]")
        #expect(topItem(inty, .code)!.isContingent == false)

        doThis(.execQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( true ) ( ( ) ) ]")
        #expect(topItem(inty, .code)!.isContingent == true)

        doThis(.execQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 44 ) ( true ) ( ( ) ) ]")
        #expect(topItem(inty, .code)!.isContingent == false)
    }


    @Test func intQuote() {
        inty.stacks[.int]!.prepend(IntItem(44))
        inty.stacks[.int]!.prepend(IntItem(55, isContingent: true))

        #expect(stackString(inty, .int) == "[ 55 44 ]")

        doThis(.intQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 55 ) ]")
        #expect(topItem(inty, .code)!.isContingent == true)

        doThis(.intQuote, to: inty)
        #expect(stackString(inty, .code) == "[ ( 44 ) ( 55 ) ]")
        #expect(topItem(inty, .code)!.isContingent == false)

    }

}
