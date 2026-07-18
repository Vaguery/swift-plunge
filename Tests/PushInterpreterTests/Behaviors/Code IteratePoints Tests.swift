//
//  Code IteratePoints Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/18/26.
//
//  codeIteratePoints and its .points IteratorKind: emit every pre-order point of
//  a tree, each boxed as .code, recording the codeNthPoint crux.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeIteratePointsTests {

    /// ( (1 2) 3 ): points 0:root 1:(1 2) 2:1 3:2 4:3
    let tree = CodeItem([CodeItem([IntItem(1), IntItem(2)]), IntItem(3)])

    /// Build a bodyless .points iterator over `code` and collect everything it
    /// emits, front to back.
    func emittedPoints(_ code: CodeItem) -> [String] {
        let it = IteratorItem(kind: .points(into: nil), origin: code, body: nil, emits: true)
        return it.collected().map { $0.pretty() }
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

    @Test func `each emitted point records the codeNthPoint crux and reproduces`() {
        let it = IteratorItem(kind: .points(into: nil), origin: tree, body: nil, emits: true)
        let points = it.collected()
        // point 2 is the leaf 1, boxed as ( 1 )
        let leafPoint = points[2]
        #expect(leafPoint.pretty() == "( 1 )")

        let redo = Interpreter()
        redo.load(program: leafPoint.crux())
        redo.run()
        #expect(redo.stacks[.code]!.first!.pretty() == "( 1 )", "reproduces the boxed point")
        #expect(redo.stacks[.int]!.isEmpty, "debris-free: the index was cleaned up")
    }

    @Test func `codeIteratePoints plays a bodyless walk to completion`() {
        // ( 1 2 ): points 0:(1 2) 1:1 2:2 → three points, each boxed to .code.
        let inty = Interpreter()
        inty.load(program: [
            CodeItem([IntItem(1), IntItem(2)]),   // the tree (deeper)
            CodeItem([]),                         // empty mouse (top)
            InstructionItem(.codeIteratePoints),
        ])
        inty.run()
        // each point lands on .code; last emitted (the leaf 2 → (2)) on top
        #expect(stackString(inty, .code) == "[ ( 2 ) ( 1 ) ( 1 2 ) ]")
    }

    @Test func `a points iterator reconstructs via iteratorFromCodePoints`() {
        var it = IteratorItem(kind: .points(into: nil), origin: tree, body: nil, emits: true)
        it.call = it.reconstruction()
        #expect(CodeItem(it.call).pretty().contains(".iteratorFromCodePoints"))

        let redo = Interpreter()
        redo.load(program: it.crux())
        redo.run()
        let rebuilt = redo.stacks[.iterator]!.first as? IteratorItem
        #expect(rebuilt?.kind == .points(into: nil))
        #expect(rebuilt?.origin.pretty() == tree.pretty())
    }
}
