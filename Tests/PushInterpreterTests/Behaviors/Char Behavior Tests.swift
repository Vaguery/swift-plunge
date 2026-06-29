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
        loadDoubles(inty, doubles: [0,21,31,91.5], contingent: [1])
        #expect(stackString(inty, .double) == "[ 0.0 21.0 31.0 91.5 ]")

        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == true)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '{' '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
    }

    @Test func charFromInt() {
        loadInts(inty, ints: [0,21,31,91], contingent: [1])
        #expect(stackString(inty, .int) == "[ 0 21 31 91 ]")

        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == true)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '{' '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
    }

    @Test func charGT() {
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

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
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

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
        loadChars(inty, chars: ["1","q","2️⃣","७"], contingent: [1])
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
        loadChars(inty, chars: ["1", "q", "-", "ϴ"], contingent: [1])
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
        loadChars(inty, chars: ["g", " ", "\n", "\t"], contingent: [1])
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
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

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
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

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
