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
/// **Why the blocks work at all**: a `CodeItem` in a program is not an
/// instruction, so when `.exec` reaches it `pushDefault` routes it to `.code` as
/// *data*. The blocks therefore pile onto `.code` before
/// the flat program runs, and the flat program finds them waiting — which is the
/// point of the encoding, since `.code` is the language's scarcest stack and a
/// program with nothing on it can build no loop bodies.
///
/// **Order matters and is deliberate.** The blocks land in the order given, so
/// with ascending lengths the *largest* block ends up on **top** of `.code` —
/// it is pushed last — and is what the first `.codeDo` or iterator constructor
/// reaches for.
///
/// A length that runs past the end of the genome takes what remains, so the last
/// block may be short; a length of zero or less is skipped rather than producing
/// an empty block, since `( )` is a no-op body and an iterator normalizes it
/// away anyway.
nonisolated enum BlockPacking {

    static func pack(_ genome: [any Item], lengths: [Int]) -> [any Item] {
        var blocks: [any Item] = []
        var cursor = 0

        for length in lengths {
            guard cursor < genome.count else { break }
            guard length > 0 else { continue }
            let end = min(cursor + length, genome.count)
            blocks.append(CodeItem(Array(genome[cursor..<end])))
            cursor = end
        }
        return blocks + genome[cursor...]
    }
}
