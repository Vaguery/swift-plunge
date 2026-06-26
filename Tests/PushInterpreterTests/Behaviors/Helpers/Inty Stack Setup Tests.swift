//
//  Inty Stack Setup Tests.swift
//  PropellerWithStructsUnitTests
//
//  Created by Barbara Tozier on 6/25/26.
//
// verify interpreter setup works as expected

@testable import PropellerWithStructs
import Testing
import DequeModule

@MainActor
struct IntyStackSetupTests {

    let inty = Interpreter()

// MARK: intyBool setup tests

    @Test func `intyBool8 setup`() {
        intyBool8(inty)
        #expect(stackString(inty, .bool) == "[ true true true false false true false false ]")
    }

    @Test func `intyBoolF setup`() {
        intyBoolF(inty)
        #expect(stackString(inty, .bool) == "[ false ]")
    }

    @Test func `intyBoolT setup`() {
        intyBoolT(inty)
        #expect(stackString(inty, .bool) == "[ true ]")
    }


    // MARK: intyChar setup tests

    @Test func `intyChar6 setup`() {
        intyChar6(inty)
        #expect(stackString(inty, .char) == "[ 'g' 'd' 'b' 'x' '-' '-' ]")
    }

    @Test func `loadChars setup`() {
        loadChars(inty, chars: [])
        #expect(stackString(inty, .char) == "[ ]")
    }

    @Test func `loadChars loads chars`() {
        loadChars(inty, chars: ["b", "a"])
        #expect(stackString(inty, .char) == "[ 'b' 'a' ]")
    }

    @Test func `loadChars sets contingency`() {
        loadChars(inty, chars: ["b", "a"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'b' 'a' ]")
        #expect(probeItemOnStack(inty,.char,index:0)!.isContingent == false)
        #expect(probeItemOnStack(inty,.char,index:1)!.isContingent == true)
    }

    // MARK: intyCode setup tests

    @Test func `intyCode4 setup`() {
        intyCode4(inty)
        #expect(stackString(inty, .code) == "[ ( 4 ) ( 8.8 ) ( '-' ) ( ) ]")
    }

    @Test func `intyCode6IB setup`() {
        intyCode6IB(inty)
        #expect(stackString(inty, .code) == "[ ( 4 false ) ( 4 false ) ( 4 false ) ( 4 false ) ( 5 false ) ( 4 true ) ]")
    }

    // MARK: intyDouble setup tests

    @Test func `intyDouble3 setup`() {
        intyDouble3(inty)
        #expect(stackString(inty, .double) == "[ 0.0 1.1 -1.1 ]")
    }

    @Test func `intyDouble4 setup`() {
        intyDouble4(inty)
        #expect(stackString(inty, .double) == "[ 0.0 1111111.11 66.6 -33.0 ]")
    }

    @Test func `loadDoubles setup`() {
        loadDoubles(inty, doubles: [])
        #expect(stackString(inty, .double) == "[ ]")
    }

    @Test func `loadDoubles loads doubles`() {
        loadDoubles(inty, doubles: [2, 3.4, 5.67])
        #expect(stackString(inty, .double) == "[ 2.0 3.4 5.67 ]")
    }

    @Test func `loadDoubles sets contingency`() {
        loadDoubles(inty, doubles: [2, 3.4, 5.67], contingent: [1])
        #expect(stackString(inty, .double) == "[ 2.0 3.4 5.67 ]")

        #expect(probeItemOnStack(inty,.double,index:0)!.isContingent == false)
        #expect(probeItemOnStack(inty,.double,index:1)!.isContingent == true)
    }

    // MARK: intyInt setup tests

    @Test func `intyInt3 setup`() {
        intyInt3(inty)
        #expect(stackString(inty, .int) == "[ 0 2 -2 ]")
    }

    @Test func `intyInt4 setup`() {
        intyInt4(inty)
        #expect(stackString(inty, .int) == "[ 0 1111111 66 -33 ]")
    }

    @Test func `intyInt5 setup`() {
        intyInt5(inty)
        #expect(stackString(inty, .int) == "[ -3 2 17 0 2 ]")
    }

}
