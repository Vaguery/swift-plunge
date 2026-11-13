//
//  CallStorage.swift
//  Plunge
//
//  An item's history, stored behind one optional reference, and its measure.
//  Split out of Items.swift, which keeps the `Item` protocol and the provenance law.
//

import Foundation


// An item's `callWeight` and `callDepth`, packed into the 8 bytes `callWeight`
// alone used to take. That matters: a small item (`IntItem` is a value, its
// `call` and this) must stay within the three words an `any Item` stores inline,
// or every one of them is boxed on the heap. Both halves saturate at
// `UInt32.max`, far above any budget.
//
/// The size and depth of an item's history, stored together.
public nonisolated struct CallMeasure: Sendable, Hashable {
    /// The size of the history: 1 for a literal.
    public let weight: UInt32
    /// How deeply the history nests: 0 for a literal.
    public let depth: UInt32

    /// A literal: an empty `call`, weight 1, depth 0.
    public static let literal = CallMeasure(weight: 1, depth: 0)
}

/// An item's provenance, its `call` and that call's `CallMeasure`, behind one
/// optional reference: `nil`, and so free, for a literal.
///
/// **Why one reference.** An `any Item` holds a value of up to three words (24
/// bytes) inline; anything larger is put in a heap box, allocated each time such a
/// value is made into an `any Item` and freed with it. `call` (8 bytes) plus its
/// measure (8) left only one word for the value, so every string, character,
/// vector and error was boxed, which the Phase 4 profile found among the largest
/// per-step costs. With recording off (the search) every `call` is empty, so this is
/// `nil` and costs nothing to make or copy. With recording on, a non-empty `call`
/// costs one more allocation, for the box.
///
/// The box is immutable; assigning `call` replaces it, so items keep value
/// semantics.
///
/// **Members** ride in the same box. A vector's or string's elements
/// are raw values, so they cannot carry a history of their own; when recording,
/// the container keeps each element's origin, as a piece table (`Pieces`), for the
/// extraction instructions to hand back (the containment law, `Containment`). Only
/// an item with a `call` keeps them: a literal's elements are addressed from the
/// literal, and assigning a new `call` (elision, a stand-in) drops them with the
/// history they belong to. They cost little memory beyond the runs themselves,
/// because every source and item they name is also reachable from the
/// container's `call`.
nonisolated struct CallStorage: Sendable {
    /// Immutable to everyone but its own release: `call` and `members` are
    /// emptied only by `deinit` and by `detach(into:)`, and only when nothing else
    /// holds the box, which is why the unchecked `Sendable` is sound.
    private final class Box: @unchecked Sendable {
        var call: [any Item]
        let measure: CallMeasure
        var members: Pieces?
        init(call: [any Item], measure: CallMeasure, members: Pieces?) {
            self.call = call; self.measure = measure; self.members = members
        }

        /// **Freeing a deep history without recursion.** Freed the ordinary way,
        /// a history costs stack frames per level, and an item too large to sit
        /// inline in an `any Item` (a code block, a binding, an iterator) costs more:
        /// on a concurrency worker thread a chain of code blocks crashed the process at
        /// 950 levels in release and under 800 in debug (measured 2026-11-10). So a
        /// deep one is taken apart from a work list instead: each item hands over
        /// its own history when nothing else holds it, and is then freed empty.
        /// A shallow history is freed the ordinary way, which is cheaper.
        deinit {
            guard measure.depth > CallStorage.drainDepth else { return }
            var work = call
            call = []
            CallStorage.appendItems(of: members, to: &work)
            members = nil
            CallStorage.drain(&work)
        }
    }
    private var box: Box?

    /// Histories at most this deep are freed by ordinary recursion.
    static let drainDepth: UInt32 = 32

    /// Frees `work` one item at a time, each first handing over whatever only it
    /// holds (`Item.detachForRelease(into:)`), so no release recurses.
    static func drain(_ work: inout [any Item]) {
        while var item = work.popLast() {
            item.detachForRelease(into: &work)
        }
    }

    /// The items a piece table names, for `drain`.
    static func appendItems(of members: Pieces?, to work: inout [any Item]) {
        guard let members else { return }
        for run in members.runs {
            switch run {
            case .item(let item): work.append(item)
            case .span(let source, _, _, _): work.append(source)
            }
        }
    }

    /// Moves this history into `work` if nothing else holds it, leaving it empty,
    /// so freeing it recurses no further (`drain`).
    mutating func detach(into work: inout [any Item]) {
        guard box != nil, isKnownUniquelyReferenced(&box), let unique = box else { return }
        work.append(contentsOf: unique.call)
        unique.call = []
        Self.appendItems(of: unique.members, to: &work)
        unique.members = nil
    }

    static let literal = CallStorage(box: nil)
    private init(box: Box?) { self.box = box }

    init(_ call: [any Item], members: Pieces? = nil) {
        box = call.isEmpty ? nil : Box(call: call, measure: CallMeasure.of(call), members: members)
    }

    var call: [any Item] { box?.call ?? [] }
    var measure: CallMeasure { box?.measure ?? .literal }
    var members: Pieces? { box?.members }

    /// The same history, members and depth, with `weight` as its measured weight
    /// (the length of its crux, which can be far below its tree's). The `call`
    /// array is shared, not copied, so the history is still the same node to
    /// `CruxSharing`.
    func remeasured(weight: Int) -> CallStorage {
        guard let box else { return self }
        return CallStorage(box: Box(
            call: box.call,
            measure: CallMeasure(weight: UInt32(clamping: weight), depth: box.measure.depth),
            members: box.members))
    }
}

