//
//  PushCollector.swift
//  Plunge
//
//  The items pushed onto one stack during a run, each distinct one once: what a
//  `.pushes` recorder reports (swift-plunge #57, 2026-11-16).
//

/// Gathers the items pushed onto one stack, in the order each was first pushed.
///
/// An item with a history is counted once per history node: copies made by dup
/// or yank share their node (``CruxSharing/Key``), and the collector holds the
/// items it has keyed, so the keys stay valid for the run. A literal, which has
/// no node, is counted once per type and value.
nonisolated final class PushCollector {
    private(set) var items: [any Item] = []
    private var nodes = Set<CruxSharing.Key>()
    private var literals = Set<String>()

    func note(_ item: any Item) {
        if let key = CruxSharing.key(item) {
            if nodes.insert(key).inserted { items.append(item) }
        } else if literals.insert("\(type(of: item)) \(item.pretty())").inserted {
            items.append(item)
        }
    }

    func reset() {
        items.removeAll()
        nodes.removeAll()
        literals.removeAll()
    }
}
