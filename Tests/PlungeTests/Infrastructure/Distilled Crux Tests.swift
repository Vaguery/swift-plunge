//
//  Distilled Crux Tests.swift
//  PlungeTests
//
//  What a history depends on (`CruxDependence`), and the distilled crux built on
//  it: constant-only work replaced by its value, everything else kept
//  (2026-11-15).
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct DistilledCruxTests {

    static let inputs: [PushInstruction: any Item] = [.input0: IntItem(5), .input1: StringItem("hello")]
    static let constants: [PushInstruction: any Item] = [.int0: IntItem(7), .int1: IntItem(-2),
                                                         .string0: StringItem("abc")]

    static func run(_ program: [any Item], inputs: [PushInstruction: any Item] = inputs,
                    settings: InterpreterSettings? = nil) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        if let settings { inty.config = settings }
        inty.load(inputs: inputs, constants: constants, program: program)
        inty.run(stepLimit: 10_000)
        return inty
    }

    static func top(_ program: [any Item], on stack: PushStack) -> any Item {
        run(program).stacks[stack]!.first!
    }

    /// The value `program` leaves on `stack`, replayed as a crux.
    static func replay(_ program: [any Item], on stack: PushStack,
                       inputs: [PushInstruction: any Item] = inputs) -> (any Item)? {
        let redo = Interpreter.recordingProvenance()
        redo.config = redo.config.reconstructing
        redo.load(inputs: inputs, constants: constants, program: program)
        redo.run(stepLimit: 100_000)
        return redo.stacks[stack]!.first
    }

    static func printed(_ program: [any Item]) -> String { CodeItem(program).pretty() }

    static func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }

    // MARK: - Rolled, with sharing kept

    @Test func `the rolled program writes a loop once and replays to the same value`() {
        // input0, then six passes of `2 .intMultiply`.
        let program: [any Item] = Self.ins(.input0) + [IntItem(6), CodeItem([IntItem(2)] + Self.ins(.intMultiply))]
            + Self.ins(.execDoTimes)
        let item = Self.top(program, on: .int)
        let distilled = item.distilledCrux()
        let rolled = distilled.rolledProgram
        #expect(rolled.count < distilled.program.count, "\(Self.printed(rolled))")
        #expect(Self.printed(rolled).contains(".execDoTimes"))
        #expect(Self.replay(rolled, on: .int)?.pretty() == item.pretty())
    }

    @Test func `the rolled program keeps a reused value shared, as the distilled crux does`() {
        // x·x·x·x by dup: written out as a tree, each dup doubles the crux.
        let program = Self.ins(.input0, .intDup, .intMultiply, .intDup, .intMultiply)
        let item = Self.top(program, on: .int)
        let distilled = item.distilledCrux()
        #expect(Self.printed(distilled.rolledProgram) == Self.printed(distilled.program))
        #expect(Self.replay(distilled.rolledProgram, on: .int)?.pretty() == item.pretty())
        let abstract = try? #require(distilled.abstracted())
        #expect((abstract?.template.count ?? 0) > distilled.rolledProgram.count, "the tree form writes x twice")
    }

    // MARK: - Dependence

    @Test func `a literal and plain arithmetic on literals depend on nothing`() {
        #expect(IntItem(3).cruxDependence.isEmpty)
        let sum = Self.top([IntItem(2), IntItem(3)] + Self.ins(.intAdd), on: .int)
        #expect(sum.cruxDependence.isEmpty)
    }

    @Test func `inputs, constants and observed state are told apart`() {
        #expect(Self.top(Self.ins(.input0), on: .int).cruxDependence == .input)
        #expect(Self.top(Self.ins(.int0, .int1, .intAdd), on: .int).cruxDependence == .constant)
        #expect(Self.top(Self.ins(.input0, .int0, .intAdd), on: .int).cruxDependence == [.input, .constant])
        // A stack depth is the run's state (law 4b).
        let depth = Self.top([IntItem(1), IntItem(1)] + Self.ins(.intStackDepth, .intAdd), on: .int)
        #expect(depth.cruxDependence == .context)
    }

    @Test func `an input read through its binding still reads the input`() {
        let pair = Self.run([]).stacks[.binding]!.first!
        #expect(pair.cruxDependence.contains(.input))
    }

    @Test func `an elided history keeps what it read`() {
        var settings = Interpreter.recordingProvenance().config
        settings.maxCallWeight = 20
        // Steps that differ, so no loop folds them and the budget elides them.
        let steps: [any Item] = (1...30).flatMap { n -> [any Item] in [IntItem(n), InstructionItem(.intAdd)] }
        let program: [any Item] = Self.ins(.input0) + steps
        let item = Self.run(program, settings: settings).stacks[.int]!.first!
        #expect(item.crux().contains { $0.exactly(StandInItem.self)?.reason == .elided })
        #expect(item.cruxDependence.contains(.input))
    }

    @Test func `an elided stand-in keeps its dependence through an archive`() throws {
        let standIn = StandInItem(standingInFor: Self.top(Self.ins(.input0), on: .int), source: .intAdd,
                                  reason: .elided)
        #expect(standIn.cruxDependence == .input)
        let decoded = try JSONDecoder().decode(AnyItem.self, from: JSONEncoder().encode(AnyItem(standIn))).item
        #expect(decoded.cruxDependence == .input)
    }

    @Test func `code run inside one step counts what its contents read`() {
        // A folded loop's body runs inside the loop instruction: `( .input0 .intAdd )`.
        let call: [any Item] = [IntItem(0), CodeItem(Self.ins(.input0, .intAdd)), IntItem(3)]
            + Self.ins(.execDoTimes, .codePop)
        #expect(CruxDependence.of(call).contains(.input))
        // The same block only measured, not run, reads nothing.
        let measured: [any Item] = [CodeItem(Self.ins(.input0, .intAdd))] + Self.ins(.codeLength)
        #expect(CruxDependence.of(measured).isEmpty)
    }

    // MARK: - Distilling

    @Test func `constant work before an input is replaced by its value`() {
        let item = Self.top([IntItem(2), IntItem(3)] + Self.ins(.intAdd, .input0, .intMultiply), on: .int)
        #expect(Self.printed(item.crux()) == "( 2 3 .intAdd .input0 .intMultiply )")
        let distilled = item.distilledCrux()
        #expect(Self.printed(distilled.program) == "( «distilled .intAdd: 5» .input0 .intMultiply )")
        #expect(distilled.derived.count == 1)
        #expect(distilled.derived.first?.slotsRead == [])
        #expect(Self.replay(distilled.program, on: .int)?.pretty() == "25")
    }

    @Test func `a branch that reads constant slots becomes a derived constant`() {
        let item = Self.top(Self.ins(.int0, .int1, .intMultiply, .input0, .intAdd), on: .int)
        let distilled = item.distilledCrux()
        #expect(Self.printed(distilled.program) == "( «distilled .intMultiply: -14» .input0 .intAdd )")
        let derived = distilled.derived.first
        #expect(derived?.slotsRead == [.int0, .int1])
        #expect(Self.printed(derived?.origin ?? []) == "( .int0 .int1 .intMultiply )")
        #expect(derived?.position == 0)
    }

    @Test func `string work on constants is one value`() {
        let item = Self.top(Self.ins(.string0, .stringReverse, .string0, .stringConcat, .input1, .stringConcat),
                            on: .string)
        let distilled = item.distilledCrux()
        #expect(Self.printed(distilled.program) == "( «distilled .stringConcat: \"cbaabc\"» .input1 .stringConcat )")
        #expect(Self.replay(distilled.program, on: .string)?.pretty() == item.pretty())
    }

    @Test func `a history of constant work alone distills to one value`() {
        let item = Self.top(Self.ins(.int0, .int1, .intAdd, .int0, .intMultiply), on: .int)
        let distilled = item.distilledCrux()
        #expect(distilled.program.count == 1)
        #expect(Self.printed(distilled.program) == "( «distilled .intMultiply: 35» )")
    }

    @Test func `a lone constant read and work on an input are kept`() {
        let item = Self.top(Self.ins(.int0, .input0, .intAdd), on: .int)
        let distilled = item.distilledCrux()
        #expect(!distilled.isChanged)
        #expect(Self.printed(distilled.program) == Self.printed(item.crux()))
    }

    @Test func `work that reads the run's state is kept`() {
        let item = Self.top([IntItem(1), IntItem(1)] + Self.ins(.intStackDepth, .intAdd, .input0, .intAdd), on: .int)
        let distilled = item.distilledCrux()
        #expect(distilled.program.contains { $0.exactly(StandInItem.self)?.reason == .observed })
        #expect(distilled.program.contains { $0.exactly(InstructionItem.self)?.value == .intAdd })
    }

    @Test func `a shared constant node is still built once`() {
        // 2 3 .intAdd is used twice: by the dup and by the multiply.
        let item = Self.top([IntItem(2), IntItem(3)] + Self.ins(.intAdd, .intDup, .input0, .intMultiply, .intAdd),
                            on: .int)
        let distilled = item.distilledCrux()
        let standIns = distilled.program.filter { $0.exactly(StandInItem.self)?.reason == .distilled }
        #expect(standIns.count == 1)
        #expect(Self.replay(distilled.program, on: .int)?.pretty() == item.pretty())
    }

    @Test func `a distilled crux is a fixed point of its own replay`() {
        let item = Self.top(Self.ins(.int0, .int1, .intMultiply, .input0, .intAdd), on: .int)
        let distilled = item.distilledCrux()
        let replayed = Self.replay(distilled.program, on: .int)
        #expect(replayed.map { Self.printed($0.crux()) } == Self.printed(distilled.program))
        #expect(replayed.map { Self.printed($0.distilledCrux().program) } == Self.printed(distilled.program))
    }

    @Test func `the distilled crux gives the same value on other inputs`() {
        let item = Self.top([IntItem(2), IntItem(3)] + Self.ins(.intAdd, .input0, .intMultiply), on: .int)
        let other: [PushInstruction: any Item] = [.input0: IntItem(-4), .input1: StringItem("")]
        let original = Self.replay(item.crux(), on: .int, inputs: other)
        let distilled = Self.replay(item.distilledCrux().program, on: .int, inputs: other)
        #expect(original?.pretty() == "-20")
        #expect(distilled?.pretty() == original?.pretty())
    }
}
