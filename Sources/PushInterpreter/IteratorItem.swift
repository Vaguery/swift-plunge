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
/// A projection must be a **pure function of `(origin, cursor)`** — that is the
/// only thing `projection()` asks of a kind, and it is what keeps every kind O(1)
/// and reconstructible. `origin` never changes for the life of a loop, so the
/// index always means the same thing.
public nonisolated enum IteratorKind: Sendable, Equatable, Codable {
    /// `origin` and `destination` are `IntItem`s; pass `i` emits
    /// `origin + i × stride` to `.int`.
    case counting(stride: Int)

    /// `origin` is a `StringItem`, a vector, or a `CodeItem`; pass `i` emits
    /// `origin[i]` — the **root level only**, never descending into nesting.
    ///
    /// `into` names the stack elements land on, and is `nil` for everything but
    /// `.exec`: a bool out of a `VecBoolItem` obviously belongs on `.bool`, and
    /// `PushStack.defaultStack(for:)` already knows that. `.exec` is the one
    /// target that cannot be derived, because its contents are heterogeneous
    /// *and* pending rather than resting. A `PushStack` is not expressible as a
    /// Push value, so a constructor cannot take one as an argument — which is why
    /// the exception is spelled in an instruction's name (`…IntoExec`) instead.
    case elements(into: PushStack?)

    /// `origin` is a `StringItem`; pass `i` emits `String(origin[i])` — a
    /// one-character *string* — to `.string`. This is `stringParseToLetters`.
    case letters

    /// `origin` is a `StringItem`; pass `i` emits its `i`-th whitespace-delimited
    /// chunk to `.string`. This is `stringSplit`.
    case words

    /// `origin` is anything at all and `destination` is an `IntItem` count; every
    /// pass emits `origin` again. This is the `xDupTimes` family — which is why
    /// the copies record nothing (law 1: a dup changes no value).
    case repeating(into: PushStack?)

    // RESERVED — `case points(into: PushStack?)`
    //
    // The unwritten `.code` behaviors (`codeNthPoint`, `codeIteratePoints`,
    // `codeIndexOfPoint`, `codeLengthPoints`) walk a CodeItem as a zipper:
    // depth-first, descending into nested `CodeItem.value` on sight,
    // left-to-right. That is `.elements`'s sibling rather than a different shape
    // — same CodeItem origin, same Int cursor, the index simply applied in a
    // different mode — and this architecture already admits it: a pre-order walk
    // is a pure function of (origin, cursor), which is all a projection must be.
    //
    // Adding it is one case here, one branch in `projection()`, one in
    // `sourceCount`, and one constructor. Two things must land first, and neither
    // belongs to the current pass: `codeNthPoint` must exist for the element's
    // `call` to name it, and a points *count* is needed for `hasNextPass` —
    // memoized on CodeItem beside its `weight`, since a fresh depth-first count
    // per pass would be O(size) per step.
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

    /// The end bound. `nil` for the kinds whose end derives from the origin
    /// itself — `.elements` runs out when the collection does.
    public var destination: (any Item)?

    /// Emitted to `.code` each pass, for the `.codeDo` beside it to run.
    ///
    /// **`nil` means this iterator is a sequence rather than a loop**: it only
    /// emits its elements, and a pass costs one step instead of three. Exploding
    /// a 200-character string costs 200 steps, not 600 — which against
    /// `stepLimit` is a difference in behaviour, not just in speed.
    ///
    /// An *empty* body is normalized to nil by `init`, so `CodeItem([])` can
    /// never be here to be confused with "no body". That is deliberate: it lets
    /// one constructor per source serve both forms, because a crux can emit `( )`
    /// for a bodyless iterator and get nil back. An empty body is a no-op body,
    /// so nothing is lost by conflating them.
    public var body: CodeItem?

    /// Whether a pass pushes its projection at all. `execDoRange` leaves its
    /// index on `.int` for the body to read; `execDoTimes` deliberately does not.
    public var emits: Bool

    /// How deep in `.exec` this loop hides its next copy — **always ≥ 0**.
    ///
    /// Zero, the overwhelmingly common case, means "directly under the payload":
    /// a tight loop that comes back round as soon as its body is done. A positive
    /// burial lets other pending work run first, so the loop interleaves with it
    /// rather than monopolising `.exec` — a coroutine, in effect.
    ///
    /// It lives here rather than being re-read every pass because re-reading is
    /// what *causes* argument starvation: a thousand-pass loop would eat a
    /// thousand `.int`s. The creators of tight loops never gather one at all, so
    /// they get 0 for free; `.iteratorPlayDelayed` gathers one, once, and it
    /// persists for the life of the loop.
    public var burial: Int

    public var call: [any Item] {
        didSet { callWeight = Self.weighCall(call) }
    }

    public var isContingent: Bool

    public var callWeight: Int

    public init(
        kind: IteratorKind,
        origin: any Item,
        destination: (any Item)? = nil,
        body: CodeItem? = nil,
        emits: Bool,
        cursor: Int = 0,
        burial: Int = 0,
        call: [any Item] = [],
        isContingent: Bool = false
    ) {
        self.value = cursor
        self.kind = kind
        self.origin = origin
        self.destination = destination
        // An empty body is no body: normalizing here is what keeps nil and
        // `CodeItem([])` from being two spellings of the same iterator.
        self.body = (body?.value.isEmpty ?? true) ? nil : body
        self.emits = emits
        self.burial = max(0, burial)
        self.call = call
        self.isContingent = isContingent
        self.callWeight = Self.weighCall(call)
    }

    /// The content this iterator holds, for the `maxItemWeight` budget: its
    /// source and its body, both of which it retains for the loop's duration.
    public var weight: Int {
        let (sum, overflowed) =
            origin.weight.addingReportingOverflow(body?.weight ?? 0)
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
            burial == other.burial,
            origin.isEqual(to: other.origin),
            Self.same(body, other.body),
            Self.same(destination, other.destination)
        else { return false }
        return true
    }

    /// Two optional items are the same when both are absent, or both present and
    /// equal. Used for `body` and `destination`, which are absent for different
    /// reasons but compare the same way.
    static func same(_ mine: (any Item)?, _ theirs: (any Item)?) -> Bool {
        switch (mine, theirs) {
        case (nil, nil):            true
        case let (mine?, theirs?):  mine.isEqual(to: theirs)
        default:                    false
        }
    }

    public func pretty() -> String {
        let where_ = destination.map { "\(origin.pretty())→\($0.pretty())" }
            ?? origin.pretty()
        let by = switch kind {
            case .counting(let stride): " by \(stride)"
            default:                    ""
        }
        let doing = body.map { " \($0.pretty())" } ?? ""
        let deep = burial > 0 ? " ⤓\(burial)" : ""
        return "«\(where_)\(by) @\(value)\(emits ? "" : " silent")\(deep)\(doing)»"
    }
}


