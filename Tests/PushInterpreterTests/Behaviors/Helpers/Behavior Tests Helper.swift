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
    public func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> any Item {
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

// MARK: Bool stack setups

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

@MainActor
    //8 boolean values pushed to [.bool]
    public func intyBool8(_ inty: Interpreter) {
        inty.stacks[.bool]!.prepend(contentsOf: [
            BoolItem(true), BoolItem(true),
            BoolItem(true), BoolItem(false),
            BoolItem(false), BoolItem(true),
            BoolItem(false), BoolItem(false, isContingent: true),
    ])
}

@MainActor
    // boolean empty
    public func intyBoolE(_ inty: Interpreter) { }

@MainActor
    // boolean false
    public func intyBoolF(_ inty: Interpreter) {
        inty.stacks[.bool]!.prepend(BoolItem(false, isContingent: true))
}

@MainActor
    // boolean true
    public func intyBoolT(_ inty: Interpreter) {
        inty.stacks[.bool]!.prepend(BoolItem(true, isContingent: true))
}

// MARK: Char stack setups

@MainActor
    // 6 characters
    public func intyChar6(_ inty: Interpreter) {
            inty.stacks[.char]!.prepend(contentsOf: [
                CharItem(Character("g")),
                CharItem(Character("d"), isContingent: true),
                CharItem(Character("b")),
                CharItem(Character("x")),
                CharItem(Character("-")),
                CharItem(Character("-")),
            ])
}

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


// MARK: Code stack setups

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

// MARK: Double stack setups

@MainActor
    // 3 doubles
    public func intyDouble3(_ inty: Interpreter) {
        inty.stacks[.double]!.prepend(contentsOf: [DoubleItem(0.0), DoubleItem(1.1), DoubleItem(-1.1, isContingent: true)])
}

@MainActor
    // 4 doubles
    public func intyDouble4(_ inty: Interpreter) {
        inty.stacks[.double]!.prepend(contentsOf: [DoubleItem(0), DoubleItem(1111111.11, isContingent: true), DoubleItem(66.6), DoubleItem(-33)])
    }

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

// MARK: Int stack setups

@MainActor
    // 3 integers
    public func intyInt3(_ inty: Interpreter) {
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(0), IntItem(2), IntItem(-2, isContingent: true)])
}

@MainActor
    // 4 integers
    public func intyInt4(_ inty: Interpreter) {
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(0), IntItem(1111111, isContingent: true), IntItem(66), IntItem(-33)])
}

@MainActor
    // 5 integers
    public func intyInt5(_ inty: Interpreter) {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),IntItem(2),IntItem(17),IntItem(0),IntItem(2),])

}


