//
//  NaN Comparison Tests.swift
//  PlungeTests
//
//  Double comparisons follow IEEE 754: any comparison with a NaN is false.
//  `doubleGTE`/`doubleLTE` used to be true, because they were "not less than" /
//  "not greater than" (fixed 2026-11-08).
//
//  Vector comparisons are vector operations, and since 2026-11-09 those treat
//  every NaN as one value above every number (`DoubleKey`),
//  so a NaN decides a vector order like any other element.
//

@testable import Plunge
import Testing

@Suite @MainActor
struct NaNComparisonTests {

    func compare(_ instruction: PushInstruction, _ y: Double, _ x: Double) -> Bool {
        let inty = Interpreter.recordingProvenance()
        loadDoubles(inty, doubles: [x, y])   // `y x .instruction`
        doThis(instruction, to: inty)
        return (topItem(inty, .bool) as! BoolItem).value
    }

    @Test(arguments: [PushInstruction.doubleGT, .doubleGTE, .doubleLT, .doubleLTE])
    func `every double comparison with a NaN is false`(instruction: PushInstruction) {
        #expect(!compare(instruction, .nan, 1.0))
        #expect(!compare(instruction, 1.0, .nan))
        #expect(!compare(instruction, .nan, .nan))
    }

    @Test func `ordinary comparisons are unchanged`() {
        #expect(compare(.doubleGTE, 2, 1) && compare(.doubleGTE, 1, 1) && !compare(.doubleGTE, 1, 2))
        #expect(compare(.doubleLTE, 1, 2) && compare(.doubleLTE, 1, 1) && !compare(.doubleLTE, 2, 1))
    }

    func compareVectors(_ instruction: PushInstruction, _ y: [Double], _ x: [Double]) -> Bool {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.vecDouble]!.prepend(contentsOf: [VecDoubleItem(x), VecDoubleItem(y)] as [any Item])
        doThis(instruction, to: inty)
        return (topItem(inty, .bool) as! BoolItem).value
    }

    @Test func `in vectors a NaN sorts above every number`() {
        #expect(compareVectors(.vecDoubleGTE, [.nan], [1]))
        #expect(!compareVectors(.vecDoubleLTE, [.nan], [1]))
        #expect(!compareVectors(.vecDoubleGTE, [1], [.nan]))
        #expect(compareVectors(.vecDoubleGTE, [.nan], [.nan]), "one NaN equals another")
        // Decided before the NaN is reached: ordinary.
        #expect(compareVectors(.vecDoubleGTE, [2, .nan], [1, 5]))
        // And without NaN, as before.
        #expect(compareVectors(.vecDoubleGTE, [1, 2], [1, 2]))
        #expect(compareVectors(.vecDoubleLTE, [1, 2], [1, 3]))
        #expect(!compareVectors(.vecDoubleLTE, [1, 3], [1, 2]))
    }
}
