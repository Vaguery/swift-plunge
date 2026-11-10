//
//  Behavior Tests Helper.swift
//  PlungeTests
//
//  Created by Barbara Tozier on 6/24/26.
//

import DequeModule
@testable import Plunge
import Testing

//
// MARK: General helper functions
//

@MainActor
    public func stackString(_ interpreter: Interpreter, _ stack: PushStack) -> String {
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

/// The literal `call` a Behavior recorded on a result, rendered as readable Push
/// source: `( 'b' 'a' .charGTE )`. An empty record reads `( )`.
///
/// One level only, and deliberately so — this is the record the Behavior wrote,
/// not the recursive reconstruction. Use it to pin what a Behavior *says*;
/// `crux()` round-tripping (see the Crux Round-Trip acceptance tests) is what
/// checks that what it says is *true*. The two catch different things: a unit
/// test written by reading the code will happily transcribe a wrong instruction
/// name, which only re-running the reconstruction can expose.
@MainActor
public func callString(_ item: any Item) -> String {
    CodeItem(item.call).pretty()
}

/// Runs `instruction` on `interpreter`.
///
/// When `interpreter` records provenance, the same instruction also runs on an
/// off-recording twin of it (`offRecordingTwin()`), and the two must leave
/// identical values. That splits every mixed test in two without writing it
/// twice: its `callString`/`crux` assertions check what is recorded with
/// recording on, and this checks that turning recording off — the default, and
/// what a search runs — computes exactly the same thing.
@MainActor
    public func doThis(_ instruction: PushInstruction, to interpreter: Interpreter,
                       sourceLocation: SourceLocation = #_sourceLocation) {
        let twin = interpreter.config.recordsProvenance ? interpreter.offRecordingTwin() : nil
        Interpreter.language[instruction]!.act(on: interpreter)
        if let twin {
            Interpreter.language[instruction]!.act(on: twin)
            #expect(twin.valueSignature == interpreter.valueSignature,
                    ".\(instruction) computes differently with provenance recording off",
                    sourceLocation: sourceLocation)
        }
    }

@MainActor
    public func doThisMany(times: Int, _ instruction: PushInstruction, to interpreter: Interpreter,
                           sourceLocation: SourceLocation = #_sourceLocation) {
        for _ in 0..<times {
            doThis(instruction, to: interpreter, sourceLocation: sourceLocation)
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
                          bools: [Bool]) {
        let newStack = bools.map({BoolItem($0)})
        inty.stacks[.bool]!.prepend(contentsOf: newStack)
    }


// MARK: Char stack setup

@MainActor
    public func loadChars(_ inty: Interpreter,
                            chars: [String]) {
        let newStack = chars.map({ $0.first! }).map({ $0 as Character }).map({ CharItem($0) })
        inty.stacks[.char]!.prepend(contentsOf: newStack)
    }

// MARK: Code stack setup


/// `loadCode()` is a helper for testing, and 100% should not
/// be used for any other purpose. Worse, it's _quirky_.
///
/// The `code: [Any]` argument is parsed by `buildProgram()` (see ProgramBuilder),
/// so it inherits the quirks of that. Any array item encountered in this array will be converted to a
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
                            code: [Any]) {

        func codeLoaderParser(_ item: Any) -> CodeItem {
            let parsed = buildProgram( [item] )
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

        let newStack = code.map({ codeLoaderParser($0) })
        inty.stacks[.code]!.prepend(contentsOf: newStack)
    }

// MARK: Double stack setup

@MainActor
    public func loadDoubles(_ inty: Interpreter,
                            doubles: [Double]) {
        let newStack = doubles.map({DoubleItem($0)})
        inty.stacks[.double]!.prepend(contentsOf: newStack)
    }

// MARK: Integer stack setup

@MainActor
    public func loadInts(_ inty: Interpreter,
                            ints: [Int]) {
        let newStack = ints.map({IntItem($0)})
        inty.stacks[.int]!.prepend(contentsOf: newStack)
    }

// MARK: String stack setup

@MainActor
    public func loadStrings(_ inty: Interpreter,
                            strings: [String]) {
        let newStack = strings.map({StringItem($0)})
        inty.stacks[.string]!.prepend(contentsOf: newStack)
    }
