//
//  Char Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/2/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct CharBehaviorTests {

    let inty = Interpreter()

    @Test func charFromDouble() {
        intyDouble4(inty)

        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ 'v' ' ' ]")
        #expect(topItem(inty, .char).isContingent == true)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ 'A' 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
    }

    @Test func charFromInt() {
        intyInt4(inty)

        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ 'v' ' ' ]")
        #expect(topItem(inty, .char).isContingent == true)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ 'A' 'b' 'v' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
    }

    @Test func charGT() {
        intyChar6(inty)

        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func charGTE() {
        intyChar6(inty)

        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func charIsDigit() {
        inty.stacks[.char]!.prepend(contentsOf: [CharItem(Character("1")), CharItem(Character("q"), isContingent: true), CharItem(Character("2️⃣")), CharItem(Character("७"))])

        #expect(stackString(inty, .char) == "[ '1' 'q' '2️⃣' '७' ]")

        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        // note that digits in other languages count!
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

    }

    @Test func charIsLetter() {
        inty.stacks[.char]!.prepend(contentsOf: [CharItem(Character("1")), CharItem(Character("q"), isContingent: true), CharItem(Character("-")), CharItem(Character("ϴ"))])

        #expect(stackString(inty, .char) == "[ '1' 'q' '-' 'ϴ' ]")

        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        // note that letters in other languages count!
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

    }

    @Test func charIsWhitespace() {
        inty.stacks[.char]!.prepend(contentsOf: [CharItem(Character("g")), CharItem(Character(" "), isContingent: true), CharItem(Character("\n")), CharItem(Character("\t"))])

        #expect(stackString(inty, .char) == "[ 'g' ' ' '\n' '\t' ]")

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func charLT() {
        intyChar6(inty)

        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func charLTE() {
        intyChar6(inty)

        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }


}
