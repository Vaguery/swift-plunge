//
//  StackView.swift
//  Plunge
//
//  The read-only view a structural rule gets of the one stack it works on.
//

import DequeModule

/// **One stack, read-only**, as a structural rule sees it once its own arguments
/// are gone. Enough to clamp a depth and, for the loops, to name the items to
/// copy; nothing that could change the stack or reach any other.
nonisolated struct StackView {
    /// How many items the stack holds.
    let count: Int
    /// Whether provenance is being recorded, for the loops' iterators.
    let recording: ProvenanceRecording
    private let items: Deque<any Item>

    init(_ items: Deque<any Item>, recording: ProvenanceRecording) {
        self.items = items
        self.count = items.count
        self.recording = recording
    }

    /// The top `n` items, top first (clamped to the depth).
    func top(_ n: Int) -> [any Item] { Array(items.prefix(max(0, n))) }

    /// The item at `depth`, counted from the top, or nil past the bottom.
    func item(at depth: Int) -> (any Item)? { depth >= 0 && depth < count ? items[depth] : nil }
}
