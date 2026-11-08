//
//  Code NthPoint Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/18/26.
//
//  codeNthPoint / codeNthRoot — point access, always yielding .code (a sub-block
//  as-is, a leaf wrapped once), non-destructive.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
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
        let inty = nth(.codeNthPoint, tree, 1)
        #expect(topItem(inty, .code).pretty() == "( 1 2 )")
        #expect(stackString(inty, .code) == "[ ( 1 2 ) ( ( 1 2 ) 3 ) ]", "result atop the surviving tree")
        #expect(stackString(inty, .int) == "[ 1 ]", "the index survives too")
    }

    @Test func `nthPoint wraps a leaf as code`() {
        let inty = nth(.codeNthPoint, tree, 2)   // the leaf 1
        #expect(topItem(inty, .code).pretty() == "( 1 )", "a leaf becomes a one-item block")
    }

    @Test func `nthPoint 0 is the whole tree; index clamps`() {
        #expect(nth(.codeNthPoint, tree, 0).stacks[.code]!.first!.pretty() == "( ( 1 2 ) 3 )")
        #expect(nth(.codeNthPoint, tree, 5).stacks[.code]!.first!.pretty() == "( 3 )", "past the end is the last point")
        #expect(nth(.codeNthPoint, tree, -2).stacks[.code]!.first!.pretty() == "( ( 1 2 ) 3 )", "below 0 is the root")
    }

    @Test func `nthPoint crux reproduces the point, debris-free`() {
        let inty = nth(.codeNthPoint, tree, 3)   // the leaf 2
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
        #expect(nth(.codeNthRoot, tree, 0).stacks[.code]!.first!.pretty() == "( 1 2 )")
        #expect(nth(.codeNthRoot, tree, 1).stacks[.code]!.first!.pretty() == "( 3 )", "leaf wrapped")
        #expect(nth(.codeNthRoot, tree, 3).stacks[.code]!.first!.pretty() == "( 3 )", "past the end is the last element")
        #expect(nth(.codeNthRoot, tree, -3).stacks[.code]!.first!.pretty() == "( 1 2 )", "below 0 is the first")
    }

    @Test func `nthRoot on an empty block is an error`() {
        let inty = nth(.codeNthRoot, CodeItem([]), 0)
        #expect(inty.stacks[.code]!.first!.pretty() == "( )", "the empty block survives, no result pushed")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .emptyCollection)
    }

}
