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
        loadDoubles(inty, doubles: [0,21,31,91.5])
        #expect(stackString(inty, .double) == "[ 0.0 21.0 31.0 91.5 ]")

        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(callString(topItem(inty, .char)) == "( 0.0 .charFromDouble )")
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '5' ' ' ]")
        #expect(callString(topItem(inty, .char)) == "( 21.0 .charFromDouble )")

        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '?' '5' ' ' ]")
        
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ '{' '?' '5' ' ' ]")
        #expect(callString(topItem(inty, .char)) == "( 91.5 .charFromDouble )")
    }

    @Test func `charFromDouble handles non-finite and out-of-range doubles`() {
        // an infinite double would trap Int(_:); route it to .error instead
        loadDoubles(inty, doubles: [Double.infinity])
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .charFromDouble"))
        #expect(callString(topItem(inty, .error)) == "( inf .charFromDouble )")

        // a finite double beyond Int's range would also trap
        loadDoubles(inty, doubles: [1e40])
        doThis(.charFromDouble, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .charFromDouble"))
        #expect(callString(topItem(inty, .error)) == "( 1e+40 .charFromDouble )")
    }

    @Test func charFromInt() {
        loadInts(inty, ints: [0,21,31,91])
        #expect(stackString(inty, .int) == "[ 0 21 31 91 ]")

        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ ' ' ]")
        #expect(callString(topItem(inty, .char)) == "( 0 .charFromInt )")
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '5' ' ' ]")
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '?' '5' ' ' ]")
        
        doThis(.charFromInt, to: inty)
        #expect(stackString(inty, .char) == "[ '{' '?' '5' ' ' ]")
        #expect(callString(topItem(inty, .char)) == "( 91 .charFromInt )")
    }

    @Test func charGT() {
        loadChars(inty, chars: ["g","d","b","x","&","&"])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charGT 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charGT 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charGT 2 .charPopItems )")
    }

    @Test func charGTE() {
        loadChars(inty, chars: ["g","d","b","x","&","&"])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charGTE 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charGTE 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charGTE 2 .charPopItems )")
    }

    @Test func charIsDigit() {
        loadChars(inty, chars: ["1","q","2️⃣","७"])
        #expect(stackString(inty, .char) == "[ '1' 'q' '2️⃣' '७' ]")

        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( '1' .charIsDigit 1 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( 'q' .charIsDigit 1 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(callString(topItem(inty, .bool)) == "( '2️⃣' .charIsDigit 1 .charPopItems )")

        // note that digits in other languages count!
        doThis(.charPop, to: inty)
        doThis(.charIsDigit, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false true ]")
        #expect(callString(topItem(inty, .bool)) == "( '७' .charIsDigit 1 .charPopItems )")
    }

    @Test func charIsLetter() {
        loadChars(inty, chars: ["1", "q", "-", "ϴ"])
        #expect(stackString(inty, .char) == "[ '1' 'q' '-' 'ϴ' ]")

        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( '1' .charIsLetter 1 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( 'q' .charIsLetter 1 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(callString(topItem(inty, .bool)) == "( '-' .charIsLetter 1 .charPopItems )")

        // note that letters in other languages count!
        doThis(.charPop, to: inty)
        doThis(.charIsLetter, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true false ]")
        #expect(callString(topItem(inty, .bool)) == "( 'ϴ' .charIsLetter 1 .charPopItems )")
    }

    @Test func charIsWhitespace() {
        loadChars(inty, chars: ["g", " ", "\n", "\t"])
        #expect(stackString(inty, .char) == "[ 'g' ' ' '\n' '\t' ]")

        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 'g' .charIsWhitespace 1 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( ' ' .charIsWhitespace 1 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(callString(topItem(inty, .bool)) == "( '\n' .charIsWhitespace 1 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charIsWhitespace, to: inty)
        #expect(stackString(inty, .bool) == "[ true true true false ]")
        #expect(callString(topItem(inty, .bool)) == "( '\t' .charIsWhitespace 1 .charPopItems )")
    }

    @Test func charLT() {
        loadChars(inty, chars: ["g","d","b","x","&","&"])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charLT 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charLT 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charLT 2 .charPopItems )")
    }

    @Test func charLTE() {
        loadChars(inty, chars: ["g","d","b","x","&","&"])
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '&' '&' ]")

        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( 'd' 'g' .charLTE 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( 'x' 'b' .charLTE 2 .charPopItems )")

        doThis(.charPop, to: inty)
        doThis(.charPop, to: inty)
        doThis(.charLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(callString(topItem(inty, .bool)) == "( '&' '&' .charLTE 2 .charPopItems )")
    }

}
