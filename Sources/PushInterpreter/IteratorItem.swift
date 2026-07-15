//
//  IteratorItem.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/15/26.
//

import Foundation


/// A provenance-only node recording "this base value, plus an offset".
///
/// Loop counters are the one place `call` has an honest excuse to grow: a
/// counter really does get 1 added to it every few steps, so its faithful
/// history is `y0 1 .intAdd 1 .intAdd 1 .intAdd …`, linear in the iteration
/// count. Recording that honestly is what runs the interpreter out of memory.
///
/// The trick that collapses it is that an `IteratorItem`'s **own `call` is
/// always empty**. It is self-describing rather than derived, so it has no
/// history of its own to grow — which is what makes it different from simply
/// pointing each counter at the previous one. Because `base` stays fixed for
/// the life of a loop, stepping is `offset + 1` against that same base and the
/// record stays exactly one node deep forever:
///
///     c1.call   = [IteratorItem(y0, +1)]
///     c999.call = [IteratorItem(y0, +999)]      crux: y0 999 .intAdd
///
/// It never comes to rest anywhere: `PushStack.defaultStack(for:)` returns nil
/// for it and no stack `accepts` it, so a leak onto a value stack trips the
/// existing `INVARIANT:` marker instead of corrupting a stack. (`.exec` accepts
/// any item, so it is not self-policing there.) It has no `AnyItem` envelope
/// case either, so an attempt to serialize one fails loudly rather than
/// silently — appropriate, since `AnyItem` drops `call` regardless.
///
/// **Known caveat:** folding is not overflow-faithful. With `base` near
/// `Int.max`, adding 1 a thousand times errors at a different step than adding
/// 1000 does. Accepted deliberately.
///
/// **This is the provenance-only core of a type that is planned to become
/// first-class** — its own stack, its own combinators — as it is in the earlier
/// interpreter this comes from, where making it first-class made the language
/// markedly more evolvable. The `exec` instructions that produce iterators will
/// change so the first-class item is popped and pushed as part of the
/// transaction. Until then `PushStack.defaultStack(for:)` returns nil for it,
/// meaning "does not come to rest anywhere yet"; callers should skip what has no
/// resting stack rather than build around the gap. Wants to follow the CodeItem
/// `.exec`→`.code` change. See "Notes on Push/Provenance and the crux.md".
///
/// **Also to revisit:** counting down and striding by an increment need no new
/// field — `offset` is a signed running total and `steppedCall(from:by:)` takes
/// any step. A `step` field would record *structure* ("333 passes of +3" vs
/// "999 passes of +1"), which the net offset cannot distinguish and which the
/// explanatory goal may want. Non-additive stepping (a doubling loop) genuinely
/// cannot be expressed by an offset and would need an operation field.
public nonisolated struct IteratorItem: Item, Pretty {
    /// The offset from `base`; negative for a descending loop.
    public var value: Int

    /// The value this counter was originally stepped away from. Fixed for the
    /// life of the loop, which is precisely why folding stays O(1).
    public var base: any Item

    /// Always empty. An `IteratorItem` describes itself, and that is what bounds
    /// the counter's provenance.
    public var call: [any Item]

    public var isContingent: Bool

    public init(base: any Item, offset: Int, isContingent: Bool = false) {
        self.value = offset
        self.base = base
        self.call = []
        self.isContingent = isContingent
    }

    /// `base`'s own reconstruction, then the one arithmetic step that reaches
    /// this value. Overriding this is why `crux()` is declared as an `Item`
    /// requirement and not only in an extension — an extension-only method would
    /// dispatch statically through `any Item` and silently ignore this.
    public func crux() -> [any Item] {
        base.crux() + [IntItem(value), InstructionItem(.intAdd)]
    }

    /// The node adds no value content of its own; it only refers to `base`.
    public var weight: Int { base.weight }

    /// Computed, not stored: `call` is always empty here, so the shared
    /// `weighCall(call)` would report 1 and hide `base` entirely. The crux this
    /// node emits is `base`'s plus the two-item `offset .intAdd` step, and that
    /// is what the budget needs to see. Constant time, because `base` stores its
    /// own — and constant across iterations, because `base` never changes.
    public var callWeight: Int {
        let (sum, overflowed) = base.callWeight.addingReportingOverflow(2)
        return overflowed ? Int.max : sum
    }

    // Hand-written rather than synthesized: `base` is an existential, so
    // `IteratorItem` cannot be `Equatable` and pick up the shared default.
    //
    // Value equality, like every other Item (see "Equality is about values" in
    // Items.swift) — and this node's value is the pair, since "y0 + 3" and
    // "y1 + 3" describe different numbers.
    public func isEqual(to other: any Item) -> Bool {
        guard let other = other as? IteratorItem else { return false }
        return value == other.value && base.isEqual(to: other.base)
    }

    public func pretty() -> String {
        "«\(base.pretty()) \(value < 0 ? "" : "+")\(value)»"
    }
}


nonisolated extension IteratorItem {

    /// The `call` a counter should record when it is reached by stepping `from`
    /// by `step`.
    ///
    /// This is the folding rule. When `from` is *already* an offset from some
    /// base, the new counter records that same base with a larger offset rather
    /// than nesting a reference to `from` — so going around the loop again costs
    /// nothing. Only the first step of a loop allocates a new node.
    static func steppedCall(from: any Item, by step: Int) -> [any Item] {
        if from.call.count == 1, let prior = from.call[0] as? IteratorItem {
            let (offset, overflowed) = prior.value.addingReportingOverflow(step)
            if !overflowed {
                return [
                    IteratorItem(
                        base: prior.base,
                        offset: offset,
                        isContingent: prior.isContingent
                    )
                ]
            }
            // Unreachable short of 2^63 iterations; nest rather than trap.
        }
        return [
            IteratorItem(
                base: from,
                offset: step,
                isContingent: from.isContingent
            )
        ]
    }
}
