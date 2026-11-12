//
//  Code Stage1 Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/18/26.
//
//  codePair (wrap two) and execIf (which codeIf duplicated until 2026-11-10).
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct CodeStage1Tests {

    @Test func `codePair wraps two blocks, nesting preserved`() {
        let inty = Interpreter.recordingProvenance()
        // push y=(c d) then x=(a b) so x is on top (a[0]=x, a[1]=y)
        inty.stacks[.code]!.prepend(contentsOf:
            [CodeItem([StringItem("a"), StringItem("b")]),
             CodeItem([StringItem("c"), StringItem("d")])] as [any Item])
        doThis(.codePair, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( \"c\" \"d\" ) ( \"a\" \"b\" ) ) ]")
        // distinct from append, which would flatten to ( c d a b )
    }

    @Test func `codePair denotes singleton arguments`() {
        // ( 1 ) ( 2 3 ) .codePair → ( 1 ( 2 3 ) ): the singleton ( 1 ) contributes
        // the bare leaf 1, the two-element ( 2 3 ) stays a block. Loaded as a
        // program so the reading order matches the plan's example.
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            CodeItem([IntItem(1)]),               // ( 1 ), deeper
            CodeItem([IntItem(2), IntItem(3)]),   // ( 2 3 ), on top
            InstructionItem(.codePair)
        ])
        inty.run()
        #expect(stackString(inty, .code) == "[ ( 1 ( 2 3 ) ) ]")
    }

    @Test func `codePair on empty blocks`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(contentsOf: [CodeItem([]), CodeItem([])] as [any Item])
        doThis(.codePair, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( ) ( ) ) ]")
    }

    @Test func `codePair reproduces from its crux`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(contentsOf: [CodeItem([IntItem(1)]), CodeItem([IntItem(2)])] as [any Item])
        doThis(.codePair, to: inty)
        let result = topItem(inty, .code)
        let redo = Interpreter.recordingProvenance()
        redo.load(program: result.crux())
        redo.run()
        #expect(stackString(redo, .code) == stackString(inty, .code))
    }

    @Test func `execIf runs the chosen block, true takes then`() {
        // Loaded as a program: the two blocks land on .code, the bool on .bool,
        // then execIf reads them. `then` is written first, so it is a[2].
        let prog = Interpreter.recordingProvenance()
        prog.load(program: [
            CodeItem([IntItem(1)]),   // goes to .code
            CodeItem([IntItem(2)]),   // goes to .code
            BoolItem(true),           // goes to .bool
            InstructionItem(.execIf)
        ])
        prog.run()
        #expect(stackString(prog, .int) == "[ 1 ]", "true → then block ran")

        let f = Interpreter.recordingProvenance()
        f.load(program: [
            CodeItem([IntItem(1)]),
            CodeItem([IntItem(2)]),
            BoolItem(false),
            InstructionItem(.execIf)
        ])
        f.run()
        #expect(stackString(f, .int) == "[ 2 ]", "false → else block ran")
    }

    /// One block and a bool: true runs it; false hands it back to
    /// `.code` untouched, where `execWhen` would discard it.
    @Test func `codeDoIf runs the block or hands it back`() {
        func run(_ condition: Bool) -> Interpreter {
            let inty = Interpreter.recordingProvenance()
            inty.load(program: [CodeItem([IntItem(7), IntItem(8)]), BoolItem(condition), InstructionItem(.codeDoIf)])
            inty.run()
            return inty
        }
        let yes = run(true)
        #expect(stackString(yes, .int) == "[ 8 7 ]")
        #expect(stackString(yes, .code) == "[ ]")

        let no = run(false)
        #expect(stackString(no, .int) == "[ ]")
        #expect(stackString(no, .code) == "[ ( 7 8 ) ]")
        #expect(stackString(no, .bool) == "[ ]", "the bool is consumed either way")
    }
}
