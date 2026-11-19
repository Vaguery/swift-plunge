//
//  Tunable Crux Tests.swift
//  PlungeTests
//
//  A crux with each input wrapped in a parametric transform, whose neutral
//  setting leaves it as it was; the inputs stay in place (`TunableCrux`,
//  2026-11-15).
//

@testable import Plunge
import Testing

@Suite
struct TunableCruxTests {

    typealias Distilled = DistilledCruxTests

    static let inputs: [PushInstruction: any Item] = [
        .input(0): IntItem(5), .input(1): StringItem("hello"), .input(2): BoolItem(true), .input(3): CharItem("m"),
        .input(4): DoubleItem(2.5), .input(5): VecIntItem([1, 2, 3])
    ]

    static func top(_ program: [any Item], on stack: PushStack) -> any Item {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, constants: Distilled.constants, program: program)
        inty.run(stepLimit: 10_000)
        return inty.stacks[stack]!.first!
    }

    static func replay(_ program: [any Item], on stack: PushStack) -> String? {
        Distilled.replay(program, on: stack, inputs: inputs)?.pretty()
    }

    @Test func `an int input is scaled and shifted in place`() {
        let item = Self.top(Distilled.ins(.input(0), .constant(0), .intAdd), on: .int)
        let tunable = item.distilledCrux().tunable()!
        #expect(tunable.key == "«fn (int, int, int) -> int: .input0 $0 .intMultiply $1 .intAdd $2 .intAdd»")
        // Neutral: 5 + 7.
        #expect(Self.replay(tunable.program(filling: tunable.originalFillers!), on: .int) == "12")
        // 5·3 − 1 + 7.
        let fillers: [any Item] = [IntItem(3), IntItem(-1), InstructionItem(.constant(0))]
        #expect(Self.replay(tunable.program(filling: fillers), on: .int) == "21")
    }

    @Test(arguments: [
        (PushInstruction.input(0), PushStack.int), (.input(1), .string), (.input(2), .bool), (.input(3), .char),
        (.input(4), .double), (.input(5), .vecInt)
    ])
    func `the neutral setting leaves every type as it was`(_ input: PushInstruction, _ stack: PushStack) {
        let item = Self.top(Distilled.ins(input), on: stack)
        let tunable = item.distilledCrux().tunable(sites: [.inputs, .output])!
        #expect(tunable.roles.contains { if case .control = $0 { true } else { false } })
        #expect(Self.replay(tunable.program(filling: tunable.originalFillers!), on: stack) == item.pretty())
    }

    @Test func `a bool's transform reaches every one-argument function`() {
        let item = Self.top(Distilled.ins(.input(2)), on: .bool)
        let tunable = item.distilledCrux().tunable()!
        func with(_ m: Bool, _ c: Bool) -> String? {
            Self.replay(tunable.program(filling: [BoolItem(m), BoolItem(c)]), on: .bool)
        }
        #expect(with(true, false) == "true")    // identity
        #expect(with(true, true) == "false")    // not
        #expect(with(false, false) == "false")  // always false
        #expect(with(false, true) == "true")    // always true
    }

    @Test func `a string can be framed and trimmed`() {
        let item = Self.top(Distilled.ins(.input(1)), on: .string)
        let tunable = item.distilledCrux().tunable()!
        let fillers: [any Item] = [StringItem("<"), StringItem(">"), IntItem(2), IntItem(1)]
        // "<hello>", 2 dropped from the front and 1 from the back.
        #expect(Self.replay(tunable.program(filling: fillers), on: .string) == "\"ello\"")
    }

    @Test func `a vector's elements are scaled and shifted, then trimmed`() {
        let item = Self.top(Distilled.ins(.input(5)), on: .vecInt)
        let tunable = item.distilledCrux().tunable()!
        // [1, 2, 3]·2 + 1, then nothing joined on and one element dropped from the front.
        let fillers: [any Item] = [IntItem(2), IntItem(1), VecIntItem([]), VecIntItem([]), IntItem(1), IntItem(0)]
        #expect(Self.replay(tunable.program(filling: fillers), on: .vecInt) == "[5, 7]")
    }

    @Test func `every use of an input shares its transform, or has its own`() {
        let item = Self.top(Distilled.ins(.input(0), .input(0), .intMultiply), on: .int)
        let shared = item.distilledCrux().tunable(.perDistinct)!
        let own = item.distilledCrux().tunable(.perUse)!
        #expect(shared.key == "«fn (int, int) -> int: .input0 $0 .intMultiply $1 .intAdd .input0 $0 .intMultiply $1 "
                + ".intAdd .intMultiply»")
        #expect(own.holeCount == 4)
        #expect(Self.replay(shared.program(filling: shared.originalFillers!), on: .int) == "25")
        #expect(Self.replay(own.program(filling: own.originalFillers!), on: .int) == "25")
    }

    @Test func `a shared hole is never filled out of order`() {
        // .input1's length, then .input0, then .input0 again beside a newer hole:
        // the second use of `.input0` must not jump ahead of it.
        let program = Distilled.ins(.input(0), .input(1), .stringLength, .intSubtract, .input(0), .intSubtract)
        let item = Self.top(program, on: .int)
        let skeleton = item.distilledCrux().skeleton()!
        #expect(Self.replay(skeleton.program(filling: skeleton.originalFillers!), on: .int) == item.pretty())
        let tunable = item.distilledCrux().tunable()!
        #expect(Self.replay(tunable.program(filling: tunable.originalFillers!), on: .int) == item.pretty())
    }
}
