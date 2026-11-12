//
//  Vector NaN Tests.swift
//  PlungeTests
//
//  One rule for NaN in vectors of doubles (since 2026-11-09):
//  every NaN is the same NaN, and it sorts above every number. NaNs reach a
//  program only through its inputs or literals; nothing computes one.
//

@testable import Plunge
import Testing

@Suite
struct VectorNaNTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }
    static let nan = Double.nan

    @Test func `a NaN can be found, counted and removed`() {
        let v = VecDoubleItem([1, Self.nan, 2, Self.nan])
        #expect(stackString(Self.run([v, DoubleItem(Self.nan), Self.op(.vecDoubleContains)]), .bool) == "[ true ]")
        #expect(stackString(Self.run([v, DoubleItem(Self.nan), Self.op(.vecDoubleIndexOf)]), .int) == "[ 1 ]")
        #expect(stackString(Self.run([v, DoubleItem(Self.nan), Self.op(.vecDoubleOccurrencesOf)]), .int) == "[ 2 ]")
        #expect(stackString(Self.run([v, DoubleItem(Self.nan), Self.op(.vecDoubleRemove)]), .vecDouble)
                == "[ [1.0, 2.0] ]")
    }

    @Test func `Distinct keeps one NaN, and the set operations see it`() {
        let v = VecDoubleItem([Self.nan, 1, Self.nan])
        #expect(stackString(Self.run([v, Self.op(.vecDoubleDistinct)]), .vecDouble) == "[ [nan, 1.0] ]")
        let w = VecDoubleItem([Self.nan])
        #expect(stackString(Self.run([v, w, Self.op(.vecDoubleIntersect)]), .vecDouble) == "[ [nan, nan] ]")
        #expect(stackString(Self.run([v, w, Self.op(.vecDoubleDifference)]), .vecDouble) == "[ [1.0] ]")
    }

    @Test func `a NaN sorts above every number, in comparisons and extremes alike`() {
        let low = VecDoubleItem([0]), high = VecDoubleItem([Self.nan])
        #expect(stackString(Self.run([low, high, Self.op(.vecDoubleLT)]), .bool) == "[ true ]")
        #expect(stackString(Self.run([high, low, Self.op(.vecDoubleGT)]), .bool) == "[ true ]")
        #expect(stackString(Self.run([high, high, Self.op(.vecDoubleGTE)]), .bool) == "[ true ]")
        let mixed = VecDoubleItem([3, Self.nan, 7])
        #expect(stackString(Self.run([mixed, Self.op(.vecDoubleMax)]), .double) == "[ nan ]")
        #expect(stackString(Self.run([mixed, Self.op(.vecDoubleMin)]), .double) == "[ 3.0 ]")
    }

    @Test func `a vector holding a NaN equals itself`() {
        let v = VecDoubleItem([1, Self.nan])
        #expect(v.isEqual(to: VecDoubleItem([1, Self.nan])))
        #expect(stackString(Self.run([v, VecDoubleItem([1, Self.nan]), Self.op(.vecDoubleEq)]), .bool) == "[ true ]")
    }
}
