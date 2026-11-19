//
//  Crux Forms Example Tests.swift
//  PlungeTests
//
//  One small double-arithmetic program carried through every form of its crux:
//  the crux, the distilled crux, the abstract crux, the tunable crux and the
//  skeleton crux (2026-11-15). The printed forms are pinned, so this is also the worked
//  example for the documentation.
//
//  The program computes x·(c0·c1) + (2 + 3)·y, with some unrelated work mixed in:
//  x and y are `.input0` and `.input1`, and c0 and c1 the constant slots
//  `.constant10` and `.constant11`.
//

@testable import Plunge
import Testing

@Suite
struct CruxFormsExampleTests {

    static let program: [any Item] = [
        InstructionItem(.input(0)), InstructionItem(.constant(10)), InstructionItem(.constant(11)),
        InstructionItem(.doubleMultiply), InstructionItem(.doubleMultiply),
        BoolItem(true), InstructionItem(.boolNot),                        // unrelated
        DoubleItem(2), DoubleItem(3), InstructionItem(.doubleAdd),
        IntItem(7), InstructionItem(.intDup), InstructionItem(.intAdd),   // unrelated
        InstructionItem(.input(1)), InstructionItem(.doubleMultiply),
        InstructionItem(.doubleAdd)
    ]
    static let inputs: [PushInstruction: any Item] = [.input(0): DoubleItem(4), .input(1): DoubleItem(10)]
    static let constants: [PushInstruction: any Item] = [.constant(10): DoubleItem(0.5), .constant(11): DoubleItem(3)]

    static func result() -> any Item {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, constants: constants, program: program)
        inty.run()
        return inty.stacks[.double]!.first!
    }

    static func replay(_ program: [any Item]) -> String? {
        let redo = Interpreter.recordingProvenance()
        redo.load(inputs: inputs, constants: constants, program: program)
        redo.run()
        return redo.stacks[.double]!.first?.pretty()
    }

    @Test func `the forms of one crux`() {
        let item = Self.result()
        #expect(item.pretty() == "56.0")
        // The crux: only what the value depends on; the bool and int work is gone.
        #expect(CodeItem(item.crux()).pretty() == "( .input0 .constant10 .constant11 .doubleMultiply .doubleMultiply "
                + "2.0 3.0 .doubleAdd .input1 .doubleMultiply .doubleAdd )")
        // Distilled: the work on constants alone is its value.
        let distilled = item.distilledCrux()
        #expect(CodeItem(distilled.program).pretty() == "( .input0 «distilled .doubleMultiply: 1.5» .doubleMultiply "
                + "«distilled .doubleAdd: 5.0» .input1 .doubleMultiply .doubleAdd )")
        #expect(distilled.derived.map(\.slotsRead) == [[.constant(10), .constant(11)], []])
        #expect(distilled.derived.map { CodeItem($0.origin).pretty() }
                == ["( .constant10 .constant11 .doubleMultiply )", "( 2.0 3.0 .doubleAdd )"])
        // Abstract: the derived constants are holes; the inputs stay in place.
        let abstract = distilled.abstracted()!
        #expect(abstract.key
                == "«fn (dbl, dbl) -> dbl: .input0 $0 .doubleMultiply $1 .input1 .doubleMultiply .doubleAdd»")
        #expect(Self.replay(abstract.program(filling: abstract.originalFillers!)) == "56.0")
        #expect(Self.replay(abstract.program(filling: [DoubleItem(2), DoubleItem(1)])) == "18.0")
        // Tunable: each input, still in place, is scaled and shifted by control holes, neutral at 1 and 0.
        let tunable = distilled.tunable()!
        #expect(tunable.key == "«fn (dbl, dbl, dbl, dbl, dbl, dbl) -> dbl: "
                + ".input0 $0 .doubleMultiply $1 .doubleAdd $2 .doubleMultiply "
                + "$3 .input1 $4 .doubleMultiply $5 .doubleAdd .doubleMultiply .doubleAdd»")
        #expect(Self.replay(tunable.program(filling: tunable.originalFillers!)) == "56.0")
        // Tuned: x scaled by 2 and y shifted by 1 gives (2·4)·1.5 + 5·(10 + 1).
        let tuned: [any Item] = [DoubleItem(2), DoubleItem(0), DoubleItem(1.5), DoubleItem(5), DoubleItem(1),
                                 DoubleItem(1)]
        #expect(Self.replay(tunable.program(filling: tuned)) == "67.0")
        // Skeleton: the inputs are holes too.
        let skeleton = distilled.skeleton()!
        #expect(skeleton.key
                == "«fn (dbl, dbl, dbl, dbl) -> dbl: $0 $1 .doubleMultiply $2 $3 .doubleMultiply .doubleAdd»")
        #expect(Self.replay(skeleton.program(filling: skeleton.originalFillers!)) == "56.0")
    }
}
