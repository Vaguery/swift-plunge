//
//  Crux Construction Tests.swift
//  PlungeTests
//
//  Building new structures from known ones (2026-11-16): the five steps, their
//  type checks, hole renumbering, and fills that replay to the expected value.
//

@testable import Plunge
import Testing

@Suite
struct CruxConstructionTests {
    static let inputs: [PushInstruction: any Item] = [.input0: DoubleItem(3), .input1: DoubleItem(-2)]

    /// The skeleton of a lone input read: `$0`.
    static var input: AbstractCrux {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, program: [InstructionItem(.input0)])
        inty.run(stepLimit: 100)
        return inty.stacks[.double]!.first!.distilledCrux().skeleton()!
    }

    static func value(_ crux: AbstractCrux, _ fillers: PushInstruction...) -> Double? {
        let redo = Interpreter()
        redo.load(inputs: inputs, program: crux.program(filling: fillers.map { InstructionItem($0) }))
        redo.run(stepLimit: 10_000)
        return redo.stacks[.double]!.first?.exactly(DoubleItem.self)?.value
    }

    static func body(_ crux: AbstractCrux) -> String {
        String(crux.key.split(separator: ": ", maxSplits: 1).last ?? "").replacingOccurrences(of: "»", with: "")
    }

    @Test func `wrap, extend and reuse build from a lone input`() throws {
        let start = Self.input
        #expect(Self.body(start) == "$0")
        let wrapped = try #require(start.wrapped(by: .doubleAbs))
        #expect(Self.body(wrapped) == "$0 .doubleAbs")
        let extended = try #require(start.extended(by: .doubleMultiply, with: .input(.double)))
        #expect(Self.body(extended) == "$0 $1 .doubleMultiply" && extended.holeCount == 2)
        if case .anyInput(let stack) = extended.roles[1] { #expect(stack == .double) } else { Issue.record("role") }
        #expect(Self.value(extended, .input0, .input1) == -6)
        let leafFirst = try #require(start.extended(by: .doubleSubtract, with: .input(.double), leafFirst: true))
        #expect(Self.body(leafFirst) == "$0 $1 .doubleSubtract")
        #expect(Self.value(leafFirst, .input1, .input0) == -5)    // −2 − 3
        let squared = try #require(start.reused(by: .doubleMultiply))
        #expect(Self.body(squared) == "$0 .doubleDup .doubleMultiply")
        #expect(Self.value(squared, .input0) == 9)
    }

    @Test func `combine keeps the holes distinct, and graft splices a structure into a hole`() throws {
        let start = Self.input
        let squared = try #require(start.reused(by: .doubleMultiply))
        let difference = try #require(start.combined(with: squared, by: .doubleSubtract))
        #expect(Self.body(difference) == "$0 $1 .doubleDup .doubleMultiply .doubleSubtract")
        #expect(Self.value(difference, .input0, .input1) == -1)  // 3 − (−2)²
        // x1·(x1 + x2): graft a sum into the second hole of a product.
        let product = try #require(start.extended(by: .doubleMultiply, with: .input(.double)))
        let sum = try #require(start.extended(by: .doubleAdd, with: .input(.double)))
        let grafted = try #require(product.grafted(sum, into: 1))
        #expect(Self.body(grafted) == "$0 $1 $2 .doubleAdd .doubleMultiply" && grafted.holeCount == 3)
        #expect(Self.value(grafted, .input0, .input0, .input1) == 3)  // 3·(3 + (−2))
        // Steps compose: wrap the graft.
        let negated = grafted.wrapped(by: .doubleNegate).map(Self.body)
        #expect(negated == "$0 $1 $2 .doubleAdd .doubleMultiply .doubleNegate")
    }

    @Test func `a step whose types don't fit gives nothing`() {
        let start = Self.input
        #expect(start.wrapped(by: .intAdd) == nil)                       // takes ints
        #expect(start.wrapped(by: .doubleAdd) == nil)                    // takes two doubles
        #expect(start.reused(by: .doubleAbs) == nil)                     // takes one
        #expect(start.extended(by: .doubleMultiply, with: .input(.int)) == nil)
        #expect(start.grafted(start, into: 5) == nil)
        #expect(start.wrapped(by: .doubleStackDepth) == nil)             // observes, takes nothing
    }
}
