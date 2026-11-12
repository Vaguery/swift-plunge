//
//  Stacks Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 5/30/26.
//

@testable import Plunge
import Testing

@Suite
struct StacksTests {

    @Test func `stacks should sort with exec first`() {
        #expect (PushStack.allStacks[0] == .exec)
        #expect (PushStack.exec < PushStack.bool)
        // Then alphabetical: `.binding` (added 2026-11-09) comes before `.bool`.
        #expect (PushStack.allStacks[1] == .binding)
        #expect (PushStack.allStacks[2] == .bool)
        #expect (Array(PushStack.allStacks.dropFirst()) == PushStack.allStacks.dropFirst().sorted())
    }

}
