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

    // MARK: loadBools tests

    @Test func `loadBools setup`() {
        loadBools(inty, bools: [])
        #expect(stackString(inty, .bool) == "[ ]")
    }

    @Test func `loadBools loads bools`() {
        loadBools(inty, bools: [false, true])
        #expect(stackString(inty, .bool) == "[ false true ]")
    }

    @Test func `loadBools sets contingency`() {
        loadBools(inty, bools: [false, true], contingent: [1])
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(probeItemOnStack(inty,.bool,index:0)!.isContingent == false)
        #expect(probeItemOnStack(inty,.bool,index:1)!.isContingent == true)
    }

    // MARK: loadChars tests

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

    // MARK: intyCode setup tests [OLD STYLE]

    @Test func `intyCode4 setup`() {
        intyCode4(inty)
        #expect(stackString(inty, .code) == "[ ( 4 ) ( 8.8 ) ( '-' ) ( ) ]")
    }

    @Test func `intyCode6IB setup`() {
        intyCode6IB(inty)
        #expect(stackString(inty, .code) == "[ ( 4 false ) ( 4 false ) ( 4 false ) ( 4 false ) ( 5 false ) ( 4 true ) ]")
    }

    // MARK: loadDoubles tests

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

    // MARK: loadInts tests

    @Test func `loadInts setup`() {
        loadInts(inty, ints: [])
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `loadInts loads ints`() {
        loadInts(inty, ints: [2, 3, 5])
        #expect(stackString(inty, .int) == "[ 2 3 5 ]")
    }

    @Test func `loadInts sets contingency`() {
        loadInts(inty, ints: [2, 3, 5], contingent: [1])
        #expect(stackString(inty, .int) == "[ 2 3 5 ]")
        #expect(probeItemOnStack(inty,.int,index:0)!.isContingent == false)
        #expect(probeItemOnStack(inty,.int,index:1)!.isContingent == true)
    }

}
