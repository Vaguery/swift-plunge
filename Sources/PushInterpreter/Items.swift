//
//  Items.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


// building up the protocol infrastructure

public nonisolated protocol Pretty {
    func pretty() -> String
}

// MARK: - The provenance law
//
// An item's `call` records how to rebuild it, and `crux()` reads that record
// back out as runnable Push source. The record is NOT a trace of what ran. Its
// one obligation is:
//
//     running an item's crux on a fresh interpreter reproduces that item's
//     value, on that item's stack.
//
// Combinatory rearrangement cannot affect that obligation, so it must not be
// recorded — recording it is what made `call` grow without bound. For each
// result a Behavior returns:
//
//  1. Rearrangement WITHIN one stack is free: the result keeps its argument's
//     `call` untouched. Covers dup/swap/rot/pop/flush/yank/yankDup/deepDup/
//     shove, the exec combinators (execK, execS, execIf), and every body copy
//     or re-pushed continuation token an iteration emits.
//
//  1b. CONTAINMENT in a CodeItem is free the same way. A block may be
//     restructured, concatenated, duplicated and taken apart again, but by
//     convention it never changes the `.value` of what it holds — so an item
//     that goes into a block and comes back out is the item that went in, and
//     the block contributes nothing to its history. Unwrapping therefore drops
//     the *block's* `call` and leaves each content's own `call` untouched,
//     exposing them as though they had been sitting there all along. This is
//     what `.codeDo` does.
//
//     An item BORN inside a block rather than put there (the contents of a
//     block bound to `.input3`, a block a structural edit rebuilt) has no history
//     to keep. Taken out of a block that has one, it records its ADDRESS instead:
//     `block k .codeEmitNthRoot` and the clean-up. See `Containment`.
//
//     The same holds for CONTAINMENT IN AN ITERATOR: an `IteratorItem` keeps the
//     bounds and body it was built from, and the getters (`.iteratorPeekStart`,
//     `.iteratorPeekEnd`, `.iteratorPeekBody`) hand back the very items that went in, so
//     they record nothing. `.iteratorPeekStride` is the exception that shows the
//     rule — there is no contained item to give back, only a stored Int, so it
//     really is produced by that instruction and records under rule 3.
//
//  2. Relocation ACROSS stacks is not free: `.intQuote` moves a value from
//     `.int` to `.code`, and a crux omitting it would leave an int where a code
//     item belongs. These record `call = [args…, InstructionItem(name)]`.
//     Transit does not count: an arg pushed to `.exec` that `pushDefault`
//     returns to `.int` has moved nowhere, so rule 1 applies.
//
//  3. A genuinely new value records `call = [args…, InstructionItem(name)]` —
//     args in the order that re-runs postfix, instruction last.
//
//  3b. UNLESS the arguments come from `.exec`, in which case the instruction is
//     recorded FIRST: `call = [InstructionItem(name), args…]`. Push is not
//     uniformly postfix, and this is the important quirk. An `.exec` argument is
//     not waiting on a stack behind the instruction — it is the next thing ahead
//     of it in the program, so the source that re-runs it must read
//     `.execQuote 3`, not `3 .execQuote`. Reconstructed source is executed from
//     `.exec` like any other program, so it has to be written the way `.exec`
//     reads it. `execQuote` is the one that records this way (`execEq` did too,
//     and was removed because a prefix crux cannot reproduce a derived operand).
//
//  4. A freshly minted instruction token records nothing. Its crux is itself.
//
//  4b. A result read from transient EXECUTION state rather than from arguments
//     records a STAND-IN: the literal value it observed, marked as observed and
//     naming the instruction (`StandInItem`). `.boolStackDepth` reported 4
//     because `.bool` happened to be 4 deep; re-running `.boolStackDepth` says
//     nothing about that, but the literal reproduces it exactly, and the stand-in
//     (`.boolStackDepth_actuallyWas_4`) says it is a literal standing in for a
//     history, not one the program contained. The same goes for errors that
//     depend on transient stack state ("missing args", "on empty stack") and for
//     the interpreter's own diagnostics. (Contrast `.input3` and `.int7`, which read the
//     *environment*: those bindings outlive the run and are re-supplied when a
//     crux is re-run, so naming them reproduces the value and they do record.)
//     The test is whether re-running the name would find the same world.
//
//  5. When a Behavior puts SEVERAL results on ONE stack, each result records the
//     discard that surfaces it, right there in its own `call`. The deeper piece
//     of a `.vecIntCut`, for instance, records the pop that removes the piece
//     above it:
//
//         call: [v, i, .vecIntCut, IntItem(1), .vecIntPopItems]
//
//     The count is taken from the END of that stack's results, NOT the order
//     they were produced in: `distribute` prepends Routers one at a time, so the
//     last one pushed ends up on top. Of N results on a stack, the one at
//     position i needs `N - 1 - i` pops — the first produced is the deepest. The
//     top one needs none and records nothing extra. Count N and i among
//     same-stack results only: an instruction emitting one `.char` and three
//     `.exec` items has N = 1 on `.char`.
//
// `crux()` needs no special case for any of this — it walks `call` and lets each
// element speak. Recording the pops as ordinary items rather than as a separate
// `index` field is deliberate: the Behavior knows exactly what it pushed and
// where, so it states the selection outright instead of leaving `crux()` to
// re-derive a stack from the item's type.
//
// Growth that survives this law is honest (a value really was accumulated), and
// is bounded by the `callWeight` budget in `Interpreter.push`.

