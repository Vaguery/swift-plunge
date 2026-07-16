//
//  IteratorItem.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/15/26.
//

import Foundation


/// How an iterator's cursor projects into the item it emits each pass.
///
/// The cursor is **always an `Int`**, and everything else is a projection of it.
/// That is what lets one type cover counting, walking a collection, and (later)
/// sampling a Double range: a Double range needs no Double counter, only an
/// origin, an endpoint, and a number of steps to divide the span into.
public nonisolated enum IteratorKind: Sendable, Equatable, Codable {
    /// `origin` and `destination` are `IntItem`s; pass `i` emits
    /// `origin + i × stride` to `.int`.
    case counting(stride: Int)

    /// `origin` is a `StringItem` or a vector; pass `i` emits `origin[i]` to the
    /// matching scalar stack.
    case elements
}


/// One loop's state, entire.
///
/// Before this type was first-class, `execDoRange` kept its bounds as loose ints
/// on `.int` and rebuilt its own recursion as Push source every pass — the
/// counting was done *in Push*. Now the bounds, the stride and the cursor live
/// in here for the loop's duration, the counting is done in Swift, and the only
/// Push-visible artifacts of a pass are the emitted payload and one continuation
/// token. State escapes by stepping, or through the getters (`.iteratorPeekStart`,
/// `.iteratorPeekEnd`, `.iteratorPeekStride`, `.iteratorPeekBody`), and by no other route.
///
/// ## Provenance
///
/// This type began as a provenance-only node living inside `call`, recording
/// "this counter is `base` plus an offset" so that a loop counter's history
/// stayed one node deep however many passes ran. **That node is gone.** Holding
/// `origin` and the cursor here makes it unnecessary: a counter can name its
/// origin and its offset directly, in ordinary items, because the iterator
/// already knows both. The emitted counter records
/// `[origin, IntItem(offset), .intAdd]`, whose crux is exactly what the folding
/// node used to produce — `y0 999 .intAdd` — with no special node to fold.
///
/// The iterator's own `call` reconstructs it *by state* rather than by history:
/// `origin dest stride cursor emits (body) .iteratorFromIntRange`. That is O(1)
/// forever, because `origin`, `destination` and `body` are fixed for the loop's
/// life and only the two literals change from pass to pass. It is self-describing
/// in the same way the old node was — see "The provenance law" in Items.swift.
///
/// **Known caveat:** projection is not overflow-faithful. With `origin` near
/// `Int.max`, adding 1 a thousand times errors at a different step than adding
/// 1000 does. Accepted deliberately.
public nonisolated struct IteratorItem: Item, Pretty {

    /// **The cursor**: how many passes have been taken from `origin`. Everything
    /// this iterator emits is a projection of this one number.
    public var value: Int

    /// How `value` projects into the emitted item.
    public var kind: IteratorKind

    /// The start value, or the collection being walked. **Fixed for the life of
    /// the loop**, which is precisely why provenance stays O(1) — and it keeps
    /// its own `call`, so the crux can still say how a computed bound was
    /// arrived at.
    public var origin: any Item

    /// The end bound. `nil` for `.elements`, whose end is its origin's length.
    public var destination: (any Item)?

    /// Emitted to `.code` every pass, for `.codeDo` to run.
    public var body: CodeItem

    /// Whether a pass pushes its projection at all. `execDoRange` leaves its
    /// index on `.int` for the body to read; `execDoTimes` deliberately does not.
    public var emits: Bool

    public var call: [any Item] {
        didSet { callWeight = Self.weighCall(call) }
    }

    public var isContingent: Bool

    public var callWeight: Int

    public init(
        kind: IteratorKind,
        origin: any Item,
        destination: (any Item)? = nil,
        body: CodeItem,
        emits: Bool,
        cursor: Int = 0,
        call: [any Item] = [],
        isContingent: Bool = false
    ) {
        self.value = cursor
        self.kind = kind
        self.origin = origin
        self.destination = destination
        self.body = body
        self.emits = emits
        self.call = call
        self.isContingent = isContingent
        self.callWeight = Self.weighCall(call)
    }

    /// The content this iterator holds, for the `maxItemWeight` budget: its
    /// source and its body, both of which it retains for the loop's duration.
    public var weight: Int {
        let (sum, overflowed) = origin.weight.addingReportingOverflow(body.weight)
        return overflowed ? Int.max : sum
    }

    // Hand-written rather than synthesized: `origin` is an existential, so
    // `IteratorItem` cannot be `Equatable` and pick up the shared default. That
    // costs nothing — `eqCombinator_Behavior` reaches equality through
    // `isEqual(to:)`, so `.iteratorEq` works without the conformance.
    //
    // Value equality, like every other Item (see "Equality is about values" in
    // Items.swift), and this item's value is its whole state: two iterators over
    // the same range differ if they are at different cursors, or emit different
    // bodies.
    public func isEqual(to other: any Item) -> Bool {
        guard let other = other as? IteratorItem else { return false }
        guard
            value == other.value,
            kind == other.kind,
            emits == other.emits,
            origin.isEqual(to: other.origin),
            body.isEqual(to: other.body)
        else { return false }
        switch (destination, other.destination) {
        case (nil, nil):             return true
        case let (mine?, theirs?):   return mine.isEqual(to: theirs)
        default:                     return false
        }
    }

    public func pretty() -> String {
        let where_ = destination.map { "\(origin.pretty())→\($0.pretty())" }
            ?? origin.pretty()
        let by = switch kind {
            case .counting(let stride): " by \(stride)"
            case .elements:             ""
        }
        return "«\(where_)\(by) @\(value)\(emits ? "" : " silent") \(body.pretty())»"
    }
}


