//
//  Code Stage1 Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/18/26.
//
//  codeCollect (wrap two) and codeIf (execIf with a .code source).
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeStage1Tests {

    @Test func `codeCollect wraps two blocks, nesting preserved`() {
        let inty = Interpreter()
        // push y=(c d) then x=(a b) so x is on top (a[0]=x, a[1]=y)
        inty.stacks[.code]!.prepend(contentsOf:
            [CodeItem([StringItem("a"), StringItem("b")]),
             CodeItem([StringItem("c"), StringItem("d")])] as [any Item])
        doThis(.codeCollect, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( \"c\" \"d\" ) ( \"a\" \"b\" ) ) ]")
        // distinct from append, which would flatten to ( c d a b )
    }

    @Test func `codeCollect on empty blocks`() {
        let inty = Interpreter()
        inty.stacks[.code]!.prepend(contentsOf: [CodeItem([]), CodeItem([])] as [any Item])
        doThis(.codeCollect, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( ) ( ) ) ]")
    }

    @Test func `codeCollect reproduces from its crux`() {
        let inty = Interpreter()
        inty.stacks[.code]!.prepend(contentsOf: [CodeItem([IntItem(1)]), CodeItem([IntItem(2)])] as [any Item])
        doThis(.codeCollect, to: inty)
        let result = topItem(inty, .code)
        let redo = Interpreter()
        redo.load(program: result.crux())
        redo.run()
        #expect(stackString(redo, .code) == stackString(inty, .code))
    }

    @Test func `codeIf runs the chosen block, true takes then`() {
        // Loaded as a program: the two blocks land on .code, the bool on .bool,
        // then codeIf reads them. `then` is written first, so it is a[2].
        let prog = Interpreter()
        prog.load(program: [
            CodeItem([IntItem(1)]),   // goes to .code
            CodeItem([IntItem(2)]),   // goes to .code
            BoolItem(true),           // goes to .bool
            InstructionItem(.codeIf),
        ])
        prog.run()
        #expect(stackString(prog, .int) == "[ 1 ]", "true → then block ran")

        let f = Interpreter()
        f.load(program: [
            CodeItem([IntItem(1)]),
            CodeItem([IntItem(2)]),
            BoolItem(false),
            InstructionItem(.codeIf),
        ])
        f.run()
        #expect(stackString(f, .int) == "[ 2 ]", "false → else block ran")
    }
}
