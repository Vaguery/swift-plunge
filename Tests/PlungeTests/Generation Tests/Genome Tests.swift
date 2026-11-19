//
//  Genome Tests.swift
//  PlungeTests
//
//  The genome a search edits, and the program it translates to (2026-11-19).
//  A genome is instruction tokens, constants, a permutation, a code target and
//  an optional plan. Without a plan, the default (Fibonacci) plan decides where
//  the code blocks are; with one, the plan does. Any program can be turned back
//  into a genome that gives it again. Each test states one rule.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct GenomeTests {

    /// A small deterministic generator, so these tests draw the same cases every run.
    struct SplitMix: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Distinct instructions to use as tokens, so a program shows where each came from.
    static let palette: [PushInstruction] = Array(InstructionName.allCases.prefix(200).map(PushInstruction.named))

    static func text(_ items: [any Item]) -> String { CodeItem(items).pretty() }

    // MARK: - The default plan

    @Test func `the default plan gives the same programs the Fibonacci translation always gave`() {
        var random = SplitMix(state: 1)
        for _ in 0..<2_000 {
            let tokens = (0..<Int.random(in: 0..<300, using: &random)).map { _ in Self.palette.randomElement(using: &random)! }
            let permutation = (0..<Int.random(in: 0..<15, using: &random)).map { _ in Double.random(in: 0...1, using: &random) }
            let genome = Genome(tokens: tokens, permutation: permutation)
            let classic = FibonacciGenome.translate(tokens.map { InstructionItem($0) }, permutation: permutation)
            #expect(Self.text(genome.translate()) == Self.text(classic))
        }
    }

    @Test func `the default plan, written out`() {
        // 12 tokens: blocks of 1, 1, 2 and 3 are cut from the head (7 tokens, the
        // first total past a third), and placed ahead of the other 5 in cut order.
        #expect(Genome.defaultPlan(tokenCount: 12, permutation: [], codeTarget: nil) == [
            GenomePiece(start: 0, length: 1, at: 0), GenomePiece(start: 0, length: 1, at: 1),
            GenomePiece(start: 0, length: 2, at: 2), GenomePiece(start: 0, length: 3, at: 3)
        ])
        // A permutation changes only where each block is placed: the order its
        // values sort into, here 1, 3, 2, 0.
        let placed = Genome.defaultPlan(tokenCount: 12, permutation: [0.9, 0.1, 0.5, 0.3], codeTarget: nil)
        #expect(placed.map(\.length) == [1, 1, 2, 3])
        let genome = Genome(tokens: Array(Self.palette.prefix(12)), permutation: [0.9, 0.1, 0.5, 0.3])
        let blocks = genome.translate().prefix(4).map { ($0 as? CodeItem)?.value.count }
        #expect(blocks == [1, 3, 2, 1], "the blocks of cuts 1, 3, 2 and 0, by their sizes")
    }

    @Test func `the code target decides how much becomes code blocks`() {
        let tokens = Array(Self.palette.prefix(30))
        let none = Genome(tokens: tokens, codeTarget: 0).translate()
        #expect(none.allSatisfy { $0 is InstructionItem }, "a target of 0 cuts no blocks")
        let all = Genome(tokens: tokens, codeTarget: 1).translate()
        #expect(all.allSatisfy { $0 is CodeItem }, "a target of 1 cuts every token")
        // Nil is the third, computed exactly; a third as a number agrees.
        for count in 1...2_000 {
            #expect(Genome.defaultLengths(tokenCount: count, codeTarget: nil)
                    == Genome.defaultLengths(tokenCount: count, codeTarget: 1.0 / 3.0))
        }
    }

    // MARK: - Explicit plans

    /// `a ( b ( c d ) ( ) e ) f ( g )`, from the tokens `a b c d e f g`.
    static let example: (tokens: [PushInstruction], plan: [GenomePiece], program: String) = {
        let tokens: [PushInstruction] = [.intAdd, .intSubtract, .intMultiply, .intQuot, .intMod, .intInc, .intDec]
        let plan = [
            GenomePiece(start: 2, length: 2, into: 2, at: 1),     // ( c d ), into piece 2
            GenomePiece(start: 2, length: 0, into: 2, at: 2),     // ( ), into piece 2
            GenomePiece(start: 1, length: 2, into: nil, at: 1),   // ( b … e ), into the trunk
            GenomePiece(start: 2, length: 1, into: nil, at: 3)    // ( g ), into the trunk
        ]
        return (tokens, plan, "( .intAdd ( .intSubtract ( .intMultiply .intQuot ) ( ) .intMod ) .intInc ( .intDec ) )")
    }()

    @Test func `an explicit plan nests code blocks anywhere`() {
        let genome = Genome(tokens: Self.example.tokens, plan: Self.example.plan)
        #expect(Self.text(genome.translate()) == Self.example.program)
    }

    @Test func `an explicit plan replaces the permutation and the code target`() {
        let genome = Genome(tokens: Self.example.tokens, permutation: [0.5, 0.1], codeTarget: 1,
                            plan: Self.example.plan)
        #expect(Self.text(genome.translate()) == Self.example.program)
    }

    @Test func `any plan gives a program, however it is edited`() {
        var random = SplitMix(state: 2)
        for _ in 0..<2_000 {
            let tokens = (0..<Int.random(in: 0..<40, using: &random)).map { _ in Self.palette.randomElement(using: &random)! }
            let plan = (0..<Int.random(in: 0..<8, using: &random)).map { _ in
                GenomePiece(start: Int.random(in: -5...50, using: &random), length: Int.random(in: -5...50, using: &random),
                            into: Bool.random(using: &random) ? Int.random(in: -3...10, using: &random) : nil,
                            at: Int.random(in: -5...50, using: &random))
            }
            let program = Genome(tokens: tokens, plan: plan).translate()
            // Every token appears exactly once, in some code block or the trunk.
            func count(_ items: [any Item]) -> Int {
                items.reduce(0) { $0 + (($1 as? CodeItem).map { count($0.value) } ?? 1) }
            }
            #expect(count(program) == tokens.count)
        }
    }

    @Test func `each program position maps back to its token`() {
        let genome = Genome(tokens: Self.example.tokens, plan: Self.example.plan)
        // a ( b ( c d ) ( ) e ) f ( g ): code blocks are nil.
        #expect(genome.tokenIndices() == [0, nil, 1, nil, 2, 3, nil, 4, 5, nil, 6])
    }

    // MARK: - From a program back to a genome

    static func randomProgram(_ random: inout SplitMix, budget: inout Int, depth: Int = 0) -> [any Item] {
        var items: [any Item] = []
        while budget > 0, Double.random(in: 0..<1, using: &random) < 0.85 {
            if depth < 4, Double.random(in: 0..<1, using: &random) < 0.25 {
                items.append(CodeItem(randomProgram(&random, budget: &budget, depth: depth + 1)))
            } else {
                budget -= 1
                items.append(InstructionItem(Self.palette.randomElement(using: &random)!))
            }
        }
        return items
    }

    @Test func `every program comes back from its genome`() {
        var random = SplitMix(state: 3)
        for _ in 0..<2_000 {
            var budget = Int.random(in: 0..<60, using: &random)
            let program = Self.randomProgram(&random, budget: &budget)
            #expect(Self.text(Genome(program: program).translate()) == Self.text(program))
        }
    }

    @Test func `the explicit example comes back as its plan`() {
        let genome = Genome(tokens: Self.example.tokens, plan: Self.example.plan)
        let back = Genome(program: genome.translate())
        #expect(back.tokens == Self.example.tokens, "tokens in reading order")
        #expect(back.plan == Self.example.plan)
    }

    @Test func `a program the default plan could make comes back without a plan`() {
        var random = SplitMix(state: 4)
        for _ in 0..<500 {
            let tokens = (0..<Int.random(in: 1..<300, using: &random)).map { _ in Self.palette.randomElement(using: &random)! }
            let permutation = (0..<Int.random(in: 0..<15, using: &random)).map { _ in Double.random(in: 0...1, using: &random) }
            let program = Genome(tokens: tokens, permutation: permutation).translate()
            let back = Genome(program: program)
            #expect(back.plan == nil)
            #expect(back.codeTarget == nil, "the default third fits, so none is set")
            #expect(Self.text(back.translate()) == Self.text(program))
        }
    }

    @Test func `a long program with only a few blocks gets the code target that makes them`() {
        // Blocks of 1, 1, 2 and 3 tokens, then 2,993 more: a third would cut more
        // blocks, so the genome records a smaller target, with no explicit plan.
        var program: [any Item] = [1, 1, 2, 3].map { size in
            CodeItem(Array(Self.palette.prefix(size)).map { InstructionItem($0) })
        }
        program += (0..<2_993).map { InstructionItem(Self.palette[$0 % Self.palette.count]) }
        let back = Genome(program: program)
        #expect(back.plan == nil)
        let target = try? #require(back.codeTarget)
        #expect(target.map { $0 >= 4.0 / 3_000 && $0 < 7.0 / 3_000 } == true)
        #expect(Self.text(back.translate()) == Self.text(program))
    }

    @Test func `a flat program comes back with a code target of 0`() {
        let program: [any Item] = Self.palette.prefix(20).map { InstructionItem($0) }
        let back = Genome(program: program)
        #expect(back.plan == nil && back.codeTarget == 0)
        #expect(Self.text(back.translate()) == Self.text(program))
    }

    @Test func `the same program always gives the same genome`() throws {
        var random = SplitMix(state: 5)
        var budget = 50
        let program = Self.randomProgram(&random, budget: &budget)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(Genome(program: program)) == encoder.encode(Genome(program: program)))
    }

    @Test func `literals in a program become constants of any type`() {
        let program: [any Item] = [IntItem(3), InstructionItem(.intAdd), CodeItem([StringItem("fizz"), BoolItem(true)])]
        let back = Genome(program: program, constants: [.constant(5): IntItem(9)])
        // New slots are numbered after the highest one given.
        #expect(back.tokens == [.constant(6), .intAdd, .constant(7), .constant(8)])
        #expect(back.constants[.constant(5)]?.pretty() == "9")
        #expect(back.constants[.constant(6)]?.pretty() == "3")
        #expect(back.constants[.constant(7)]?.pretty() == "\"fizz\"")
        #expect(back.constants[.constant(8)]?.pretty() == "true")
        #expect(Self.text(back.translate()) == "( .constant6 .intAdd ( .constant7 .constant8 ) )")
    }

    // MARK: - Individuals and encoding

    @Test func `an individual made from a genome runs the genome's translation`() {
        let genome = Genome(tokens: [.constant(0), .input(0), .intAdd], constants: [.constant(0): IntItem(10)], codeTarget: 0)
        let individual = Individual(id: "g", genome: genome)
        #expect(Self.text(individual.program) == "( .constant0 .input0 .intAdd )")
        #expect(individual.constants[.constant(0)]?.pretty() == "10")
        #expect(individual.genome != nil)
        #expect(Individual(id: "p", program: []).genome == nil)
    }

    @Test func `a genome and an individual carrying one round-trip through JSON`() throws {
        let genome = Genome(tokens: Self.example.tokens, constants: [.constant(2): StringItem("s")],
                            permutation: [0.25, 0.75], codeTarget: 0.5, plan: Self.example.plan)
        let restored = try JSONDecoder().decode(Genome.self, from: JSONEncoder().encode(genome))
        #expect(restored.tokens == genome.tokens && restored.plan == genome.plan)
        #expect(restored.permutation == genome.permutation && restored.codeTarget == genome.codeTarget)
        #expect(restored.constants[.constant(2)]?.pretty() == "\"s\"")
        #expect(Self.text(restored.translate()) == Self.example.program)

        let individual = Individual(id: "i", genome: genome)
        let back = try JSONDecoder().decode(Individual.self, from: JSONEncoder().encode(individual))
        #expect(back.genome?.plan == genome.plan)
        #expect(Self.text(back.program) == Self.example.program)
    }

    @Test func `an empty genome is an empty program`() {
        #expect(Genome(tokens: []).translate().isEmpty)
        #expect(Genome(program: []).tokens.isEmpty)
    }
}