// MARK: - Stepping and projection

nonisolated extension IteratorItem {

    /// The stride, as the projection uses it. `.elements` walks one at a time.
    var stride: Int {
        switch kind {
        case .counting(let stride): stride
        case .elements:             1
        }
    }

    /// The value this iterator's cursor currently names, with the provenance that
    /// reproduces it — or `nil` if the cursor has run past what `origin` holds,
    /// or if projecting it would overflow.
    ///
    /// At cursor 0 the answer is `origin` **itself**, `call` untouched: nothing
    /// has been derived yet, so law 1 applies and the item passes straight
    /// through. After that the counter names its origin and its offset directly:
    /// `[origin, IntItem(offset), .intAdd]`, whose crux is `y0 999 .intAdd`. This
    /// is where the old provenance-only folding node used to be needed, and is
    /// why it no longer is.
    func projection() -> (any Item)? {
        switch kind {
        case .counting:
            guard let current = currentValue() else { return nil }
            guard value != 0 else { return origin }
            let (offset, overflowed) = value.multipliedReportingOverflow(by: stride)
            guard !overflowed else { return nil }
            return IntItem(
                current,
                call: [origin, IntItem(offset), InstructionItem(.intAdd)],
                isContingent: isContingent
            )

        case .elements:
            return element(at: value)
        }
    }

    /// The counter this cursor names, or `nil` on overflow. `.counting` only.
    func currentValue() -> Int? {
        guard let start = (origin as? IntItem)?.value else { return nil }
        let (offset, offsetOverflowed) = value.multipliedReportingOverflow(by: stride)
        guard !offsetOverflowed else { return nil }
        let (current, sumOverflowed) = start.addingReportingOverflow(offset)
        return sumOverflowed ? nil : current
    }

    /// Whether this iterator has anything left to emit at its current cursor.
    var isSpent: Bool {
        switch kind {
        case .counting: currentValue() == nil
        case .elements: value < 0 || value >= sourceCount
        }
    }

    /// Whether another pass follows the one at the current cursor.
    ///
    /// The counting rule preserves `execDoRange`'s existing behavior exactly, and
    /// that behavior is **not** inclusive of the destination, whatever the docs
    /// say: `4 7 .execDoRange` emits 7, 6, 5 and stops, because the old base case
    /// fired at `|current − dest| ≤ 1` *having already emitted* `current`.
    /// Generalizing that to `|dest − current| > |stride|` is bit-for-bit
    /// identical at stride ±1, and extends sensibly to wider strides (0→10 by 3
    /// emits 0, 3, 6, 9).
    ///
    /// The subtraction can overflow — `Int.min` to `Int.max` — and an overflowing
    /// difference means the two are as far apart as it is possible to be, so it
    /// is the looping branch, not a trap. `abs` would trap on `Int.min`; this
    /// does not.
    var hasNextPass: Bool {
        switch kind {
        case .counting:
            guard
                let current = currentValue(),
                let end = (destination as? IntItem)?.value
            else { return false }
            let (difference, tooFarApart) = end.subtractingReportingOverflow(current)
            if tooFarApart { return true }
            return difference.magnitude > stride.magnitude
        case .elements:
            return value + 1 < sourceCount
        }
    }

    /// This iterator advanced by one pass, with provenance for its new state.
    func stepped() -> IteratorItem {
        var next = self
        next.value = value + 1
        next.call = next.reconstruction()
        return next
    }

    /// The `call` that rebuilds this iterator *by state* — the whole reason its
    /// provenance stays O(1). `origin`, `destination` and `body` are fixed for
    /// the loop's life, so only the two literals differ from pass to pass.
    func reconstruction() -> [any Item] {
        guard case .counting(let stride) = kind, let destination else { return [] }
        return [
            origin,
            destination,
            IntItem(stride),
            IntItem(value),
            BoolItem(emits),
            body,
            InstructionItem(.iteratorFromIntRange),
        ]
    }
}


// MARK: - Walking a collection

nonisolated extension IteratorItem {

    /// How many items `origin` holds. Zero for anything that is not a source a
    /// `.elements` iterator can walk.
    var sourceCount: Int {
        switch origin {
        case let s as StringItem:       s.value.count
        case let v as VecBoolItem:      v.value.count
        case let v as VecDoubleItem:    v.value.count
        case let v as VecIntItem:       v.value.count
        case let v as VecStringItem:    v.value.count
        default:                        0
        }
    }

    /// The element at `index`, recording the `Nth` instruction that honestly
    /// reproduces it: `origin index .vecBoolNth` — O(1), and independent of how
    /// many passes have run.
    func element(at index: Int) -> (any Item)? {
        guard index >= 0, index < sourceCount else { return nil }
        let cursor = IntItem(index)
        func record(_ name: PushInstruction) -> [any Item] {
            [origin, cursor, InstructionItem(name)]
        }
        switch origin {
        case let s as StringItem:
            let i = s.value.index(s.value.startIndex, offsetBy: index)
            return CharItem(s.value[i], call: record(.stringNth), isContingent: isContingent)
        case let v as VecBoolItem:
            return BoolItem(v.value[index], call: record(.vecBoolNth), isContingent: isContingent)
        case let v as VecDoubleItem:
            return DoubleItem(v.value[index], call: record(.vecDoubleNth), isContingent: isContingent)
        case let v as VecIntItem:
            return IntItem(v.value[index], call: record(.vecIntNth), isContingent: isContingent)
        case let v as VecStringItem:
            return StringItem(v.value[index], call: record(.vecStringNth), isContingent: isContingent)
        default:
            return nil
        }
    }
}
