//
//  Crux Forms Example Tests.swift
//  PlungeTests
//
//  One small double-arithmetic program carried through every form of its crux:
//  the crux, the distilled crux, the abstract crux and the tunable crux
//  (2026-11-15). The printed forms are pinned, so this is also the worked
//  example for the documentation.
//
//  The program computes x·(c0·c1) + (2 + 3)·y, with some unrelated work mixed in:
//  x and y are `.input0` and `.input1`, and c0 and c1 the constant slots
//  `.double0` and `.double1`.
//

@testable import Plunge
import Testing

@Suite
struct CruxFormsExampleTests {

    static let program: [any Item] = [
        InstructionItem(.input0), InstructionItem(.double0), InstructionItem(.double1),
        InstructionItem(.doubleMultiply), InstructionItem(.doubleMultiply),
        BoolItem(true), InstructionItem(.boolNot),                        // unrelated
        DoubleItem(2), DoubleItem(3), InstructionItem(.doubleAdd),
        IntItem(7), InstructionItem(.intDup), InstructionItem(.intAdd),   // unrelated
        InstructionItem(.input1), InstructionItem(.doubleMultiply),
        InstructionItem(.doubleAdd)
    ]
    static let inputs: [PushInstruction: any Item] = [.input0: DoubleItem(4), .input1: DoubleItem(10)]
    static let constants: [PushInstruction: any Item] = [.double0: DoubleItem(0.5), .double1: DoubleItem(3)]

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
        #expect(CodeItem(item.crux()).pretty() == "( .input0 .double0 .double1 .doubleMultiply .doubleMultiply "
                + "2.0 3.0 .doubleAdd .input1 .doubleMultiply .doubleAdd )")
        // Distilled: the work on constants alone is its value.
        let distilled = item.distilledCrux()
        #expect(CodeItem(distilled.program).pretty() == "( .input0 «distilled .doubleMultiply: 1.5» .doubleMultiply "
                + "«distilled .doubleAdd: 5.0» .input1 .doubleMultiply .doubleAdd )")
        #expect(distilled.derived.map(\.slotsRead) == [[.double0, .double1], []])
        #expect(distilled.derived.map { CodeItem($0.origin).pretty() }
                == ["( .double0 .double1 .doubleMultiply )", "( 2.0 3.0 .doubleAdd )"])
        // Abstract: inputs and derived constants are holes.
        let abstract = distilled.abstracted()!
        #expect(abstract.key
                == "«fn (dbl, dbl, dbl, dbl) -> dbl: $0 $1 .doubleMultiply $2 $3 .doubleMultiply .doubleAdd»")
        #expect(Self.replay(abstract.program(filling: abstract.originalFillers!)) == "56.0")
        // Tunable: each input is scaled and shifted by control holes, neutral at 1 and 0.
        let tunable = distilled.tunable()!
        #expect(tunable.key == "«fn (dbl, dbl, dbl, dbl, dbl, dbl, dbl, dbl) -> dbl: "
                + "$0 $1 .doubleMultiply $2 .doubleAdd $3 .doubleMultiply "
                + "$4 $5 $6 .doubleMultiply $7 .doubleAdd .doubleMultiply .doubleAdd»")
        #expect(Self.replay(tunable.program(filling: tunable.originalFillers!)) == "56.0")
        // Tuned: x scaled by 2 and y shifted by 1 gives (2·4)·1.5 + 5·(10 + 1).
        let tuned: [any Item] = [InstructionItem(.input0), DoubleItem(2), DoubleItem(0), DoubleItem(1.5),
                                 DoubleItem(5), InstructionItem(.input1), DoubleItem(1), DoubleItem(1)]
        #expect(Self.replay(tunable.program(filling: tuned)) == "67.0")
    }
}
