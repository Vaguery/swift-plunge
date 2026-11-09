//
//  Iterator End Tests.swift
//  PushInterpreterTests
//
//  A counting iterator is exclusive of its end, whatever put its cursor there:
//  stepping stops short of it, and (since 2026-11-09) so does a cursor set onto
//  it. A range whose bounds are equal still gets its one pass.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct IteratorEndTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// `a b s i d e ( body ) .iteratorFromIntRange`, then play it.
    static func range(_ a: Int, _ b: Int, cursor: Int) -> [any Item] {
        [IntItem(a), IntItem(b), IntItem(1), IntItem(cursor), IntItem(0), BoolItem(true), CodeItem([]),
         op(.iteratorFromIntRange), op(.iteratorPlay)]
    }

    @Test func `a range stops short of its end`() {
        #expect(stackString(Self.run(Self.range(0, 3, cursor: 0)), .int) == "[ 2 1 0 ]")
    }

    @Test func `equal bounds give one pass`() {
        #expect(stackString(Self.run(Self.range(5, 5, cursor: 0)), .int) == "[ 5 ]")
    }

    @Test func `a cursor on the end has nothing to emit`() {
        let inty = Self.run(Self.range(0, 3, cursor: 3))
        #expect(stackString(inty, .int) == "[ ]", "until 2026-11-09 this emitted 3")
        #expect(inty.stacks[.iterator]!.isEmpty)
        #expect(inty.stacks[.error]!.contains { $0.pretty().contains("has nothing to emit") }, "the constructor refuses")
    }
}
