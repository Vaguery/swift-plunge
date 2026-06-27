//
//  Behavior Tests Helper.swift
//  PropellerWithStructsUnitTests
//
//  Created by Barbara Tozier on 6/24/26.
//

import DequeModule
@testable import PropellerWithStructs
import Testing

//
// MARK: General helper functions
//

@MainActor 
    public func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }

@MainActor
    public func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> (any Item) {
        return interpreter.stacks[stack]!.first!
    }

@MainActor
public func probeItemOnStack(_ interpreter: Interpreter,
                             _ stack: PushStack,
                             index: Int ) -> (any Item)? {
    return interpreter.stacks[stack]![index]
}

@MainActor
    public func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }

@MainActor
    public func doThisMany(times: Int, _ instruction:PushInstruction, to interpreter: Interpreter) {
        for _ in 0..<times {
            Interpreter.language[instruction]!.act(on: interpreter)
        }
    }

// TODO: make a selectable number of `step()` ???

//
// Common stacks setups
//

// MARK: Bool stack setup

@MainActor
    public func loadBools(_ inty: Interpreter,
                          bools: [Bool],
                          contingent: [Int] = [] ) {
        var newStack = bools.map({BoolItem($0)})
        for idx in contingent {
            newStack[idx].isContingent = true
        }
        inty.stacks[.bool]!.prepend(contentsOf: newStack)
    }


// MARK: Char stack setup

@MainActor
    public func loadChars(_ inty: Interpreter,
                            chars: [String],
                            contingent: [Int] = [] ) {
        var newStack = chars.map({ $0.first! }).map({ $0 as Character }).map({ CharItem($0) })
        for idx in contingent {
            newStack[idx].isContingent = true
        }
        inty.stacks[.char]!.prepend(contentsOf: newStack)
    }


// MARK: Code stack setups (OLD STYLE)

@MainActor
    // 4 Mixed CodeItems
    public func intyCode4(_ inty: Interpreter) {
        inty.stacks[.code]!.prepend(
            contentsOf: [CodeItem([IntItem(4)]),
                         CodeItem([DoubleItem(8.8)]),
                         CodeItem([CharItem(Character("-"))], isContingent: true),
                         CodeItem([]),
                        ]
        )
}

@MainActor
    // 6 CodeItems of (int, bool)
    public func intyCode6IB(_ inty: Interpreter) {
        inty.stacks[.code]!.prepend(
            contentsOf: [CodeItem([IntItem(4),BoolItem(false)], isContingent: true),
                         CodeItem([IntItem(4),BoolItem(false)], isContingent: true),
                         CodeItem([IntItem(4),BoolItem(false)], isContingent: true),
                         CodeItem([IntItem(4),BoolItem(false)], isContingent: false),
                         CodeItem([IntItem(5),BoolItem(false)], isContingent: false),
                         CodeItem([IntItem(4),BoolItem(true)], isContingent: false),
                        ]
        )
}

// MARK: Double stack setup

@MainActor
    public func loadDoubles(_ inty: Interpreter,
                            doubles: [Double],
                            contingent: [Int] = [] ) {
        var newStack = doubles.map({DoubleItem($0)})
        for idx in contingent {
            newStack[idx].isContingent = true
        }
        inty.stacks[.double]!.prepend(contentsOf: newStack)
    }

// MARK: Integer stack setup

@MainActor
    public func loadInts(_ inty: Interpreter,
                            ints: [Int],
                            contingent: [Int] = [] ) {
        var newStack = ints.map({IntItem($0)})
        for idx in contingent {
            newStack[idx].isContingent = true
        }
        inty.stacks[.int]!.prepend(contentsOf: newStack)
    }




