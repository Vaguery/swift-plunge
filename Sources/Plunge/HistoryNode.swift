//
//  HistoryNode.swift
//  Plunge
//
//  The identity of a node of provenance, and where its arguments end, for tools
//  that walk histories outside the package (2026-11-20; PlungeGP's local
//  reconciliation of cruxes).
//

/// **Which node of provenance an item holds.** Items with equal nodes share one
/// history: copies made by dup or yank, and a value a program reused. A value
/// rebuilt by another route has a node of its own, even with the same crux. A
/// literal has none.
///
/// It names the storage of the item's `call`, so it is meaningful only while that
/// item, or a copy of it, is alive: keep the items for as long as their nodes are
/// compared or used as keys.
public nonisolated struct HistoryNode: Hashable {
    let key: CruxSharing.Key
}

nonisolated extension Item {
    /// The node of provenance this item holds; `nil` for a literal. See
    /// ``HistoryNode``.
    public var historyNode: HistoryNode? { CruxSharing.key(self).map(HistoryNode.init) }

    /// How many leading elements of this item's `call` are its arguments: the
    /// items, each with a crux of its own, that the instruction following them
    /// consumed. What comes after is the instruction and any clean-up it
    /// recorded. 0 for a literal.
    public var callArgumentCount: Int { CruxSharing.argumentCount(call) }
}
