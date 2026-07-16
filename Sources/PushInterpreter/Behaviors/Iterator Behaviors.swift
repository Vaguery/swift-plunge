//
//  Iterator Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/16/26.
//

import DequeModule

nonisolated extension Interpreter {

    // MARK: - Stepping

    /// The payload of one pass, as Routers: the projected item (when the iterator
    /// emits one), then — if it has a body — the body and the `.codeDo` that runs
    /// it.
    ///
    /// `.exec` ends up top→bottom `body, .codeDo, …`, so the body runs *between*
    /// the payload and whatever continuation the caller appends. That is what lets
    /// the body see — or steal — the iterator resting on `.iterator`.
    ///
    /// **A bodyless iterator emits only its element.** Those are the sequences —
    /// `stringPushAllChars` and the dup families — which have no mouse to run, and
    /// pushing an empty block for them would cost two wasted steps per element.
    ///
    /// Provenance: the body copy is combinatory (laws 1 and 1b) and the `.codeDo`
    /// token is freshly minted (law 4), so neither records anything. The
    /// projection carries its own record; see `IteratorItem.projection`.
    static func iteratorPass(_ iterator: IteratorItem) -> [Router] {
        var results = [Router]()

        if iterator.emits, let projected = iterator.projection() {
            // `?? .exec` because `defaultStack(for:)` answers nil for an
            // InstructionItem — it executes rather than lands. Without the
            // fallback an instruction walked out of a code block would be
            // silently dropped, which is exactly what a points traversal would
            // meet: most leaves of a block ARE instructions. An instruction with
            // no resting place should run, and `.exec` is where running happens.
            let resting = iterator.target
                ?? PushStack.defaultStack(for: projected)
                ?? .exec
            results.append(Router(resting, projected))
        }

        if let body = iterator.body {
            var bodyCopy = body
            bodyCopy.isContingent = Behavior.netContingency(of: iterator, body)
            results.append(Router(.exec, InstructionItem(.codeDo)))
            results.append(Router(.exec, bodyCopy))
        }
        return results
    }

    /// Insert `token` into `.exec` at `burial` items below the payload the caller
    /// has already pushed, clamped to the stack's depth.
    ///
    /// Burial 0 means directly under the payload — a tight loop that comes back
    /// round the moment its body is done, which is what every ordinary loop wants
    /// and what `.iteratorPlay` did before burial existed. A positive burial lets
    /// whatever else is pending run first.
    static func bury(
        _ token: any Item,
        _ burial: Int,
        under payload: [Router],
        in interpreter: Interpreter
    ) {
        let before = interpreter.stacks[.exec]!.count
        for router in payload {
            interpreter.push(router.item, to: router.stack)
        }
        let payloadDepth = interpreter.stacks[.exec]!.count - before

        let target = min(payloadDepth + max(0, burial), interpreter.stacks[.exec]!.count)
        interpreter.stacks[.exec]!.insert(token, at: target)
    }

    /// One pass, by hand — no continuation. A program driving a loop itself calls
    /// this as often as it wants a pass.
    ///
    /// A spent iterator emits nothing and does not come back: it is consumed and
    /// simply disappears, which is how a loop ends.
    static let iteratorStep_Behavior =
        Behavior(
            .iteratorStep,
            takes: [.iterator],
            fxn: { a in
                let iterator = a[0] as! IteratorItem
                guard !iterator.isSpent else { return [] }

                var results = iteratorPass(iterator)
                if iterator.hasNextPass {
                    results.append(Router(.iterator, iterator.stepped()))
                }
                return results
            }
        )

    /// One pass, plus its own next copy buried `burial` items below the payload —
    /// the loop, and **the only continuation token**.
    ///
    /// At burial 0, which is what every tight loop carries, the copy lands
    /// directly under the payload and this is an ordinary loop. A positive burial
    /// lets other pending work run in between, so the loop interleaves rather than
    /// monopolising `.exec`. Reading the depth from the iterator rather than from
    /// `.int` is the whole point: a thousand-pass loop consumes no arguments at
    /// all, which is what `.iteratorPlayDelayed` re-reading a delay every pass got
    /// wrong.
    ///
    /// On the last pass neither the iterator nor the continuation is emitted, so a
    /// loop never leaves a token behind to fire against an empty stack. A dangling
    /// `.iteratorPlay` can only arise if the body itself removed the iterator, and
    /// then "missing args" on `.error` is the honest answer.
    static let iteratorPlay_Behavior =
        BehaviorWithSideEffects(
            .iteratorPlay,
            takes: [.iterator],
            modifier: { (interpreter, collectedItems) in
                let iterator = collectedItems[0] as! IteratorItem
                guard !iterator.isSpent else { return [] }

                let payload = iteratorPass(iterator)
                guard iterator.hasNextPass else {
                    return payload
                }

                bury(
                    InstructionItem(.iteratorPlay, isContingent: iterator.isContingent),
                    iterator.burial,
                    under: payload,
                    in: interpreter
                )
                return [Router(.iterator, iterator.stepped())]
            }
        )

    /// Aim a loop's burial depth, once, and play it.
    ///
    /// Pops a single `.int`, **stores it on the iterator**, and then behaves
    /// exactly as `.iteratorPlay` — including handing the loop off to
    /// `.iteratorPlay` as its continuation. So the depth is read one time and
    /// persists for the life of the loop.
    ///
    /// This used to re-read a delay every pass, which was a dead end: it made a
    /// long loop eat every `.int` in sight, and argument starvation is the very
    /// Push design flaw first-class iterators are meant to relieve.
    ///
    /// - `burial < 0` — the loop ends here, short of exhaustion. This pass still
    ///   happens; only the continuation is dropped.
    /// - `burial == 0` — an ordinary tight loop.
    /// - `burial > 0` — that many items further down `.exec`, clamped to its depth
    ///   like the `Shove`/`Yank` combinators clamp.
    ///
    /// Note `gather` is all-or-nothing, so meeting an empty `.int` leaves the
    /// iterator un-popped: the loop stalls with its state intact rather than
    /// vanishing, and can be played again.
    static let iteratorPlayDelayed_Behavior =
        BehaviorWithSideEffects(
            .iteratorPlayDelayed,
            takes: [.int, .iterator],
            modifier: { (interpreter, collectedItems) in
                let burial = (collectedItems[0] as! IntItem).value
                var iterator = collectedItems[1] as! IteratorItem
                guard !iterator.isSpent else { return [] }

                let payload = iteratorPass(iterator)
                guard burial >= 0, iterator.hasNextPass else { return payload }

                iterator.burial = burial
                iterator.call = iterator.reconstruction()

                // The continuation is a plain `.iteratorPlay`: it will read the
                // burial now stored on the iterator, and consume no more ints.
                bury(
                    InstructionItem(.iteratorPlay, isContingent: iterator.isContingent),
                    burial,
                    under: payload,
                    in: interpreter
                )
                return [Router(.iterator, iterator.stepped())]
            }
        )

    /// Advance the cursor without emitting anything — skip a pass.
    static let iteratorPopState_Behavior =
        Behavior(
            .iteratorPopState,
            takes: [.iterator],
            fxn: { a in
                let iterator = a[0] as! IteratorItem
                guard !iterator.isSpent, iterator.hasNextPass else { return [] }
                return [Router(.iterator, iterator.stepped())]
            }
        )


    // MARK: - Getters

    /// The getters are non-destructive: they hand back the iterator unchanged —
    /// which is what `Peek` in their names is there to promise.
    ///
    /// Push convention would have them consume it — `.stringFirst` eats its
    /// string — but an iterator is a live loop rather than a value, and a getter
    /// that killed the loop to report its stride would be unusable in the body,
    /// which is exactly where a program wants to ask. `.iteratorPop` is there for
    /// anyone who wants it gone.
    ///
    /// Provenance is **law 1b, extended from CodeItems to iterators**: an item put
    /// into a container and taken back out is the item that went in, so `origin`,
    /// `destination` and `body` come back with their own `call` untouched and
    /// record nothing.
    static func iteratorGetter_Behavior(
        _ name: PushInstruction,
        reading field: @escaping @Sendable (IteratorItem) -> (any Item)?
    ) -> Behavior {
        Behavior(
            name,
            takes: [.iterator],
            fxn: { a in
                let iterator = a[0] as! IteratorItem
                var results = [Router(.iterator, iterator)]
                if let item = field(iterator),
                   let resting = PushStack.defaultStack(for: item) {
                    results.append(Router(resting, item))
                }
                return results
            }
        )
    }

    /// Where the loop started, or the collection it walks. Lands on whatever stack
    /// that item belongs to, so it is `.int` for a counting loop and `.string` or a
    /// vector stack for one walking a collection.
    static let iteratorPeekStart_Behavior =
        iteratorGetter_Behavior(.iteratorPeekStart) { $0.origin }

    /// Where the loop ends. A `.elements` iterator has no end bound of its own —
    /// its end is its source's length — so this emits nothing for one.
    static let iteratorPeekEnd_Behavior =
        iteratorGetter_Behavior(.iteratorPeekEnd) { $0.destination }

    /// The step between passes; `1` for an iterator walking a collection.
    ///
    /// The one getter that records provenance: there is no contained item to hand
    /// back, so the `IntItem` really is produced here, from the iterator, and law 3
    /// applies — argument first, instruction last.
    static let iteratorPeekStride_Behavior =
        iteratorGetter_Behavior(.iteratorPeekStride) { iterator in
            IntItem(
                iterator.stride,
                call: [iterator, InstructionItem(.iteratorPeekStride)],
                isContingent: iterator.isContingent
            )
        }

    /// The block this iterator emits each pass. Lands on `.code` as data — running
    /// it is `.codeDo`'s job.
    static let iteratorPeekBody_Behavior =
        iteratorGetter_Behavior(.iteratorPeekBody) { $0.body }


    // MARK: - Construction

    /// Builds a counting iterator and **leaves it alone**: no pass, no body, no
    /// continuation.
    ///
    /// This exists so `crux()` has something to say. An iterator's `call`
    /// reconstructs it by state — `origin dest stride cursor burial emits (body)`
    /// — and re-running that reconstruction has to produce the iterator, not run
    /// its loop. Anything that ran the body here would make a crux a side effect.
    ///
    /// The body arrives as `( )` for a bodyless iterator, and `init` normalizes an
    /// empty body back to nil, so one constructor serves both a sequence and a
    /// loop rather than needing a second instruction for each.
    ///
    /// Provenance: law 3, the ordinary shape. The arguments are all read off
    /// ordinary stacks, so the record is postfix with the instruction last, which
    /// is what `IteratorItem.reconstruction` writes.
    static let iteratorFromIntRange_Behavior =
        Behavior(
            .iteratorFromIntRange,
            takes: [.int, .int, .int, .int, .int, .bool, .code],
            fxn: { a in
                // `.int` is a stack, so the last argument written is on top:
                // `origin dest stride cursor burial` arrives reversed.
                let (burial, cursor, stride, destination, origin) = (
                    a[0] as! IntItem, a[1] as! IntItem, a[2] as! IntItem,
                    a[3] as! IntItem, a[4] as! IntItem
                )
                let (emits, body) = (a[5] as! BoolItem, a[6] as! CodeItem)

                let iterator = IteratorItem(
                    kind: .counting(stride: stride.value),
                    origin: origin,
                    destination: destination,
                    body: body,
                    emits: emits.value,
                    cursor: cursor.value,
                    burial: burial.value,
                    call: [
                        origin, destination, stride, cursor, burial, emits, body,
                        InstructionItem(.iteratorFromIntRange),
                    ],
                    isContingent: Behavior.netContingency(
                        of: origin, destination, stride, cursor, burial, emits, body
                    )
                )
                return [Router(.iterator, iterator)]
            }
        )


    /// Builds an iterator that **walks** a source — a string's characters, its
    /// letters, its words, or a vector's elements — and leaves it alone.
    ///
    /// One factory for all of them, because they differ only in where the origin
    /// comes from and how the cursor projects: the state is the same shape either
    /// way. No bounds, because a walker's end is its origin's own length.
    ///
    /// `origin cursor burial emits (body)`. The origin lands on its own stack, so
    /// only the two ints share `.int` — `burial` is written last and arrives on
    /// top. An empty body means a sequence rather than a loop (see
    /// `IteratorItem.init`), which is how one constructor serves both.
    static func iteratorWalking_Behavior(
        _ name: PushInstruction,
        over source: PushStack,
        kind: @escaping @Sendable (any Item) -> IteratorKind
    ) -> Behavior {
        Behavior(
            name,
            takes: [source, .int, .int, .bool, .code],
            fxn: { a in
                let origin = a[0]
                let (burial, cursor) = (a[1] as! IntItem, a[2] as! IntItem)
                let (emits, body) = (a[3] as! BoolItem, a[4] as! CodeItem)

                let iterator = IteratorItem(
                    kind: kind(origin),
                    origin: origin,
                    body: body,
                    emits: emits.value,
                    cursor: cursor.value,
                    burial: burial.value,
                    call: [
                        origin, cursor, burial, emits, body,
                        InstructionItem(name),
                    ],
                    isContingent: Behavior.netContingency(
                        of: origin, cursor, burial, emits, body
                    )
                )
                return [Router(.iterator, iterator)]
            }
        )
    }

    static let iteratorFromString_Behavior =
        iteratorWalking_Behavior(.iteratorFromString, over: .string) { _ in
            .elements(into: nil)
        }

    static let iteratorFromStringLetters_Behavior =
        iteratorWalking_Behavior(.iteratorFromStringLetters, over: .string) { _ in
            .letters
        }

    static let iteratorFromStringWords_Behavior =
        iteratorWalking_Behavior(.iteratorFromStringWords, over: .string) { _ in
            .words
        }

    static func iteratorFromVector_Behavior<V: VectorItem>(
        _ name: PushInstruction,
        over itemType: V.Type
    ) -> Behavior {
        iteratorWalking_Behavior(name, over: V.pushStack) { _ in .elements(into: nil) }
    }

    /// Builds an iterator that walks a **code block's contents**, root level only,
    /// and leaves it alone.
    ///
    /// Its own constructor rather than one from the factory above, because both
    /// the origin and the body come off `.code`: the factory's argument positions
    /// only hold when the origin has a stack to itself. `origin ( body )` in
    /// source, so the body is written last and arrives on top.
    ///
    /// `into` is `.exec` for the `IntoExec` variant and derived otherwise. It
    /// cannot be an argument — a `PushStack` is not a Push value — which is why
    /// there are two names.
    static func iteratorFromCode_Behavior(
        _ name: PushInstruction,
        into: PushStack?
    ) -> Behavior {
        Behavior(
            name,
            takes: [.code, .code, .int, .int, .bool],
            fxn: { a in
                let (body, origin) = (a[0] as! CodeItem, a[1] as! CodeItem)
                let (burial, cursor) = (a[2] as! IntItem, a[3] as! IntItem)
                let emits = a[4] as! BoolItem

                let iterator = IteratorItem(
                    kind: .elements(into: into),
                    origin: origin,
                    body: body,
                    emits: emits.value,
                    cursor: cursor.value,
                    burial: burial.value,
                    call: [
                        origin, cursor, burial, emits, body,
                        InstructionItem(name),
                    ],
                    isContingent: Behavior.netContingency(
                        of: origin, cursor, burial, emits, body
                    )
                )
                return [Router(.iterator, iterator)]
            }
        )
    }

    static let iteratorFromCode_Behavior =
        iteratorFromCode_Behavior(.iteratorFromCode, into: nil)
    static let iteratorFromCodeIntoExec_Behavior =
        iteratorFromCode_Behavior(.iteratorFromCodeIntoExec, into: .exec)

    /// Builds an iterator that emits the **same item** over and over, `count`
    /// times, and leaves it alone. This is what the `xDupTimes` family rests on.
    ///
    /// `( item ) count cursor burial`. The item arrives boxed in a code block,
    /// which is the trick that makes **one** constructor serve all thirteen
    /// stacks instead of thirteen: a CodeItem holds any item, and law 1b says
    /// taking it back out gives back the item that went in, `call` and all.
    ///
    /// No body and no `emits` flag: a repeating iterator is always a sequence, and
    /// always emits.
    static func iteratorRepeating_Behavior(
        _ name: PushInstruction,
        into: PushStack?
    ) -> Behavior {
        Behavior(
            name,
            takes: [.code, .int, .int, .int],
            fxn: { a in
                let box = a[0] as! CodeItem
                let (burial, cursor, count) = (
                    a[1] as! IntItem, a[2] as! IntItem, a[3] as! IntItem
                )
                guard let origin = box.value.first else {
                    return [Router(.error, ErrorItem("\(name) needs an item in its block"))]
                }

                let iterator = IteratorItem(
                    kind: .repeating(into: into),
                    origin: origin,
                    destination: count,
                    body: nil,
                    emits: true,
                    cursor: cursor.value,
                    burial: burial.value,
                    call: [
                        box, count, cursor, burial,
                        InstructionItem(name),
                    ],
                    isContingent: Behavior.netContingency(
                        of: box, count, cursor, burial
                    )
                )
                return [Router(.iterator, iterator)]
            }
        )
    }

    static let iteratorRepeating_Behavior =
        iteratorRepeating_Behavior(.iteratorRepeating, into: nil)
    static let iteratorRepeatingIntoExec_Behavior =
        iteratorRepeating_Behavior(.iteratorRepeatingIntoExec, into: .exec)

    static let iteratorFromVecBool_Behavior =
        iteratorFromVector_Behavior(.iteratorFromVecBool, over: VecBoolItem.self)
    static let iteratorFromVecDouble_Behavior =
        iteratorFromVector_Behavior(.iteratorFromVecDouble, over: VecDoubleItem.self)
    static let iteratorFromVecInt_Behavior =
        iteratorFromVector_Behavior(.iteratorFromVecInt, over: VecIntItem.self)
    static let iteratorFromVecString_Behavior =
        iteratorFromVector_Behavior(.iteratorFromVecString, over: VecStringItem.self)


    static let iteratorBehaviors: [PushInstruction: Behavior] =
    [
        .iteratorFromCode : iteratorFromCode_Behavior,
        .iteratorFromCodeIntoExec : iteratorFromCodeIntoExec_Behavior,
        .iteratorRepeating : iteratorRepeating_Behavior,
        .iteratorRepeatingIntoExec : iteratorRepeatingIntoExec_Behavior,
        .iteratorFromString : iteratorFromString_Behavior,
        .iteratorFromStringLetters : iteratorFromStringLetters_Behavior,
        .iteratorFromStringWords : iteratorFromStringWords_Behavior,
        .iteratorFromVecBool : iteratorFromVecBool_Behavior,
        .iteratorFromVecDouble : iteratorFromVecDouble_Behavior,
        .iteratorFromVecInt : iteratorFromVecInt_Behavior,
        .iteratorFromVecString : iteratorFromVecString_Behavior,
        .iteratorPeekBody : iteratorPeekBody_Behavior,
        .iteratorPeekEnd : iteratorPeekEnd_Behavior,
        .iteratorFromIntRange : iteratorFromIntRange_Behavior,
        .iteratorPlay : iteratorPlay_Behavior,
        .iteratorPlayDelayed : iteratorPlayDelayed_Behavior,
        .iteratorPopState : iteratorPopState_Behavior,
        .iteratorPeekStart : iteratorPeekStart_Behavior,
        .iteratorStep : iteratorStep_Behavior,
        .iteratorPeekStride : iteratorPeekStride_Behavior,
    ]
}
