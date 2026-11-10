//
//  Iterator Pass Order Tests.swift
//  PlungeTests
//
//  What a pass emits comes before its body runs, wherever the emitted item
//  goes: onto a data stack, or onto `.exec` to run (`…IntoExec` iterators, an
//  instruction walked out of a block, a point unwrapped by `.codeDo`). Until
//  2026-11-09 an item bound for `.exec` ran after the body.
//

@testable import Plunge
import Testing

@Suite @MainActor
struct IteratorPassOrderTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    @Test func `an item emitted onto a data stack lands before the body runs`() {
        let inty = Self.run([CodeItem([IntItem(1), IntItem(2)]), CodeItem([IntItem(10)]), IntItem(0), IntItem(0),
                             BoolItem(true), Self.op(.iteratorFromCodeRoot), Self.op(.iteratorPlay)])
        #expect(stackString(inty, .int) == "[ 10 2 10 1 ]", "pushed 1, 10, 2, 10")
    }

    @Test func `an item emitted onto exec runs before the body, too`() {
        let inty = Self.run([CodeItem([IntItem(1), IntItem(2)]), CodeItem([IntItem(10)]), IntItem(0), IntItem(0),
                             BoolItem(true), Self.op(.iteratorFromCodeRootIntoExec), Self.op(.iteratorPlay)])
        #expect(stackString(inty, .int) == "[ 10 2 10 1 ]", "pushed 1, 10, 2, 10, as the data-stack form does")
    }

    @Test func `an instruction walked out of a block runs before the body`() {
        // The block's items are 5, then .intInc; the body pushes 0 after each.
        // Pass 1: 5, then the body's 0. Pass 2: .intInc turns that 0 into 1,
        // then the body pushes 0. (Body first would have given [ 1 0 5 ].)
        let inty = Self.run([CodeItem([IntItem(5), Self.op(.intInc)]), CodeItem([IntItem(0)]),
                             Self.op(.codeIterateRoot)])
        #expect(stackString(inty, .int) == "[ 0 1 5 ]")
    }
}
