//
//  Behavior Infrastructure Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 6/1/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct BehaviorInfrastructureTests {
    
    @Test func `each instruction in language has matching name in behavior`() {
        for (instruction, behavior) in Interpreter.language {
            #expect(instruction.rawValue == behavior.name.rawValue)
        }
    }
}
