//
//  Behavior Tests Helper.swift
//  PropellerWithStructsUnitTests
//
//  Created by Barbara Tozier on 6/24/26.
//

import DequeModule
@testable import PushInterpreter
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
// TODO: contants stacks setup?
// TODO: inputs stacks setup?
// TODO: exec stacks setup?

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

// MARK: Code stack setup


/// `loadCode()` is a helper for testing, and 100% should not
/// be used for any other purpose. Worse, it's _quirky_.
///
/// The `code: [Any]` argument is parsed by `Plushy.plushy2push()`, so
/// it inherits the quirks of that. Any array item encountered in this array will be converted to a
/// vector Item if possible first, including empty ones. Any array that contains multiple
/// types will be comverted to a `CodeItem` recursively.
///
///  The function returns an array of `CodeItems` that contain what's found in the array,
///  _except_ for CodeItems parsed. Those are returned "flat" as themselves.
///
///  Note also that an empty array is parsed as a `VecBoolItem`. To insert an empty
///  `CodeItem` use the explicit `CodeItem([])`
///
@MainActor
    public func loadCode(_ inty: Interpreter,
                            code: [Any],
                            contingent: [Int] = [] ) {

        func codeLoaderParser(_ item: Any) -> CodeItem {
            let parsed = Plushy.plushy2push( [item] )
            var result = CodeItem([])
            if parsed.count > 0 {
                if parsed[0] is CodeItem {
                    result = parsed[0] as! CodeItem
                } else {
                    result = CodeItem(parsed)
                }
            }
            return result
        }

        var newStack = code.map({ codeLoaderParser($0) })
        for idx in contingent {
            newStack[idx].isContingent = true
        }
        inty.stacks[.code]!.prepend(contentsOf: newStack)
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

// MARK: String stack setup

@MainActor
    public func loadStrings(_ inty: Interpreter,
                            strings: [String],
                            contingent: [Int] = [] ) {
        var newStack = strings.map({StringItem($0)})
        for idx in contingent {
            newStack[idx].isContingent = true
        }
        inty.stacks[.string]!.prepend(contentsOf: newStack)
    }



