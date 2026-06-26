//
//  PropellerWithStructsUnitTests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 5/30/26.
//

@testable import PropellerWithStructs
import Testing

@Suite @MainActor
struct StacksTests {

    @Test func StacksShouldSortWithExecFirst() {
        #expect (PushStack.allStacks[0] == .exec)
        #expect (PushStack.exec < PushStack.bool)
        #expect (PushStack.allStacks[1] == .bool)
    }

}
