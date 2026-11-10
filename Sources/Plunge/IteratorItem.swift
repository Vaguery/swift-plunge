//
//  IteratorItem.swift
//  Plunge
//
//  Created by Bill Tozier on 7/15/26.
//

import Foundation


/// How a `.points` walk hands each point on. The three modes are the pre-order
/// analog of the `codeNth`/`codeEmitNth`/`codeDoNth` trio, and they differ only
/// in what becomes of a point that is itself a sub-block:
///
/// - `boxed` — every point boxed as `.code` (via `codePeekNth`) and left resting
///   there. A leaf becomes `( leaf )`. This is `codeIterate`.
/// - `whole` — the point routed **as it is**: a sub-block rests whole on `.code`,
///   a leaf routes to its own stack, an instruction runs. This is
///   `codeIterateEmit`.
/// - `unwrapped` — the point sent through `.exec` via `.codeDo`, so a sub-block's
///   contents run. Identical to `whole` for a leaf. This is `codeIterateDo`.
public nonisolated enum PointsEmission: Sendable, Equatable, Codable {
    case boxed, whole, unwrapped
}

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
    /// one-character *string* — to `.string`. This is `stringPushAllLetters`.
    case letters

    /// `origin` is a `StringItem`; pass `i` emits its `i`-th whitespace-delimited
    /// chunk to `.string`. This is `stringPushAllWords`.
    case words

    /// `origin` is a `CodeItem`; pass `i` emits its `i`-th **pre-order point**
    /// (root at 0). `.elements`'s sibling — same origin, same Int cursor — but the
    /// index walks the whole tree, not just the root. The `PointsEmission` mode
    /// decides how each point is handed on. This is the `codeIterate*Points` family.
    case points(PointsEmission)

    /// `origin` is anything at all and `destination` is an `IntItem` count; every
    /// pass emits `origin` again. This is the `xDupTimes` family — which is why
    /// the copies record nothing (law 1: a dup changes no value).
    case repeating(into: PushStack?)
}


nonisolated extension IteratorKind {

    /// Whether this kind walks a source, and so has a cycle to go round.
    ///
    /// The dividing line is **where the length comes from**. A walk's length is a
    /// fact about data it was handed, so going round again is a coherent thing to
    /// ask for. `.counting` and `.repeating` were *told* how far to go, in
    /// `destination`; laps there would be a second number meaning the same thing.
    var cycles: Bool {
        switch self {
        case .elements, .letters, .words, .points: true
        case .counting, .repeating:                false
        }
    }
}