public nonisolated protocol Item: Pretty, Sendable {
    associatedtype Value
    var call: [any Item] {get set}
    var value: Value {get set}

    /// Declared here (not only in an extension) so it dispatches dynamically
    /// through `any Item` — same reason as `weight` below. A
    /// protocol-extension-only method would dispatch *statically* through the
    /// existential and silently ignore any override.
    ///
    /// **Nothing overrides it today.** `IteratorItem` did, back when it was a
    /// provenance-only node whose crux was `base.crux() + [offset, .intAdd]`;
    /// making the iterator first-class removed the need (see IteratorItem.swift),
    /// and every type now walks `call` the same way. The requirement stays because
    /// the failure it prevents is silent: a future override written against an
    /// extension-only method would compile, look right, and never run.
    func crux() -> [any Item]

    /// A recursive memory-proxy: the total primitive content this item holds,
    /// summed through nesting (a vector's elements, a string's characters, a
    /// code block's leaves). Scalars weigh 1. Container types store it, computed
    /// once at construction. Declared here (not only in an extension) so it
    /// dispatches correctly through `any Item`.
    var weight: Int {get}

    /// The provenance counterpart of `weight`: roughly the number of items
    /// `crux()` would emit for this item, and so a proxy for both the memory the
    /// history occupies and the size of the reconstruction. Bounded by
    /// `maxCallWeight` at the push boundary (`Interpreter.push`).
    ///
    /// Unlike `weight` this cannot be a construction-time `let`: `value` is never
    /// mutated after construction, but `call` *is* reassigned during execution.
    /// So each struct stores it and refreshes it from `call`'s `didSet`. It is
    /// maintained rather than computed on demand because the case that matters —
    /// a long accumulation chain — would otherwise cost a full walk per push, and
    /// re-walking a chain that grows by one each step is the quadratic behaviour
    /// this whole exercise exists to remove.
    var callWeight: Int {get}

    /// How deeply `call` nests: 0 for a literal, one more than the deepest child
    /// otherwise. Maintained alongside `callWeight` (packed with it in a
    /// `CallMeasure`) for the same reason: a long chain must not cost a walk per
    /// push. `Interpreter.push` elides provenance deeper than `maxCallDepth`,
    /// because releasing or walking a tree costs a stack frame per level, and a
    /// concurrency worker thread's stack is small (see `maxCallDepth`).
    var callDepth: Int {get}

    /// How deeply other items nest inside this one's *value*, counting every
    /// container: blocks inside blocks, and blocks and iterators inside each other
    /// (an iterator's origin, destination and body; an iterator quoted into a
    /// block). 0 for a scalar. Cached by the containers at construction, so
    /// `maxCodeDepth` can be enforced at every push without a walk, and so no walk
    /// or release can recurse deeper than it on a small worker-thread stack.
    var nestingDepth: Int {get}

    func isEqual(to other: any Item) -> Bool
}

