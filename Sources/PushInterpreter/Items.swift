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
//     `.execEq 3 3`, not `3 3 .execEq`. Reconstructed source is executed from
//     `.exec` like any other program, so it has to be written the way `.exec`
//     reads it. `execQuote` and `execEq` are the two that record this way.
//
//  4. A freshly minted instruction token records nothing. Its crux is itself.
//
//  4b. A result read from transient EXECUTION state rather than from arguments
//     records nothing either — its crux is the literal value it observed.
//     `.boolStackDepth` reported 4 because `.bool` happened to be 4 deep;
//     re-running `.boolStackDepth` says nothing about that, but the literal `4`
//     reproduces it exactly. (Contrast `.input3` and `.int7`, which read the
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
    var isContingent: Bool {get set}
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

    func isEqual(to other: any Item) -> Bool
}

nonisolated extension Item {
    // Default for scalar items (Bool, Int, Double, Char, Instruction, Error):
    // one unit each. Container types override with a stored, memoized weight.
    public var weight: Int { 1 }


    /// The `callWeight` for a freshly assigned `call`. Each child already stores
    /// its own, so this is O(call.count) — not O(chain) — which is what keeps
    /// maintaining it cheap.
    ///
    /// Saturating rather than trapping: provenance is a DAG, so a shared node
    /// counted once per path can in principle exceed `Int.max` even though the
    /// stored graph is small. Saturating keeps the over-budget check firing;
    /// wrapping would make it silently pass.
    static func weighCall(_ call: [any Item]) -> Int {
        var total = 1
        for child in call {
            let (sum, overflowed) = total.addingReportingOverflow(child.callWeight)
            total = overflowed ? Int.max : sum
        }
        return total
    }
}

