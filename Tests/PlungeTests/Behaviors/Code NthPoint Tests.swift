//
//  Code NthPoint Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/18/26.
//
//  codeNth / codeNthRoot and their Peek forms — point access, always yielding
//  .code (a sub-block as-is, a leaf wrapped once). The Nth forms consume the
//  block and index; the Peek forms leave them.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct CodeNthPointTests {

    /// ( (1 2) 3 ): points 0:root 1:(1 2) 2:1 3:2 4:3
    let tree = CodeItem([CodeItem([IntItem(1), IntItem(2)]), IntItem(3)])

    /// index on top of .int, code below it on .code.
    func nth(_ instr: PushInstruction, _ code: CodeItem, _ i: Int) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.code]!.prepend(code)
        inty.stacks[.int]!.prepend(IntItem(i))
        doThis(instr, to: inty)
        return inty
    }

    @Test func `nthPoint yields a sub-block as-is`() {
        let inty = nth(.codePeekNth, tree, 1)
        #expect(topItem(inty, .code).pretty() == "( 1 2 )")
        #expect(stackString(inty, .code) == "[ ( 1 2 ) ( ( 1 2 ) 3 ) ]", "result atop the surviving tree")
        #expect(stackString(inty, .int) == "[ 1 ]", "the index survives too")
    }

    @Test func `nthPoint wraps a leaf as code`() {
        let inty = nth(.codePeekNth, tree, 2)   // the leaf 1
        #expect(topItem(inty, .code).pretty() == "( 1 )", "a leaf becomes a one-item block")
    }

    @Test func `nthPoint 0 is the whole tree; index clamps`() {
        #expect(nth(.codePeekNth, tree, 0).stacks[.code]!.first!.pretty() == "( ( 1 2 ) 3 )")
        #expect(nth(.codePeekNth, tree, 5).stacks[.code]!.first!.pretty() == "( 3 )", "past the end is the last point")
        #expect(nth(.codePeekNth, tree, -2).stacks[.code]!.first!.pretty() == "( ( 1 2 ) 3 )", "below 0 is the root")
    }

    @Test func `nthPoint crux reproduces the point, debris-free`() {
        let inty = nth(.codePeekNth, tree, 3)   // the leaf 2
        let result = topItem(inty, .code)
        #expect(result.pretty() == "( 2 )")

        let redo = Interpreter.recordingProvenance()
        redo.load(program: result.crux())
        redo.run()
        #expect(redo.stacks[.code]!.first!.pretty() == "( 2 )")
        #expect(redo.stacks[.code]!.count == 1, "no tree debris left on .code")
        #expect(redo.stacks[.int]!.isEmpty, "no index debris left on .int")
    }

    @Test func `nthRoot indexes the root array, wrapping leaves`() {
        // root elements: 0:(1 2)  1:3
        #expect(nth(.codePeekNthRoot, tree, 0).stacks[.code]!.first!.pretty() == "( 1 2 )")
        #expect(nth(.codePeekNthRoot, tree, 1).stacks[.code]!.first!.pretty() == "( 3 )", "leaf wrapped")
        #expect(nth(.codePeekNthRoot, tree, 3).stacks[.code]!.first!.pretty() == "( 3 )", "past the end is the last element")
        #expect(nth(.codePeekNthRoot, tree, -3).stacks[.code]!.first!.pretty() == "( 1 2 )", "below 0 is the first")
    }

    @Test func `nthRoot on an empty block is an error`() {
        let inty = nth(.codePeekNthRoot, CodeItem([]), 0)
        #expect(inty.stacks[.code]!.first!.pretty() == "( )", "the empty block survives, no result pushed")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .emptyCollection)
    }


    @Test func `the consuming forms take the block and index`() {
        let point = nth(.codeNth, tree, 1)
        #expect(stackString(point, .code) == "[ ( 1 2 ) ]", "only the point is left")
        #expect(stackString(point, .int) == "[ ]")
        let root = nth(.codeNthRoot, tree, 1)
        #expect(stackString(root, .code) == "[ ( 3 ) ]", "root item 1, boxed")
        #expect(stackString(root, .int) == "[ ]")
        let empty = nth(.codeNthRoot, CodeItem([]), 0)
        #expect(empty.stacks[.error]!.count == 1, "an empty block has no root item")

        for result in [topItem(point, .code), topItem(root, .code)] {
            let redo = Interpreter.recordingProvenance()
            redo.load(program: result.crux())
            redo.run()
            #expect(stackString(redo, .code) == "[ \(result.pretty()) ]")
            #expect(redo.stacks[.int]!.isEmpty)
        }
    }

    @Test func `codeOccurrencesOf counts equal points, leaving both`() {
        let hay = CodeItem([IntItem(1), CodeItem([IntItem(1), IntItem(2)]), IntItem(1)])
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [hay, CodeItem([IntItem(1)]), InstructionItem(.codeOccurrencesOf)])
        inty.run()
        #expect(stackString(inty, .int) == "[ 3 ]", "a one-item needle stands for its item")
        #expect(inty.stacks[.code]!.count == 2)
        let block = Interpreter()
        block.load(program: [hay, CodeItem([CodeItem([IntItem(1), IntItem(2)])]), InstructionItem(.codeOccurrencesOf)])
        block.run()
        #expect(stackString(block, .int) == "[ 1 ]")
    }
}
