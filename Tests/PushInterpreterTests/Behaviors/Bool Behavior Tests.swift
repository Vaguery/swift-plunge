//
//  Bool Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/1/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct BoolBehaviorTests {

    let inty = Interpreter()

    @Test func boolAnd() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolPop, to: inty)
        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolPop, to: inty)
        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolPop, to: inty)
        doThis(.boolAnd, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolFromDouble() {
        loadDoubles(inty, doubles: [ 0.0, 1.1, -1.1 ], contingent: [2])
        #expect(stackString(inty, .double) == "[ 0.0 1.1 -1.1 ]")

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromDouble, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func boolFromInt() {
        loadInts(inty, ints: [0, 1, -1], contingent: [2])
        #expect(stackString(inty, .int) == "[ 0 1 -1 ]")

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.boolFromInt, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func boolIfPThenQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfPThenQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolIfQThenP() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolIfQThenP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolNand() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNand, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolNor() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolNot() {
        loadBools(inty, bools: [false], contingent: [0])
        #expect(stackString(inty, .bool) == "[ false ]")

        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }

    @Test func boolNotP() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolNotPandQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotPandQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolNotQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolOr() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolOr, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)

    }

    @Test func boolP() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolP, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolPandNotQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolPandNotQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolQ() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolQ, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolXnor() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXnor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

    @Test func boolXor() {
        loadBools(inty, bools: [true, true, true, false, false, true, false, false], contingent: [7])
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == true)
        #expect(topItem(inty, .bool).isContingent == false)
        doThis(.boolPop, to: inty)

        doThis(.boolXor, to: inty)
        #expect(topItem(inty, .bool).value as! Bool == false)
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolPop, to: inty)
    }

}