/// One loop's state, entire.
///
/// Before this type was first-class, `execDoRange` kept its bounds as loose ints
/// on `.int` and rebuilt its own recursion as Push source every pass — the
/// counting was done *in Push*. Now the bounds, the stride and the cursor live
/// in here for the loop's duration, the counting is done in Swift, and the only
/// Push-visible artifacts of a pass are the emitted payload and one continuation
/// token. State escapes by stepping, by collecting (`.vecFromIterator`, which is
/// stepping to exhaustion and keeping the result), or through the getters
/// (`.iteratorPeekStart`, `.iteratorPeekEnd`, `.iteratorPeekStride`,
/// `.iteratorPeekBody`, `.iteratorPeekLaps`) — and by no other route. Nothing
/// outside this type reads the cursor.
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
    public var kind: IteratorKind {
        didSet { source = SourceView(kind: kind, origin: origin) }
    }

    /// The start value, or the collection being walked. **Fixed for the life of
    /// the loop**, which is precisely why provenance stays O(1) — and it keeps
    /// its own `call`, so the crux can still say how a computed bound was
    /// arrived at.
    public var origin: any Item {
        didSet {
            source = SourceView(kind: kind, origin: origin)
            nestingDepth = Self.depth(origin, destination, body)
        }
    }

    /// What a walk reads from `origin`, worked out once — see `SourceView`. Kept in
    /// step with `origin` and `kind` by their observers; never part of equality,
    /// encoding or weight, since it holds nothing `origin` does not already say.
    private(set) var source: SourceView

    /// The end bound. `nil` for the kinds whose end derives from the origin
    /// itself — `.elements` runs out when the collection does.
    public var destination: (any Item)? {
        didSet { nestingDepth = Self.depth(origin, destination, body) }
    }

    /// Emitted to `.code` each pass, for the `.codeDo` beside it to run.
    ///
    /// **`nil` means this iterator is a sequence rather than a loop**: it only
    /// emits its elements, and a pass costs one step instead of three. Exploding
    /// a 200-character string costs 200 steps, not 600 — which against
    /// `stepLimit` is a difference in behavior, not just in speed.
    ///
    /// An *empty* body is normalized to nil by `init`, so `CodeItem([])` can
    /// never be here to be confused with "no body". That is deliberate: it lets
    /// one constructor per source serve both forms, because a crux can emit `( )`
    /// for a bodyless iterator and get nil back. An empty body is a no-op body,
    /// so nothing is lost by conflating them.
    public var body: CodeItem? {
        didSet { nestingDepth = Self.depth(origin, destination, body) }
    }

    /// `Item.nestingDepth`: one more than the deepest of what this iterator holds.
    /// Maintained by the observers above (and set in `init`), so it is O(1) to read.
    public private(set) var nestingDepth: Int = 1

    static func depth(_ origin: any Item, _ destination: (any Item)?, _ body: CodeItem?) -> Int {
        1 + max(origin.nestingDepth, destination?.nestingDepth ?? 0, body?.nestingDepth ?? 0)
    }

    /// Whether a pass pushes its projection at all. `execDoRange` leaves its
    /// index on `.int` for the body to read; `execDoTimes` deliberately does not.
    public var emits: Bool

    /// How many times the cursor goes round the source — **always ≥ 1**, and 1
    /// (once through, then done) is every iterator that has not asked otherwise.
    ///
    /// **Cycling is an attribute, not a kind.** The projection wraps; the cursor
    /// does not. Pass `i` of a walk emits `element(at: i % sourceCount)`, so a
    /// cycling walk over `[a b c]` emits `a b c a b c …` while its cursor climbs
    /// 0,1,2,3,4,5 — and at `laps == 1` the wrap is the identity, which is why one
    /// expression serves both and there is no second code path to keep honest.
    ///
    /// **The cursor must stay monotone**, and that is the whole design. Resetting
    /// it to 0 at the end of a lap would be observably the same *this pass* and
    /// wrong forever after: `reconstruction()` names the cursor, so a reset cursor
    /// rebuilds an iterator that has done no laps and the crux stops being a fixed
    /// point — and with nothing else to count by, an iterator that rewinds its own
    /// only state is infinite. A second counter would fix that and cost the type
    /// its one invariant: the cursor is an `Int` and everything emitted is a
    /// projection of it.
    ///
    /// **This costs the provenance nothing.** `element(at:)` records
    /// `origin index .vecIntNth`, and for a wrapped index that record is already
    /// right — element 2 of the third lap is still element 2.
    ///
    /// **Only the walking kinds cycle.** `.counting` keeps its span in
    /// `destination` and `.repeating` its count; laps there would be a second
    /// spelling of a number the iterator already has (and `.repeating` *is* a
    /// cycle of length 1, run `destination` times). A program wanting a sawtooth
    /// counter cycles a vector of the numbers. `init` normalizes those kinds to 1
    /// and `.iteratorSetLaps` refuses them outright.
    ///
    public var laps: Int

    /// How deep in `.exec` this loop hides its next copy — **always ≥ 0**.
    ///
    /// Zero, the overwhelmingly common case, means "directly under the payload":
    /// a tight loop that comes back round as soon as its body is done. A positive
    /// burial lets other pending work run first, so the loop interleaves with it
    /// rather than monopolizing `.exec` — a coroutine, in effect.
    ///
    /// It lives here rather than being re-read every pass because re-reading is
    /// what *causes* argument starvation: a thousand-pass loop would eat a
    /// thousand `.int`s. The creators of tight loops never gather one at all, so
    /// they get 0 for free; `.iteratorPlayDelayed` gathers one, once, and it
    /// persists for the life of the loop.
    public var burial: Int

    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    public init(
        kind: IteratorKind,
        origin: any Item,
        destination: (any Item)? = nil,
        body: CodeItem? = nil,
        emits: Bool,
        cursor: Int = 0,
        laps: Int = 1,
        burial: Int = 0,
        call: [any Item] = []) {
        self.value = cursor
        self.kind = kind
        self.origin = origin
        self.destination = destination
        // An empty body is no body: normalizing here is what keeps nil and
        // `CodeItem([])` from being two spellings of the same iterator.
        self.body = (body?.value.isEmpty ?? true) ? nil : body
        self.emits = emits
        // A kind that cannot cycle is normalized rather than trusted, so `laps`
        // can never disagree with a span the iterator already stores.
        self.laps = kind.cycles ? max(1, laps) : 1
        self.burial = max(0, burial)
        self.callStorage = CallStorage(call)
        self.source = SourceView(kind: kind, origin: origin)
        self.nestingDepth = Self.depth(origin, destination, self.body)
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
    // costs nothing — `eqFamily_Behavior` reaches equality through
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
            laps == other.laps,
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

    /// `«origin→destination by stride @cursor ↻laps silent ⤓burial body»`, with
    /// the optional parts present only when they say something. Rendered by
    /// `NestedRendering`, since origin and body can hold blocks holding iterators.
    public func pretty() -> String {
        NestedRendering.render(self)
    }

    /// The fixed text between the destination and the body: stride, cursor, laps,
    /// the silent flag and the burial.
    var prettyMiddle: String {
        let by = switch kind {
            case .counting(let stride): " by \(stride)"
            default:                    ""
        }
        let deep = burial > 0 ? " ⤓\(burial)" : ""
        let round = laps > 1 ? " ↻\(laps)" : ""
        return "\(by) @\(value)\(round)\(emits ? "" : " silent")\(deep)"
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
        // `.whole` derives its stack from the point itself (a sub-block to `.code`,
        // a leaf to its own stack); `.boxed` always lands a CodeItem, so it also
        // derives `.code`. `.unwrapped` is special-cased in `iteratorPass` (it emits
        // a `.codeDo` alongside the point), so its target here is unused.
        case .points:              nil
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
    ///
    /// With `recording` off the counter carries no `call` (the offset is still
    /// computed: its overflow guard decides whether there is a projection at all).
    func projection(recording: ProvenanceRecording) -> (any Item)? {
        switch kind {
        case .counting:
            guard let current = currentValue() else { return nil }
            guard value != 0 else { return origin }
            let (offset, overflowed) = value.multipliedReportingOverflow(by: stride)
            guard !overflowed else { return nil }
            return IntItem(
                current,
                call: recording([origin, IntItem(offset), InstructionItem(.intAdd)]))

        // The wrap is the identity at `laps == 1`, so this one expression is both
        // the plain walk and the cycling one.
        case .elements, .letters, .words, .points:
            guard let index = wrappedCursor else { return nil }
            return element(at: index, recording: recording)

        // A dup: the copy IS the argument, so law 1 applies and it records
        // nothing. This is why the whole `xDupTimes` family needs no `Nth`.
        case .repeating:
            guard !isSpent else { return nil }
            return origin
        }
    }

    /// Which element of the source this cursor names, wrapping once per lap — or
    /// `nil` if the cursor is off the end, or the source is empty.
    ///
    /// **The empty guard is not defensive**, it is the whole reason this is a
    /// property rather than an inline `%`: `x % 0` **traps**, and a trap is a
    /// crashed interpreter rather than an `ErrorItem`. A cycle over nothing
    /// emits nothing, and `isSpent` already says so — but nothing may compute the
    /// index to find that out.
    var wrappedCursor: Int? {
        let count = sourceCount
        guard count > 0, !isSpent else { return nil }
        return value % count
    }

    /// How many items this iterator will emit before it is done, or `nil` if the
    /// question has no answer for its kind — and `Int.max` where the arithmetic
    /// overflows, since a count too large to compute is larger than any budget.
    var totalEmissions: Int? {
        switch kind {
        case .counting, .repeating:
            return nil
        case .elements, .letters, .words, .points:
            let (total, overflowed) = laps.multipliedReportingOverflow(by: sourceCount)
            return overflowed ? Int.max : total
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
    ///
    /// For `.counting` this asks two things: whether the projection is even
    /// computable (it overflows near `Int.max`), and whether the cursor has been
    /// carried *past* the destination. Stepping can never do the latter —
    /// `hasNextPass` stops a pass short of it — but **a setter can put the cursor
    /// anywhere**, and an iterator sitting beyond its own end is finished by any
    /// honest reading.
    var isSpent: Bool {
        switch kind {
        case .counting:
            // A negative cursor is nonsense in every kind — the cursor counts
            // passes taken, and a descending loop carries its direction in the
            // stride rather than here. Stepping cannot produce one; a setter can.
            guard value >= 0 else { return true }
            guard let current = currentValue() else { return true }
            guard let end = (destination as? IntItem)?.value else { return true }
            // Exclusive of the end, as `hasNextPass` is: a cursor that has reached
            // it has nothing to emit. The one exception is the single pass a range
            // whose bounds are equal gets, at cursor 0. (Until 2026-11-09 a cursor
            // set onto the end still emitted it once.)
            if current == end { return value != 0 }
            return stride > 0 ? current > end : current < end
        case .repeating:
            return value < 0 || value >= (destination as? IntItem)?.value ?? 0
        // Laps multiply the source, so this is the one reading that changed
        // when cycling arrived: `sourceCount` was the end, and now it is the end
        // of the *first* lap.
        case .elements, .letters, .words, .points:
            return value < 0 || value >= (totalEmissions ?? 0)
        }
    }

    /// Whether another pass follows the one at the current cursor.
    ///
    /// The counting engine is **exclusive** of its destination: an iterator from 7
    /// toward 4 emits 7, 6, 5 and stops, the rule `|dest − current| > |stride|`,
    /// which extends sensibly to wider strides (0→10 by 3 emits 0, 3, 6, 9).
    /// `execDoCount`, `execDoTimes`, `execDoRange` and `iteratorFromIntRange` all
    /// use it as is, so every counted loop in the language stops short of its end
    /// (`execDoRange` was inclusive, as in Push3, until 2026-11-09).
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
        case .elements, .letters, .words, .points:
            return value + 1 < (totalEmissions ?? 0)
        }
    }

    /// Everything this iterator would emit from its current cursor onward, in
    /// order — the whole sequence, driven to exhaustion.
    ///
    /// **This drives the loop in Swift, inside one step**, and that is the point:
    /// the mechanics of iterating were never meant to be done in Push. What comes
    /// back is a value; the iterator that produced it is finished by definition,
    /// since exhausting it is the only thing this does.
    ///
    /// It follows the **same protocol a played pass does** — emit at the cursor,
    /// stop when `hasNextPass` says the last one has gone by — rather than reading
    /// `isSpent` and running one further. That is not a detail: the counting engine
    /// is exclusive of its destination, so a collector that used the other rule
    /// would hand back a longer sequence than the same iterator emits when played,
    /// and the language would contradict itself.
    ///
    /// **`emits` is ignored**, deliberately. That flag exists so a counted loop's
    /// index does not litter `.int` while its body runs; collecting has no body
    /// and litters nothing, so the flag has nothing to say here. The projections
    /// are what the sequence *contains*, which is a different question from what a
    /// pass *pushes*.
    ///
    /// **What bounds it: `collectionLimit`.** This loop runs inside one step,
    /// where `stepLimit` cannot see it, so it carries its own bound. A played
    /// loop is protected by `stepLimit`; this one is protected by
    /// `collectionLimit` instead. Over it, the answer is `nil`, and the caller
    /// refuses rather than handing back a silently truncated sequence. (A
    /// counting loop's claimed span used to be clamped to `maxIterations` at
    /// `push` first; that was deleted 2026-11-08, and this bound was already the
    /// one that mattered: a stride-0 counter, never clamped, once hung a whole
    /// search here.) The result is a vector, so the push gate measures it once
    /// more on the way out.
    ///
    /// `recording` decides whether the collected items carry provenance; the
    /// cursor's own steps never need any, since nothing outside this loop sees it.
    ///
    /// **A refusal costs nothing.** Walking up to the limit before refusing cost
    /// about 20 ms, and a program that retries in a loop paid it every pass: one
    /// stress-run program spent 44 minutes in `.codeFromIterator` this way. So an
    /// iterator that provably emits more than `limit` is refused before any
    /// walking (`certainlyEmitsMore(than:)`), and the walk below decides only the
    /// cases that check cannot.
    func collected(recording: ProvenanceRecording,
                   limit: Int = IteratorItem.collectionLimit) -> [any Item]? {
        guard !certainlyEmitsMore(than: limit) else { return nil }
        return collectedByWalking(recording: recording, limit: limit)
    }

    /// `collected` without the precheck: the definition the precheck has to agree
    /// with (*Iterator Collection Precheck Tests*).
    func collectedByWalking(recording: ProvenanceRecording, limit: Int) -> [any Item]? {
        var items: [any Item] = []
        var cursor = self
        while let projected = cursor.projection(recording: recording) {
            guard items.count < limit else { return nil }
            items.append(projected)
            guard cursor.hasNextPass else { break }
            cursor = cursor.stepped(recording: .off)
        }
        return items
    }

    /// Whether collecting from the cursor would certainly gather more than `limit`
    /// items, decided in O(1). Only `true` is a promise: `false` means "walk and
    /// see", which is then bounded by about `limit` passes.
    ///
    /// It works from a **lower bound** on the emissions left, which is exact for
    /// every kind except a counting loop whose offset `value × stride` overflows
    /// before it reaches its end (pass counts near `Int.max / |stride|`). That edge
    /// is why it is a bound and not a count. A spent iterator never rests on a
    /// stack (`iteratorBuilt`), so it is left to the walk rather than reasoned
    /// about.
    func certainlyEmitsMore(than limit: Int) -> Bool {
        guard limit >= 0, !isSpent, let atLeast = emissionsLowerBound else { return false }
        return atLeast > UInt(limit)
    }

    /// A lower bound on how many items are left to emit from the cursor, for a
    /// live iterator; nil when its state is malformed. Saturates rather than
    /// overflowing.
    private var emissionsLowerBound: UInt? {
        switch kind {
        case .repeating:
            // Projects at value, value + 1, …, end − 1.
            guard let end = (destination as? IntItem)?.value, end > value, value >= 0 else { return nil }
            return UInt(bitPattern: end &- value)
        case .elements, .letters, .words, .points:
            guard let total = totalEmissions, total > value, value >= 0 else { return nil }
            return UInt(total - value)
        case .counting(let stride):
            guard let current = currentValue(), let end = (destination as? IntItem)?.value else { return nil }
            let distance = end >= current
                ? UInt(bitPattern: end &- current)
                : UInt(bitPattern: current &- end)
            // Stride 0 never moves: `hasNextPass` holds forever unless it starts at
            // its end.
            guard stride != 0 else { return distance == 0 ? 1 : .max }
            // Emits `current`, then steps while more than one stride remains:
            // ⌈distance / |stride|⌉ passes, and at least one.
            let toEnd = distance == 0 ? 1 : (distance - 1) / stride.magnitude + 1
            // The offset `value × stride` must stay representable; past that the
            // projection is nil and the walk stops early.
            let representable = UInt(Int.max) / stride.magnitude
            guard representable >= UInt(value) else { return 1 }
            return min(toEnd, representable - UInt(value) + 1)
        }
    }

    /// The most items `collected()` will gather before refusing. Tied to the
    /// default `maxItemWeight`, because a collection longer than that weighs more
    /// than it (every item weighs at least 1) and the push gate would refuse it
    /// anyway — so under default settings this changes no result, it only stops
    /// a collection that would never end from being computed at all.
    static let collectionLimit = InterpreterSettings().maxItemWeight

    /// This iterator advanced by one pass, with provenance for its new state when
    /// `recording` is on.
    func stepped(recording: ProvenanceRecording) -> IteratorItem {
        var next = self
        next.value = value + 1
        next.call = recording(next.reconstruction())
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
                body ?? CodeItem([]),
                IntItem(value),
                IntItem(burial),
                BoolItem(emits),
                InstructionItem(.iteratorFromIntRange)
            ]

        // A walking iterator needs no bounds: its end is its origin's own length.
        // The body is written beside the origin; only the two cursor-ish ints share
        // `.int`, and `burial` is written last of them and so arrives on top.
        //
        // `laps` is the single piece of state no constructor takes, so a cycling
        // walk has to rebuild itself and then say how far round it goes. At
        // `laps == 1` — every iterator that never asked — the record is exactly
        // what a constructor takes and nothing more.
        case .letters, .words, .elements, .points:
            guard let name = walkingConstructor else { return [] }
            guard laps > 1 else {
                return [
                    origin,
                    body ?? CodeItem([]),
                    IntItem(value),
                    IntItem(burial),
                    BoolItem(emits),
                    InstructionItem(name)
                ]
            }
            // **A cycling walk cannot be rebuilt cursor-first.** `value` counts
            // through all `laps` passes over the source, so a cursor perfectly
            // live at `laps == 7` is past the end at the `laps == 1` a constructor
            // starts with — and `iteratorBuilt` refuses a spent iterator at the
            // door, on the reasoning that a spent one cannot exist so no crux need
            // reproduce one. True of the *destination* state, false of this
            // intermediate one: the rebuild was asking for an iterator that is
            // only spent because it has not been told about its laps yet. The
            // constructor errored, `.iteratorSetLaps` then found no iterator to
            // set, and the crux rebuilt nothing at all.
            //
            // So build at cursor 0 — always live, since an iterator with nothing
            // to emit at 0 could never have been constructed in the first place —
            // then say how far round it goes, then carry the cursor to where it
            // actually is. Each setter re-derives `call` and re-checks liveness,
            // so the rebuilt iterator records this same shape and the crux is a
            // fixed point.
            return [
                origin,
                body ?? CodeItem([]),
                IntItem(0),
                IntItem(burial),
                BoolItem(emits),
                InstructionItem(name),
                IntItem(laps),
                InstructionItem(.iteratorSetLaps),
                IntItem(value),
                InstructionItem(.iteratorSetCounter)
            ]

        // The box is what lets one constructor serve all thirteen stacks: a
        // CodeItem can hold any item, and law 1b says taking it back out gives
        // back the item that went in.
        case .repeating(let into):
            guard let destination else { return [] }
            return [
                CodeItem([origin]),
                destination,
                IntItem(value),
                IntItem(burial),
                InstructionItem(
                    into == .exec ? .iteratorRepeatingIntoExec : .iteratorRepeating
                )
            ]
        }
    }

    /// The construct-only instruction that rebuilds this walking iterator. The
    /// kind and the origin's type together pick it — `.letters` and `.words` walk
    /// a string too, but project differently, so each needs its own name.
    var walkingConstructor: PushInstruction? {
        switch kind {
        case .letters: return .iteratorFromStringLetters
        case .words:   return .iteratorFromStringWords
        case .points(let mode):
            switch mode {
            case .boxed:     return .iteratorFromCode
            case .whole:     return .iteratorFromCodeEmit
            case .unwrapped: return .iteratorFromCodeDo
            }
        case .elements(let into):
            switch origin {
            case is StringItem:    return .iteratorFromString
            case is VecBoolItem:   return .iteratorFromVecBool
            case is VecDoubleItem: return .iteratorFromVecDouble
            case is VecIntItem:    return .iteratorFromVecInt
            case is VecStringItem: return .iteratorFromVecString
            case is CodeItem:      return into == .exec
                                        ? .iteratorFromCodeRootIntoExec
                                        : .iteratorFromCodeRoot
            default:               return nil
            }
        default:
            return nil
        }
    }
}


