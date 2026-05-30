//
//  Router tests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
@testable import PropellerWithStructs
import Testing

struct Router_tests {
    
    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }

    
    let inty = Interpreter()
    
    @Test
    @MainActor
    func routingWorks() {
        let r = Router(PushStack.int, Item(17) )
        inty.pushItem(r)
        #expect(inty.stacks[.int]!.count == 1)
        #expect(inty.stacks[.int]!.first!.value as! Int == 17)
        #expect(stackString(inty, .int) == "[ 17 ]")
    }
}
