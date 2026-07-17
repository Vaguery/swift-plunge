//
//  FibonacciGenome.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/17/26.
//

/// A linear genome whose code blocks are implied rather than encoded: take the
/// front of the stream in runs of 1, 1, 2, 3, 5, 8, 13… until roughly a third of
/// it is used up, box each run into a block, and let the rest be a flat program.
///
/// ```
/// ( a ) ( b ) ( c d ) ( e f g ) ( h i j k l ) …then the rest, flat
/// ```
///
/// **What it is for.** Blocks in a program land on `.code` as data (§7), so this
/// front-loads the language's scarcest stack with a spread of block sizes — a
/// 1-item block for a trivial body, a 21-item block for something substantial —
/// before the flat program runs and goes looking for them. Fibonacci is a cheap
/// way to get that spread out of nothing but the genome's length: no size genes,
/// nothing to tune, deterministic.
///
/// **It is a testing genome, not an evolvable one**, and the reason is worth
/// recording: the block lengths are not genes, so a search cannot adjust them. It
/// can only change *which* instructions fall inside a block whose size is fixed
/// by arithmetic. `ForestGenome` is the same shape with the lengths encoded —
/// which is why they share `BlockPacking` — and that is the one meant to evolve.
///
/// **No nesting, ever.** The genes are a flat stream of instruction tokens, so
/// every block is depth 1. Nested code can only appear at run time, built by the
/// program itself. That is another reason this is a poor evolving genome and a
/// fine testing one.
nonisolated enum FibonacciGenome {

    /// The block lengths for a genome of `count` items: 1, 1, 2, 3, 5, 8, …,
    /// stopping with **the first block that carries the total past `count / 3`**.
    ///
    /// The last block is included rather than dropped, so the third is a floor,
    /// not a target. Two consequences of that rule, both measured and both
    /// deliberate:
    ///
    /// - **The realized code fraction oscillates between ~34% and ~55%**, because
    ///   consecutive Fibonacci sums approach φ; it never settles near a third.
    /// - **N divisible by 3 is a cliff.** 59 items give 34% code (6 blocks, 20
    ///   items); 60 give 55% (7 blocks, 33 items) — because 20 > 19.67 stops the
    ///   first, and 20 > 20 is false for the second. A single inserted gene can
    ///   nearly double a program's code fraction.
    ///
    /// Randomizing the genome length over a reasonable range covers the
    /// discontinuity, which is what makes it acceptable in a testing genome.
    static func blockLengths(forGenomeOf count: Int) -> [Int] {
        guard count > 0 else { return [] }

        var lengths: [Int] = []
        var (previous, current) = (0, 1)
        var total = 0

        // `total * 3 <= count` is "total <= count/3" in exact integers — keep
        // adding blocks while the third has not yet been passed, so the block
        // that passes it is the last one included. Floating point would put the
        // N-divisible-by-3 cliff in a slightly different place depending on
        // rounding, which is the one thing this rule cannot afford to be vague
        // about.
        while total * 3 <= count {
            lengths.append(current)
            total += current
            (previous, current) = (current, previous + current)
            // A genome cannot yield more blocks than it has items, whatever the
            // arithmetic says — and Fibonacci overflows Int in 92 steps.
            if total >= count { break }
        }
        return lengths
    }

    /// Translate a Fibonacci genome into a runnable program.
    ///
    /// The genome is a linear collection of Items — the instruction stream half of
    /// an individual; its constant assignments travel separately and are merged
    /// into the interpreter before a run. Anything in the array that is not an
    /// `Item` is not part of this encoding and is dropped, which is what lets the
    /// `[Any]` seam serve both this and Plushy's raw token stream.
    static func translate(_ genome: [Any]) -> [any Item] {
        let items = genome.compactMap { $0 as? any Item }
        return BlockPacking.pack(items, lengths: blockLengths(forGenomeOf: items.count))
    }
}
