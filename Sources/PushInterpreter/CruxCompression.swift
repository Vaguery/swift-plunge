//
//  CruxCompression.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/22/26.
//
//  PROTOTYPE — a two-pass crux composition that collapses the linear provenance a
//  loop leaves behind. `crux()` flattens an item's history to a leaf sequence; a
//  counted loop (`.execDoTimes`) folding one accumulator produces
//  `seed  body body … body` — the body block repeated once per pass, growing O(N).
//  This pass finds that repeated trailing block and rewrites it as
//  `seed  ( body )  N  .execDoTimes`, which re-runs to the same value in O(body).
//
//  It is the mechanism that would let `maxIterations` retire: with the actual pass
//  count recorded compactly and reconstructably, a loop can run to `stepLimit`
//  without its crux blowing up or being elided. Scoped to the exact-repeat case
//  (`.execDoTimes`, no per-pass index); varying-index loops (`.execDoRange`) and
//  recursion are the deferred harder cases. See
//  `Notes on Push/Compressing looped provenance.md`.
//
public nonisolated enum CruxCompression {

    /// Collapse the longest repeated trailing block in a flat crux into a counted
    /// loop. Returns the input unchanged when no worthwhile repeat is found.
    ///
    /// Compose it at the boundary where a crux is rendered or stored — e.g.
    /// `CodeItem(CruxCompression.compressed(item.crux())).pretty()` — so a long
    /// loop reads as `seed ( body ) N .execDoTimes` instead of `body`×N.
    public static func compressed(_ crux: [any Item]) -> [any Item] {
        let n = crux.count
        guard n >= 4 else { return crux }

        // The fundamental repeat: the period whose repeated trailing region is
        // longest (ties → smallest period, since a shorter body is the true one).
        var best: (period: Int, region: Int)?
        for period in 1...(n / 2) {
            var matched = 0
            var i = n - 1
            while i - period >= 0 && crux[i].isEqual(to: crux[i - period]) {
                matched += 1
                i -= 1
            }
            guard matched >= period else { continue }        // at least two full blocks
            let blocks = matched / period + 1                // + the block the tail matched against
            let region = blocks * period
            guard blocks >= 2, region <= n else { continue }
            if region > (best?.region ?? 0) { best = (period, region) }
        }

        guard let best else { return crux }
        let period = best.period
        let count = best.region / period
        let prefix = Array(crux[0 ..< (n - best.region)])    // the seed, untouched
        let body = Array(crux[(n - period) ..< n])           // one repeat unit
        return prefix + [CodeItem(body), IntItem(count), InstructionItem(.execDoTimes)]
    }
}
