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
//  It is the mechanism that let `maxIterations` retire (deleted 2026-11-08): with
//  the actual pass count recorded compactly and reconstructably, a loop can run to
//  `stepLimit` without its crux blowing up or being elided. Scoped to the exact-repeat case
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
        // A finished loop hands its body back to `.code`; the crux discards it.
        return prefix + [CodeItem(body), IntItem(count), InstructionItem(.execDoTimes), InstructionItem(.codePop)]
    }
}

// MARK: - Folding a loop's chain at the push boundary

/// **A loop's accumulator is a chain.** `0 ( 1 .intAdd ) 5000 .execDoTimes`
/// leaves 5000 with a history 5000 levels deep, each level `[previous, 1,
/// .intAdd]`. It is honestly linear, and a history deeper than `maxCallDepth`
/// is elided (releasing it costs a stack frame per level). Folded, it is
/// `0 ( 1 .intAdd ) 5000 .execDoTimes` again: one level over the seed, ordinary
/// runnable Push that replays the chain pass by pass.
///
/// `Interpreter.push` folds a history that is over budget before it elides one,
/// and keeps the fold if that brings it within budget. A chain that keeps
/// growing folds again, and the new levels join the old fold (`K` passes become
/// `K + M`), so a loop that runs to `stepLimit` keeps its history.
///
/// **A fixed point.** The levels a fold matches are compared by structure, not
/// by identity, and the fold is a function of the history alone; a replay
/// rebuilds the chain level by level, crosses the budget at the same level, and
/// folds it the same way.
nonisolated extension CruxCompression {

    /// `item` with the chain under it folded into a counted loop, or nil if its
    /// history is not a chain of at least `minimumPasses` identical levels.
    ///
    /// A level is a node whose `call` starts with the level below and goes on
    /// with the same elements (by structure) as every other level: the loop's
    /// body. The body runs after the level below, so it is written as its
    /// elements' cruxes, and the chain as `seed ( body ) K .execDoTimes .codePop`:
    /// a finished loop hands its body back to `.code` (`iteratorFarewell`), and
    /// the crux must leave nothing but its item.
    static func folded(_ item: any Item, minimumPasses: Int = 3) -> (any Item)? {
        guard let holder = item as? any HoldsCall else { return nil }
        let top = item.call
        guard top.count >= 2, !top[0].call.isEmpty else { return nil }
        let sides = Array(top.dropFirst())

        // Walk down while each level has the same sides.
        var passes = 1
        var seed = top[0]
        while seed.call.count == top.count,
              zip(seed.call.dropFirst(), sides).allSatisfy({ sameHistory($0, $1) }) {
            passes += 1
            seed = seed.call[0]
        }

        let body = sides.flatMap { $0.crux() }
        var count = passes
        // A chain that has folded before: its seed is the earlier fold, with
        // the same body. The new passes join it.
        if let earlier = Fold(seed), sameLeaves(earlier.body, body) {
            seed = earlier.seed
            count += earlier.count
        } else if passes < minimumPasses {
            return nil
        }
        let call: [any Item] = [seed, CodeItem(body), IntItem(count), InstructionItem(.execDoTimes),
                                InstructionItem(.codePop)]
        return holder.recalled(call)
    }

    /// The parts of a fold: `seed ( body ) count .execDoTimes .codePop`.
    struct Fold {
        let seed: any Item
        let body: [any Item]
        let count: Int

        /// The fold `item`'s `call` is, if it is one.
        init?(_ item: any Item) {
            let call = item.call
            guard call.count == 5,
                  call[3].exactly(InstructionItem.self)?.value == .execDoTimes,
                  call[4].exactly(InstructionItem.self)?.value == .codePop,
                  let count = call[2].exactly(IntItem.self), call[2].call.isEmpty,
                  let body = call[1].exactly(CodeItem.self), call[1].call.isEmpty
            else { return nil }
            (seed, self.body, self.count) = (call[0], body.value, count.value)
        }
    }

    /// Whether `left` and `right` have the same history, compared by structure:
    /// the same leaves, in the same tree. Identical storage answers at once.
    /// Gives up (answers no) past `budget` comparisons, which keeps a fold's walk
    /// bounded without making its answer depend on anything but the histories.
    static func sameHistory(_ left: any Item, _ right: any Item, budget: Int = 4_096) -> Bool {
        var pending: [(any Item, any Item)] = [(left, right)]
        var spent = 0
        while let (one, other) = pending.popLast() {
            spent += 1
            guard spent <= budget, type(of: one) == type(of: other) else { return false }
            let oneCall = one.call, otherCall = other.call
            guard oneCall.count == otherCall.count else { return false }
            if oneCall.isEmpty {
                guard one.pretty() == other.pretty() else { return false }
                continue
            }
            if CruxSharing.key(one) == CruxSharing.key(other) { continue }
            guard one.isEqual(to: other) else { return false }
            pending.append(contentsOf: zip(oneCall, otherCall).map { ($0, $1) })
        }
        return true
    }

    /// Whether two leaf sequences would run the same.
    static func sameLeaves(_ left: [any Item], _ right: [any Item]) -> Bool {
        left.count == right.count
            && zip(left, right).allSatisfy { type(of: $0) == type(of: $1) && $0.pretty() == $1.pretty() }
    }

    /// Roughly how many steps running `crux` takes: one per item, and a counted
    /// loop's body once per pass. A replay needs a step budget, and a folded
    /// crux is short but runs long.
    public static func replaySteps(_ crux: [any Item]) -> Int {
        var steps = 0
        for (index, item) in crux.enumerated() {
            steps += 1
            guard item.exactly(InstructionItem.self)?.value == .execDoTimes, index >= 2,
                  let count = crux[index - 1].exactly(IntItem.self),
                  let body = crux[index - 2].exactly(CodeItem.self) else { continue }
            let pass = replaySteps(body.value) + 4
            let (total, overflow) = pass.multipliedReportingOverflow(by: max(0, count.value))
            steps = overflow ? .max : steps.addingReportingOverflow(total).partialValue
        }
        return steps
    }
}
