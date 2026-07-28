//
//  Exec Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L335-L343
    //  "`:exec-do*while` pops the top of the `:exec` stack. It builds and pushes a continuation to the `:exec` stack which is `'([item] :exec-while [item])` (_Note_ the instruction is `:exec-while` in the continuation form)."
    static let execDoWhile_Behavior =
        Behavior(
            .execDoWhile,
            takes: [.bool, .code],
            tags: [.reEntrant],
            // Provenance: every result here is combinatory. The body copies are
            // duplications of the block (law 1b — containment leaves no mark),
            // and the `.execWhile` and `.codeDo` tokens are freshly minted
            // (law 4). Nothing is derived, so nothing records a `call`.
            fxn: { a in
                let (x, body) = (a[0] as! BoolItem, a[1])

                var bodyCopy = body

                // Always runs the body at least once — `.exec` top→bottom is
                // body, .codeDo.
                var results = [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, bodyCopy),
                ]

                if x.value {
                    // …then re-supplies the body to `.code` and hands off to
                    // `.execWhile`, which consults the next BOOL.
                    var yCopy2 = body

                    results.insert(
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile)
                        ),
                        at: 0
                    )
                    results.insert(Router(.exec, yCopy2), at: 1)
                }
                return results
            }
        )

    // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L13-L32
    //

    static let execDoCount_Behavior =
        Behavior(
            .execDoCount,
            takes: [.int, .code],
            // Counts from 0 up to `x`, leaving each index on `.int` for the body.
            //
            // It used to rewrite itself into an `.execDoRange` continuation and let
            // that do the counting; now it simply builds the iterator that does,
            // and the delegation is gone. The bounds go *into* the iterator rather
            // than back onto `.int`.
            //
            // Provenance: the iterator records how to rebuild itself (see
            // `IteratorItem.reconstruction`); the `.iteratorPlay` token is freshly
            // minted (law 4). `newEndPoint` is the literal 0 whatever the arguments
            // were, so it is its own crux and records nothing.
            fxn: { a in
                let (x, body) = (a[0] as! IntItem, a[1] as! CodeItem)

                guard x.value >= 1 else {
                    // Both arguments are returned to where they came from.
                    return [
                        Router(.code, body),
                        Router(.exec, x),
                    ]
                }

                var origin = IntItem(0)

                return iteratorLoop(
                    kind: .counting(stride: 1),
                    origin: origin,
                    destination: x,
                    body: body,
                    emits: true
                )
            }
        )

    //        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L183-L203
    static let execDoTimes_Behavior =
        Behavior(
            .execDoTimes,
            takes: [.int, .code],
            // "Do the body, `x` times" — the index is the loop's business and is
            // never shown to the body, which is the whole of the difference from
            // `.execDoCount`. That distinction is now one flag on the iterator
            // rather than a separate recursion.
            //
            // Provenance: the iterator records how to rebuild itself; the
            // `.iteratorPlay` token is freshly minted (law 4). The counter that
            // used to need `IteratorItem.steppedCall` to fold is gone — the
            // iterator holds the count, and never emits it.
            fxn: { a in
                let (x, body) = (a[0] as! IntItem, a[1] as! CodeItem)

                var bodyCopy = body

                guard x.value >= 1 else {
                    // No iteration: the body is returned to where it came from,
                    // which is now `.code`. It stays data rather than running,
                    // which is the whole point of the CodeItem change.
                    return [Router(.code, bodyCopy)]
                }

                var origin = IntItem(0)

                // Identical to `.execDoCount`'s iterator but for `emits`, which is
                // the whole of the difference between the two instructions. `x` is
                // the destination, not `x - 1`: the range stops one short of its
                // destination (see `hasNextPass`), so counting 0 toward `x` is
                // exactly `x` passes.
                return iteratorLoop(
                    kind: .counting(stride: 1),
                    origin: origin,
                    destination: x,
                    body: bodyCopy,
                    emits: false
                )
            }
        )

    //        // using my own code as an example from: https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L83-L112
    static let execDoRange_Behavior =
        Behavior(
            .execDoRange,
            takes: [.int, .int, .code],
            // Steps an index from `y` toward `x`, leaving it on `.int` each pass.
            //
            // This is where `.call` used to blow up: the next counter recorded
            // `[y, x, .execDoRange]` where `y` was the PREVIOUS counter, so the
            // chain deepened once per pass — and `y x .execDoRange` does not
            // produce `y+1` in any case. The counter now names its origin and its
            // offset directly (`IteratorItem.projection`), which is O(1) without
            // needing anything folded.
            //
            // It also used to rebuild its own recursion as Push source every pass,
            // re-pushing both bounds and a fresh `.execDoRange` token. The bounds
            // now go into the iterator and stay there; the counting is Swift's job.
            //
            // Provenance: the body copy is combinatory (laws 1 and 1b) and the
            // `.iteratorPlay` token is freshly minted (law 4). The iterator records
            // how to rebuild itself by state.
            fxn: { a in
                let (x, y, body) = (a[0] as! IntItem, a[1] as! IntItem, a[2] as! CodeItem)

                var bodyCopy = body

                // The stride is the direction to travel, and equal bounds are a
                // single pass either way.
                let direction = y.value <= x.value ? 1 : -1

                return iteratorLoop(
                    kind: .counting(stride: direction),
                    origin: y,
                    destination: x,
                    body: bodyCopy,
                    emits: true
                )
            }
        )

    /// Build an iterator and hand it to `.iteratorPlay` — the shape every looping
    /// instruction in the language now reduces to, whether it counts a range or
    /// walks a collection.
    ///
    /// `.exec` top→bottom ends up `.iteratorPlay`, so the iterator is resting on
    /// `.iterator` by the time it fires. The loop's whole state travels inside it;
    /// none of the counting or walking is expressed in Push any more.
    ///
    /// `destination` is nil for a walker, whose end is its origin's own length.
    /// Burial is 0 and deliberately not a parameter: these are all tight loops,
    /// and never gathering a burial is exactly how they avoid paying for one.
    static func iteratorLoop(
        kind: IteratorKind,
        origin: any Item,
        destination: (any Item)? = nil,
        body: CodeItem?,
        emits: Bool
    ) -> [Router] {
        var iterator = IteratorItem(
            kind: kind,
            origin: origin,
            destination: destination,
            body: body,
            emits: emits)
        iterator.call = iterator.reconstruction()

        return [
            Router(.exec, InstructionItem(.iteratorPlay)),
            Router(.iterator, iterator),
        ]
    }

    static let execIf_Behavior =
        Behavior(
            .execIf,
            takes: [.bool, .code, .code],
            // Provenance: selecting one of two blocks and discarding the other
            // changes no value, so this is a pure combinator (law 1) and records
            // nothing. The branch not taken simply never contributes to
            // anything's crux.
            //
            // The chosen block RUNS — `.exec` top→bottom is chosen, .codeDo.
            // Selecting a block *without* running it is what the `.code`
            // combinators are for.
            fxn: { a in
                // Argument order reverses when a code argument moves from `.exec`
                // to `.code`: `.exec` was read forward from the program, but
                // `.code` is a stack, so the LAST-written block is on top and
                // arrives as a[1]. The rest of the language reads postfix
                // arguments first-written-first (`2 3 .intSubtract` is 2-3, with
                // the 2 at a[1]), so `( then ) ( else ) .execIf` keeps that:
                // a[2] is `then`.
                let (x, elseBlock, thenBlock) = (a[0] as! BoolItem, a[1], a[2])
                var result = x.value ? thenBlock : elseBlock
                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, result),
                ]
            }
        )

    static let execK_Behavior =
        Behavior(
            .execK,
            takes: [.code, .code],
            // The K combinator: keep the first, discard the second. Law 1 — no
            // value changes. The kept block runs, as it did when it was handed
            // back to `.exec`.
            fxn: { a in
                // `K x y = x` keeps the first-written block, which off `.code`
                // arrives as a[1] — see the note on `execIf` about the order
                // reversing with the move from `.exec`.
                let x = a[1]
                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, x),
                ]
            }
        )

    static let execY_Behavior =
        Behavior(
            .execY,
            takes: [.code],
            tags: [.reEntrant, .risky],
            // Law 1 throughout: the block is duplicated and the `.execY` and
            // `.codeDo` tokens are freshly minted.
            //
            // `.exec` top→bottom: x, .codeDo, x, .execY — run the body, then
            // re-supply it to `.code` and recur. Routers are prepended one at a
            // time, so their order is the reverse of the resulting stack.
            fxn: { a in
                let x = a[0]
                return [
                    Router(.exec, InstructionItem(.execY)),
                    Router(.exec, x),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, x),
                ]
            }
        )

    static let execS_Behavior =
        Behavior(
            .execS,
            takes: [.code, .code, .code],
            // The S combinator: `S x y z` → `x z (y z)`. Pure rearrangement, so
            // law 1 — nothing is recorded.
            //
            // Each of the four runs needs its own `.codeDo`, since `.exec`
            // top→bottom is x, z, y, z and every one of them is a block. The
            // `(y z)` grouping flattens harmlessly: `.exec` is flat, so `x z (y z)`
            // and `x z y z` execute identically.
            fxn: { a in
                // Written `x y z .execS`, so off `.code` the top is z — see the
                // note on `execIf` about the order reversing with the move from
                // `.exec`.
                let (x, y, z) = (a[2], a[1], a[0])

                var yCopy = y
                var zCopy = z

                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, zCopy),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, yCopy),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, z),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, x),
                ]
            }
        )

    static let execWhen_Behavior =
        Behavior(
            .execWhen,
            takes: [.bool, .code],
            // Law 1: the block passes through untouched when the guard holds,
            // and runs. When it does not hold, it is discarded.
            fxn: { a in
                var (x, body) = (a[0] as! BoolItem, a[1])
                var results = [Router]()

                if x.value {
                    results = [
                        Router(.exec, InstructionItem(.codeDo)),
                        Router(.exec, body),
                    ]
                }
                return results
            }
        )

    static let execWhile_Behavior =
        Behavior(
            .execWhile,
            takes: [.bool, .code],
            tags: [.reEntrant],
            // Provenance: as `execDoWhile` — body copies (laws 1 and 1b) and
            // freshly minted continuation tokens (law 4). Nothing is derived.
            //
            // On a true guard, `.exec` top→bottom is body, .codeDo, body,
            // .execWhile: run the body, re-supply it to `.code`, and re-test the
            // next BOOL. A false guard consumes both and stops.
            fxn: { a in
                let (x, body) = (a[0] as! BoolItem, a[1])

                var results = [Router]()

                if x.value {
                    var bodyCopy = body

                    var yCopy2 = body

                    results = [
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile)
                        ),
                        Router(.exec, yCopy2),
                        Router(.exec, InstructionItem(.codeDo)),
                        Router(.exec, bodyCopy),
                    ]
                }
                return results
            }
        )

    static let execBehaviors:[PushInstruction : Behavior] =
    [
        .execDoCount : execDoCount_Behavior,
        .execDoRange : execDoRange_Behavior,
        .execDoTimes : execDoTimes_Behavior,
        .execDoWhile : execDoWhile_Behavior,
        .execIf : execIf_Behavior,
        .execK : execK_Behavior,
        .execS : execS_Behavior,
        .execWhen : execWhen_Behavior,
        .execWhile : execWhile_Behavior,
        .execY : execY_Behavior,
    ]
}
