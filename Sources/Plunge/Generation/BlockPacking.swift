//
//  BlockPacking.swift
//  Plunge
//
//  Created by Bill Tozier on 7/17/26.
//
//  Packing a flat gene stream into code blocks followed by a flat program —
//  the shape `FibonacciGenome` and `ForestGenome` share.
//

/// Take items from the front of `genome` in runs of the given `lengths`, boxing
/// each run into a `CodeItem`; everything left over follows, flat.
///
/// **This is the whole of both genomes.** They differ only in where the lengths
/// come from: `FibonacciGenome` generates them (1, 1, 2, 3, 5…) and stops at a
/// size rule, while `ForestGenome` will read them from the genome itself, as
/// genes. So the packing lives here once, and a new encoding of this family is a
/// new `lengths` sequence rather than new machinery.
///
/// **Why the code blocks work at all**: a `CodeItem` in a program is not an
/// instruction, so when `.exec` reaches it `pushDefault` routes it to `.code` as
/// *data*. The code blocks therefore pile onto `.code` before
/// the flat program runs, and the flat program finds them waiting — which is the
/// point of the encoding, since `.code` is the language's scarcest stack and a
/// program with nothing on it can build no loop bodies.
///
/// **Order matters and is deliberate.** By default the code blocks land in the order
/// they were cut, so with ascending lengths the *largest* code block ends up on
/// **top** of `.code` — it is pushed last — and is what the first `.codeDo` or
/// iterator constructor reaches for. `pack(_:lengths:order:)` places them in
/// another order after cutting.
///
/// A length that runs past the end of the genome takes what remains, so the last
/// code block may be short; a length of zero or less is skipped rather than producing
/// an empty code block, since `( )` is a no-op body and an iterator normalizes it
/// away anyway.
nonisolated enum BlockPacking {

    /// The code blocks in the order they were cut, then the rest, flat.
    static func pack(_ genome: [any Item], lengths: [Int]) -> [any Item] {
        pack(genome, lengths: lengths, order: Array(lengths.indices))
    }

    /// **Cut first, then reorder.** The code blocks are cut from the front of `genome`
    /// in `lengths` order exactly as above, and only then placed in the program
    /// in `order`, a permutation of `lengths.indices`: `order[k]` is the index of
    /// the code block placed `k`-th, so `order.last` ends up on top of `.code`.
    ///
    /// Reordering finished code blocks, rather than reordering the lengths before
    /// cutting, is what makes the order evolvable: a change to `order` moves
    /// whole code blocks and never changes what is in them. Reordering the lengths
    /// instead would move every boundary after the first changed length.
    ///
    /// A length that produced no code block (zero or less, or past the end of the
    /// genome) is simply absent from the placement.
    static func pack(_ genome: [any Item], lengths: [Int], order: [Int]) -> [any Item] {
        assert(order.sorted() == Array(lengths.indices), "order must be a permutation of the lengths' indices")
        var blocks: [Int: any Item] = [:]
        var cursor = 0

        for (index, length) in lengths.enumerated() {
            guard cursor < genome.count else { break }
            guard length > 0 else { continue }
            let end = min(cursor + length, genome.count)
            blocks[index] = CodeItem(Array(genome[cursor..<end]))
            cursor = end
        }
        return order.compactMap { blocks[$0] } + genome[cursor...]
    }
}