// MARK: - Stepping and projection

nonisolated extension IteratorItem {

    /// The stride, as the projection uses it. Everything that walks a source
    /// walks it one at a time.
    var stride: Int {
        switch kind {
        case .counting(let stride): stride
        default:                    1
        }
    }

    /// The stack this iterator's projections come to rest on, when the kind names
    /// one explicitly. `nil` means "derive it from the element itself".
    var target: PushStack? {
        switch kind {
        case .elements(let into):  into
        case .repeating(let into): into
        default:                   nil
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

        case .elements, .letters, .words:
            return element(at: value)

        // A dup: the copy IS the argument, so law 1 applies and it records
        // nothing. This is why the whole `xDupTimes` family needs no `Nth`.
        case .repeating:
            guard !isSpent else { return nil }
            return origin
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
        case .counting:
            currentValue() == nil
        case .repeating:
            value < 0 || value >= (destination as? IntItem)?.value ?? 0
        case .elements, .letters, .words:
            value < 0 || value >= sourceCount
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
        case .repeating:
            return value + 1 < (destination as? IntItem)?.value ?? 0
        case .elements, .letters, .words:
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
    /// the loop's life, so only the literals differ from pass to pass.
    ///
    /// A nil body is written as `( )` and read back as nil, since `init`
    /// normalizes an empty body away. That is what lets one constructor per
    /// source serve both a sequence and a loop.
    func reconstruction() -> [any Item] {
        switch kind {
        case .counting(let stride):
            guard let destination else { return [] }
            return [
                origin,
                destination,
                IntItem(stride),
                IntItem(value),
                IntItem(burial),
                BoolItem(emits),
                body ?? CodeItem([]),
                InstructionItem(.iteratorFromIntRange),
            ]

        // A walking iterator needs no bounds: its end is its origin's own length.
        // The origin lands on its own stack, so only the two cursor-ish ints share
        // `.int`, and `burial` is written last and so arrives on top.
        case .letters, .words, .elements:
            guard let name = walkingConstructor else { return [] }
            return [
                origin,
                IntItem(value),
                IntItem(burial),
                BoolItem(emits),
                body ?? CodeItem([]),
                InstructionItem(name),
            ]

        case .repeating:
            return []   // stage 4
        }
    }

    /// The construct-only instruction that rebuilds this walking iterator. The
    /// kind and the origin's type together pick it — `.letters` and `.words` walk
    /// a string too, but project differently, so each needs its own name.
    var walkingConstructor: PushInstruction? {
        switch kind {
        case .letters: return .iteratorFromStringLetters
        case .words:   return .iteratorFromStringWords
        case .elements:
            switch origin {
            case is StringItem:    return .iteratorFromString
            case is VecBoolItem:   return .iteratorFromVecBool
            case is VecDoubleItem: return .iteratorFromVecDouble
            case is VecIntItem:    return .iteratorFromVecInt
            case is VecStringItem: return .iteratorFromVecString
            default:               return nil   // CodeItem origins: stage 4
            }
        default:
            return nil
        }
    }
}


// MARK: - Walking a collection

nonisolated extension IteratorItem {

    /// The whitespace-delimited chunks of a string origin. `.words` only.
    var sourceWords: [Substring] {
        (origin as? StringItem)?.value.split { $0.isWhitespace } ?? []
    }

    /// How many things this iterator's cursor can address. Zero for anything that
    /// is not a source it knows how to walk.
    var sourceCount: Int {
        switch kind {
        case .words:
            return sourceWords.count
        default:
            switch origin {
            case let s as StringItem:    return s.value.count
            case let v as VecBoolItem:   return v.value.count
            case let v as VecDoubleItem: return v.value.count
            case let v as VecIntItem:    return v.value.count
            case let v as VecStringItem: return v.value.count
            case let c as CodeItem:      return c.value.count
            default:                     return 0
            }
        }
    }

    /// The element at `index`, recording the instruction that honestly reproduces
    /// it — `origin index .vecBoolNth` — which is O(1) and, crucially,
    /// independent of how many passes have run. Order within the record is free:
    /// every `Nth` takes its two arguments from *different* stacks.
    func element(at index: Int) -> (any Item)? {
        guard index >= 0, index < sourceCount else { return nil }
        let cursor = IntItem(index)
        func record(_ names: PushInstruction...) -> [any Item] {
            [origin, cursor] + names.map { InstructionItem($0) }
        }

        switch kind {
        // A one-character *string*, not a char: `stringParseToLetters`. Two
        // instructions to reproduce, still O(1).
        case .letters:
            guard let s = origin as? StringItem else { return nil }
            let i = s.value.index(s.value.startIndex, offsetBy: index)
            return StringItem(
                String(s.value[i]),
                call: record(.stringNth, .stringFromChar),
                isContingent: isContingent
            )

        case .words:
            let chunks = sourceWords
            guard index < chunks.count else { return nil }
            return StringItem(
                String(chunks[index]),
                call: record(.stringNthWord),
                isContingent: isContingent
            )

        default:
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

            // Law 1b: an item that goes into a block and comes back out is the
            // item that went in, so it keeps its own `call` and records nothing.
            // This is what spares the dup families an `Nth` — and it is why
            // `codeNthRoot` can stay unimplemented.
            case let c as CodeItem:
                var element = c.value[index]
                element.isContingent = Behavior.netContingency(of: c, element)
                return element

            default:
                return nil
            }
        }
    }
}
