//
//  Router Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 5/30/26.
//

import DequeModule
@testable import PushInterpreter
import Testing

@Suite @MainActor
struct RouterTests {

    let inty = Interpreter()

    @Test func `routing works`() {
        let r = Router(PushStack.int, IntItem(17) )
        inty.pushItem(r)
        #expect(inty.stacks[.int]!.count == 1)
        #expect(stackString(inty, .int) == "[ 17 ]")
    }
}
