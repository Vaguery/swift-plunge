//
//  PropellerWithStructsUnitTests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 5/30/26.
//

@testable import PropellerWithStructs
import Testing

struct PropellerWithStructsUnitTests {

    @Test func example() {
        #expect (PushStack.allStacks[0] == .exec)
        #expect (PushStack.allStacks[1] == .bool)
    }

}
