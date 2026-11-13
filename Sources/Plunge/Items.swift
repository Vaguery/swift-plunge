//
//  Items.swift
//  Plunge
//
//  Created by Bill Tozier on 5/30/26.
//

import Foundation


// building up the protocol infrastructure

/// Something that can print itself in the notation this documentation uses for programs.
public nonisolated protocol Pretty {
    /// This item as text, in the form the documentation writes programs: `3`,
    /// `"hello"`, `[1, 2, 3]`, `( 1 .intAdd )`. See <doc:ThePushLanguage>.
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

/// Anything that can sit on a stack: a value, with a record of how it was made.
///
/// Every item has a ``value``, which is what the language computes with, and a
/// history (``call``), which is kept only while provenance recording is on and
/// never affects a result. Two items are equal when their values are equal.
///
/// At present every item type is defined by the library. To make items, use the
/// concrete types (``IntItem``, ``StringItem``, ``CodeItem`` and the rest),
/// ``pushItem(_:)``, or the `program { … }` builder. See <doc:WritingPrograms>.
public nonisolated protocol Item: Pretty, Sendable {
    associatedtype Value
    /// How this item was made: the arguments and the instruction that produced it.
    /// Empty for a literal, and always empty when provenance recording is off. The
    /// interpreter maintains it; read it through ``crux()``.
    var call: [any Item] {get set}
    /// What the item holds.
    var value: Value {get set}

    // Declared here (not only in an extension) so it dispatches dynamically
    // through `any Item` — same reason as `weight` below. A
    // protocol-extension-only method would dispatch *statically* through the
    // existential and silently ignore any override.
    //
    // **Nothing overrides it today.** `IteratorItem` did, back when it was a
    // provenance-only node whose crux was `base.crux() + [offset, .intAdd]`;
    // making the iterator first-class removed the need (see IteratorItem.swift),
    // and every type now walks `call` the same way. The requirement stays because
    // the failure it prevents is silent: a future override written against an
    // extension-only method would compile, look right, and never run.
    //
    /// A program that reproduces this item. Run on a new interpreter with the same
    /// inputs and constants, it leaves this item's value on this item's stack and
    /// nothing else. For a literal, or any item made without provenance recording,
    /// the crux is the item itself. See <doc:Provenance>.
    func crux() -> [any Item]

    // A recursive memory-proxy: the total primitive content this item holds,
    // summed through nesting (a vector's elements, a string's characters, a
    // code block's leaves). Scalars weigh 1. Container types store it, computed
    // once at construction. Declared here (not only in an extension) so it
    // dispatches correctly through `any Item`.
    //
    /// The size of this item's content, summed through any nesting: 1 for a bool, a
    /// number or a char, and the total of its elements for a collection. The size
    /// limits are stated in weight. See <doc:LimitsAndGuards>.
    var weight: Int {get}

    // The provenance counterpart of `weight`: roughly the number of items
    // `crux()` would emit for this item, and so a proxy for both the memory the
    // history occupies and the size of the reconstruction. Bounded by
    // `maxCallWeight` at the push boundary (`Interpreter.push`).
    //
    // Unlike `weight` this cannot be a construction-time `let`: `value` is never
    // mutated after construction, but `call` *is* reassigned during execution.
    // So each struct stores it and refreshes it from `call`'s `didSet`. It is
    // maintained rather than computed on demand because the case that matters —
    // a long accumulation chain — would otherwise cost a full walk per push, and
    // re-walking a chain that grows by one each step is the quadratic behavior
    // this whole exercise exists to remove.
    //
    /// The size of this item's history: roughly the number of items its crux
    /// holds. Limited by ``InterpreterSettings/maxCallWeight``.
    var callWeight: Int {get}

    // How deeply `call` nests: 0 for a literal, one more than the deepest child
    // otherwise. Maintained alongside `callWeight` (packed with it in a
    // `CallMeasure`) for the same reason: a long chain must not cost a walk per
    // push. `Interpreter.push` elides provenance deeper than `maxCallDepth`,
    // because releasing or walking a tree costs a stack frame per level, and a
    // concurrency worker thread's stack is small (see `maxCallDepth`).
    //
    /// How deeply this item's history nests: 0 for a literal. Limited by
    /// ``InterpreterSettings/maxCallDepth``.
    var callDepth: Int {get}

    // How deeply other items nest inside this one's *value*, counting every
    // container: blocks inside blocks, and blocks and iterators inside each other
    // (an iterator's origin, destination and body; an iterator quoted into a
    // block). 0 for a scalar. Cached by the containers at construction, so
    // `maxCodeDepth` can be enforced at every push without a walk, and so no walk
    // or release can recurse deeper than it on a small worker-thread stack.
    //
    /// How deeply other items nest inside this one's value, counting code blocks and
    /// iterators: 0 for an item that holds none. Limited by
    /// ``InterpreterSettings/maxCodeDepth``.
    var nestingDepth: Int {get}

    /// Whether another item has the same type and an equal value. Histories are
    /// not compared.
    func isEqual(to other: any Item) -> Bool

    /// Moves into `work` whatever this item alone holds that would otherwise be
    /// freed recursively with it: its history, and a code block's contents. Called
    /// only while a deep history is being freed, so that freeing it needs no
    /// recursion; an item type with no history of its own need do nothing.
    @_documentation(visibility: internal)
    mutating func detachForRelease(into work: inout [any Item])
}

nonisolated public extension Item {
    /// Nothing to hand over.
    @_documentation(visibility: internal)
    mutating func detachForRelease(into work: inout [any Item]) {}
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
//  - `.xEq` (Stack Family Behaviors) compares with `isEqual(to:)`, so the language's
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
    /// Whether another item has the same type and an equal value. This is the
    /// language's equality, the one the `Eq` instructions use, and it ignores
    /// histories.
    public func isEqual(to other: any Item) -> Bool {
        guard let otherWithSameType = other as? Self else { return false }
        return self == otherWithSameType
    }
}

nonisolated extension Item {
    /// A program that reproduces this item's value on this item's stack. See
    /// <doc:Provenance>.
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
/// Whether two lists of items hold equal values in the same order. Items of
/// different types are never equal.
public nonisolated func == (lhs: [any Item], rhs: [any Item]) -> Bool {
    // Arrays must have the same count to be equal
    guard lhs.count == rhs.count else { return false }

    // Compare elements line-by-line using zip
    return zip(lhs, rhs).allSatisfy { leftElement, rightElement in
        leftElement.isEqual(to: rightElement)
    }
}
