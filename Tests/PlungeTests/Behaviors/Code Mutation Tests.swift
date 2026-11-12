//
//  Code Mutation Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/18/26.
//
//  Flatten and point-mutation transforms (they consume): codeFlatten,
//  codeFlattenOnce, codeFlattenNth, codeRemoveNth, codeReplace,
//  codeReplaceFirst.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct CodeMutationTests {

    /// ( (1 2) 3 ): points 0:root 1:(1 2) 2:1 3:2 4:3
    let tree = CodeItem([CodeItem([IntItem(1), IntItem(2)]), IntItem(3)])

    func onTree(_ instr: PushInstruction, _ code: CodeItem, int: Int? = nil) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(code)
        if let int { inty.stacks[.int]!.prepend(IntItem(int)) }
        doThis(instr, to: inty)
        return inty
    }

    @Test func flatten() {
        let inty = onTree(.codeFlatten, tree)
        #expect(stackString(inty, .code) == "[ ( 1 2 3 ) ]")
        // empty blocks vanish
        let e = onTree(.codeFlatten, CodeItem([IntItem(1), CodeItem([]), IntItem(2)]))
        #expect(stackString(e, .code) == "[ ( 1 2 ) ]")
    }

    @Test func flattenOnce() {
        let deep = CodeItem([IntItem(1),
                             CodeItem([IntItem(2), CodeItem([IntItem(3), IntItem(4)])]),
                             IntItem(5)])
        let inty = onTree(.codeFlattenOnce, deep)
        #expect(stackString(inty, .code) == "[ ( 1 2 ( 3 4 ) 5 ) ]", "one level only")
    }

    @Test func flattenPoint() {
        // flatten point 1, the (1 2) subtree — already flat, unchanged shape
        let a = onTree(.codeFlattenNth, tree, int: 1)
        #expect(stackString(a, .code) == "[ ( ( 1 2 ) 3 ) ]")

        // a nested subtree: ( (1 (2 3)) 4 ), flatten point 1 → ( (1 2 3) 4 )
        let nested = CodeItem([CodeItem([IntItem(1), CodeItem([IntItem(2), IntItem(3)])]), IntItem(4)])
        let b = onTree(.codeFlattenNth, nested, int: 1)
        #expect(stackString(b, .code) == "[ ( ( 1 2 3 ) 4 ) ]")

        // a leaf point is unchanged
        let c = onTree(.codeFlattenNth, tree, int: 2)
        #expect(stackString(c, .code) == "[ ( ( 1 2 ) 3 ) ]")

        // point 0 flattens the whole thing
        let d = onTree(.codeFlattenNth, nested, int: 0)
        #expect(stackString(d, .code) == "[ ( 1 2 3 4 ) ]")
    }

    @Test func removePoint() {
        #expect(stackString(onTree(.codeRemoveNth, tree, int: 2), .code) == "[ ( ( 2 ) 3 ) ]")
        #expect(stackString(onTree(.codeRemoveNth, tree, int: 1), .code) == "[ ( 3 ) ]", "whole subtree")
        #expect(stackString(onTree(.codeRemoveNth, tree, int: 0), .code) == "[ ( ) ]", "root → empty")
    }

    /// subject deepest, needle, replacement on top.
    func replace(_ instr: PushInstruction, _ subject: CodeItem, _ needle: CodeItem, _ repl: CodeItem) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(contentsOf: [repl, needle, subject] as [any Item])
        doThis(instr, to: inty)
        return inty
    }

    @Test func `a singleton needle denotes a bare leaf (singleton-unwrap)`() {
        // needle ( 1 ) is a one-element block, so it DENOTES the leaf 1; the
        // replacement ( 9 ) denotes the leaf 9. Every leaf-1 point in
        // ( 1 ( 1 2 ) 1 ) becomes 9.
        let subj = CodeItem([IntItem(1), CodeItem([IntItem(1), IntItem(2)]), IntItem(1)])
        let inty = replace(.codeReplace, subj, CodeItem([IntItem(1)]), CodeItem([IntItem(9)]))
        #expect(stackString(inty, .code) == "[ ( 9 ( 9 2 ) 9 ) ]")
    }

    @Test func `a subtree needle takes two elements or a double wrap`() {
        // needle ( 1 2 ) has two elements, so it denotes the subtree ( 1 2 );
        // replacement ( 9 ) denotes the leaf 9. Each ( 1 2 ) subtree → 9.
        let subj = CodeItem([CodeItem([IntItem(1), IntItem(2)]), CodeItem([IntItem(1), IntItem(2)])])
        let needle = CodeItem([IntItem(1), IntItem(2)])
        let all = replace(.codeReplace, subj, needle, CodeItem([IntItem(9)]))
        #expect(stackString(all, .code) == "[ ( 9 9 ) ]", "subtrees replaced by the leaf 9")

        let first = replace(.codeReplaceFirst, subj, needle, CodeItem([IntItem(9)]))
        #expect(stackString(first, .code) == "[ ( 9 ( 1 2 ) ) ]", "only the first")

        // To replace a subtree WITH a singleton block, double-wrap the
        // replacement: (( 9 )) denotes the subtree ( 9 ).
        let asBlock = replace(.codeReplace, subj, needle, CodeItem([CodeItem([IntItem(9)])]))
        #expect(stackString(asBlock, .code) == "[ ( ( 9 ) ( 9 ) ) ]")
    }

    @Test func `mutation cruxes reproduce`() {
        for (instr, code, i) in [(PushInstruction.codeFlatten, tree, nil),
                                 (.codeRemoveNth, tree, 2),
                                 (.codeFlattenNth, tree, 1)] as [(PushInstruction, CodeItem, Int?)] {
            let inty = onTree(instr, code, int: i)
            let result = topItem(inty, .code)
            let redo = Interpreter.recordingProvenance()
            redo.load(program: result.crux())
            redo.run()
            #expect(stackString(redo, .code) == stackString(inty, .code), "\(instr) crux")
        }
    }
}
