//
//  Code Iterate Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/18/26.
//
//  codeIterate and its .points IteratorKind: emit every pre-order point of
//  a tree, each boxed as .code, recording the codeNthPoint crux.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeIterateTests {

    /// ( (1 2) 3 ): points 0:root 1:(1 2) 2:1 3:2 4:3
    let tree = CodeItem([CodeItem([IntItem(1), IntItem(2)]), IntItem(3)])

    /// Build a bodyless .points iterator over `code` and collect everything it
    /// emits, front to back.
    func emittedPoints(_ code: CodeItem) -> [String] {
        let it = IteratorItem(kind: .points(.boxed), origin: code, body: nil, emits: true)
        return it.collected(recording: .on)?.map { $0.pretty() } ?? []
    }

    @Test func `points emits every node pre-order, each boxed as code`() {
        #expect(emittedPoints(tree) == [
            "( ( 1 2 ) 3 )",   // 0: root
            "( 1 2 )",         // 1: subtree
            "( 1 )",           // 2: leaf 1, wrapped
            "( 2 )",           // 3: leaf 2, wrapped
            "( 3 )",           // 4: leaf 3, wrapped
        ])
    }

    @Test func `an empty block still emits its root`() {
        #expect(emittedPoints(CodeItem([])) == ["( )"])
    }

    @Test func `each emitted point records the codeNthPoint crux and reproduces`() throws {
        let it = IteratorItem(kind: .points(.boxed), origin: tree, body: nil, emits: true)
        let points = try #require(it.collected(recording: .on))
        // point 2 is the leaf 1, boxed as ( 1 )
        let leafPoint = points[2]
        #expect(leafPoint.pretty() == "( 1 )")

        let redo = Interpreter.recordingProvenance()
        redo.load(program: leafPoint.crux())
        redo.run()
        #expect(redo.stacks[.code]!.first!.pretty() == "( 1 )", "reproduces the boxed point")
        #expect(redo.stacks[.int]!.isEmpty, "debris-free: the index was cleaned up")
    }

    @Test func `codeIterate plays a bodyless walk to completion`() {
        // ( 1 2 ): points 0:(1 2) 1:1 2:2 → three points, each boxed to .code.
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            CodeItem([IntItem(1), IntItem(2)]),   // the tree (deeper)
            CodeItem([]),                         // empty mouse (top)
            InstructionItem(.codeIterate),
        ])
        inty.run()
        // each point lands on .code; last emitted (the leaf 2 → (2)) on top
        #expect(stackString(inty, .code) == "[ ( 2 ) ( 1 ) ( 1 2 ) ]")
    }

    @Test func `a points iterator reconstructs via iteratorFromCode`() {
        var it = IteratorItem(kind: .points(.boxed), origin: tree, body: nil, emits: true)
        it.call = it.reconstruction()
        #expect(CodeItem(it.call).pretty().contains(".iteratorFromCode"))

        let redo = Interpreter.recordingProvenance()
        redo.load(program: it.crux())
        redo.run()
        let rebuilt = redo.stacks[.iterator]!.first as? IteratorItem
        #expect(rebuilt?.kind == .points(.boxed))
        #expect(rebuilt?.origin.pretty() == tree.pretty())
    }
}