// MARK: - Equality is about values
//
// An Item's `==` compares its `value` and nothing else. Not `call`, not
// `isContingent`: those describe how the item came to be and where it sits, not
// what it is. `5` computed as `2 3 .intAdd` equals `5` computed as `1 4 .intAdd`,
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
    /// provenance and contingency. See the note above.
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
        // runnable program producing itself. This is also why eliding an
        // over-budget `call` (Interpreter.push) is always safe: it costs the
        // explanation, never the correctness of the reconstruction.
        if self.call.isEmpty { return [self] }
        return self.call.flatMap { $0.crux() }
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Bool, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Character, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool

    /// The number of items in this code's fully flattened `.value`: every
    /// non-code item counts as one, and a nested `CodeItem` contributes its own
    /// `flatSize` (its contents), recursively — so `[1, [2, 3]]` is 3 and an
    /// empty or empty-nested block contributes nothing. Computed once here
    /// because `value` is never mutated after construction.
    public let flatSize: Int

    /// Recursive content weight: the sum of the weights of everything this block
    /// holds, at every level. Reuses each child's already-stored weight.
    public let weight: Int

    public init(_ value: [any Item], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.flatSize = value.reduce(0) { $0 + (($1 as? CodeItem)?.flatSize ?? 1) }
        self.weight = value.reduce(0) { $0 + $1.weight }
    }

    public static func == (lhs: CodeItem, rhs: CodeItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        var result = "( "
        for i in value {
            result += "\(i.pretty()) "
        }
        result += ")"
        return result
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

    /// Every pre-order point, the whole tree included, root first. The simple
    /// backbone the other point operations index into.
    var preorderPoints: [any Item] {
        var out: [any Item] = []
        func walk(_ node: any Item) {
            out.append(node)
            if let block = node as? CodeItem { for child in block.value { walk(child) } }
        }
        walk(self)
        return out
    }

    /// The total number of pre-order points, including the root. `( (1 2) 3 )` is
    /// 5. Recursive: a leaf is 1, a CodeItem is 1 + its children's counts.
    var pointCount: Int {
        1 + value.reduce(0) { $0 + (($1 as? CodeItem)?.pointCount ?? 1) }
    }

    /// The pre-order point at `index`, taken `magnitude % pointCount` so any int
    /// lands on a real point (0 is the whole tree).
    func point(at index: Int) -> any Item {
        let points = preorderPoints
        return points[Int(index.magnitude % UInt(points.count))]
    }

    /// The maximum nesting depth: root is 0, each nested block adds one.
    /// `(1 (2 3))` is 2, a flat block is 1, an empty block is 0.
    var depth: Int {
        1 + (value.map { ($0 as? CodeItem)?.depth ?? 0 }.max() ?? -1)
    }

    /// Every leaf, left to right — the fully flattened contents. Empty blocks
    /// contribute nothing. `(1 (2 3) ())` → `[1, 2, 3]`.
    func flattenedLeaves() -> [any Item] {
        value.flatMap { ($0 as? CodeItem)?.flattenedLeaves() ?? [$0] }
    }

    /// One level of flattening: each root element that is a CodeItem is replaced
    /// by *its* elements, no deeper. `(1 (2 (3 4)) 5)` → `(1 2 (3 4) 5)`.
    func flattenedOnce() -> [any Item] {
        value.flatMap { ($0 as? CodeItem)?.value ?? [$0] }
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
                if let cb = child as? CodeItem, let hit = search(cb) { return hit }
            }
            return nil
        }
        return search(self)
    }

    /// A new tree with the pre-order point at `index` replaced by `replacement`.
    /// Index 0 (the root) replaces the whole tree. One replacement; the counter
    /// threads pre-order left to right.
    func replacingPoint(at index: Int, with replacement: any Item) -> any Item {
        let target = Int(index.magnitude % UInt(pointCount))
        var counter = 0
        func rebuild(_ node: any Item) -> any Item {
            let here = counter
            counter += 1
            if here == target { return replacement }   // subtree discarded
            guard let block = node as? CodeItem else { return node }
            return CodeItem(block.value.map { rebuild($0) })
        }
        return rebuild(self)
    }

    /// A new tree with the point at `index` (and its subtree) removed. Removing
    /// the root gives an empty block; a removed element vanishes from its parent.
    func removingPoint(at index: Int) -> CodeItem {
        let target = Int(index.magnitude % UInt(pointCount))
        if target == 0 { return CodeItem([]) }
        var counter = 1   // root (index 0) already accounted for
        func rebuild(_ block: CodeItem) -> CodeItem {
            var kept: [any Item] = []
            for child in block.value {
                let here = counter
                counter += 1
                if here == target {
                    // drop it; skip its subtree in the counter
                    if let cb = child as? CodeItem { counter += cb.pointCount - 1 }
                    continue
                }
                kept.append((child as? CodeItem).map { rebuild($0) } ?? child)
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
            guard let block = node as? CodeItem else { return node }
            return CodeItem(block.value.map { rebuild($0) })
        }
        return rebuild(self)
    }
}


public nonisolated struct DoubleItem: Item, Equatable, Comparable, Pretty {
    public var value: Double
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Double, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: PushInstruction, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Int, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: String, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.utf8.count
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: [Bool], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: [Double], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.count
    }
    
    public static func == (lhs: VecDoubleItem, rhs: VecDoubleItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}


public nonisolated struct VecIntItem: Item, Equatable, Pretty {
    public var value: [Int]
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: [Int], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool

    /// Total characters across all contained strings — the "total characters"
    /// measure that a plain element count would miss. O(element count) once.
    public let weight: Int

    public init(_ value: [String], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.reduce(0) { $0 + $1.utf8.count }
    }
    
    public static func == (lhs: VecStringItem, rhs: VecStringItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct ErrorItem: Item, Equatable {
    public var value: String
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: String, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
    }
    
    public static func == (lhs: ErrorItem, rhs: ErrorItem) -> Bool {
        lhs.value == rhs.value
    }
    
    public func pretty() -> String {
        "« ‼️ \(value) »"
    }
}
