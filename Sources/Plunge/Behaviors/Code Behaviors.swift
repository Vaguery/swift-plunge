//
//  Code Behaviors.swift
//  Plunge
//
//  Created by Bill Tozier on 6/17/26.
//

import DequeModule

// The `.code` instruction set is complete. The four gap-based ops that stood
// unimplemented longest — codeCutAtGap, codeInsertAtGap, codeWrapRange,
// codeFlattenRange — are under "Tree-wide gap surgery" below, on the model in
// `CodeGaps.swift`.

nonisolated extension Interpreter {

    static let codeConcat_Behavior =
        Behavior.operation(.codeConcat, takes: CodeItem.self, CodeItem.self, gives: CodeItem.self) { y, x in
            y + x
        }
        .described("Concatenates two code blocks' root items: `( a ) ( b c ) .codeConcat` gives `( a b c )`.")

    /// Pair **two** items into one new code block `( y x )` — the arity-2 sibling of
    /// `.codeWrap`, and Clojure's `list` with two arguments. Each argument is
    /// **denoted** (singleton-unwrap): a one-element code block contributes its bare
    /// element, so `( 1 ) ( 2 3 ) .codePair` → `( 1 ( 2 3 ) )`, not
    /// `( ( 1 ) ( 2 3 ) )`. Distinct from `.codeConcat`, which concatenates
    /// contents flat.
    static let codePair_Behavior =
        Behavior.composing(.codePair, takes: CodeItem.self, CodeItem.self, gives: CodeItem.self) { y, x in
            [y.denotedItem, x.denotedItem]
        }
        .described("Pairs two code blocks into one: `( a ) ( b c ) .codePair` gives `( a ( b c ) )`, a one-item code " +
            "block contributing its sole item.")

    /// **One code block and a bool**: run the code block if the bool is true; otherwise
    /// hand it back to `.code` untouched. Built from the pieces already here:
    /// `.codeDo` when true, the code block replaced when false. It differs from
    /// `.execWhen`, which discards the code block on false: here a refused code block is
    /// still data the program owns, as every other ending returns its body.
    static let codeDoIf_Behavior =
        Behavior.control(
            .codeDoIf,
            takes: [.bool, .code],
            fxn: { a, _ in
                let (cond, block) = (a[0] as! BoolItem, a[1])
                guard cond.value else { return [Router(.code, block)] }
                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, block)
                ]
            }
        )
        .described("Runs the code block as `.codeDo` would if the bool is true; otherwise does nothing, leaving the " +
            "code block on `.code`. `.execWhen` discards it instead.")

    static let codeItemIsEmpty_Behavior =
        Behavior.operation(.codeItemIsEmpty, reads: CodeItem.self, gives: BoolItem.self) { x in x.isEmpty }
        .described("Tests whether the code block has no items, leaving the code block.")

    static let codeLengthRoot_Behavior =
        Behavior.operation(.codeLengthRoot, reads: CodeItem.self, gives: IntItem.self) { x in x.count }
        .described("Counts the code block's root items, leaving the code block.")

    // MARK: - Whole-tree queries (non-destructive)
    //
    // All read their code argument(s) and leave them; the crux pops what it read
    // (`Behavior.reading`), like the vector queries. They use the pre-order point
    // walker on `CodeItem` (CodeItem.swift), on a block rebuilt from the argument's
    // value: every walk here counts and compares by value, never by `call`.

    /// The number of pre-order points in the whole tree, root included.
    /// `( (1 2) 3 )` → 5. (Contrast `.codeLengthRoot`, the root `.value` count.)
    static let codeLength_Behavior =
        Behavior.operation(.codeLength, reads: CodeItem.self, gives: IntItem.self) { x in
            CodeItem(x).pointCount
        }
        .described("Counts the code block's points, the code block itself included, leaving the code block: `( ( 1 2 " +
            ") 3 )` has 5.")

    /// The number of leaves in the tree — everything that is not a nested code block, so
    /// scalars, instructions and whole vectors each count one. Equals `flatSize`.
    static let codeWidth_Behavior =
        Behavior.operation(.codeWidth, reads: CodeItem.self, gives: IntItem.self) { x in
            CodeItem(x).flatSize
        }
        .described("Counts the code block's leaves (items that are not code blocks) at every depth, leaving the code " +
            "block.")

    /// The maximum nesting depth: root 0, each nested code block one deeper.
    static let codeDepth_Behavior =
        Behavior.operation(.codeDepth, reads: CodeItem.self, gives: IntItem.self) { x in
            CodeItem(x).depth
        }
        .described("Measures how deeply code blocks nest, leaving the code block: `( )` is 0, a flat code block 1, " +
            "each nested level one more.")

    /// Whether a target code block occurs as a point anywhere in another's tree. Since
    /// the root is a point, a tree contains itself. Reads both, leaves both.
    ///
    /// Written `needle hay .codeContains`: the haystack is on top. The needle is
    /// *denoted* for the search (singleton-unwrap), but the crux re-pushes the
    /// original code block, so re-running denotes it again.
    static let codeContains_Behavior =
        Behavior.operation(.codeContains, reads: CodeItem.self, CodeItem.self, gives: BoolItem.self) { hay, needle in
            CodeItem(hay).firstPointIndex(of: CodeItem(needle).denotedItem) != nil
        }
        .described("Tests whether code block n occurs as a point of code block h, leaving both: `h n .codeContains`; " +
            "a one-item n stands for its sole item.")

    /// The pre-order index of the first point equal to the target; an error if
    /// there is none (it used to answer −1).
    static let codeIndexOf_Behavior =
        Behavior.operation(.codeIndexOf, reads: CodeItem.self, CodeItem.self, gives: IntItem.self) { hay, needle throws(Refusal) in
            guard let found = CodeItem(hay).firstPointIndex(of: CodeItem(needle).denotedItem) else {
                throw Refusal("Not found in .codeIndexOf", kind: .notFound)
            }
            return found
        }
        .described("Finds the first point of h equal to n, leaving both: `h n .codeIndexOf`; a one-item n " +
                   "stands for its sole item; refuses when absent.")

    /// How many points equal the target. Equal subtrees cannot nest inside one
    /// another, so there is no question of overlap.
    static let codeOccurrencesOf_Behavior =
        Behavior.operation(.codeOccurrencesOf, reads: CodeItem.self, CodeItem.self,
                           gives: IntItem.self) { hay, needle in
            let target = CodeItem(needle).denotedItem
            return CodeItem(hay).preorderPoints.count { $0.isEqual(to: target) }
        }
        .described("Counts the points of h equal to n, leaving both: `h n .codeOccurrencesOf`; a one-item n stands "
                   + "for its sole item.")

    /// The code block that directly contains the first point equal to the target —
    /// its parent. An error if the target is absent, or if it is the whole tree
    /// (which has no parent here). Reads both, leaves both.
    static let codeContainer_Behavior =
        Behavior.operation(.codeContainer, reads: CodeItem.self, CodeItem.self, gives: CodeItem.self) { hay, needle throws(Refusal) in
            guard let parent = CodeItem(hay).parentContaining(CodeItem(needle).denotedItem) else {
                throw Refusal("No container found in .codeContainer", kind: .notFound)
            }
            return parent.value
        }
        .described("Copies the code block directly holding n's first occurrence in h, leaving both: `h n " +
            ".codeContainer`; refuses if n is absent or is h itself.")

    // MARK: - Point access (non-destructive)
    //
    // Both **always yield `.code`**: a point that is a sub-block pushes as itself;
    // a leaf (scalar, instruction, whole vector) is wrapped `( x )` so the result
    // is uniform and inert. The extracted point is treated as a derived value —
    // "the code at point i of x" — recording the reading crux rather than the
    // point's own history, so the crux is uniform whatever the point's type and
    // cleans up both arguments. The index is clamped (`Position.item`).

    /// Box a point as a `.code` result: a nested code block as-is, a leaf wrapped once.
    static func boxedPointContents(_ point: any Item) -> [any Item] {
        (point.exactly(CodeItem.self))?.value ?? [point]
    }

    /// The pre-order point at the `.int` index (root at 0), yielded as `.code`,
    /// consuming the code block and the index.
    static let codeNth_Behavior =
        Behavior.operation(.codeNth, takes: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, i in
            boxedPointContents(CodeItem(x).point(at: i))
        }
        .described("Takes point i (clamped) as a code block; a leaf comes boxed as `( x )`.")

    /// The root item at the `.int` index (clamped), yielded as `.code`, consuming
    /// the code block and the index. An empty code block has no root items, so it refuses.
    static let codeNthRoot_Behavior =
        Behavior.operation(.codeNthRoot, takes: CodeItem.self, IntItem.self,
                           gives: CodeItem.self) { x, i throws(Refusal) in
            guard let element = rootPicker(CodeItem(x), i) else {
                throw Refusal("Empty block in .\(PushInstruction.codeNthRoot)", kind: .emptyCollection)
            }
            return boxedPointContents(element)
        }
        .described("Takes root item i (clamped) as a code block; a leaf comes boxed as `( x )`; refuses an empty " +
            "code block.")

    /// `.codeNth` without consuming: the code block and the index stay where they were.
    static let codePeekNth_Behavior =
        Behavior.operation(.codePeekNth, reads: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, i in
            boxedPointContents(CodeItem(x).point(at: i))
        }
        .described("Copies point i (clamped) as a code block, leaving the code block and index; a leaf comes boxed " +
            "as `( x )`.")

    /// The root `.value` element at the `.int` index (clamped), yielded as
    /// `.code`. An empty code block has no root elements, so it is an error.
    static let codePeekNthRoot_Behavior =
        Behavior.operation(.codePeekNthRoot, reads: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, i throws(Refusal) in
            guard let element = rootPicker(CodeItem(x), i) else {
                throw Refusal("Empty block in .\(PushInstruction.codePeekNthRoot)", kind: .emptyCollection)
            }
            return boxedPointContents(element)
        }
        .described("Copies root item i (clamped) as a code block, leaving the code block and index; a leaf comes " +
            "boxed as `( x )`; refuses an empty code block.")

    // MARK: - Point access that emits to `.exec` (Do / Emit)
    //
    // The `.exec` cousins of `codeNth*`. They read the tree and index
    // non-destructively, like `codeNth`, but instead of producing a boxed `.code`
    // result they route the point through `.exec`:
    //
    //   Emit — push the point **as it is**. A sub-block rests on `.code` whole; a
    //          leaf routes to its own stack; an instruction runs.
    //   Do   — push the point **unwrapped** (via `.codeDo`), so a sub-block's
    //          contents run. Identical to Emit for a leaf.
    //
    // They emit existing items (law 1b / combinatory), so they record no crux of
    // their own — the routed items carry their own provenance. An item with no
    // history of its own, out of a block that has one, records its address
    // instead: `x i .codeEmitNthRoot` and the clean-up (`Containment`). The index is
    // clamped (`Position.item`). A tree always has a point (its root), but an
    // empty block has no root elements, so the `Root` forms can refuse.

    /// The error for a root-indexed read of `( )`, which has no root elements.
    static func emptyBlockRefusal(
        _ instruction: PushInstruction, _ x: CodeItem, _ i: IntItem, _ recording: ProvenanceRecording
    ) -> Router {
        Behavior.refusal(
            "Empty block in .\(instruction)",
            kind: .emptyCollection,
            source: instruction,
            call: recording(Behavior.reading([.code: 1, .int: 1], producing: .error, from: [x, i, InstructionItem(instruction)])))
    }

    /// Emit a point to `.exec` as-is (whole).
    static func emitNthBehavior(
        _ instruction: PushInstruction,
        point pick: @escaping @Sendable (CodeItem, Int) -> (any Item)?,
        tags: Set<InstructionTag> = []
    ) -> Behavior {
        Behavior.control(
            instruction,
            reads: [.code, .int],
            tags: tags,
            fxn: { a, recording in
                let (x, i) = (a[0] as! CodeItem, a[1] as! IntItem)
                guard let point = pick(x, i.value) else {
                    return [emptyBlockRefusal(instruction, x, i, recording)]
                }
                return [Router(.exec, Containment.takenOut(point, of: x, at: i, by: instruction, recording))]
            }
        )
    }

    /// Emit a point to `.exec` unwrapped — box it and let `.codeDo` run it.
    ///
    /// The box is a **new** code block, and a code block met on `.exec` comes to rest on
    /// `.code` before `.codeDo` takes it, so it can be left there as a result (a
    /// run that stops between the two steps). It is exactly the code block `twin`
    /// (`.codePeekNth`/`.codePeekNthRoot`) produces, so it records that history.
    static func doNthBehavior(
        _ instruction: PushInstruction,
        point pick: @escaping @Sendable (CodeItem, Int) -> (any Item)?,
        twin: PushInstruction,
        tags: Set<InstructionTag> = []
    ) -> Behavior {
        Behavior.control(
            instruction,
            reads: [.code, .int],
            tags: tags,
            fxn: { a, recording in
                let (x, i) = (a[0] as! CodeItem, a[1] as! IntItem)
                guard let point = pick(x, i.value) else {
                    return [emptyBlockRefusal(instruction, x, i, recording)]
                }
                let boxed = CodeItem(
                    boxedPointContents(point),
                    call: recording(Behavior.reading([.code: 1, .int: 1], producing: .code,
                                                     from: [x, i, InstructionItem(twin)])))
                return [Router(.exec, InstructionItem(.codeDo)), Router(.exec, boxed)]
            }
        )
    }

    static let pointPicker: @Sendable (CodeItem, Int) -> (any Item)? = { x, i in x.point(at: i) }
    static let rootPicker: @Sendable (CodeItem, Int) -> (any Item)? = { x, i in
        x.value.isEmpty ? nil : x.value[Position.item(i, count: x.value.count)]
    }

    static let codeEmitNth_Behavior = emitNthBehavior(.codeEmitNth, point: pointPicker)
        .described("Sends point i (clamped) to `.exec` as it is, leaving the code block and index: a nested code " +
            "block lands on `.code`, an instruction runs.")
    static let codeDoNth_Behavior   = doNthBehavior(.codeDoNth, point: pointPicker, twin: .codePeekNth)
        .described("Runs point i (clamped), leaving the code block and index: a nested code block's contents " +
            "execute, a leaf goes to its stack.")
    static let codeEmitNthRoot_Behavior  = emitNthBehavior(.codeEmitNthRoot, point: rootPicker, tags: [.fallible])
        .described("Sends root item i (clamped) to `.exec` as it is, leaving the code block and index; refuses an " +
            "empty code block.")
    static let codeDoNthRoot_Behavior    = doNthBehavior(.codeDoNthRoot, point: rootPicker, twin: .codePeekNthRoot, tags: [.fallible])
        .described("Runs root item i (clamped), leaving the code block and index: a nested code block's contents " +
            "execute; refuses an empty code block.")

    // MARK: - Flatten and point mutation (transforms, consume)

    /// Flatten the whole tree to its leaves, left to right. `(1 (2 3) ())` →
    /// `(1 2 3)`. Empty code blocks vanish.
    static let codeFlatten_Behavior =
        Behavior.operation(.codeFlatten, takes: CodeItem.self, gives: CodeItem.self) { x in
            CodeItem(x).flattenedLeaves()
        }
        .described("Flattens a code block to its leaves, in order; nested empty code blocks vanish.")

    /// Flatten one level: each root element that is a code block is replaced by its
    /// contents, no deeper. `(1 (2 (3 4)) 5)` → `(1 2 (3 4) 5)`.
    static let codeFlattenOnce_Behavior =
        Behavior.operation(.codeFlattenOnce, takes: CodeItem.self, gives: CodeItem.self) { x in
            CodeItem(x).flattenedOnce()
        }
        .described("Flattens one level: each root item that is a code block is replaced by its items.")

    /// Flatten the subtree at the indexed point in place. A leaf point is
    /// unchanged; point 0 (the root) flattens the whole thing (= codeFlatten).
    static let codeFlattenNth_Behavior =
        Behavior.operation(.codeFlattenNth, takes: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, i in
            let tree = CodeItem(x)
            let point = tree.point(at: i)
            let flattened: any Item =
                (point.exactly(CodeItem.self)).map { CodeItem($0.flattenedLeaves()) } ?? point
            let rebuilt = tree.replacingPoint(at: i, with: flattened)
            return ((rebuilt.exactly(CodeItem.self)) ?? CodeItem([rebuilt])).value
        }
        .described("Flattens the subtree at point i (clamped) in place; a leaf point is unchanged, and point 0 " +
                   "flattens everything.")

    /// Remove the point at the indexed location, subtree and all. Removing the
    /// root gives an empty code block.
    static let codeRemoveNth_Behavior =
        Behavior.operation(.codeRemoveNth, takes: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, i in
            CodeItem(x).removingPoint(at: i).value
        }
        .described("Removes point i (clamped) with everything under it; removing point 0 gives `( )`.")

    /// Replace every point equal to `needle` with `replacement` (whole subtree),
    /// single pass. Consumes subject, needle, replacement (all `.code`).
    static let codeReplace_Behavior =
        replacePointsBehavior(.codeReplace, firstOnly: false)
        .described("Replaces matching points: `s n r .codeReplace` puts r for every point of s equal to n; " +
                   "a one-item n or r stands for its item.")

    /// As above, but only the first matching point in pre-order.
    static let codeReplaceFirst_Behavior =
        replacePointsBehavior(.codeReplaceFirst, firstOnly: true)
        .described("Replaces the first matching point: `s n r .codeReplaceFirst` puts r for s's first point " +
                   "equal to n; a one-item n or r stands for its item.")

    static func replacePointsBehavior(_ instruction: PushInstruction, firstOnly: Bool) -> Behavior {
        // Written `subject needle replacement`. A one-item needle or replacement
        // stands for its item (`denotedItem`), so `( 5 )` replaces with 5 itself.
        Behavior.composing(instruction, takes: CodeItem.self, CodeItem.self, CodeItem.self,
                           gives: CodeItem.self) { subject, needle, repl in
            let rebuilt = subject.replacingPoints(equalTo: needle.denotedItem, with: repl.denotedItem, firstOnly: firstOnly)
            return ((rebuilt.exactly(CodeItem.self)) ?? CodeItem([rebuilt])).value
        }
    }

    // MARK: - Root-level split and iterate

    /// Split the **root** `.value` array at the indexed gap into two code blocks — the
    /// `.code` analog of `.vecXCut`/`.stringCut`. Prefix deeper, suffix on top (so
    /// `cut` then `.codeConcat` rebuilds the original); law-5 multi-result crux.
    static let codeCutRoot_Behavior =
        Behavior.splitting(.codeCutRoot, takes: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, y in
            // Gaps, not elements: a root of N items has N+1 gaps, from 0 (before
            // everything → empty prefix) to N (after everything → empty suffix).
            // The index clamps over those gaps.
            let idx = Position.gap(y.value, count: x.value.count)
            return (Array(x.value[0..<idx]), Array(x.value[idx...]))
        }
        .described("Splits a code block's root items at gap i, clamped to 0 through their count: the front part " +
            "beneath, the back part on top.")

    // MARK: - Tree-wide gap surgery
    //
    // The four instructions that name a position *between* things rather than a
    // point. The model — what a gap is, why the root's own boundary is not one,
    // and why rebuilding repairs rather than refuses — is in `CodeGaps.swift`.
    // Read that first; these four are thin on top of it.

    /// Split the **whole tree** at the indexed gap — `.codeCutRoot`'s sibling,
    /// reaching inside nested code blocks rather than only between root elements.
    /// Prefix deeper, suffix on top; law-5 multi-result crux.
    ///
    /// **Leaves are preserved exactly**, in order, across the two pieces. Nesting
    /// on the cut path is not: a code block the cut passes through becomes one code block in
    /// each piece, so cut-then-`.codeConcat` is the identity only when the gap
    /// happens to fall between root elements. That is a property of cutting trees;
    /// see the note in `CodeGaps.swift`.
    static let codeCutAtGap_Behavior =
        Behavior.splitting(.codeCutAtGap, takes: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, y in
            let tokens = x.gapTokens
            let idx = x.gapIndex(y.value)
            return (CodeItem.rebuilt(from: Array(tokens[0..<idx])).value,
                    CodeItem.rebuilt(from: Array(tokens[idx...])).value)
        }
        .described("Splits the whole tree at gap i (clamped), front part beneath, back on top; leaves keep their " +
            "order, and code blocks the cut crosses split in two.")

    /// Splice one code block into another's tree at the indexed gap.
    ///
    /// Written `subject insert n .codeInsertAtGap`, so the subject is deeper — the
    /// argument order `.codeReplaceFirst` already uses. The insertion is
    /// **denoted** (`denotedItem`, singleton-unwrap), like every other code
    /// instruction that names a target: `( 5 )` inserts the bare leaf `5`,
    /// `( ( 5 ) )` inserts the code block `( 5 )`.
    static let codeInsertAtGap_Behavior =
        Behavior.operation(.codeInsertAtGap, takes: CodeItem.self, CodeItem.self, IntItem.self, gives: CodeItem.self) { subject, insert, n in
            let tree = CodeItem(subject)
            var tokens = tree.gapTokens
            let idx = tree.gapIndex(n)
            // A block the insertion denotes is spliced as tokens and rebuilt, so
            // its own `call` never reaches the result: rebuilding it from its value
            // here loses nothing.
            let denoted = CodeItem(insert).denotedItem
            let spliced: [CodeToken] = (denoted.exactly(CodeItem.self))
                .map { [.open] + $0.gapTokens + [.close] } ?? [.item(denoted)]
            tokens.insert(contentsOf: spliced, at: idx)
            return CodeItem.rebuilt(from: tokens).value
        }
        .described("Inserts: `s x i .codeInsertAtGap` splices code block x into s at gap i (clamped); a one-item x " +
            "inserts its sole item.")

    /// Open a new code block at one gap and close it at another, then rebuild.
    ///
    /// The two indices are **sorted**, so a reversed pair wraps the same span
    /// rather than producing nonsense — monotone, like every other clamp here.
    /// Equal indices give an empty code block at that gap, which needs no special case.
    ///
    /// A wrap that crosses an existing code block's boundary leaves the token stream
    /// unbalanced; `rebuilt(from:)` repairs it, which is the whole reason that
    /// function is total.
    static let codeWrapRange_Behavior =
        Behavior.operation(.codeWrapRange, takes: CodeItem.self, IntItem.self, IntItem.self, gives: CodeItem.self) { x, deep, top in
            // `top` is the last int written and `deep` the first, so the crux
            // names them `deep top` — law 3 records in *written* order. Getting
            // that backwards is invisible to the value here, since the pair is
            // sorted below, and shows up only as a crux that is not a fixed point.
            // Which is exactly how the fuzzer found it.
            let tree = CodeItem(x)
            var tokens = tree.gapTokens
            let (lo, hi) = { let p = [tree.gapIndex(top), tree.gapIndex(deep)].sorted()
                             return (p[0], p[1]) }()
            // The higher index first, so inserting there cannot shift the lower.
            tokens.insert(.close, at: hi)
            tokens.insert(.open, at: lo)
            return CodeItem.rebuilt(from: tokens).value
        }
        .described("Wraps everything between gaps i and j (clamped, either order) in a new code block; equal gaps " +
            "insert `( )`, and crossed code block edges are repaired.")

    /// Flatten every code block the gap range reaches into, and only those.
    ///
    /// A code block goes iff its head or tail gap falls inside the range. One that
    /// merely *encloses* the range keeps its shape, and so does one entirely
    /// outside it — so the effect stays where the program pointed. Indices are
    /// sorted, as in `.codeWrapRange`.
    static let codeFlattenRange_Behavior =
        Behavior.operation(.codeFlattenRange, takes: CodeItem.self, IntItem.self, IntItem.self, gives: CodeItem.self) { x, deep, top in
            // `deep top`, not `top deep` — see the note on `codeWrapRange`.
            let tree = CodeItem(x)
            let (lo, hi) = { let p = [tree.gapIndex(top), tree.gapIndex(deep)].sorted()
                             return (p[0], p[1]) }()
            return tree.flatteningBlocks(inGapRange: lo, through: hi).value
        }
        .described("Flattens every code block whose first or last gap lies between gaps i and j (clamped, either " +
            "order); code blocks enclosing the range keep their shape.")

    /// Iterate a code block's **root** elements, running the mouse once per element —
    /// the `.code` sibling of `.stringIterate`/`.vecXIterate`, over the existing
    /// `.elements`-over-CodeItem walk. `code MOUSE .codeIterateRoot`: the mouse is
    /// on top (a[0]), the iterated code beneath (a[1]). An empty code block makes no
    /// passes, and the mouse goes back to `.code`, as a finished loop's body does.
    static let codeIterateRoot_Behavior =
        Behavior.control(
            .codeIterateRoot,
            takes: [.code, .code],
            tags: [.reEntrant],
            fxn: { a, recording in
                let (mouse, x) = (a[0] as! CodeItem, a[1] as! CodeItem)
                guard !x.value.isEmpty else { return [Router(.code, mouse)] }
                return Interpreter.iteratorLoop(
                    kind: .elements(into: nil),
                    origin: x,
                    body: mouse,
                    emits: true, recording: recording
                )
            }
        )
        .described("Loops: `x b .codeIterateRoot` runs code block b once per root item of code block x, pushing each " +
            "item to its stack (an instruction runs); b ends on `.code`.")

    /// Iterate every **pre-order point** of the tree, running the mouse once per
    /// point. The three variants differ only in how each point is handed on (see
    /// `PointsEmission`): `.codeIterate` boxes it as `.code`,
    /// `.codeIterateEmit` hands it on whole, and `.codeIterateDo` runs a
    /// nested code block's contents. The `.points` siblings of `.codeIterateRoot`. A tree
    /// always has at least its root, so none of them ever does nothing.
    static func iteratePointsBehavior(_ instruction: PushInstruction, _ mode: PointsEmission) -> Behavior {
        Behavior.control(
            instruction,
            takes: [.code, .code],
            // The whole generated family is re-entrant — tagging in the factory is
            // what makes it impossible to tag two of the three.
            tags: [.reEntrant],
            fxn: { a, recording in
                let (mouse, x) = (a[0] as! CodeItem, a[1] as! CodeItem)
                return Interpreter.iteratorLoop(
                    kind: .points(mode),
                    origin: x,
                    body: mouse,
                    emits: true, recording: recording
                )
            }
        )
    }

    static let codeIterate_Behavior     = iteratePointsBehavior(.codeIterate, .boxed)
        .described("Loops: `x b .codeIterate` runs code block b once per point of code block x, root first, pushing " +
            "each point as a code block; b ends on `.code`.")
    static let codeIterateEmit_Behavior = iteratePointsBehavior(.codeIterateEmit, .whole)
        .described("Loops: `x b .codeIterateEmit` runs code block b once per point of code block x, root first, " +
            "pushing each point as it is (an instruction runs); b ends on `.code`.")
    static let codeIterateDo_Behavior   = iteratePointsBehavior(.codeIterateDo, .unwrapped)
        .described("Loops: `x b .codeIterateDo` runs code block b once per point of code block x, root first, also " +
            "running each point; b ends on `.code`.")

    static let codeWrap_Behavior =
        Behavior.composing(.codeWrap, takes: CodeItem.self, gives: CodeItem.self) { x in [x] }
        .described("Wraps a code block in another: `( a b )` becomes `( ( a b ) )`.")

    /// Unwraps the top code block on `.code` onto `.exec`, so its contents run.
    ///
    /// This is the only way a code block executes: the Interpreter pushes any
    /// `CodeItem` it meets on `.exec` to `.code` intact, so code is data until a
    /// program asks for it. It is `unwrapCodeItem` — which used to happen
    /// implicitly, on sight — promoted to an instruction.
    ///
    /// Note it cannot work the Push3 way. `CODE.DO` there pushes the code block onto
    /// `EXEC`, where lists unwrap; here that would send it straight back to
    /// `.code`, forever. So it spreads the contents directly.
    ///
    /// Provenance: combinatory, law 1b. The code block's own `call` is erased with the
    /// code block, and each content keeps the `call` it already had — exposed as
    /// though it had been sitting there all along, unchanged from the time it
    /// went in. Being inside a code block leaves no mark.
    ///
    /// **Except on what was born there**. A content with no history
    /// of its own, out of a code block that has one (a code block bound to `.input3`, or one
    /// a structural edit rebuilt), records its address, `block k .codeEmitNthRoot`
    /// and the clean-up, so its crux keeps the link to the code block. See
    /// `Containment`.
    static let codeDo_Behavior =
    Behavior.control(.codeDo, takes: [.code]) { collectedItems, recording in
        let block = collectedItems[0] as! CodeItem
        return [.place(Containment.contents(of: block, recording))]
    }
    .described("Runs a code block: its items go onto `.exec`, the first to run first.")

    /// Drive an iterator to exhaustion and box what it emitted into one code block.
    ///
    /// **This is the general form of collecting, and it never refuses.** A
    /// CodeItem is the vector-of-anything (see "The universal box" in CodeItem.swift),
    /// so every iterator that emits anything at all has an answer here — including
    /// the ones `.vecFromIterator` must turn away: a tree walk emitting subtrees,
    /// a `.repeating` iterator carrying a code block, an `.elements` walk over a mixed
    /// code block, a string's chars. Read the pair the right way round and the
    /// asymmetry disappears: **a vector is the special case where the emissions
    /// are uniform scalars**, and this is the case that always applies.
    ///
    /// Provenance is law 3, exactly as `.vecFromIterator`: the code block records its
    /// iterator and this instruction, and the iterator's own record rebuilds it at
    /// its cursor, so re-running collects the same sequence from the same place.
    /// The elements keep their own `call`s, which is what makes the code block's crux
    /// say where each of its contents came from.
    ///
    /// An empty collect needs no special case here, and that is the difference
    /// from the vector form: `( )` is a perfectly good value, where an empty
    /// vector of *no particular type* is a question with no answer.
    ///
    /// **Order**: the body is handed back first so the collected code block lands on
    /// top of it. Both go to `.code`, and the result is what the next instruction
    /// should find — a crux fragment has to leave its value on top or nothing
    /// composes.
    static let codeFromIterator_Behavior =
    Behavior(
        .codeFromIterator,
        takes: [.iterator],
        tags: [.fallible],
        // The collected block, under it the body if the loop had one.
        produces: .alternatives([[.code], [.code, .code]]),
        fxn: { a, recording in
            let iterator = a[0] as! IteratorItem
            // The farewell returns the body to `.code`, *under* the result. The
            // crux has to clear it, or the fragment leaves debris on the very
            // stack it lands on — so it records the same
            // swap-and-pop `reading` uses. No body, nothing to clear.
            // Over `collectionLimit` the sequence has no answer worth computing: refuse
            // as `.vecFromIterator` does, handing the iterator back untouched.
            guard let items = iterator.collected(recording: recording) else {
                return [
                    Router(.iterator, iterator),
                    Router(.error, ErrorItem(
                        "codeFromIterator: iterator emits more than \(IteratorItem.collectionLimit) items",
                        kind: .sizeRefusal, source: .codeFromIterator)
                        .observed(by: .codeFromIterator, recording))
                ]
            }
            // A function, so it is only built when recording.
            func record() -> [any Item] {
                let produced: [any Item] = [iterator, InstructionItem(.codeFromIterator)]
                return iterator.body == nil
                    ? produced
                    : Behavior.reading([.code: 1], producing: .code, from: produced)
            }
            let collected = CodeItem(items, call: recording(record()))
            return Interpreter.iteratorFarewell(iterator) + [Router(.code, collected)]
        }
    )
    .described("Collects everything the iterator has left to emit into one code block, its body returning to `.code` " +
        "beneath; refuses, keeping the iterator, when that is too many items.")

    /// Box a live iterator and park it on `.code`, where no continuation can
    /// reach it.
    ///
    /// Provenance is law 2 — relocation across stacks is not free — and it records
    /// exactly as the other quotes do: `«iter» .iteratorQuote`. The iterator's own
    /// `call` rebuilds it by state, so the code block reproduces a loop at the cursor it
    /// was parked at, which is the whole point of shelving one.
    ///
    /// **A spent iterator cannot arrive here**, because a spent iterator cannot
    /// rest on `.iterator` to be quoted. So the code block always holds a live loop, and
    /// `.codeDo` hands back something that still has something to emit.
    static let iteratorQuote_Behavior =
    Behavior(
        .iteratorQuote,
        takes: [.iterator],
        produces: .results([.code]),
        fxn: { a, recording in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.call = recording([x, InstructionItem(.iteratorQuote)])
            return [ Router(.code, result) ]
        }
    )
    .described("Quotes an iterator as a one-item code block on `.code`, parking it where no loop continues it.")

    static let codeBehaviors: [PushInstruction: Behavior] =
    [
        .codeFromIterator: codeFromIterator_Behavior,
        .iteratorQuote: iteratorQuote_Behavior,
        .codeConcat: codeConcat_Behavior,
        .codePair: codePair_Behavior,
        .codeDoIf: codeDoIf_Behavior,
        .codeDo: codeDo_Behavior,
        .codeItemIsEmpty: codeItemIsEmpty_Behavior,
        .codeLengthRoot: codeLengthRoot_Behavior,
        .codeLength: codeLength_Behavior,
        .codeWidth: codeWidth_Behavior,
        .codeDepth: codeDepth_Behavior,
        .codeContains: codeContains_Behavior,
        .codeIndexOf: codeIndexOf_Behavior,
        .codeOccurrencesOf: codeOccurrencesOf_Behavior,
        .codeContainer: codeContainer_Behavior,
        .codePeekNth: codePeekNth_Behavior,
        .codeNth: codeNth_Behavior,
        .codeNthRoot: codeNthRoot_Behavior,
        .codePeekNthRoot: codePeekNthRoot_Behavior,
        .codeDoNth: codeDoNth_Behavior,
        .codeDoNthRoot: codeDoNthRoot_Behavior,
        .codeEmitNth: codeEmitNth_Behavior,
        .codeEmitNthRoot: codeEmitNthRoot_Behavior,
        .codeFlatten: codeFlatten_Behavior,
        .codeFlattenOnce: codeFlattenOnce_Behavior,
        .codeFlattenNth: codeFlattenNth_Behavior,
        .codeCutAtGap: codeCutAtGap_Behavior,
        .codeInsertAtGap: codeInsertAtGap_Behavior,
        .codeWrapRange: codeWrapRange_Behavior,
        .codeFlattenRange: codeFlattenRange_Behavior,
        .codeRemoveNth: codeRemoveNth_Behavior,
        .codeReplace: codeReplace_Behavior,
        .codeReplaceFirst: codeReplaceFirst_Behavior,
        .codeCutRoot: codeCutRoot_Behavior,
        .codeIterateRoot: codeIterateRoot_Behavior,
        .codeIterate: codeIterate_Behavior,
        .codeIterateEmit: codeIterateEmit_Behavior,
        .codeIterateDo: codeIterateDo_Behavior,
        .codeWrap: codeWrap_Behavior
    ]
}
