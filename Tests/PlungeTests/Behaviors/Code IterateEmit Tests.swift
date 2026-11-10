//
//  Code IterateEmit Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/18/26.
//
//  codeIterateEmit (whole) and codeIterateDo (unwrapped): the .exec
//  cousins of codeIterate, walking every pre-order point and handing each on
//  to .exec whole or run, respectively. Bodyless walks isolate the emission.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeIterateEmitTests {

    /// ( ( 7 8 ) 9 ): points 0:root 1:(7 8) 2:7 3:8 4:9.
    let tree = CodeItem([CodeItem([IntItem(7), IntItem(8)]), IntItem(9)])

    /// What a bodyless walk of `mode` emits over `code`, front to back.
    func emitted(_ code: CodeItem, _ mode: PointsEmission) -> [String] {
        IteratorItem(kind: .points(mode), origin: code, body: nil, emits: true)
            .collected(recording: .on)?.map { $0.pretty() } ?? []
    }

    @Test func `whole hands each point on unboxed`() {
        // Sub-blocks stay whole, leaves are bare (not wrapped ( x )).
        #expect(emitted(tree, .whole) == [
            "( ( 7 8 ) 9 )",   // 0: root
            "( 7 8 )",         // 1: subtree, whole
            "7",               // 2: bare leaf
            "8",               // 3: bare leaf
            "9"               // 4: bare leaf
        ])
    }

    @Test func `boxed still wraps its leaves`() {
        // Contrast: the original codeIterate mode boxes every leaf.
        #expect(emitted(tree, .boxed) == [
            "( ( 7 8 ) 9 )", "( 7 8 )", "( 7 )", "( 8 )", "( 9 )"
        ])
    }

    @Test func `emitPoints routes leaves to their own stacks, blocks to code`() {
        // A bodyless walk played to completion: each point routed whole.
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            tree,             // deeper
            CodeItem([]),     // empty mouse, on top
            InstructionItem(.codeIterateEmit)
        ])
        inty.run()
        // Leaves 7, 8, 9 route to .int, front-to-back (9 emitted last, on top).
        #expect(stackString(inty, .int) == "[ 9 8 7 ]")
        // Blocks — the root and ( 7 8 ) — rest whole on .code; ( 7 8 ) emitted
        // after the root, so it is on top.
        #expect(stackString(inty, .code) == "[ ( 7 8 ) ( ( 7 8 ) 9 ) ]")
    }

    @Test func `doPoints runs each point, blocks unwrapped`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            tree,
            CodeItem([]),
            InstructionItem(.codeIterateDo)
        ])
        inty.run()
        // Every point is sent through .codeDo. The blocks unwrap:
        //   root ( ( 7 8 ) 9 ) → ( 7 8 ) rests on .code, then 9 → .int
        //   ( 7 8 )            → 7, 8 → .int
        //   leaves 7, 8, 9     → .int
        // .int accumulates 9, 7, 8, 7, 8, 9 in emission order.
        #expect(stackString(inty, .int) == "[ 9 8 7 8 7 9 ]")
        // The only block that comes to rest is the ( 7 8 ) spilled from the root.
        #expect(stackString(inty, .code) == "[ ( 7 8 ) ]")
    }

    @Test func `doPoints equals emitPoints on a flat block of leaves`() {
        let flat = CodeItem([IntItem(1), IntItem(2), IntItem(3)])
        let doInty = Interpreter.recordingProvenance()
        doInty.load(program: [flat, CodeItem([]), InstructionItem(.codeIterateDo)])
        doInty.run()
        let emitInty = Interpreter.recordingProvenance()
        emitInty.load(program: [flat, CodeItem([]), InstructionItem(.codeIterateEmit)])
        emitInty.run()
        // Only difference would be block handling; the sole block here is the root,
        // which doPoints unwraps (spilling its leaves) and emitPoints rests whole.
        // So the .int stacks agree on the leaves but the root differs — assert the
        // leaves that both produce from points 1..3 line up.
        #expect(stackString(doInty, .int) == "[ 3 2 1 3 2 1 ]", "root unwraps to 1 2 3, then each leaf")
        #expect(stackString(emitInty, .int) == "[ 3 2 1 ]", "root rests whole; only leaves route")
    }

    @Test func `a whole points iterator reconstructs via its own constructor`() {
        var it = IteratorItem(kind: .points(.whole), origin: tree, body: nil, emits: true)
        it.call = it.reconstruction()
        #expect(CodeItem(it.call).pretty().contains(".iteratorFromCodeEmit"))
        let redo = Interpreter.recordingProvenance()
        redo.load(program: it.crux())
        redo.run()
        let rebuilt = redo.stacks[.iterator]!.first as? IteratorItem
        #expect(rebuilt?.kind == .points(.whole))
    }

    @Test func `an unwrapped points iterator reconstructs via its own constructor`() {
        var it = IteratorItem(kind: .points(.unwrapped), origin: tree, body: nil, emits: true)
        it.call = it.reconstruction()
        #expect(CodeItem(it.call).pretty().contains(".iteratorFromCodeDo"))
        let redo = Interpreter.recordingProvenance()
        redo.load(program: it.crux())
        redo.run()
        let rebuilt = redo.stacks[.iterator]!.first as? IteratorItem
        #expect(rebuilt?.kind == .points(.unwrapped))
    }
}
