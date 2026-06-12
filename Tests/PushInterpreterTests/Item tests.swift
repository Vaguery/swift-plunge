//
//  Item tests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 5/30/26.
//

@testable import PropellerWithStructs
import Testing

@Suite @MainActor
struct Item_tests {
    
    
    @Test func errorTest() {
        let e = ErrorItem("a bad thing")
        #expect(e.value == "a bad thing")
    }
    
    @Test func equality() {
        #expect(IntItem(1) == IntItem(1))
        #expect(IntItem(1) != IntItem(2))
    }
    
    @Test func anItemCanBeChanged() {
        var foo = StringItem("foo")
        #expect(foo.call.isEmpty)
        #expect( type(of: foo.call) == Array<any Item>.self)
        let newHistory = [InstructionItem(.input2)]
        foo.call = newHistory
    }
}

@MainActor
struct Code_tests {
    
    @Test
    func codeCallsCreateItems() {
        let stuff:[any Item] = [IntItem(34), DoubleItem(1.2)]
        let codey1 = CodeItem( stuff )
        let codey2 = CodeItem( stuff )
        
        #expect(codey1.value.count == 2)
        #expect(codey2.value.count == 2)
        #expect(codey1.value == codey2.value)
        #expect(codey1 == codey2)
    }
    
    
}