/// An item that keeps its history in a `CallStorage`: every item type but
/// `StandInItem`, which never has one. Lets the push boundary record a measured
/// weight (`Interpreter.elidingOverBudgetProvenance`).
nonisolated protocol HoldsCall: Item {
    var callStorage: CallStorage { get set }
}

nonisolated extension BoolItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension CharItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension CodeItem: HoldsCall {
    /// A code block hands over its contents as well as its history, so a history that
    /// runs through code blocks is freed without recursion too.
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) {
        callStorage.detach(into: &work)
        work.append(contentsOf: value)
        value = []
    }
}
nonisolated extension DoubleItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension InstructionItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension IntItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension StringItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension VecBoolItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension VecDoubleItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension VecIntItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension VecStringItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension ErrorItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}
nonisolated extension IteratorItem: HoldsCall {
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) { callStorage.detach(into: &work) }
}

nonisolated extension HoldsCall {
    /// This item with `call` as its history, keeping its members: a fold
    /// (`CruxCompression.folded`) rewrites how the history is written, not where
    /// the elements came from.
    func recalled(_ call: [any Item]) -> any Item {
        var copy = self
        copy.callStorage = CallStorage(call, members: callStorage.members)
        return copy
    }

    /// This item with its weight measured as `weight`; see `CallStorage.remeasured`.
    func remeasured(weight: Int) -> any Item {
        var copy = self
        copy.callStorage = callStorage.remeasured(weight: weight)
        return copy
    }
}

nonisolated extension CallMeasure {
    /// The measure of a `call`; see `Item.measureCall`.
    static func of(_ call: [any Item]) -> CallMeasure {
        var weight: UInt32 = 1
        var deepest: UInt32 = 0
        for child in call {
            let (sum, overflowed) = weight.addingReportingOverflow(UInt32(clamping: child.callWeight))
            weight = overflowed ? .max : sum
            deepest = max(deepest, UInt32(clamping: child.callDepth))
        }
        let depth: UInt32 = call.isEmpty ? 0 : (deepest == .max ? .max : deepest + 1)
        return CallMeasure(weight: weight, depth: depth)
    }
}