nonisolated extension Item {
    /// This item as a `T` when its type is exactly `T`, else `nil`, without a
    /// runtime cast.
    ///
    /// Called on an `any Item`, the existential is opened, so `Self` is the item's
    /// concrete type: the test is a metadata pointer compare, and on a match the
    /// value is reinterpreted with `unsafeBitCast`, which is exact because `Self` *is*
    /// `T`. `as?`/`as!` out of an existential instead call `swift_dynamicCast`, which
    /// the Phase 4 profile found on every push and every step. Exact type, not `is`,
    /// for the reason given at `PushStack.accepts`.
    @inline(__always)
    func exactly<T: Item>(_: T.Type) -> T? {
        Self.self == T.self ? unsafeBitCast(self, to: T.self) : nil
    }
}

/// An item's `callWeight` and `callDepth`, packed into the 8 bytes `callWeight`
/// alone used to take. That matters: a small item (`IntItem` is a value, its
/// `call` and this) must stay within the three words an `any Item` stores inline,
/// or every one of them is boxed on the heap. Both halves saturate at
/// `UInt32.max`, far above any budget.
public nonisolated struct CallMeasure: Sendable, Hashable {
    public let weight: UInt32
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
    private final class Box: Sendable {
        let call: [any Item]
        let measure: CallMeasure
        let members: Pieces?
        init(call: [any Item], measure: CallMeasure, members: Pieces?) {
            self.call = call; self.measure = measure; self.members = members
        }
    }
    private let box: Box?

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

nonisolated extension BoolItem: HoldsCall {}
nonisolated extension CharItem: HoldsCall {}
nonisolated extension CodeItem: HoldsCall {}
nonisolated extension DoubleItem: HoldsCall {}
nonisolated extension InstructionItem: HoldsCall {}
nonisolated extension IntItem: HoldsCall {}
nonisolated extension StringItem: HoldsCall {}
nonisolated extension VecBoolItem: HoldsCall {}
nonisolated extension VecDoubleItem: HoldsCall {}
nonisolated extension VecIntItem: HoldsCall {}
nonisolated extension VecStringItem: HoldsCall {}
nonisolated extension ErrorItem: HoldsCall {}
nonisolated extension IteratorItem: HoldsCall {}

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

nonisolated extension Item {
    // Default for scalar items (Bool, Int, Double, Char, Instruction, Error):
    // one unit each. Container types override with a stored, memoized weight.
    public var weight: Int { 1 }

    /// Scalars hold nothing: depth 0. Containers store their own.
    public var nestingDepth: Int { 0 }


    /// The `callWeight` and `callDepth` for a freshly assigned `call`. Each child already stores
    /// its own, so this is O(call.count) — not O(chain) — which is what keeps
    /// maintaining it cheap.
    ///
    /// Saturating rather than trapping: provenance is a DAG, so a shared node
    /// counted once per path can in principle exceed `Int.max` even though the
    /// stored graph is small. Saturating keeps the over-budget check firing;
    /// wrapping would make it silently pass.
    static func measureCall(_ call: [any Item]) -> CallMeasure { CallMeasure.of(call) }
}

// MARK: - Equality is about values
//
// An Item's `==` compares its `value` and nothing else. Not `call`: that
// describes how the item came to be, not what it is. `5` computed as
// `2 3 .intAdd` equals `5` computed as `1 4 .intAdd`,
// and equals a literal `5`.
//
// This matters in two places:
//
//  - `.xEq` (Combinator Behaviors) compares with `isEqual(to:)`, so the language's
//    equality is this equality. Comparing provenance there made `5 == 5` false
//    whenever the fives were derived differently, which also made an `.xEq`
//    result impossible to reconstruct — a re-run necessarily builds its operands
//    by a different route than the original did.
//
//  - `Comparable`. `<` compares `value` alone, so an `==` that compared more than
//    `value` contradicted it: two items both holding 5 were simultaneously
//    not-less, not-equal and not-greater, which is not a strict total order.
//    Value-only equality is what makes `==` and `<` agree.
//
// **Language quirk to explore later:** Push has no `===`. Items are immutable, so
// "the identical object" cannot arise in the literal sense — but a *deep*
// identity (same value AND same history) does arise, most obviously when `.xDup`
// copies an item's whole call tree onto its duplicate. There is currently no way
// for a program to ask that question, and no instruction that answers it.
// Whether the language wants one is open.

nonisolated extension Item where Self: Equatable {
    /// Value equality, reached across the `any Item` existential. This is the
    /// language's equality — `.xEq` is built on it — so it deliberately ignores
    /// provenance. See the note above.
    public func isEqual(to other: any Item) -> Bool {
        guard let otherWithSameType = other as? Self else { return false }
        return self == otherWithSameType
    }
}


nonisolated extension Item {
    /// Runnable Push source that reproduces this item's value on this item's
    /// stack. See "The provenance law" above — this reads back what the law
    /// tells Behaviors to record.
    public func crux() -> [any Item] {
        // An empty `call` means "I am a literal", and a literal is already a
        // runnable program producing itself. A literal that stands in for a lost
        // history is a `StandInItem`, which is also a leaf (its `call` is empty),
        // so it appears in the crux as itself, marked. That is how eliding an
        // over-budget `call` (Interpreter.push) stays safe *and* visible.
        //
        // Otherwise the history is written out left to right, each SHARED node
        // built once and reused by dup and yank, as the program reused it
        // (`CruxSharing`). With nothing shared, that is the tree leaf by leaf.
        // Iterative, not recursive: a call tree can legally nest thousands deep,
        // and recursion one Swift frame per level overflowed the small stack of a
        // concurrency worker thread (found by the dual-mode stress run: depth 2,463).
        CruxSharing.crux(of: self)
    }
}






//  global == definition to help compare items that aren't the same exact type
//
public nonisolated func == (lhs: [any Item], rhs: [any Item]) -> Bool {
    // Arrays must have the same count to be equal
    guard lhs.count == rhs.count else { return false }
    
    // Compare elements line-by-line using zip
    return zip(lhs, rhs).allSatisfy { leftElement, rightElement in
        leftElement.isEqual(to: rightElement)
    }
}











// creating structs for each PushType

public nonisolated struct BoolItem: Item, Equatable, Pretty {
    public var value: Bool
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    
    public init(_ value: Bool, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }
    
    public static func == (lhs: BoolItem, rhs: BoolItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}

public nonisolated struct CharItem: Item, Equatable, Comparable, Pretty {
    public var value: Character
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    
    public init(_ value: Character, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }
    
    public static func == (lhs: CharItem, rhs: CharItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public static func < (lhs: CharItem, rhs: CharItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "'\(value)'"
    }

}


// MARK: - The universal box
//
// **A CodeItem is this language's vector-of-anything**, and that is worth saying
// out loud because its name does not say it. `value` is `[any Item]`: it holds
// ints, strings, vectors, instructions, iterators, other blocks — anything, in any
// mixture, nested to any depth. Every other collection here is homogeneous by
// construction. This one is the only heterogeneous container in the language, and
// the only one that can hold an item that is not a value at all.
//
// Read `.code` as "the code stack" and you will keep meeting the same surprise
// from different directions. Read it as "the stack of arbitrary sequences, which
// a program may also choose to run", and these stop being surprises:
//
//  - **One constructor serves thirteen stacks.** `.iteratorRepeating` takes its
//    payload boxed — `( item ) count cursor burial` — because a block can hold any
//    item, so there is no need for a per-stack constructor. The setters do the
//    same with `( 5 )`: `takes:` is declared statically and cannot ask an iterator
//    what type it wants, so the value arrives in the universal box.
//  - **It is the general case of collecting.** `.codeFromIterator` never refuses,
//    while `.vecFromIterator` is the special case for when the emissions happen to
//    be uniform scalars. A tree walk emitting subtrees, a mixed block, a string's
//    chars — all have an answer, because a block holds anything.
//  - **Boxing costs nothing** (law 1b, and principle 8): an item put in and taken
//    back out is the item that went in, keeping its own `call`. The box is
//    transparent to provenance, which is precisely what makes it usable as a
//    universal channel rather than a lossy one.
//  - **It is the scarcest thing in the language.** Structurally, `.code` has ~0.29
//    producers per consumer — the five quotes, and now the collector. Everything
//    else reshapes code it was already given. See "Stack economics".
//
// The cost of that generality is that `.code` is the one stack where two items of
// the same type are not interchangeable as arguments, which `.exec` shares and
// `.iterator` now joins — see "Sieve arguments.md" on liquid types.
public nonisolated struct CodeItem: Item, Equatable, Pretty {
    /// **Anything, in any mixture, nested to any depth** — see "The universal box"
    /// above. This is the only heterogeneous container in the language.
    public var value: [any Item]
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// The number of items in this code's fully flattened `.value`: every
    /// non-code item counts as one, and a nested `CodeItem` contributes its own
    /// `flatSize` (its contents), recursively — so `[1, [2, 3]]` is 3 and an
    /// empty or empty-nested block contributes nothing. Computed once here
    /// because `value` is never mutated after construction.
    public let flatSize: Int

    /// Recursive content weight: the sum of the weights of everything this block
    /// holds, at every level. Reuses each child's already-stored weight.
    public let weight: Int

    /// How deeply blocks nest inside this one, counting blocks only: 0 for an
    /// empty block, 1 for a flat one, one more per level — `(1 (2 3))` is 2. This
    /// is what `.codeDepth` reports. Computed once from the children, like
    /// `flatSize`.
    public let blockDepth: Int

    /// `Item.nestingDepth`: like `blockDepth`, but counting iterators too (a block
    /// holding a quoted iterator whose body is a block…). The one `maxCodeDepth`
    /// enforces. Weight cannot stand in for it: wrapping adds a level and no weight.
    public let nestingDepth: Int

    public init(_ value: [any Item], call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
        // One pass, and no runtime casts (`exactly`; see `Item.exactly(_:)`): an edit
        // rebuilds every block on its path, so this runs for most points of a block a
        // code instruction touches, and four passes with two `as?` casts per element
        // were most of what a code edit on a large block cost.
        var flatSize = 0, weight = 0, deepestBlock = 0, deepestNesting = 0
        for element in value {
            weight += element.weight
            deepestNesting = Swift.max(deepestNesting, element.nestingDepth)
            if let block = element.exactly(CodeItem.self) {
                flatSize += block.flatSize
                deepestBlock = Swift.max(deepestBlock, block.blockDepth)
            } else {
                flatSize += 1
            }
        }
        self.flatSize = flatSize
        self.weight = weight
        self.blockDepth = value.isEmpty ? 0 : 1 + deepestBlock
        self.nestingDepth = value.isEmpty ? 0 : 1 + deepestNesting
    }

    public static func == (lhs: CodeItem, rhs: CodeItem) -> Bool {
        lhs.value == rhs.value
    }
    
    /// `( a b c )`. Rendered by `NestedRendering`, which walks nested blocks and
    /// iterators with an explicit stack rather than recursing.
    public func pretty() -> String {
        NestedRendering.render(self)
    }


}


// MARK: - CodeItem as a tree: pre-order points
//
// A **point** is any node of the tree a CodeItem implies: the CodeItem itself
// (the root, index 0), every element of its `.value`, and — descending into any
// element that is itself a CodeItem — that block's points too, recursively.
// Ordering is **pre-order** (a node before its children, left to right): root,
// then `.value[0]` and everything under it, then `.value[1]`, and so on, ending
// at the deepest-rightmost leaf.
//
//   ( (1 2) 3 )  →  0:((1 2) 3)  1:(1 2)  2:1  3:2  4:3
//
// A **leaf** is any non-CodeItem — a scalar, an instruction, or a whole vector.
// Vectors are opaque: a `VecIntItem [1,2,3]` is one point, never four. An empty
// block `( )` is a point (a node with no children).
nonisolated extension CodeItem {

    /// The item this block **denotes** under the singleton-unwrap convention: a
    /// one-element block denotes its sole element, any other block denotes itself.
    ///
    /// `(6)` denotes the leaf `6` — because `CodeItem([IntItem(6)])` *is* a
    /// quoted 6, the Lisp reading of a one-element list. This is how the code
    /// search/replace instructions let a program name a **leaf**, not only a
    /// subtree: `(5)` searches for the leaf 5, `((5))` for the subtree `(5)`, and
    /// `(1 2)` for the subtree `(1 2)`. See Design Principles.
    var denotedItem: any Item {
        value.count == 1 ? value[0] : self
    }

    /// Every pre-order point, the whole tree included, root first. The simple
    /// backbone the other point operations index into.
    var preorderPoints: [any Item] {
        var out: [any Item] = []
        func walk(_ node: any Item) {
            out.append(node)
            if let block = node.exactly(CodeItem.self) { for child in block.value { walk(child) } }
        }
        walk(self)
        return out
    }

    /// The total number of pre-order points, including the root. `( (1 2) 3 )` is
    /// 5. Recursive: a leaf is 1, a CodeItem is 1 + its children's counts.
    var pointCount: Int {
        1 + value.reduce(0) { $0 + (($1.exactly(CodeItem.self))?.pointCount ?? 1) }
    }

    /// The pre-order point at `index`, clamped (`Position.item`) so any int lands
    /// on a real point: 0 and below is the whole tree, past the end the last point.
    /// A tree always has at least one point, its root.
    func point(at index: Int) -> any Item {
        let points = preorderPoints
        return points[Position.item(index, count: points.count)]
    }

    /// The maximum nesting depth: root is 0, each nested block adds one.
    /// `(1 (2 3))` is 2, a flat block is 1, an empty block is 0.
    var depth: Int { blockDepth }

    /// Every leaf, left to right — the fully flattened contents. Empty blocks
    /// contribute nothing. `(1 (2 3) ())` → `[1, 2, 3]`.
    func flattenedLeaves() -> [any Item] {
        value.flatMap { ($0.exactly(CodeItem.self))?.flattenedLeaves() ?? [$0] }
    }

    /// One level of flattening: each root element that is a CodeItem is replaced
    /// by *its* elements, no deeper. `(1 (2 (3 4)) 5)` → `(1 2 (3 4) 5)`.
    func flattenedOnce() -> [any Item] {
        value.flatMap { ($0.exactly(CodeItem.self))?.value ?? [$0] }
    }

    /// The first pre-order index whose point equals `target` (by value), or nil.
    /// The root is index 0 and is checked first, so a tree contains itself.
    func firstPointIndex(of target: any Item) -> Int? {
        preorderPoints.firstIndex { $0.isEqual(to: target) }
    }

    /// The CodeItem that directly contains the first point equal to `target`, or
    /// nil (target absent, or target is the whole tree so has no parent here).
    func parentContaining(_ target: any Item) -> CodeItem? {
        func search(_ block: CodeItem) -> CodeItem? {
            for child in block.value {
                if child.isEqual(to: target) { return block }
                if let cb = child.exactly(CodeItem.self), let hit = search(cb) { return hit }
            }
            return nil
        }
        return search(self)
    }

    /// A new tree with the pre-order point at `index` replaced by `replacement`.
    /// Index 0 (the root) replaces the whole tree. One replacement; the counter
    /// threads pre-order left to right.
    func replacingPoint(at index: Int, with replacement: any Item) -> any Item {
        let target = Position.item(index, count: pointCount)
        var counter = 0
        func rebuild(_ node: any Item) -> any Item {
            let here = counter
            counter += 1
            if here == target { return replacement }   // subtree discarded
            guard let block = node.exactly(CodeItem.self) else { return node }
            return CodeItem(block.value.map { rebuild($0) })
        }
        return rebuild(self)
    }

    /// A new tree with the point at `index` (and its subtree) removed. Removing
    /// the root gives an empty block; a removed element vanishes from its parent.
    func removingPoint(at index: Int) -> CodeItem {
        let target = Position.item(index, count: pointCount)
        if target == 0 { return CodeItem([]) }
        var counter = 1   // root (index 0) already accounted for
        func rebuild(_ block: CodeItem) -> CodeItem {
            var kept: [any Item] = []
            for child in block.value {
                let here = counter
                counter += 1
                if here == target {
                    // drop it; skip its subtree in the counter
                    if let cb = child.exactly(CodeItem.self) { counter += cb.pointCount - 1 }
                    continue
                }
                kept.append((child.exactly(CodeItem.self)).map { rebuild($0) } ?? child)
            }
            return CodeItem(kept)
        }
        return rebuild(self)
    }

    /// A new tree in which every point equal to `needle` is replaced by `repl`
    /// (whole subtree), single pass — the replacement is not re-scanned. If
    /// `firstOnly`, stops after the first match in pre-order.
    func replacingPoints(equalTo needle: any Item, with repl: any Item, firstOnly: Bool) -> any Item {
        var done = false
        func rebuild(_ node: any Item) -> any Item {
            if done && firstOnly { return node }
            if node.isEqual(to: needle) {
                done = true
                return repl
            }
            guard let block = node.exactly(CodeItem.self) else { return node }
            return CodeItem(block.value.map { rebuild($0) })
        }
        return rebuild(self)
    }
}


public nonisolated struct DoubleItem: Item, Equatable, Comparable, Pretty {
    public var value: Double
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    
    public init(_ value: Double, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }
    
    public static func == (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public static func < (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}


public nonisolated struct InstructionItem: Item, Equatable, Comparable, Pretty {
    public var value: PushInstruction
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    
    public init(_ value: PushInstruction, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }
    
    public static func == (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public static func < (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        lhs.value.rawValue < rhs.value.rawValue
    }
    
    public func pretty() -> String {
        ".\(value)"
    }

}



public nonisolated struct IntItem: Item, Equatable, Comparable, Pretty {
    public var value: Int
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    
    public init(_ value: Int, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }
    
    public static func == (lhs: IntItem, rhs: IntItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public static func < (lhs: IntItem, rhs: IntItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct StringItem: Item, Equatable, Comparable, Pretty {
    public var value: String
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    /// The string's UTF-8 length, which a native `String` stores, so this is O(1).
    /// Not cached: a stored copy would put a `StringItem` over the three words an
    /// `any Item` holds inline (see `CallStorage`).
    public var weight: Int { value.utf8.count }

    /// Where each character came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    /// `members`, if given, must line up with the characters. Character boundaries
    /// can move when strings are joined (a combining mark after a letter), so a
    /// list that does not line up exactly is dropped, and the characters are
    /// addressed from the string instead.
    public init(_ value: String, call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: String, call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { Containment.aligned($0, with: Array(value)) })
    }
    
    public static func == (lhs: StringItem, rhs: StringItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public static func < (lhs: StringItem, rhs: StringItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "\"\(value)\""
    }
}


public nonisolated struct VecBoolItem: Item, Equatable, Pretty {
    public var value: [Bool]
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    public init(_ value: [Bool], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [Bool], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.count
    }
    
    public static func == (lhs: VecBoolItem, rhs: VecBoolItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct VecDoubleItem: Item, Equatable, Pretty {
    public var value: [Double]
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    public init(_ value: [Double], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [Double], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.count
    }
    
    /// Equal as vector operations compare doubles: every NaN is the same NaN
    /// (`DoubleKey`), so a vector holding one still equals itself.
    public static func == (lhs: VecDoubleItem, rhs: VecDoubleItem) -> Bool {
        lhs.value.elementsEqual(rhs.value) { DoubleKey(value: $0) == DoubleKey(value: $1) }
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}


public nonisolated struct VecIntItem: Item, Equatable, Pretty {
    public var value: [Int]
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    public init(_ value: [Int], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [Int], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.count
    }
    
    public static func == (lhs: VecIntItem, rhs: VecIntItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct VecStringItem: Item, Equatable, Pretty {
    public var value: [String]
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// Total characters across all contained strings — the "total characters"
    /// measure that a plain element count would miss. O(element count) once.
    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    public init(_ value: [String], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [String], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.reduce(0) { $0 + $1.utf8.count }
    }
    
    public static func == (lhs: VecStringItem, rhs: VecStringItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



/// Why an error was raised, as a value rather than as prose.
///
/// The message already says this in English, and for a long time that was the only
/// record. Counting them needed better: `.errorMissingArgCount` and its siblings
/// have to partition the `.error` stack exactly, and a filter on
/// `value.contains("missing args")` would silently under-report the first time
/// anybody reworded a message. A count that quietly drifts is worse than no count.
///
/// The cases split by **who noticed**, which is also what a program can act on:
/// starvation it could fix by supplying arguments, an unbound name it could fix by
/// binding one, and the interpreter's own refusals, which it cannot fix at all.
public nonisolated enum ErrorKind: String, Sendable, Codable, CaseIterable {
    /// A Behavior refused because a stack came up short (`Behavior.act`).
    case missingArgument
    /// An `.inputN` with no binding.
    case missingInput
    /// A typed constant (`.int3`, `.vecDouble8`) with no binding.
    case missingConstant
    /// A push the interpreter would not accept: over a size cap, or a stack at
    /// `maxStackDepth`.
    case sizeRefusal
    /// The `INVARIANT:` marker — a mis-tagged `Router`, which is a programming bug
    /// in the interpreter rather than a program bug.
    case invariant
    /// The `RUNAWAY:` and `MEMORY:` markers: a run stopped early by a guard.
    case guardStop
    /// A read of an element from a collection that has none: `.vecIntFirst` or
    /// `.stringNth` of an empty one, `.codeNthRoot` of `( )`, `.stringNthWord` of
    /// a string with no words. An index into a non-empty collection clamps and
    /// never errs; this is the one case where no position exists.
    case emptyCollection
    /// A search that found nothing: `.vecIntIndexOf`, `.stringIndexOfChar`,
    /// `.codeIndexOfPoint`, `.codeContainer`. These used to answer `-1` (which
    /// every index-taking instruction would then quietly accept) or nothing at all.
    case notFound
    /// A value with no counterpart in the target type: a string that is not a
    /// number, an int that is not a Unicode scalar, a character made of several.
    case conversion
    /// A Behavior's own complaint about its arguments — a negative count, a type
    /// this kind of loop does not have — and anything not otherwise classified.
    case other
}


public nonisolated struct ErrorItem: Item, Equatable {
    /// The message. Read as text everywhere, but stored as data for the one error
    /// that is raised constantly — an instruction starved of arguments, the most
    /// common event in a random program — whose text is only built when someone
    /// reads it. Profiling found that formatting it eagerly cost ~4% of all
    /// interpreter time, nearly always for a message nobody reads.
    public var value: String {
        get {
            switch message {
            case .text(let text): text.text
            case .missingArguments(let instruction, let stack): "\(instruction) missing args: .\(stack)"
            }
        }
        set { message = .text(Text(text: newValue, kind: kind)) }
    }

    /// The message, and with it the kind, in one word plus a tag. A free-text
    /// message and its kind sit behind a reference (`Text`) so that an `ErrorItem`
    /// fits the three words an `any Item` holds inline (see `CallStorage`): the
    /// common error, a starved instruction's, then costs no allocation at all. A
    /// free-text one costs one, as its `String` usually did anyway.
    enum Message: Sendable {
        case text(Text)
        case missingArguments(PushInstruction, PushStack)
    }

    final class Text: Sendable {
        let text: String
        let kind: ErrorKind
        init(text: String, kind: ErrorKind) { self.text = text; self.kind = kind }
    }
    private var message: Message

    /// Why this error was raised. See `ErrorKind`.
    ///
    /// Deliberately **not** part of `==`, which compares `value` alone like every
    /// other Item: two errors with the same message are the same error, and the
    /// kind is a classification of it rather than part of its identity.
    public var kind: ErrorKind {
        get {
            switch message {
            case .text(let text): text.kind
            case .missingArguments: .missingArgument
            }
        }
        set { message = .text(Text(text: value, kind: newValue)) }
    }

    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    public init(_ value: String, kind: ErrorKind = .other, call: [any Item] = []) {
        self.message = .text(Text(text: value, kind: kind))
        self.callStorage = CallStorage(call)
    }

    /// A starved instruction's refusal: `intAdd missing args: .int`, built on read.
    init(missingArgumentsFor instruction: PushInstruction, on stack: PushStack) {
        self.message = .missingArguments(instruction, stack)
        self.callStorage = .literal
    }

    public static func == (lhs: ErrorItem, rhs: ErrorItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "« ‼️ \(value) »"
    }
}
