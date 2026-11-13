//
//  FibonacciGenome.swift
//  Plunge
//
//  Created by Bill Tozier on 7/17/26.
//

/// A linear genome whose code blocks are implied rather than encoded: take the
/// front of the stream in runs of 1, 1, 2, 3, 5, 8, 13… until roughly a third of
/// it is used up, box each run into a code block, and let the rest be a flat program.
///
/// ```
/// ( a ) ( b ) ( c d ) ( e f g ) ( h i j k l ) …then the rest, flat
/// ```
///
/// **What it is for.** Code blocks in a program land on `.code` as data, so this
/// front-loads the language's scarcest stack with a spread of code block sizes — a
/// 1-item code block for a trivial body, a 21-item code block for something substantial —
/// before the flat program runs and goes looking for them. Fibonacci is a cheap
/// way to get that spread out of nothing but the genome's length: no size genes,
/// nothing to tune, deterministic.
///
/// **Code block order can be a gene; code block sizes cannot.** `translate(_:permutation:)`
/// cuts the code blocks first, always 1, 1, 2, 3, 5… from the head, and then
/// reorders the finished code blocks by a permutation, so a change to the
/// permutation moves whole code blocks without changing what is in them. (Permuting
/// the *sizes* before cutting, which the app's first permuted genome did, moves
/// every boundary at once.) The lengths themselves are still arithmetic, so a
/// search can only change *which* instructions fall inside a code block whose size is
/// fixed, and inserting or deleting a gene still shifts every boundary after it.
/// `ForestGenome` is the same shape with the lengths encoded — which is why they
/// share `BlockPacking` — and that is the design meant to evolve sizes.
///
/// **No nesting, ever.** The genes are a flat stream of instruction tokens, so
/// every code block is depth 1. Nested code can only appear at run time, built by the
/// program itself. That is another reason this is a poor evolving genome and a
/// fine testing one.
nonisolated enum FibonacciGenome {

    /// The code block lengths for a genome of `count` items: 1, 1, 2, 3, 5, 8, …,
    /// stopping with **the first code block that carries the total past `count / 3`**.
    ///
    /// The last code block is included rather than dropped, so the third is a floor,
    /// not a target. Two consequences of that rule, both measured and both
    /// deliberate:
    ///
    /// - **The realized code fraction oscillates between ~34% and ~55%**, because
    ///   consecutive Fibonacci sums approach φ; it never settles near a third.
    /// - **N divisible by 3 is a cliff.** 59 items give 34% code (6 code blocks, 20
    ///   items); 60 give 55% (7 code blocks, 33 items) — because 20 > 19.67 stops the
    ///   first, and 20 > 20 is false for the second. A single inserted gene can
    ///   nearly double a program's code fraction.
    ///
    /// Randomizing the genome length over a reasonable range covers the
    /// discontinuity, which is what makes it acceptable in a testing genome.
    ///
    /// **A consequence worth knowing before designing an experiment**: length and
    /// code fraction are not independent here, so a sweep over lengths is also a
    /// sweep over how much of the program is code blocks. At the sizes people set as
    /// initial GP arguments:
    ///
    /// | genes | code blocks | in code | code % | largest code block |
    /// |---|---|---|---|---|
    /// | 50 | 6 | 20 | 40.0% | 8 |
    /// | 100 | 8 | 54 | **54.0%** | 21 |
    /// | 250 | 9 | 88 | **35.2%** | 34 |
    /// | 500 | 11 | 232 | 46.4% | 89 |
    ///
    /// Note it is not even monotonic: 100 is the *most* blocked and 250 the least.
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

    /// Translate with the code blocks reordered after cutting: `permutation[i]`
    /// belongs to the `i`-th code block cut from the head, and the code blocks are placed
    /// in ascending order of their values, so the code block with the highest value
    /// is pushed last and ends up on top of `.code`.
    ///
    /// The permutation is fitted to the code block count first
    /// (`adjustedPermutation`), so it need not know how many code blocks the genome's
    /// length implies. An empty permutation is the cut order, the same program
    /// as `translate(_:)`.
    static func translate(_ genome: [Any], permutation: [Double]) -> [any Item] {
        let items = genome.compactMap { $0 as? any Item }
        let lengths = blockLengths(forGenomeOf: items.count)
        let order = placementOrder(adjustedPermutation(permutation, toCount: lengths.count))
        return BlockPacking.pack(items, lengths: lengths, order: order)
    }

    /// Fit `permutation` to exactly `count` values: truncated if longer; if
    /// shorter, cycled, with each further cycle nudged up by `epsilon` so the
    /// repeats break ties the same way every time. `[1.1, 2.2]` fitted to 5 is
    /// `[1.1, 2.2, 1.1001, 2.2001, 1.1002]`. Empty fits as `0, 1, 2…`, the cut
    /// order. The app's rule, so the two genomes read a permutation alike.
    static func adjustedPermutation(_ permutation: [Double], toCount count: Int,
                                    epsilon: Double = 0.0001) -> [Double] {
        guard count > 0 else { return [] }
        guard !permutation.isEmpty else { return (0..<count).map(Double.init) }
        if permutation.count >= count { return Array(permutation.prefix(count)) }
        let period = permutation.count
        return (0..<count).map { permutation[$0 % period] + epsilon * Double($0 / period) }
    }

    /// The indices of `values` in ascending order of value, ties broken by
    /// index: the order the code blocks are placed in. `[0.7, 0.2, 0.9, 0.2]` gives
    /// `[1, 3, 0, 2]`. A NaN sorts as the largest value, so a corrupt gene
    /// still gives a permutation.
    static func placementOrder(_ values: [Double]) -> [Int] {
        let keys = values.map { $0.isNaN ? Double.infinity : $0 }
        return keys.indices.sorted { keys[$0] != keys[$1] ? keys[$0] < keys[$1] : $0 < $1 }
    }
}
