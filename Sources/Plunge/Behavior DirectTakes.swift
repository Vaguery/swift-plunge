//
//  Behavior DirectTakes.swift
//  Plunge
//
//  The argument plan for a Behavior that only ever `.takes` and `.needs` — worked
//  out once, at construction, so `Behavior.act` can skip the `Planner` for most of
//  the language.
//

/// One position a plain Behavior must find on a stack: the k-th claim on a stack
/// is always that stack's index k, exactly the claim the `Planner` would make.
nonisolated struct DirectTake: Sendable {
    let stack: PushStack
    let index: Int
}

nonisolated extension Behavior {

    /// The depth each requirement must find, in requirement order (`checks`); where
    /// each consumed argument sits (`takes`); and how many items each stack gives
    /// up (`counts`). `checks` is nil when any requirement is something else, in
    /// which case the Behavior plans through the `Planner`.
    ///
    /// A `.needs` claims its positions without consuming them, as the `Planner`'s
    /// does, so it is one check at its deepest position. A `.takes` after a `.needs`
    /// on the same stack would consume an item from below the top, which dropping
    /// the top n cannot express; that case also falls back to the `Planner`.
    static func directPlan(
        for requirements: [Requirement]
    ) -> (checks: [DirectTake]?, takes: [DirectTake], counts: [(stack: PushStack, count: Int)]) {
        var checks: [DirectTake] = []
        var takes: [DirectTake] = []
        var claimed: [PushStack: Int] = [:]
        var needed: Set<PushStack> = []
        for requirement in requirements {
            switch requirement {
            case .takes(let stack):
                guard !needed.contains(stack) else { return (nil, [], []) }
                let take = DirectTake(stack: stack, index: claimed[stack, default: 0])
                checks.append(take)
                takes.append(take)
                claimed[stack, default: 0] += 1
            case .needs(let stack, let count):
                guard count > 0 else { continue }
                claimed[stack, default: 0] += count
                checks.append(DirectTake(stack: stack, index: claimed[stack, default: 0] - 1))
                needed.insert(stack)
            case .reads, .takesMany, .takesFirst:
                return (nil, [], [])
            }
        }
        // Consumed counts, in first-claim order so the removal is reproducible.
        var counts: [(stack: PushStack, count: Int)] = []
        for take in takes {
            if let slot = counts.firstIndex(where: { $0.stack == take.stack }) {
                counts[slot].count += 1
            } else {
                counts.append((take.stack, 1))
            }
        }
        return (checks, takes, counts)
    }
}
