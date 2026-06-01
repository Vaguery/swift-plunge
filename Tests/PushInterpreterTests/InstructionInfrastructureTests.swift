//
//  InstructionInfrastructureTests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/1/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

struct InstructionInfrastructureTests {
    @Test func contingencyWorks() {
        let arg1 = IntItem(4, isContingent: true)
        let arg2 = IntItem(2, isContingent: false)
        #expect(Instruction.netContingency(of: arg1, arg2) == true)
    }
}
