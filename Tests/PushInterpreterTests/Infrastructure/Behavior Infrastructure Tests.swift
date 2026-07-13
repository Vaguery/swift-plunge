//
//  Behavior Infrastructure Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/1/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct BehaviorInfrastructureTests {
    
    @Test func `contingency works`() {
        let arg1 = IntItem(4, isContingent: true)
        let arg2 = IntItem(2, isContingent: false)
        #expect(Behavior.netContingency(of: arg1, arg2) == true)
    }
    
    @Test func `each instruction in language has matching name in behavior`() {
        for (instruction, behavior) in Interpreter.language {
            #expect(instruction.rawValue == behavior.name.rawValue)
        }
    }
}
