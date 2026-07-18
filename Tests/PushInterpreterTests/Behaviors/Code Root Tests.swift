//
//  Code Root Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/18/26.
//
//  codeCutRootAtGap (root-array split, vecXCut analog) and codeIterateRoot
//  (iterate root elements with a mouse).
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeRootTests {

    @Test func `cutRootAtGap splits the root array, prefix deeper`() {
        let inty = Interpreter()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3), IntItem(4)]))
        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.codeCutRootAtGap, to: inty)
        #expect(stackString(inty, .code) == "[ ( 3 4 ) ( 1 2 ) ]", "suffix on top, prefix deeper")
    }

    @Test func `cutRootAtGap then codeAppend is the identity`() {
        let inty = Interpreter()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3), IntItem(4)]))
        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.codeCutRootAtGap, to: inty)
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 2 3 4 ) ]")
    }

    @Test func `cutRootAtGap index wraps; empty block gives two empties`() {
        let a = Interpreter()
        a.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3)]))
        a.stacks[.int]!.prepend(IntItem(4))   // 4 % 3 == 1
        doThis(.codeCutRootAtGap, to: a)
        #expect(stackString(a, .code) == "[ ( 2 3 ) ( 1 ) ]")

        let e = Interpreter()
        e.stacks[.code]!.prepend(CodeItem([]))
        e.stacks[.int]!.prepend(IntItem(3))
        doThis(.codeCutRootAtGap, to: e)
        #expect(stackString(e, .code) == "[ ( ) ( ) ]")
    }

    @Test func `both cut pieces reproduce from their crux`() {
        let inty = Interpreter()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3)]))
        inty.stacks[.int]!.prepend(IntItem(1))
        doThis(.codeCutRootAtGap, to: inty)
        let suffix = inty.stacks[.code]![0]   // ( 2 3 ), on top
        let prefix = inty.stacks[.code]![1]   // ( 1 ), deeper, records the discard pop

        for piece in [prefix, suffix] {
            let redo = Interpreter()
            redo.load(program: piece.crux())
            redo.run()
            #expect(redo.stacks[.code]!.first!.pretty() == piece.pretty())
        }
    }

    @Test func `iterateRoot runs the mouse once per root element`() {
        // ( "a" "b" "c" ) with a mouse that pushes each char? Use a code to iterate
        // whose elements are ints, and a mouse that does nothing observable but the
        // element lands on .code as data each pass. Simplest: verify the element
        // count by iterating and letting each root element route to .code.
        let inty = Interpreter()
        // program: ( 1 2 3 )  ( )  .codeIterateRoot   — mouse is empty, so each
        // pass just emits the element (an int) to .int (its natural stack).
        inty.load(program: [
            CodeItem([IntItem(1), IntItem(2), IntItem(3)]),   // the code to iterate (deeper)
            CodeItem([]),                                     // mouse (empty), on top
            InstructionItem(.codeIterateRoot),
        ])
        inty.run()
        // each root element (1, 2, 3) is an int, emitted to .int front-to-back
        #expect(stackString(inty, .int) == "[ 3 2 1 ]")
    }

    @Test func `iterateRoot on an empty block does nothing`() {
        let inty = Interpreter()
        inty.load(program: [
            CodeItem([]),
            CodeItem([BoolItem(true)]),
            InstructionItem(.codeIterateRoot),
        ])
        inty.run()
        #expect(inty.stacks[.iterator]!.isEmpty)
        #expect(stackString(inty, .bool) == "[ ]")
    }
}