// MARK: - Walking a collection

nonisolated extension IteratorItem {

    /// The whitespace-delimited chunks of a string origin. `.words` only.
    var sourceWords: [Substring] { source.words }

    /// How many things this iterator's cursor can address. Zero for anything that
    /// is not a source it knows how to walk.
    var sourceCount: Int { source.count }

    /// The element at `index`, recording the instruction that honestly reproduces
    /// it — `origin index .vecBoolNth` — which is O(1) and, crucially,
    /// independent of how many passes have run. Order within the record is free:
    /// every `Nth` takes its two arguments from *different* stacks.
    func element(at index: Int, recording: ProvenanceRecording) -> (any Item)? {
        guard index >= 0, index < sourceCount else { return nil }
        let cursor = IntItem(index)
        func record(_ names: PushInstruction...) -> [any Item] {
            [origin, cursor] + names.map { InstructionItem($0) }
        }

        switch kind {
        // A one-character *string*, not a char: `stringPushAllLetters`. Two
        // instructions to reproduce, still O(1). Built exactly as `.stringNth` then
        // `.stringFromChar` would build it, members included, so a replay of
        // anything taken out of it agrees with the original.
        case .letters:
            guard index < source.characters.count else { return nil }
            let character = source.characters[index]
            let char = (origin as? StringItem)?.traced(at: index, character, recording)
                ?? CharItem(character, call: recording(record(.stringNth)))
            return StringItem(
                String(character),
                call: recording([char, InstructionItem(.stringFromChar)]),
                members: recording.pieces([Origin.item(char)]))

        case .words:
            let chunks = source.words
            guard index < chunks.count, let text = origin as? StringItem else { return nil }
            return StringItem(
                String(chunks[index]),
                call: recording(record(.stringNthWord)),
                members: recording.pieces(text.origins(of: chunks[index])))

        // The i-th pre-order point. `.boxed` yields exactly what `codePeekNth`
        // does — the point boxed as `.code`, recording that (nondestructive)
        // instruction's cleanup crux, reproducing debris-free. `.unwrapped` also
        // boxes: `iteratorPass` routes the box through `.codeDo`, which spills the
        // contents (a leaf's box `( x )` spills to `x`). `.whole` hands the raw
        // point on, keeping its own provenance (law 1b) so it rests wherever its
        // type belongs.
        case .points(let mode):
            guard index < source.points.count else { return nil }
            let point = source.points[index]
            if mode == .whole {
                guard let tree = origin.exactly(CodeItem.self) else { return point }
                return Containment.takenOut(point, of: tree, at: cursor, by: .codeEmitNth, recording)
            }
            let contents = (point.exactly(CodeItem.self))?.value ?? [point]
            return CodeItem(
                contents,
                call: recording(Behavior.reading(
                    [.code: 1, .int: 1],
                    producing: .code,
                    from: [origin, IntItem(index), InstructionItem(.codePeekNth)]
                )))

        // A vector's or string's element is the item that went in, if it kept a
        // history (a member, `Containment`); otherwise its address.
        default:
            switch origin {
            case let text as StringItem:
                guard index < source.characters.count else { return nil }
                return text.traced(at: index, source.characters[index], recording)
                    ?? CharItem(source.characters[index], call: recording(record(.stringNth)))
            case let v as VecBoolItem:
                return v.traced(at: index, recording) ?? BoolItem(v.value[index], call: recording(record(.vecBoolNth)))
            case let v as VecDoubleItem:
                return v.traced(at: index, recording)
                    ?? DoubleItem(v.value[index], call: recording(record(.vecDoubleNth)))
            case let v as VecIntItem:
                return v.traced(at: index, recording) ?? IntItem(v.value[index], call: recording(record(.vecIntNth)))
            case let v as VecStringItem:
                return v.traced(at: index, recording)
                    ?? StringItem(v.value[index], call: recording(record(.vecStringNth)))

            // Law 1b: an item that goes into a block and comes back out is the
            // item that went in, so it keeps its own `call` and records nothing.
            // This is what spares the dup families an `Nth`: their copies need no
            // record of where they came from. One born in the block records its
            // address instead (`Containment`).
            case let c as CodeItem:
                return Containment.takenOut(c.value[index], of: c, at: cursor, by: .codeEmitNthRoot, recording)

            default:
                return nil
            }
        }
    }
}


