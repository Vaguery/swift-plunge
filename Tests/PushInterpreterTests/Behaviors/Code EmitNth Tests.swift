//
//  Code EmitNth Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/18/26.
//
//  The `.exec` cousins of codeNth: codeEmitNth{Point,Root} push a point as-is,
//  codeDoNth{Point,Root} push it unwrapped (run its contents). Both read the tree
//  and index non-destructively; they differ only on how a CodeItem-valued point is
//  handled, and are identical for a leaf.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeEmitNthTests {

    /// ( ( 7 8 ) 9 ): points 0:root 1:(7 8) 2:7 3:8 4:9.
    let tree = CodeItem([CodeItem([IntItem(7), IntItem(8)]), IntItem(9)])

    // MARK: - Emit (whole)

    @Test func `emitNthPoint pushes a subtree whole onto code`() {
        let inty = Interpreter()
        inty.load(program: [tree, IntItem(1), InstructionItem(.codeEmitNthPoint)])
        inty.run()
        // point 1 = ( 7 8 ) is a CodeItem, so it rests on .code whole, on top of
        // the (still-present, non-destructively read) original tree.
        #expect(stackString(inty, .code) == "[ ( 7 8 ) ( ( 7 8 ) 9 ) ]")
        #expect(stackString(inty, .int) == "[ 1 ]", "the index survives (non-destructive read)")
    }

    @Test func `emitNthPoint routes a leaf point to its own stack`() {
        let inty = Interpreter()
        inty.load(program: [tree, IntItem(2), InstructionItem(.codeEmitNthPoint)])
        inty.run()
        // point 2 = leaf 7 routes to .int, on top of the index 2.
        #expect(stackString(inty, .int) == "[ 7 2 ]")
        #expect(stackString(inty, .code) == "[ ( ( 7 8 ) 9 ) ]", "tree survives, nothing boxed")
    }

    // MARK: - Do (unwrapped)

    @Test func `doNthPoint runs a subtree's contents`() {
        let inty = Interpreter()
        inty.load(program: [tree, IntItem(1), InstructionItem(.codeDoNthPoint)])
        inty.run()
        // point 1 = ( 7 8 ) is unwrapped: 7 then 8 run onto .int, above index 1.
        #expect(stackString(inty, .int) == "[ 8 7 1 ]")
        #expect(stackString(inty, .code) == "[ ( ( 7 8 ) 9 ) ]")
    }

    @Test func `doNthPoint equals emitNthPoint on a leaf`() {
        let doInty = Interpreter()
        doInty.load(program: [tree, IntItem(2), InstructionItem(.codeDoNthPoint)])
        doInty.run()
        let emitInty = Interpreter()
        emitInty.load(program: [tree, IntItem(2), InstructionItem(.codeEmitNthPoint)])
        emitInty.run()
        #expect(stackString(doInty, .int) == stackString(emitInty, .int))
        #expect(stackString(doInty, .int) == "[ 7 2 ]")
    }

    // MARK: - Root variants

    @Test func `emitNthRoot pushes a root element whole`() {
        let inty = Interpreter()
        inty.load(program: [tree, IntItem(0), InstructionItem(.codeEmitNthRoot)])
        inty.run()
        // root element 0 = ( 7 8 ), pushed whole to .code.
        #expect(stackString(inty, .code) == "[ ( 7 8 ) ( ( 7 8 ) 9 ) ]")
    }

    @Test func `doNthRoot runs a root element's contents`() {
        let inty = Interpreter()
        inty.load(program: [tree, IntItem(0), InstructionItem(.codeDoNthRoot)])
        inty.run()
        // root element 0 = ( 7 8 ) unwrapped: 7, 8 onto .int, above index 0.
        #expect(stackString(inty, .int) == "[ 8 7 0 ]")
    }

    @Test func `nthRoot variants agree on a bare root element`() {
        // root element 1 = 9, a leaf: Do and Emit both route it to .int.
        let doInty = Interpreter()
        doInty.load(program: [tree, IntItem(1), InstructionItem(.codeDoNthRoot)])
        doInty.run()
        let emitInty = Interpreter()
        emitInty.load(program: [tree, IntItem(1), InstructionItem(.codeEmitNthRoot)])
        emitInty.run()
        #expect(stackString(doInty, .int) == "[ 9 1 ]")
        #expect(stackString(doInty, .int) == stackString(emitInty, .int))
    }

    @Test func `emitNthRoot on an empty block is an error`() {
        let inty = Interpreter()
        inty.load(program: [CodeItem([]), IntItem(3), InstructionItem(.codeEmitNthRoot)])
        inty.run()
        #expect(stackString(inty, .code) == "[ ( ) ]", "only the untouched tree remains")
        #expect(stackString(inty, .int) == "[ 3 ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .emptyCollection)
    }

    @Test func `index clamps to the point count`() {
        // 5 points; index 6 clamps to 4 → the leaf 9, which goes to `.int`.
        let inty = Interpreter()
        inty.load(program: [tree, IntItem(6), InstructionItem(.codeEmitNthPoint)])
        inty.run()
        #expect(stackString(inty, .code) == "[ ( ( 7 8 ) 9 ) ]")
        #expect(stackString(inty, .int) == "[ 9 6 ]")
    }
}
