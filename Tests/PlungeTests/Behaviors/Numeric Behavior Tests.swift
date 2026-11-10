//
//  Numeric Behavior Tests.swift
//  PlungeTests
//
//  Abs, negate, sign and power for ints and doubles; sqrt, exp, log and the
//  roundings for doubles. Every result is the
//  intended one or an error.
//

@testable import Plunge
import Testing

@Suite @MainActor
struct NumericBehaviorTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func ints(_ values: [Int], _ instruction: PushInstruction) -> (String, Int) {
        let inty = run(values.map { IntItem($0) } + [InstructionItem(instruction)])
        return (stackString(inty, .int), inty.stacks[.error]!.count)
    }

    static func doubles(_ values: [Double], _ instruction: PushInstruction) -> (String, Int) {
        let inty = run(values.map { DoubleItem($0) } + [InstructionItem(instruction)])
        return (stackString(inty, .double), inty.stacks[.error]!.count)
    }

    @Test func `int abs, negate and sign`() {
        #expect(Self.ints([-5], .intAbs) == ("[ 5 ]", 0))
        #expect(Self.ints([5], .intNegate) == ("[ -5 ]", 0))
        #expect(Self.ints([-7], .intSign) == ("[ -1 ]", 0))
        #expect(Self.ints([0], .intSign) == ("[ 0 ]", 0))
        #expect(Self.ints([Int.min], .intAbs).1 == 1, "|Int.min| overflows")
    }

    @Test func `int power is base to the exponent, as written`() {
        #expect(Self.ints([2, 10], .intPow) == ("[ 1024 ]", 0))
        #expect(Self.ints([7, 0], .intPow) == ("[ 1 ]", 0))
        #expect(Self.ints([-1, -3], .intPow) == ("[ -1 ]", 0))
        #expect(Self.ints([2, -1], .intPow).1 == 1, "no int result")
        #expect(Self.ints([10, 40], .intPow).1 == 1, "overflow")
    }

    @Test func `double abs, negate, sign and power`() {
        #expect(Self.doubles([-2.5], .doubleAbs) == ("[ 2.5 ]", 0))
        #expect(Self.doubles([2.5], .doubleNegate) == ("[ -2.5 ]", 0))
        #expect(Self.doubles([-0.1], .doubleSign) == ("[ -1.0 ]", 0))
        #expect(Self.doubles([.nan], .doubleSign).1 == 1)
        #expect(Self.doubles([2.0, 0.5], .doublePow).0 == "[ 1.4142135623730951 ]")
        #expect(Self.doubles([-8.0, 0.5], .doublePow).1 == 1, "no real result")
    }

    @Test func `roots, exponentials and logarithms refuse outside their domains`() {
        #expect(Self.doubles([9.0], .doubleSqrt) == ("[ 3.0 ]", 0))
        #expect(Self.doubles([-1.0], .doubleSqrt).1 == 1)
        #expect(Self.doubles([0.0], .doubleExp) == ("[ 1.0 ]", 0))
        #expect(Self.doubles([1000.0], .doubleExp).1 == 1, "overflow")
        #expect(Self.doubles([1.0], .doubleLog) == ("[ 0.0 ]", 0))
        #expect(Self.doubles([0.0], .doubleLog).1 == 1)
    }

    @Test func `the three roundings`() {
        #expect(Self.doubles([-2.5], .doubleFloor).0 == "[ -3.0 ]")
        #expect(Self.doubles([-2.5], .doubleCeil).0 == "[ -2.0 ]")
        #expect(Self.doubles([2.5], .doubleRound).0 == "[ 3.0 ]")
        #expect(Self.doubles([-2.5], .doubleRound).0 == "[ -3.0 ]", "halves away from zero")
    }

    @Test func `absolute value in one step, beside the older five`() {
        let older = Self.run([IntItem(-5), InstructionItem(.intDup), IntItem(0), InstructionItem(.intSwap),
                              InstructionItem(.intSubtract), InstructionItem(.intMax)])
        #expect(stackString(older, .int) == Self.ints([-5], .intAbs).0)
    }
}
