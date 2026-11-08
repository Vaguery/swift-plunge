//
//  WrittenOrder.swift
//  PushInterpreter
//
//  Where each argument of a typed operation sits (Roadmap #44).
//

/// **Where each argument of a typed operation sits**, worked out once from the
/// argument stacks listed in written order.
///
/// The rule reproduces how the hand-written operations always recorded `call`
/// (provenance law 3): arguments grouped by stack in order of first appearance,
/// and within a stack deepest first — `y x .intAdd`, `"abc" 2 .stringNth`,
/// `[1, 2] 9 0 .vecIntSet`. It also gives the requirements: each stack's items
/// claimed top first, the stacks in the same order.
nonisolated struct WrittenOrder: Sendable {
    /// Each stack and how many arguments it supplies, in order of first appearance.
    let groups: [(stack: PushStack, count: Int)]
    /// For each argument in written order, its index in the gathered arguments
    /// (which arrive in requirement order: each stack's top first).
    let positions: [Int]

    init(_ stacks: [PushStack]) {
        var groups: [(stack: PushStack, count: Int)] = []
        for stack in stacks {
            if let slot = groups.firstIndex(where: { $0.stack == stack }) {
                groups[slot].count += 1
            } else {
                groups.append((stack, 1))
            }
        }
        var offset: [PushStack: Int] = [:]
        var running = 0
        for group in groups {
            offset[group.stack] = running
            running += group.count
        }
        var seen: [PushStack: Int] = [:]
        var positions: [Int] = []
        for stack in stacks {
            let k = seen[stack, default: 0]
            seen[stack] = k + 1
            let count = groups.first { $0.stack == stack }!.count
            // Written k-th, so it is (count − 1 − k) from the top.
            positions.append(offset[stack]! + count - 1 - k)
        }
        self.groups = groups
        self.positions = positions
    }

}
