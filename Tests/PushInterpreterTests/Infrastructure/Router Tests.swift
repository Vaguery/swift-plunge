//
//  Router tests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
@testable import PropellerWithStructs
import Testing

@Suite @MainActor
struct Router_tests {

    let inty = Interpreter()
    
    @Test func routingWorks() {
        let r = Router(PushStack.int, IntItem(17) )
        inty.pushItem(r)
        #expect(inty.stacks[.int]!.count == 1)
        #expect(stackString(inty, .int) == "[ 17 ]")
    }
}
