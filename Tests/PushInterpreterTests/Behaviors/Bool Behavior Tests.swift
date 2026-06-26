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
        intyBool8(inty)

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
        intyDouble3(inty)

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
        intyInt3(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBoolF(inty)

        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == true)
        doThis(.boolNot, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == true)

    }

    @Test func boolNotP() {
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
        intyBool8(inty)

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