/// What an iterator walks, read out of its `origin` once rather than on every pass.
///
/// A pass used to recount its source several times (`isSpent`, `hasNextPass`,
/// `wrappedCursor`, `element(at:)`), and for strings, words and code trees every
/// count was O(n): a string's characters counted from the start, its words
/// re-split into a fresh array, a tree re-walked into a fresh pre-order list. A
/// whole walk was quadratic. This holds the count and the indexable view, so a pass
/// is O(1). Rebuilt whenever `origin` or `kind` changes.
nonisolated struct SourceView: Sendable {
    /// How many elements one lap emits — what `sourceCount` reports.
    let count: Int
    /// A string origin's characters, indexable (`.letters`, and `.elements`).
    let characters: [Character]
    /// A string origin's whitespace-separated words (`.words`).
    let words: [Substring]
    /// A code origin's pre-order points, root first (`.points`).
    let points: [any Item]

    init(kind: IteratorKind, origin: any Item) {
        var characters: [Character] = []
        var words: [Substring] = []
        var points: [any Item] = []
        let count: Int
        switch kind {
        case .words:
            words = (origin as? StringItem)?.value.split { $0.isWhitespace } ?? []
            count = words.count
        case .points:
            // The whole pre-order point count (root included), not the root
            // length — that is the difference between `.points` and `.elements`.
            points = (origin.exactly(CodeItem.self))?.preorderPoints ?? []
            count = points.count
        default:
            switch origin {
            case let s as StringItem:
                characters = Array(s.value)
                count = characters.count
            case let v as VecBoolItem:   count = v.value.count
            case let v as VecDoubleItem: count = v.value.count
            case let v as VecIntItem:    count = v.value.count
            case let v as VecStringItem: count = v.value.count
            case let c as CodeItem:      count = c.value.count
            default:                     count = 0
            }
        }
        self.count = count
        self.characters = characters
        self.words = words
        self.points = points
    }
}
