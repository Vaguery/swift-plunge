//
//  FullSize.swift
//  Plunge
//
//  How big a history is with nothing compressed: every pass of a folded loop,
//  every elided or distilled history at the size it had (2026-11-20, for
//  comparing cruxes by size however they are written).
//

nonisolated extension Item {
    /// **The size of this item's history written out in full:** roughly how long
    /// its crux would be if nothing in it were compressed.
    ///
    /// A crux is written compactly. A loop's chain is folded into
    /// `seed ( body ) K .execDoTimes`, an over-budget history is elided, and a
    /// distilled crux puts constant work's value in its place. Each of these
    /// makes a crux shorter than the work it records, so two loops that ran 100
    /// and 300 passes can have cruxes of the same length. This measure undoes
    /// each compression in the count, not in the crux:
    ///
    /// - A folded loop counts its body once per pass, and its seed once.
    /// - An elided or distilled stand-in counts the full size of the history it
    ///   replaced (``StandInItem/replacedSize``). Other stand-ins count 1.
    /// - Every other leaf counts 1, and a code block the sum of its contents.
    /// - A value the history reuses (by dup, yank, or a read that leaves its
    ///   arguments) counts once, as the crux builds it once.
    ///
    /// It is approximate wherever a history is: what ran inside a sandbox, or
    /// in a branch not taken, is not in it. It is computed on demand by a walk of
    /// the history's distinct nodes, and saturates rather than overflowing.
    public var fullSize: Int {
        var total = 0
        var visited = Set<CruxSharing.Key>()
        var pending: [any Item] = [self]
        while let node = pending.popLast() {
            if let key = CruxSharing.key(node), !visited.insert(key).inserted { continue }
            let call = node.call
            if call.isEmpty {
                total = saturatingSum(total, leafSize(node))
                continue
            }
            if let fold = CruxCompression.Fold(node) {
                let passes = CruxCompression.fullSize(fold.body).multipliedReportingOverflow(by: max(0, fold.count))
                total = saturatingSum(total, passes.overflow ? .max : passes.partialValue)
                pending.append(fold.seed)
                continue
            }
            pending.append(contentsOf: call)
        }
        return total
    }

}

/// A leaf's size: a stand-in's replaced size, a code block's contents in full,
/// 1 for anything else.
private nonisolated func leafSize(_ leaf: any Item) -> Int {
    if let standIn = leaf.exactly(StandInItem.self) { return standIn.replacedSize }
    if let block = leaf.exactly(CodeItem.self) { return CruxCompression.fullSize(block.value) }
    return 1
}

private nonisolated func saturatingSum(_ left: Int, _ right: Int) -> Int {
    let (sum, overflow) = left.addingReportingOverflow(right)
    return overflow ? .max : sum
}

nonisolated extension CruxCompression {
    /// The full size of a crux, as ``Item/fullSize`` counts a history: a counted
    /// loop (`( body ) K .execDoTimes`, with the `.codePop` a fold ends with) its
    /// body once per pass, an elided or distilled stand-in the size it replaced,
    /// a code block the sum of its contents, each other item 1 plus its own
    /// history's full size beyond itself.
    public static func fullSize(_ crux: [any Item]) -> Int {
        var total = 0
        var index = 0
        while index < crux.count {
            let item = crux[index]
            if let block = item.exactly(CodeItem.self), index + 2 < crux.count,
               let count = crux[index + 1].exactly(IntItem.self),
               crux[index + 2].exactly(InstructionItem.self)?.value == .execDoTimes {
                let passes = fullSize(block.value).multipliedReportingOverflow(by: max(0, count.value))
                total = saturatingSum(total, passes.overflow ? .max : passes.partialValue)
                index += 3
                if index < crux.count, crux[index].exactly(InstructionItem.self)?.value == .codePop { index += 1 }
                continue
            }
            total = saturatingSum(total, item.call.isEmpty ? leafSize(item) : item.fullSize)
            index += 1
        }
        return total
    }
}
