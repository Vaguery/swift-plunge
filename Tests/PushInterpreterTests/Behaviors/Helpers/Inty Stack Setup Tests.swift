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

    // MARK: loadStrings tests

    @Test func `loadStrings setup`() {
        loadStrings(inty, strings: [])
        #expect(stackString(inty, .string) == "[ ]")
    }

    @Test func `loadStrings loads ints`() {
        loadStrings(inty, strings: ["2", "purple", "(ツ)"])
        #expect(stackString(inty, .string) == "[ \"2\" \"purple\" \"(ツ)\" ]")
    }

    @Test func `loadStrings sets contingency`() {
        loadStrings(inty, strings: ["2", "purple", "(ツ)"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"2\" \"purple\" \"(ツ)\" ]")
        #expect(probeItemOnStack(inty,.string,index:0)!.isContingent == false)
        #expect(probeItemOnStack(inty,.string,index:1)!.isContingent == true)
    }
    // MARK: loadCode tests

    @Test func `loadCode setup`() {
        loadCode(inty, code: [])
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `loadCode loads code items`() {
        loadCode(inty, code: [1, 2.2, false, CodeItem([IntItem(2)]) ])
        #expect(stackString(inty, .code) == "[ ( 1 ) ( 2.2 ) ( false ) ( 2 ) ]")
        #expect(probeItemOnStack(inty, .code, index:0)! is CodeItem)
        let top = probeItemOnStack(inty, .code, index:0)! as! CodeItem
        #expect(top.value[0] is IntItem)
        #expect((top.value[0] as! IntItem).value == 1)
    }

    @Test func `loadCode sets contingency`() {
        loadCode(inty, code: [1, 2.2, "foo", ["a","b"]], contingent: [1])
        #expect(stackString(inty, .code) ==
                "[ ( 1 ) ( 2.2 ) ( \"foo\" ) ( [\"a\", \"b\"] ) ]")
        #expect(probeItemOnStack(inty, .code, index:0)!.isContingent == false)
        #expect(probeItemOnStack(inty, .code, index:1)!.isContingent == true)
    }

    @Test func `loadCode works on nested CodeItems`() {
        loadCode(inty, code: [ [ 1, false, [2, 3.4, [5.6, true] ] ] ] )
        #expect(stackString(inty, .code) ==
                "[ ( 1 false ( 2 3.4 ( 5.6 true ) ) ) ]")
    }

    @Test func `loadCode works on empty CodeItems, but you have to use the right syntax`() {
        loadCode(inty, code: [ [], CodeItem([]) ] )
        #expect(stackString(inty, .code) ==
                "[ ( [] ) ( ) ]")
        #expect(probeItemOnStack(inty, .code, index:0)! is CodeItem)
        let top = probeItemOnStack(inty, .code, index:0)! as! CodeItem
        #expect(top.value[0] is VecIntItem)

    }

}

