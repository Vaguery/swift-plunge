//
//  Code Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/17/26.
//

import DequeModule

// Remaining unimplemented (gap-based ops deferred to a later batch):
//   codeCutAtGap, codeInsertAtGap, codeWrapPoints, codeFlattenRange

nonisolated extension Interpreter {

    static let codeAppend_Behavior =
        Behavior(
            .codeAppend,
            takes: [.code, .code],
            fxn: { a in
                let (x, y) = (a[0] as! CodeItem, a[1] as! CodeItem)
                let result =
                    CodeItem(
                        y.value + x.value,
                        call: [y, x, InstructionItem(.codeAppend)],
                        isContingent: Behavior.netContingency(of: x, y)
                    )
                return [Router(.code, result)]
            }
        )

    /// Wrap **two** code items into one new block `( x y )` — the arity-2 sibling
    /// of `codeWrapRoot`, and Clojure's `list` with two arguments. Distinct from
    /// `codeAppend`, which concatenates their contents flat: `(a b)` collect
    /// `(c d)` → `( (a b) (c d) )`, not `(a b c d)`.
    static let codeCollect_Behavior =
        Behavior(
            .codeCollect,
            takes: [.code, .code],
            fxn: { a in
                let (x, y) = (a[0], a[1])
                return [
                    Router(
                        .code,
                        CodeItem(
                            [y, x],
                            call: [y, x, InstructionItem(.codeCollect)],
                            isContingent: Behavior.netContingency(of: x, y)
                        )
                    )
                ]
            }
        )

    /// The `.code` sibling of `execIf`: pop a bool and two blocks, run the chosen
    /// one on `.exec`. Only the source stack differs — the mechanics (argument
    /// order, `.codeDo` the winner, the loser recorded nowhere) are execIf's.
    static let codeIf_Behavior =
        Behavior(
            .codeIf,
            takes: [.bool, .code, .code],
            fxn: { a in
                // Like execIf: `( then ) ( else ) .codeIf` — the last-written block
                // is on top and arrives as a[1] (`else`), so a[2] is `then`.
                let (cond, elseBlock, thenBlock) = (a[0] as! BoolItem, a[1], a[2])
                var result = cond.value ? thenBlock : elseBlock
                result.isContingent = cond.isContingent
                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, result),
                ]
            }
        )

    static let codeItemIsEmpty_Behavior =
        Behavior(
            .codeItemIsEmpty,
            reads: [.code],
            fxn: { a in
                let (x) = (a[0] as! CodeItem)
                let result =
                    BoolItem(
                        x.value.isEmpty,
                        call: Behavior.reading([.code: 1], producing: .bool, from: [x, InstructionItem(.codeItemIsEmpty)]),
                        isContingent: Behavior.netContingency(of: x)
                    )
                return [Router(.bool, result)]
            }
        )

    static let codeLengthRoot_Behavior =
        Behavior(
            .codeLengthRoot,
            reads: [.code],
            fxn: { a in
                let (x) = (a[0] as! CodeItem)
                let result =
                    IntItem(
                        x.value.count,
                        call: Behavior.reading([.code: 1], producing: .int, from: [x, InstructionItem(.codeLengthRoot)]),
                        isContingent: Behavior.netContingency(of: x)
                    )
                return [Router(.int, result)]
            }
        )

    // MARK: - Whole-tree queries (non-destructive)
    //
    // All read their code argument(s) and leave them; the crux pops what it read
    // (`Behavior.reading`), like the vector queries. They use the pre-order point
    // walker on `CodeItem` (Items.swift).

    /// The number of pre-order points in the whole tree, root included.
    /// `( (1 2) 3 )` → 5. (Contrast `codeLengthRoot`, the root `.value` count.)
    static let codeLengthPoints_Behavior =
        Behavior(
            .codeLengthPoints,
            reads: [.code],
            fxn: { a in
                let x = a[0] as! CodeItem
                return [Router(.int, IntItem(
                    x.pointCount,
                    call: Behavior.reading([.code: 1], producing: .int, from: [x, InstructionItem(.codeLengthPoints)]),
                    isContingent: Behavior.netContingency(of: x)
                ))]
            }
        )

    /// The number of leaves in the tree — everything that is not a sub-block, so
    /// scalars, instructions and whole vectors each count one. Equals `flatSize`.
    static let codeWidth_Behavior =
        Behavior(
            .codeWidth,
            reads: [.code],
            fxn: { a in
                let x = a[0] as! CodeItem
                return [Router(.int, IntItem(
                    x.flatSize,
                    call: Behavior.reading([.code: 1], producing: .int, from: [x, InstructionItem(.codeWidth)]),
                    isContingent: Behavior.netContingency(of: x)
                ))]
            }
        )

    /// The maximum nesting depth: root 0, each nested block one deeper.
    static let codeDepth_Behavior =
        Behavior(
            .codeDepth,
            reads: [.code],
            fxn: { a in
                let x = a[0] as! CodeItem
                return [Router(.int, IntItem(
                    x.depth,
                    call: Behavior.reading([.code: 1], producing: .int, from: [x, InstructionItem(.codeDepth)]),
                    isContingent: Behavior.netContingency(of: x)
                ))]
            }
        )

    /// Whether a target block occurs as a point anywhere in another's tree. Since
    /// the root is a point, a tree contains itself. Reads both, leaves both.
    static let codeContains_Behavior =
        Behavior(
            .codeContains,
            reads: [.code, .code],
            fxn: { a in
                // a[0] is the haystack (top), a[1] the target.
                let (hay, target) = (a[0] as! CodeItem, a[1])
                return [Router(.bool, BoolItem(
                    hay.firstPointIndex(of: target) != nil,
                    call: Behavior.reading([.code: 2], producing: .bool, from: [target, hay, InstructionItem(.codeContains)]),
                    isContingent: Behavior.netContingency(of: hay, target)
                ))]
            }
        )

    /// The pre-order index of the first point equal to the target, or −1.
    static let codeIndexOfPoint_Behavior =
        Behavior(
            .codeIndexOfPoint,
            reads: [.code, .code],
            fxn: { a in
                let (hay, target) = (a[0] as! CodeItem, a[1])
                return [Router(.int, IntItem(
                    hay.firstPointIndex(of: target) ?? -1,
                    call: Behavior.reading([.code: 2], producing: .int, from: [target, hay, InstructionItem(.codeIndexOfPoint)]),
                    isContingent: Behavior.netContingency(of: hay, target)
                ))]
            }
        )

    /// The block that directly contains the first point equal to the target —
    /// its parent. Nothing is pushed if the target is absent, or if it is the
    /// whole tree (which has no parent here). Reads both, leaves both.
    static let codeContainer_Behavior =
        Behavior(
            .codeContainer,
            reads: [.code, .code],
            fxn: { a in
                let (hay, target) = (a[0] as! CodeItem, a[1])
                guard let parent = hay.parentContaining(target) else { return [] }
                return [Router(.code, CodeItem(
                    parent.value,
                    call: Behavior.reading([.code: 2], producing: .code, from: [target, hay, InstructionItem(.codeContainer)]),
                    isContingent: Behavior.netContingency(of: hay, target)
                ))]
            }
        )

    // MARK: - Point access (non-destructive)
    //
    // Both **always yield `.code`**: a point that is a sub-block pushes as itself;
    // a leaf (scalar, instruction, whole vector) is wrapped `( x )` so the result
    // is uniform and inert. The extracted point is treated as a derived value —
    // "the code at point i of x" — recording the reading crux rather than the
    // point's own history, so the crux is uniform whatever the point's type and
    // cleans up both arguments (§5). Index is `magnitude % count`.

    /// Box a point as a `.code` result: a sub-block as-is, a leaf wrapped once.
    static func boxedPointContents(_ point: any Item) -> [any Item] {
        (point as? CodeItem)?.value ?? [point]
    }

    /// The pre-order point at the `.int` index (root at 0), yielded as `.code`.
    static let codeNthPoint_Behavior =
        Behavior(
            .codeNthPoint,
            reads: [.code, .int],
            fxn: { a in
                let (x, i) = (a[0] as! CodeItem, a[1] as! IntItem)
                return [Router(.code, CodeItem(
                    boxedPointContents(x.point(at: i.value)),
                    call: Behavior.reading([.code: 1, .int: 1], producing: .code, from: [x, i, InstructionItem(.codeNthPoint)]),
                    isContingent: Behavior.netContingency(of: x, i)
                ))]
            }
        )

    /// The root `.value` element at the `.int` index (`magnitude % count`), yielded
    /// as `.code`. An empty block has no root elements, so nothing is pushed.
    static let codeNthRoot_Behavior =
        Behavior(
            .codeNthRoot,
            reads: [.code, .int],
            fxn: { a in
                let (x, i) = (a[0] as! CodeItem, a[1] as! IntItem)
                guard !x.value.isEmpty else { return [] }
                let element = x.value[Int(i.value.magnitude % UInt(x.value.count))]
                return [Router(.code, CodeItem(
                    boxedPointContents(element),
                    call: Behavior.reading([.code: 1, .int: 1], producing: .code, from: [x, i, InstructionItem(.codeNthRoot)]),
                    isContingent: Behavior.netContingency(of: x, i)
                ))]
            }
        )

    // MARK: - Flatten and point mutation (transforms, consume)

    /// Flatten the whole tree to its leaves, left to right. `(1 (2 3) ())` →
    /// `(1 2 3)`. Empty blocks vanish.
    static let codeFlatten_Behavior =
        Behavior(
            .codeFlatten,
            takes: [.code],
            fxn: { a in
                let x = a[0] as! CodeItem
                return [Router(.code, CodeItem(
                    x.flattenedLeaves(),
                    call: [x, InstructionItem(.codeFlatten)],
                    isContingent: Behavior.netContingency(of: x)
                ))]
            }
        )

    /// Flatten one level: each root element that is a block is replaced by its
    /// contents, no deeper. `(1 (2 (3 4)) 5)` → `(1 2 (3 4) 5)`.
    static let codeFlattenOnce_Behavior =
        Behavior(
            .codeFlattenOnce,
            takes: [.code],
            fxn: { a in
                let x = a[0] as! CodeItem
                return [Router(.code, CodeItem(
                    x.flattenedOnce(),
                    call: [x, InstructionItem(.codeFlattenOnce)],
                    isContingent: Behavior.netContingency(of: x)
                ))]
            }
        )

    /// Flatten the subtree at the indexed point in place. A leaf point is
    /// unchanged; point 0 (the root) flattens the whole thing (= codeFlatten).
    static let codeFlattenPoint_Behavior =
        Behavior(
            .codeFlattenPoint,
            takes: [.code, .int],
            fxn: { a in
                let (x, i) = (a[0] as! CodeItem, a[1] as! IntItem)
                let point = x.point(at: i.value)
                let flattened: any Item =
                    (point as? CodeItem).map { CodeItem($0.flattenedLeaves()) } ?? point
                let rebuilt = x.replacingPoint(at: i.value, with: flattened)
                let result = (rebuilt as? CodeItem) ?? CodeItem([rebuilt])
                return [Router(.code, CodeItem(
                    result.value,
                    call: [x, i, InstructionItem(.codeFlattenPoint)],
                    isContingent: Behavior.netContingency(of: x, i)
                ))]
            }
        )

    /// Remove the point at the indexed location, subtree and all. Removing the
    /// root gives an empty block.
    static let codeRemovePoint_Behavior =
        Behavior(
            .codeRemovePoint,
            takes: [.code, .int],
            fxn: { a in
                let (x, i) = (a[0] as! CodeItem, a[1] as! IntItem)
                return [Router(.code, CodeItem(
                    x.removingPoint(at: i.value).value,
                    call: [x, i, InstructionItem(.codeRemovePoint)],
                    isContingent: Behavior.netContingency(of: x, i)
                ))]
            }
        )

    /// Replace every point equal to `needle` with `replacement` (whole subtree),
    /// single pass. Consumes subject, needle, replacement (all `.code`).
    static let codeReplaceAllPoints_Behavior =
        replacePointsBehavior(.codeReplaceAllPoints, firstOnly: false)

    /// As above, but only the first matching point in pre-order.
    static let codeReplaceFirstPoint_Behavior =
        replacePointsBehavior(.codeReplaceFirstPoint, firstOnly: true)

    static func replacePointsBehavior(_ instruction: PushInstruction, firstOnly: Bool) -> Behavior {
        Behavior(
            instruction,
            takes: [.code, .code, .code],
            fxn: { a in
                // a[0]=replacement (top), a[1]=needle, a[2]=subject (deepest).
                let (repl, needle, subject) = (a[0] as! CodeItem, a[1] as! CodeItem, a[2] as! CodeItem)
                let rebuilt = subject.replacingPoints(equalTo: needle, with: repl, firstOnly: firstOnly)
                let result = (rebuilt as? CodeItem) ?? CodeItem([rebuilt])
                return [Router(.code, CodeItem(
                    result.value,
                    call: [subject, needle, repl, InstructionItem(instruction)],
                    isContingent: Behavior.netContingency(of: subject, needle, repl)
                ))]
            }
        )
    }

    // MARK: - Root-level split and iterate

    /// Split the **root** `.value` array at the indexed gap into two blocks — the
    /// `.code` analog of `vecXCut`/`stringCut`. Prefix deeper, suffix on top (so
    /// `cut` then `codeAppend` rebuilds the original); law-5 multi-result crux.
    static let codeCutRootAtGap_Behavior =
        Behavior(
            .codeCutRootAtGap,
            takes: [.code, .int],
            fxn: { a in
                let (x, y) = (a[0] as! CodeItem, a[1] as! IntItem)
                let count = x.value.count
                let idx = count == 0 ? 0 : Int(y.value.magnitude % UInt(count))
                let prefix = Array(x.value[0..<idx])
                let suffix = Array(x.value[idx...])
                let source: [any Item] = [x, y, InstructionItem(.codeCutRootAtGap)]
                let contingent = Behavior.netContingency(of: x, y)
                return [
                    Router(.code, CodeItem(
                        prefix,
                        call: Behavior.selecting(0, of: 2, on: .code, from: source),
                        isContingent: contingent
                    )),
                    Router(.code, CodeItem(
                        suffix,
                        call: Behavior.selecting(1, of: 2, on: .code, from: source),
                        isContingent: contingent
                    )),
                ]
            }
        )

    /// Iterate a block's **root** elements, running the mouse once per element —
    /// the `.code` sibling of `stringIterate`/`vecXIterate`, over the existing
    /// `.elements`-over-CodeItem walk. `code MOUSE .codeIterateRoot`: the mouse is
    /// on top (a[0]), the iterated code beneath (a[1]). An empty block does
    /// nothing.
    static let codeIterateRoot_Behavior =
        Behavior(
            .codeIterateRoot,
            takes: [.code, .code],
            fxn: { a in
                let (mouse, x) = (a[0] as! CodeItem, a[1] as! CodeItem)
                guard !x.value.isEmpty else { return [] }
                return Interpreter.iteratorLoop(
                    kind: .elements(into: nil),
                    origin: x,
                    body: mouse,
                    emits: true
                )
            }
        )

    static let codeWrapRoot_Behavior =
    Behavior(
        .codeWrapRoot,
        takes: [.code],
        fxn: {a in
            let (x) = (a[0] as! CodeItem)
            let result =
                CodeItem(
                    [x],
                    call: [x, InstructionItem(.codeWrapRoot)],
                    isContingent: Behavior.netContingency(of: x)
                    )
            return [ Router( .code, result) ]
        }
    )

    static let execQuote_Behavior =
    Behavior(
        .execQuote,
        takes: [.exec],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [InstructionItem(.execQuote), x]
            return [ Router(.code, result) ]
        }
    )


    static let intQuote_Behavior =
    Behavior(
        .intQuote,
        takes: [.int],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.intQuote)]
            return [ Router(.code, result) ]
        }
    )

    static let boolQuote_Behavior =
    Behavior(
        .boolQuote,
        takes: [.bool],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.boolQuote)]
            return [ Router(.code, result) ]
        }
    )

    static let stringQuote_Behavior =
    Behavior(
        .stringQuote,
        takes: [.string],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.stringQuote)]
            return [ Router(.code, result) ]
        }
    )

    static let charQuote_Behavior =
    Behavior(
        .charQuote,
        takes: [.char],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.charQuote)]
            return [ Router(.code, result) ]
        }
    )

    static let doubleQuote_Behavior =
    Behavior(
        .doubleQuote,
        takes: [.double],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.doubleQuote)]
            return [ Router(.code, result) ]
        }
    )


    /// Unwraps the top `.code` block onto `.exec`, so its contents run.
    ///
    /// This is the only way a block executes: the Interpreter pushes any
    /// `CodeItem` it meets on `.exec` to `.code` intact, so code is data until a
    /// program asks for it. It is `unwrapCodeItem` — which used to happen
    /// implicitly, on sight — promoted to an instruction.
    ///
    /// Note it cannot work the Push3 way. `CODE.DO` there pushes the block onto
    /// `EXEC`, where lists unwrap; here that would send it straight back to
    /// `.code`, forever. So it spreads the contents directly.
    ///
    /// Provenance: combinatory, law 1b. The block's own `call` is erased with the
    /// block, and each content keeps the `call` it already had — exposed as
    /// though it had been sitting there all along, unchanged from the time it
    /// went in. Being inside a block leaves no mark. Contingency does propagate:
    /// a block reached contingently makes its contents contingent.
    static let codeDo_Behavior =
    BehaviorWithSideEffects(
        .codeDo,
        takes: [.code],
        modifier: { (interpreter, collectedItems) in
            let block = collectedItems[0] as! CodeItem
            let contents = block.value.map { item -> any Item in
                var copy = item
                copy.isContingent = Behavior.netContingency(of: block, copy)
                return copy
            }
            interpreter.stacks[.exec]!.prepend(contentsOf: contents)
            return []
        }
    )


    /// Drive an iterator to exhaustion and box what it emitted into one block.
    ///
    /// **This is the general form of collecting, and it never refuses.** A
    /// CodeItem is the vector-of-anything (see "The universal box" in Items.swift),
    /// so every iterator that emits anything at all has an answer here — including
    /// the ones `.vecFromIterator` must turn away: a tree walk emitting subtrees,
    /// a `.repeating` iterator carrying a block, an `.elements` walk over a mixed
    /// block, a string's chars. Read the pair the right way round and the
    /// asymmetry disappears: **a vector is the special case where the emissions
    /// are uniform scalars**, and this is the case that always applies.
    ///
    /// Provenance is law 3, exactly as `.vecFromIterator`: the block records its
    /// iterator and this instruction, and the iterator's own record rebuilds it at
    /// its cursor, so re-running collects the same sequence from the same place.
    /// The elements keep their own `call`s, which is what makes the block's crux
    /// say where each of its contents came from.
    ///
    /// An empty collect needs no special case here, and that is the difference
    /// from the vector form: `( )` is a perfectly good value, where an empty
    /// vector of *no particular type* is a question with no answer.
    ///
    /// **Order**: the body is handed back first so the collected block lands on
    /// top of it. Both go to `.code`, and the result is what the next instruction
    /// should find — a crux fragment has to leave its value on top or nothing
    /// composes.
    static let codeFromIterator_Behavior =
    Behavior(
        .codeFromIterator,
        takes: [.iterator],
        fxn: { a in
            let iterator = a[0] as! IteratorItem
            let collected = CodeItem(
                iterator.collected(),
                call: [iterator, InstructionItem(.codeFromIterator)],
                isContingent: Behavior.netContingency(of: iterator)
            )
            return Interpreter.iteratorFarewell(iterator) + [Router(.code, collected)]
        }
    )


    /// Box a live iterator and park it on `.code`, where no continuation can
    /// reach it.
    ///
    /// Provenance is law 2 — relocation across stacks is not free — and it records
    /// exactly as the other quotes do: `«iter» .iteratorQuote`. The iterator's own
    /// `call` rebuilds it by state, so the block reproduces a loop at the cursor it
    /// was parked at, which is the whole point of shelving one.
    ///
    /// **A spent iterator cannot arrive here**, because a spent iterator cannot
    /// rest on `.iterator` to be quoted. So the block always holds a live loop, and
    /// `.codeDo` hands back something that still has something to emit.
    static let iteratorQuote_Behavior =
    Behavior(
        .iteratorQuote,
        takes: [.iterator],
        fxn: { a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x)
            result.call = [x, InstructionItem(.iteratorQuote)]
            return [ Router(.code, result) ]
        }
    )


    static let codeBehaviors:[PushInstruction : Behavior] =
    [
        .codeFromIterator : codeFromIterator_Behavior,
        .iteratorQuote : iteratorQuote_Behavior,
        .boolQuote : boolQuote_Behavior,
        .charQuote : charQuote_Behavior,
        .codeAppend : codeAppend_Behavior,
        .codeCollect : codeCollect_Behavior,
        .codeIf : codeIf_Behavior,
        .codeDo : codeDo_Behavior,
        .codeItemIsEmpty : codeItemIsEmpty_Behavior,
        .codeLengthRoot : codeLengthRoot_Behavior,
        .codeLengthPoints : codeLengthPoints_Behavior,
        .codeWidth : codeWidth_Behavior,
        .codeDepth : codeDepth_Behavior,
        .codeContains : codeContains_Behavior,
        .codeIndexOfPoint : codeIndexOfPoint_Behavior,
        .codeContainer : codeContainer_Behavior,
        .codeNthPoint : codeNthPoint_Behavior,
        .codeNthRoot : codeNthRoot_Behavior,
        .codeFlatten : codeFlatten_Behavior,
        .codeFlattenOnce : codeFlattenOnce_Behavior,
        .codeFlattenPoint : codeFlattenPoint_Behavior,
        .codeRemovePoint : codeRemovePoint_Behavior,
        .codeReplaceAllPoints : codeReplaceAllPoints_Behavior,
        .codeReplaceFirstPoint : codeReplaceFirstPoint_Behavior,
        .codeCutRootAtGap : codeCutRootAtGap_Behavior,
        .codeIterateRoot : codeIterateRoot_Behavior,
        .codeWrapRoot : codeWrapRoot_Behavior,
        .doubleQuote : doubleQuote_Behavior,
        .execQuote : execQuote_Behavior,
        .intQuote : intQuote_Behavior,
        .stringQuote : stringQuote_Behavior,

    ]
}
