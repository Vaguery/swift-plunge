//
//  Bool Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/1/26.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct BoolBehaviorTests {

    let inty = Interpreter.recordingProvenance()

    @Test func boolAnd() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolAnd )")

        doThis(.boolPop, to: inty)
        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolAnd )")

        doThis(.boolPop, to: inty)
        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolAnd )")

        doThis(.boolPop, to: inty)
        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolAnd )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolFromDouble() {
        loadDoubles(inty, doubles: [ 0.0, 1.1, -1.1 ])
        #expect(stackString(inty, .double) == "[ 0.0 1.1 -1.1 ]")

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 0.0 .boolFromDouble )")

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( 1.1 .boolFromDouble )")

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -1.1 .boolFromDouble )")
    }

    @Test func boolFromInt() {
        loadInts(inty, ints: [0, 1, -1])
        #expect(stackString(inty, .int) == "[ 0 1 -1 ]")

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 0 .boolFromInt )")

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( 1 .boolFromInt )")

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -1 .boolFromInt )")
    }

    @Test func boolIfPThenQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolIfPThenQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolIfPThenQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolIfPThenQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolIfPThenQ )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolIfQThenP() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolIfQThenP )")
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolIfQThenP )")
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolIfQThenP )")
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolIfQThenP )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolNand() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolNand )")
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolNand )")
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolNand )")
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolNand )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolNor() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolNor )")
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolNor )")
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolNor )")
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolNor )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolNot() {
        loadBools(inty, bools: [false])
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( false .boolNot )")

        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( true .boolNot )")

    }

    @Test func boolNotP() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolNotP )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolNotP )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolNotP )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolNotP )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolNotPandQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolNotPandQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolNotPandQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolNotPandQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolNotPandQ )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolNotQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolNotQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolNotQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolNotQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolNotQ )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolOr() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolOr )")
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolOr )")
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolOr )")
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolOr )")
        doThis(.boolPop, to: inty)

    }

    @Test func boolP() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolP )")
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolP )")
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolP )")
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolP )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolPandNotQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolPandNotQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolPandNotQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolPandNotQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolPandNotQ )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolQ )")
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolQ )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolXnor() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolXnor )")
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolXnor )")
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolXnor )")
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolXnor )")
        doThis(.boolPop, to: inty)
    }

    @Test func boolXor() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( true true .boolXor )")
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( false true .boolXor )")
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(callString(topItem(inty, .bool)) == "( true false .boolXor )")
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(callString(topItem(inty, .bool)) == "( false false .boolXor )")
        doThis(.boolPop, to: inty)
    }

}
