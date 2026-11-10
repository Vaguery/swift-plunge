//
//  FibonacciGenome Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/17/26.
//
//  A flat gene stream, packed into blocks of implied Fibonacci lengths.
//
//  The claim that matters is not "it makes blocks" — it is **where the blocks
//  go**. A CodeItem in a program is not an instruction, so `.exec` routes it to
//  `.code` as data, and the encoding's whole purpose is to have a spread of
//  block sizes waiting on the language's scarcest stack before the flat program
//  starts looking for them.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct FibonacciGenomeTests {

    /// A genome of `n` distinguishable instruction tokens.
    func genome(_ n: Int) -> [any Item] {
        (0..<n).map { _ in InstructionItem(.intAdd) }
    }


    // MARK: - the lengths

    /// The sequence itself, and the sums it stops at. Computed independently
    /// while planning this, so it is a real check rather than a restatement of
    /// the code.
    @Test func `the block lengths are Fibonacci and stop past a third`() {
        #expect(FibonacciGenome.blockLengths(forGenomeOf: 100)
                == [1, 1, 2, 3, 5, 8, 13, 21], "sums to 54, the first sum past 33.3")
        #expect(FibonacciGenome.blockLengths(forGenomeOf: 30) == [1, 1, 2, 3, 5])
        #expect(FibonacciGenome.blockLengths(forGenomeOf: 200)
                == [1, 1, 2, 3, 5, 8, 13, 21, 34], "sums to 88")
    }

    /// **The third is a floor, not a target**, and the code fraction never
    /// settles near it: consecutive Fibonacci sums approach φ, so the realized
    /// fraction swings between about a third and about a half forever.
    @Test func `the realized code fraction oscillates between a third and a half`() {
        let table: [(n: Int, blocks: Int, inCode: Int)] = [
            (30, 5, 12), (50, 6, 20), (100, 8, 54),
            (150, 8, 54), (200, 9, 88), (250, 9, 88), (1_000, 12, 376)
        ]
        for row in table {
            let lengths = FibonacciGenome.blockLengths(forGenomeOf: row.n)
            #expect(lengths.count == row.blocks, "n=\(row.n)")
            #expect(lengths.reduce(0, +) == row.inCode, "n=\(row.n)")

            let fraction = Double(row.inCode) / Double(row.n)
            #expect(fraction > 0.33 && fraction < 0.56, "n=\(row.n) → \(fraction)")
        }
    }

    /// **The cliff.** One more gene, and the code fraction nearly doubles: 20 is
    /// past 59/3 but not past 60/3, so a genome of 60 takes one more block — the
    /// 13. Deliberate and accepted; randomizing genome length over a range is
    /// what covers it.
    @Test func `a genome divisible by three is a cliff edge`() {
        let short = FibonacciGenome.blockLengths(forGenomeOf: 59)
        let long = FibonacciGenome.blockLengths(forGenomeOf: 60)

        #expect(short.reduce(0, +) == 20)   // 33.9% of 59
        #expect(long.reduce(0, +) == 33)    // 55.0% of 60
        #expect(long.count == short.count + 1, "exactly one more block")
    }


    // MARK: - the packing

    @Test func `the front is blocked and the rest is flat`() {
        let program = FibonacciGenome.translate(genome(30))

        // 5 blocks (1,1,2,3,5 = 12 items), then 18 flat.
        #expect(program.prefix(5).allSatisfy { $0 is CodeItem })
        #expect(program.dropFirst(5).allSatisfy { $0 is InstructionItem })
        #expect(program.count == 5 + 18)
        #expect(program.prefix(5).map { ($0 as! CodeItem).value.count } == [1, 1, 2, 3, 5])
    }

    /// Every gene survives, in order: the blocks' contents followed by the flat
    /// remainder are the genome again. A packer that dropped or duplicated a gene
    /// would still look right in the shape tests above.
    @Test func `packing loses nothing and reorders nothing`() {
        let source: [any Item] = (0..<40).map { IntItem($0) }
        let program = FibonacciGenome.translate(source)

        let flattened = program.flatMap { item -> [any Item] in
            (item as? CodeItem)?.value ?? [item]
        }
        #expect(flattened.count == 40)
        #expect(flattened.map { ($0 as! IntItem).value } == Array(0..<40))
    }

    /// No nesting: the genes are a flat token stream, so every block is depth 1.
    /// Nested code can only be built at run time — which is a reason this is a
    /// testing genome rather than an evolving one.
    @Test func `no block contains a block`() {
        fuzzRNG = SeededRNG(seed: 3)
        let program = FibonacciGenome.translate(RandomCode.randomProgram(120))

        for case let block as CodeItem in program {
            #expect(block.value.allSatisfy { !($0 is CodeItem) })
        }
    }

    @Test func `small and empty genomes do not misbehave`() {
        #expect(FibonacciGenome.translate([]).isEmpty)
        #expect(FibonacciGenome.blockLengths(forGenomeOf: 0).isEmpty)

        // n=1: one block of 1, nothing flat.
        let one = FibonacciGenome.translate(genome(1))
        #expect(one.count == 1)
        #expect((one[0] as? CodeItem)?.value.count == 1)

        // n=3: blocks 1,1 (2 items), 1 flat.
        let three = FibonacciGenome.translate(genome(3))
        #expect(three.count == 3)
        #expect(three.prefix(2).allSatisfy { $0 is CodeItem })
        #expect(three[2] is InstructionItem)
    }

    /// A length running past the end takes what is left rather than reaching for
    /// items that are not there. Unreachable through `translate` — the lengths are
    /// derived from the count — but `ForestGenome` will read lengths from the
    /// genome, where nothing constrains them, so the packer must already be safe.
    @Test func `a length past the end truncates the last block`() {
        let packed = BlockPacking.pack(genome(4), lengths: [1, 99])
        #expect(packed.count == 2)
        #expect((packed[1] as? CodeItem)?.value.count == 3, "took what remained")

        // And a zero or negative length is skipped, not turned into an empty block.
        let skipped = BlockPacking.pack(genome(3), lengths: [0, -5, 2])
        #expect(skipped.count == 2)
        #expect((skipped[0] as? CodeItem)?.value.count == 2)
    }


    // MARK: - what it is for

    /// **The point of the whole encoding.** The blocks are data, so they land on
    /// `.code` before the flat program runs — a spread of body sizes waiting on
    /// the scarcest stack in the language.
    @Test func `the blocks arrive on code, biggest on top`() {
        let inty = Interpreter()
        inty.load(program: FibonacciGenome.translate(genome(30)))
        // Only the five blocks; stop before the flat program can consume them.
        for _ in 0..<5 { inty.step() }

        let blocks = inty.stacks[.code]!.compactMap { ($0 as? CodeItem)?.value.count }
        #expect(blocks == [5, 3, 2, 1, 1],
                "ascending lengths push the largest last, so it is on top")
    }

    /// The `[Any]` seam carries any token stream, so anything that is not an Item
    /// is not part of this encoding and is dropped rather than crashing on a bad
    /// cast.
    @Test func `non-items in the array are not part of this encoding`() {
        let messy: [Any] = [IntItem(1), Brace.open, IntItem(2), "nonsense", IntItem(3)]
        let program = FibonacciGenome.translate(messy)

        let flattened = program.flatMap { ($0 as? CodeItem)?.value ?? [$0] }
        #expect(flattened.count == 3)
    }

    /// End to end: a random Fibonacci genome runs, and the blocks it left on
    /// `.code` are real enough for the program to use as loop bodies.
    @Test func `a random fibonacci program runs`() {
        fuzzRNG = SeededRNG(seed: 20_260_717)
        var ran = 0
        for _ in 0..<50 {
            let inty = Interpreter()
            inty.load(program: FibonacciGenome.translate(RandomCode.randomProgram(120)))
            RandomCode.setRandomConstants(in: inty)
            RandomCode.setRandomInputs(in: inty)
            inty.run()
            ran += 1
            #expect(!inty.stacks[.error]!.contains { ($0 as? ErrorItem)?.value
                .contains(Interpreter.invariantMarker) == true },
                "a genome must never break the interpreter's own invariant")
        }
        #expect(ran == 50)
    }
}
