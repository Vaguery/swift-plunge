//
//  Stacks tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 5/30/26.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct StacksTests {

    @Test func `stacks should sort with exec first`() {
        #expect (PushStack.allStacks[0] == .exec)
        #expect (PushStack.exec < PushStack.bool)
        #expect (PushStack.allStacks[1] == .bool)
    }

}
