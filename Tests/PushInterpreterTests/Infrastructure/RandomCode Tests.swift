//
//  RandomCode Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/17/26.
//
//  The generator's two promises: **a gene stream is instruction tokens and
//  nothing else**, and **a mix means what it says**.
//
//  The second is not obvious, and getting it wrong is how a diagnostic ends up
//  measuring the language's shape instead of the mix under test — constants and
//  inputs live *in* `Interpreter.language`, so a "40% other" built on
//  `randomInstruction()` was really ~33% other, ~31% constants and ~26% inputs.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct RandomCodeTests {

    /// Realized proportions of a large sample, by tag.
    func composition(of mix: InstructionMix, draws: Int = 20_000) -> [InstructionTag: Double] {
        fuzzRNG = SeededRNG(seed: 424_242)
        var counts: [InstructionTag: Int] = [:]
        for _ in 0..<draws {
            let token = RandomCode.randomInstruction(from: mix)
            let tag = InstructionTag.allCases.first {
                Interpreter.instructions(tagged: $0).contains(token)
            }!
            counts[tag, default: 0] += 1
        }
        return counts.mapValues { Double($0) / Double(draws) }
    }

    /// Sampling is uniform *within* a tag and weighted *between* them — so this is
    /// the test that a mix is not quietly re-weighted by how many instructions a
    /// tag happens to contain.
    @Test func `equal shares really are equal`() {
        let realized = composition(of: .equalShares)
        for tag in InstructionTag.allCases {
            #expect(abs((realized[tag] ?? 0) - 0.25) < 0.02,
                    "\(tag) drew \(realized[tag] ?? 0), wanted 0.25")
        }
    }

    /// A third to the target, the remainder three ways.
    @Test func `enriched is a third against two-ninths`() {
        let realized = composition(of: .enriched(.combinator))
        #expect(abs((realized[.combinator] ?? 0) - 0.333) < 0.02)
        for tag in InstructionTag.allCases where tag != .combinator {
            #expect(abs((realized[tag] ?? 0) - 0.222) < 0.02, "\(tag)")
        }
    }

    /// A ninth to the target, the remainder three ways — 29.6% each, not 30%.
    @Test func `depleted is a ninth against the remainder split three ways`() {
        let realized = composition(of: .depleted(.constant))
        #expect(abs((realized[.constant] ?? 0) - 0.111) < 0.02)
        for tag in InstructionTag.allCases where tag != .constant {
            #expect(abs((realized[tag] ?? 0) - 0.296) < 0.02, "\(tag)")
        }
    }

    /// The control, and the reason the others exist: drawing from the language as
    /// it is over-weights whatever the language happens to hold most of —
    /// combinators are a large minority, inputs a sliver — a shape nobody chose.
    ///
    /// Compared against the *actual* tag fractions rather than frozen numbers, so
    /// it stays true as `.other` grows with each new instruction. What it pins is
    /// that `uniformOverLanguage` really is proportional to tag size, and that the
    /// language is furniture-heavy and input-starved.
    @Test func `the language's own shape is not neutral`() {
        let realized = composition(of: .uniformOverLanguage)
        let total = Double(Interpreter.language.count)
        func fraction(_ tag: InstructionTag) -> Double {
            Double(Interpreter.instructions(tagged: tag).count) / total
        }
        #expect(abs((realized[.combinator] ?? 0) - fraction(.combinator)) < 0.02)
        #expect(abs((realized[.constant] ?? 0) - fraction(.constant)) < 0.02)
        #expect((realized[.input] ?? 0) < 0.03, "inputs are a sliver of the language")
        #expect(fraction(.combinator) > 0.25, "furniture is a large minority")
    }

    /// A weight of zero means never.
    @Test func `a tag weighted zero is never drawn`() {
        let realized = composition(of: InstructionMix([.other: 1, .combinator: 1]), draws: 2_000)
        #expect(realized[.constant] == nil)
        #expect(realized[.input] == nil)
        #expect(abs((realized[.other] ?? 0) - 0.5) < 0.03)
    }

    @Test func `the standard sweep is nine mixes plus the control`() {
        let names = InstructionMix.standardSweep.map(\.name)
        #expect(names.count == 10)
        #expect(names.first == "equal")
        #expect(names.contains("combinator-rich"))
        #expect(names.contains("combinator-poor"))
        #expect(names.last == "language-shaped")
    }


    // MARK: - what a gene may be

    /// **Instruction tokens and nothing else.** No literals — every value reaches
    /// a program through a constant or an input token, which is what lets a search
    /// tune an individual's constants independently of its structure.
    ///
    /// And **never an IteratorItem**: an iterator is a live loop rather than a
    /// value, and the instructions construct them.
    @Test func `a gene stream is instruction tokens only`() {
        fuzzRNG = SeededRNG(seed: 7)
        let program = RandomCode.randomProgram(3_000)

        #expect(program.count == 3_000)
        #expect(program.allSatisfy { $0 is InstructionItem },
                "a literal, a block or an iterator got into the gene pool")
        #expect(program.contains { $0 is IteratorItem } == false)

        // Every token names a real behavior — nothing is invented from parts.
        let names = program.compactMap { ($0 as? InstructionItem)?.value }
        #expect(names.allSatisfy { Interpreter.language[$0] != nil })
    }

    /// The genome's *other* half: constant and input bindings can be any Item at
    /// all, including a code block. That asymmetry is deliberate — it is a value,
    /// not a gene in the instruction stream.
    @Test func `a bound value may be anything except an iterator`() {
        fuzzRNG = SeededRNG(seed: 11)
        let values = (0..<400).map { _ in RandomCode.randomPushItem() }

        #expect(values.contains { $0 is CodeItem }, "a block is a legitimate input")
        #expect(values.contains { $0 is IntItem })
        #expect(values.contains { $0 is InstructionItem })
        #expect(values.contains { $0 is IteratorItem } == false,
                "a live loop is never a value handed in from outside")
    }
}
