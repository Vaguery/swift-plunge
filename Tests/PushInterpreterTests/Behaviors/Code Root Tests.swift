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
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3), IntItem(4)]))
        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.codeCutRootAtGap, to: inty)
        #expect(stackString(inty, .code) == "[ ( 3 4 ) ( 1 2 ) ]", "suffix on top, prefix deeper")
    }

    @Test func `cutRootAtGap then codeAppend is the identity`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3), IntItem(4)]))
        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.codeCutRootAtGap, to: inty)
        doThis(.codeAppend, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 2 3 4 ) ]")
    }

    @Test func `cutRootAtGap reaches both extremes and wraps modulo count+1`() {
        // ( 1 2 ) has 3 gaps: 0 (before), 1 (between), 2 (after).
        // gap 0 → empty prefix, whole suffix.
        let g0 = Interpreter.recordingProvenance()
        g0.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2)]))
        g0.stacks[.int]!.prepend(IntItem(0))
        doThis(.codeCutRootAtGap, to: g0)
        #expect(stackString(g0, .code) == "[ ( 1 2 ) ( ) ]", "empty prefix (deeper), whole suffix on top")

        // gap 2 (== count) → whole prefix, empty suffix — the after-the-final gap.
        let g2 = Interpreter.recordingProvenance()
        g2.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2)]))
        g2.stacks[.int]!.prepend(IntItem(2))
        doThis(.codeCutRootAtGap, to: g2)
        #expect(stackString(g2, .code) == "[ ( ) ( 1 2 ) ]", "whole prefix (deeper), empty suffix on top")

        // wraps modulo count+1: gap 3 on a 3-item root (4 gaps) == gap 3.
        let w = Interpreter.recordingProvenance()
        w.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3)]))
        w.stacks[.int]!.prepend(IntItem(3))   // 3 % 4 == 3 → after everything
        doThis(.codeCutRootAtGap, to: w)
        #expect(stackString(w, .code) == "[ ( ) ( 1 2 3 ) ]")

        // empty block: one gap only, both pieces empty.
        let e = Interpreter.recordingProvenance()
        e.stacks[.code]!.prepend(CodeItem([]))
        e.stacks[.int]!.prepend(IntItem(3))
        doThis(.codeCutRootAtGap, to: e)
        #expect(stackString(e, .code) == "[ ( ) ( ) ]")
    }

    @Test func `both cut pieces reproduce from their crux`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(CodeItem([IntItem(1), IntItem(2), IntItem(3)]))
        inty.stacks[.int]!.prepend(IntItem(1))
        doThis(.codeCutRootAtGap, to: inty)
        let suffix = inty.stacks[.code]![0]   // ( 2 3 ), on top
        let prefix = inty.stacks[.code]![1]   // ( 1 ), deeper, records the discard pop

        for piece in [prefix, suffix] {
            let redo = Interpreter.recordingProvenance()
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
        let inty = Interpreter.recordingProvenance()
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
        let inty = Interpreter.recordingProvenance()
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
