//
//  CodeItem.swift
//  Plunge
//
//  The code block: the language's one container for items of mixed types.
//  Split out of Items.swift, which keeps the `Item` protocol and the provenance law.
//

import Foundation


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
//  - **Boxing costs nothing** (law 1b): an item put in and taken
//    back out is the item that went in, keeping its own `call`. The box is
//    transparent to provenance, which is precisely what makes it usable as a
//    universal channel rather than a lossy one.
//  - **It is the scarcest thing in the language.** Structurally, `.code` has ~0.29
//    producers per consumer — the five quotes, and now the collector. Everything
//    else reshapes code it was already given. See "Stack economics".
//
// The cost of that generality is that `.code` is the one stack where two items of
// the same type are not interchangeable as arguments, which `.exec` shares and
// `.iterator` now joins.
/// A code block: a list of any items, nested to any depth.
///
/// Code blocks are the items of the `.code` stack, and the language's one container
/// for items of mixed types. A code block in a program doesn't run when the
/// interpreter reaches it; it rests on `.code` until an instruction runs it.
/// See <doc:CodeAndControl>.
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
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// The number of items in this code's fully flattened `.value`: every
    /// non-code item counts as one, and a nested `CodeItem` contributes its own
    /// `flatSize` (its contents), recursively — so `[1, [2, 3]]` is 3 and an
    /// empty or empty-nested code block contributes nothing. Computed once here
    /// because `value` is never mutated after construction.
    public let flatSize: Int

    /// Recursive content weight: the sum of the weights of everything this code block
    /// holds, at every level. Reuses each child's already-stored weight.
    public let weight: Int

    /// How deeply code blocks nest inside this one, counting code blocks only: 0 for an
    /// empty code block, 1 for a flat one, one more per level — `(1 (2 3))` is 2. This
    /// is what `.codeDepth` reports. Computed once from the children, like
    /// `flatSize`.
    public let blockDepth: Int

    /// `Item.nestingDepth`: like `blockDepth`, but counting iterators too (a code block
    /// holding a quoted iterator whose body is a code block…). The one `maxCodeDepth`
    /// enforces. Weight cannot stand in for it: wrapping adds a level and no weight.
    public let nestingDepth: Int

    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
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

    /// `( a b c )`. Rendered by `NestedRendering`, which walks nested code blocks and
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

    /// The item this code block **denotes** under the singleton-unwrap convention: a
    /// one-element code block denotes its sole element, any other code block denotes itself.
    ///
    /// `(6)` denotes the leaf `6` — because `CodeItem([IntItem(6)])` *is* a
    /// quoted 6, the Lisp reading of a one-element list. This is how the code
    /// search/replace instructions let a program name a **leaf**, not only a
    /// subtree: `(5)` searches for the leaf 5, `((5))` for the subtree `(5)`, and
    /// `(1 2)` for the subtree `(1 2)`.
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

    /// The maximum nesting depth: root is 0, each nested code block adds one.
    /// `(1 (2 3))` is 2, a flat code block is 1, an empty code block is 0.
    var depth: Int { blockDepth }

    /// Every leaf, left to right — the fully flattened contents. Empty code blocks
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
    /// the root gives an empty code block; a removed element vanishes from its parent.
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
