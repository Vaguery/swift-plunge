//
//  Char Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/2/26.
//

@testable import PushInterpreter
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
        #expect(callString(topItem(inty, .char)) == "( 0.0 .charFromDouble )")
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(callString(topItem(inty, .char)) == "( 21.0 .charFromDouble )")

        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '{' '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(callString(topItem(inty, .char)) == "( 91.5 .charFromDouble )")
    }

    @Test func `charFromDouble handles non-finite and out-of-range doubles`() {
        // an infinite double would trap Int(_:); route it to .error instead
        loadDoubles(inty, doubles: [Double.infinity])
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .charFromDouble"))

        // a finite double beyond Int's range would also trap
        loadDoubles(inty, doubles: [1e40])
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .charFromDouble"))
    }

    @Test func charFromInt() {
        loadInts(inty, ints: [0,21,31,91], contingent: [1])
        #expect(stackString(inty, .int) == "[ 0 21 31 91 ]")

        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(callString(topItem(inty, .char)) == "( 0 .charFromInt )")
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == true)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '{' '?' '5' ' ' ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(callString(topItem(inty, .char)) == "( 91 .charFromInt )")
    }

    @Test func charGT() {
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charGT )")

        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charGT )")

        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charGT )")
    }

    @Test func charGTE() {
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charGTE )")

        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charGTE )")

        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charGTE )")
    }

    @Test func charIsDigit() {
        loadChars(inty, chars: ["1","q","2️⃣","७"], contingent: [1])
        #expect(stackString(inty, .char) == "[ '1' 'q' '2️⃣' '७' ]")

        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '1' .charIsDigit )")

        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( 'q' .charIsDigit )")

        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '2️⃣' .charIsDigit )")

        // note that digits in other languages count!
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '७' .charIsDigit )")
    }

    @Test func charIsLetter() {
        loadChars(inty, chars: ["1", "q", "-", "ϴ"], contingent: [1])
        #expect(stackString(inty, .char) == "[ '1' 'q' '-' 'ϴ' ]")

        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '1' .charIsLetter )")

        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( 'q' .charIsLetter )")

        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '-' .charIsLetter )")

        // note that letters in other languages count!
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( 'ϴ' .charIsLetter )")
    }

    @Test func charIsWhitespace() {
        loadChars(inty, chars: ["g", " ", "\n", "\t"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' ' ' '\n' '\t' ]")

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( 'g' .charIsWhitespace )")

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( ' ' .charIsWhitespace )")

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '\n' .charIsWhitespace )")

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '\t' .charIsWhitespace )")
    }

    @Test func charLT() {
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charLT )")

        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charLT )")

        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charLT )")
    }

    @Test func charLTE() {
        loadChars(inty, chars: ["g","d","b","x","&","&"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charLTE )")

        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charLTE )")

        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charLTE )")
    }

}
