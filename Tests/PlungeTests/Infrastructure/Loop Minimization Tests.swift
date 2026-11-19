//
//  Loop Minimization Tests.swift
//  PlungeTests
//
//  A crux's loops folded and run as few times as keeps the result
//  (`Item.minimizingLoops`, 2026-11-15).
//

@testable import Plunge
import Testing

@Suite
struct LoopMinimizationTests {

    static func run(_ program: [any Item], inputs: [PushInstruction: any Item] = [:]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, program: program)
        inty.run(stepLimit: 10_000)
        return inty
    }

    static func loop(_ seed: any Item, _ body: [any Item], _ count: Int) -> [any Item] {
        [seed, CodeItem(body), IntItem(count), InstructionItem(.execDoTimes)]
    }

    static func replay(_ program: [any Item], inputs: [PushInstruction: any Item], on stack: PushStack) -> String? {
        let redo = Interpreter()
        redo.load(inputs: inputs, program: program)
        redo.run(stepLimit: 100_000)
        return redo.stacks[stack]!.first?.pretty()
    }

    @Test func `a saturating loop runs only until it saturates`() {
        // Add 1 a hundred times, but never past 7.
        let body: [any Item] = [IntItem(1), InstructionItem(.intAdd), IntItem(7), InstructionItem(.intMin)]
        let program = Self.loop(IntItem(0), body, 100)
        let item = Self.run(program).stacks[.int]!.first!
        #expect(item.pretty() == "7")
        let minimized = item.minimizingLoops(on: [([:], [:])])!
        #expect(minimized.loops == 1)
        #expect(minimized.changes == [LoopMinimization.Change(from: 100, to: 7)])
        #expect(CodeItem(minimized.program).pretty() == "( 0 ( 1 .intAdd 7 .intMin ) 7 .execDoTimes .codePop )")
        #expect(Self.replay(minimized.program, inputs: [:], on: .int) == "7")
    }

    @Test func `a loop that flips back and forth runs not at all`() {
        let item = Self.run(Self.loop(BoolItem(true), [InstructionItem(.boolNot)], 10)).stacks[.bool]!.first!
        let minimized = item.minimizingLoops(on: [([:], [:])])!
        #expect(minimized.changes == [LoopMinimization.Change(from: 10, to: 0)])
        #expect(Self.replay(minimized.program, inputs: [:], on: .bool) == "true")
    }

    @Test func `a loop whose every pass counts is left alone`() {
        let item = Self.run(Self.loop(IntItem(0), [IntItem(2), InstructionItem(.intAdd)], 30)).stacks[.int]!.first!
        let minimized = item.minimizingLoops(on: [([:], [:])])!
        #expect(minimized.loops == 1)
        #expect(minimized.changes.isEmpty)
        #expect(Self.replay(minimized.program, inputs: [:], on: .int) == "60")
    }

    @Test func `every case given must still hold`() {
        // Count to 50, then take the smaller of that and the input.
        let program = Self.loop(IntItem(0), [IntItem(1), InstructionItem(.intAdd)], 50)
            + [InstructionItem(.input(0)), InstructionItem(.intMin)]
        let five: [PushInstruction: any Item] = [.input(0): IntItem(5)]
        let twelve: [PushInstruction: any Item] = [.input(0): IntItem(12)]
        let item = Self.run(program, inputs: five).stacks[.int]!.first!
        // On its own case, five passes are enough.
        let alone = item.minimizingLoops(on: [(five, [:])])!
        #expect(alone.changes == [LoopMinimization.Change(from: 50, to: 5)])
        // With a second case, twelve are needed.
        let both = item.minimizingLoops(on: [(five, [:]), (twelve, [:])])!
        #expect(both.changes == [LoopMinimization.Change(from: 50, to: 12)])
        #expect(Self.replay(both.program, inputs: twelve, on: .int) == "12")
        #expect(Self.replay(both.program, inputs: five, on: .int) == "5")
    }

    @Test func `a history with no loop is unchanged`() {
        let item = Self.run([IntItem(2), IntItem(3), InstructionItem(.intAdd)]).stacks[.int]!.first!
        let minimized = item.minimizingLoops(on: [([:], [:])])!
        #expect(minimized.loops == 0)
        #expect(CodeItem(minimized.program).pretty() == CodeItem(item.crux()).pretty())
    }
}
