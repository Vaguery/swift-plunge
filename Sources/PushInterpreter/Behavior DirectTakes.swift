//
//  Behavior DirectTakes.swift
//  PushInterpreter
//
//  The argument plan for a Behavior that only ever `.takes` — worked out once, at
//  construction, so `Behavior.act` can skip the `Planner` for most of the language.
//

/// Where one argument of a plain-`.takes` Behavior sits: the k-th `.takes` of a
/// stack is always that stack's index k, exactly the claim the `Planner` would make.
nonisolated struct DirectTake: Sendable {
    let stack: PushStack
    let index: Int
}

nonisolated extension Behavior {

    /// Each argument's position, in requirement order, plus how many items each
    /// stack gives up — or `(nil, [])` when any requirement is not a plain `.takes`,
    /// in which case the Behavior plans through the `Planner` as before.
    static func directPlan(
        for requirements: [Requirement]
    ) -> ([DirectTake]?, [(stack: PushStack, count: Int)]) {
        var takes: [DirectTake] = []
        var counts: [(stack: PushStack, count: Int)] = []
        for requirement in requirements {
            guard case .takes(let stack) = requirement else { return (nil, []) }
            if let slot = counts.firstIndex(where: { $0.stack == stack }) {
                takes.append(DirectTake(stack: stack, index: counts[slot].count))
                counts[slot].count += 1
            } else {
                takes.append(DirectTake(stack: stack, index: 0))
                counts.append((stack, 1))
            }
        }
        return (takes, counts)
    }
}
