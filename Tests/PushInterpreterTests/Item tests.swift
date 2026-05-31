//
//  Item tests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 5/30/26.
//

@testable import PropellerWithStructs
import Testing

struct Item_tests {
    @Test
    func errorTest() {
        let e = Error("a bad thing")
        #expect(e.value == "a bad thing")
    }
    
    @Test
    func equality() {
        #expect(Item<Int>(1) == Item<Int>(1))
        #expect(Item<Int>(1) != Item<Int>(2))
    }
    
    @Test func anItemCanBeChanged() {
        var foo = Item<String>("foo")
        #expect(foo.call.isEmpty)
        #expect( type(of: foo.call) == Array<any Pushable>.self)
        let newHistory = [Item<PI>(.input2)]
        foo.call = newHistory
    }
}


struct Code_tests {
    @MainActor
    @Test
    func codeCallsCreateItems() {
        let stuff:[any Pushable] = [Item<Int>(34), Item<Double>(1.2)]
        let codey1 = Code( stuff )
        let codey2 = Code( stuff )
    }
}
