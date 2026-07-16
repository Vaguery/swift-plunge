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
    /// emits one), then the body and the `.codeDo` that runs it.
    ///
    /// `.exec` ends up top→bottom `body, .codeDo, …`, so the body runs *between*
    /// the payload and whatever continuation the caller appends. That is what lets
    /// the body see — or steal — the iterator resting on `.iterator`.
    ///
    /// Provenance: the body copy is combinatory (laws 1 and 1b) and the `.codeDo`
    /// token is freshly minted (law 4), so neither records anything. The
    /// projection carries its own record; see `IteratorItem.projection`.
    static func iteratorPass(_ iterator: IteratorItem) -> [Router] {
        var results = [Router]()

        if iterator.emits, let projected = iterator.projection(),
           let resting = PushStack.defaultStack(for: projected) {
            results.append(Router(resting, projected))
        }

        var bodyCopy = iterator.body
        bodyCopy.isContingent = Behavior.netContingency(of: iterator, iterator.body)

        results.append(Router(.exec, InstructionItem(.codeDo)))
        results.append(Router(.exec, bodyCopy))
        return results
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

    /// One pass, plus its own next copy just below the payload — the ordinary
    /// loop, and what the `exec` looping instructions emit.
    ///
    /// On the last pass neither the iterator nor the continuation is emitted, so a
    /// loop never leaves a token behind to fire against an empty stack. A dangling
    /// `.iteratorPlay` can only arise if the body itself removed the iterator, and
    /// then "missing args" on `.error` is the honest answer.
    static let iteratorPlay_Behavior =
        Behavior(
            .iteratorPlay,
            takes: [.iterator],
            fxn: { a in
                let iterator = a[0] as! IteratorItem
                guard !iterator.isSpent else { return [] }

                var results = [Router]()
                if iterator.hasNextPass {
                    // Prepended first, so it lands *under* the payload: the body
                    // runs, then the loop comes back round.
                    results.append(
                        Router(
                            .exec,
                            InstructionItem(
                                .iteratorPlay,
                                isContingent: iterator.isContingent
                            )
                        )
                    )
                    results.append(Router(.iterator, iterator.stepped()))
                }
                results.append(contentsOf: iteratorPass(iterator))
                return results
            }
        )

    /// One pass, then the loop's next copy is **inserted `delay` items deep** in
    /// `.exec` rather than sitting directly under the payload — shoved, without
    /// the Push code a shove would need.
    ///
    /// The delay is popped fresh every pass, so the schedule can change as the
    /// loop runs, and a loop can interleave itself with whatever else is pending.
    ///
    /// - `delay < 0` — no continuation: the loop ends here, short of exhaustion.
    /// - `delay == 0` — exactly where `.iteratorPlay` puts it, just below the payload.
    /// - `delay > 0` — that many items further down, clamped to the depth of
    ///   `.exec` like the `Shove`/`Yank` combinators clamp.
    ///
    /// Note `gather` is all-or-nothing, so meeting an empty `.int` leaves the
    /// iterator un-popped: the loop stalls with its state intact rather than
    /// vanishing, and can be played again.
    static let iteratorPlayDelayed_Behavior =
        BehaviorWithSideEffects(
            .iteratorPlayDelayed,
            takes: [.int, .iterator],
            modifier: { (interpreter, collectedItems) in
                let delay = (collectedItems[0] as! IntItem).value
                let iterator = collectedItems[1] as! IteratorItem
                guard !iterator.isSpent else { return [] }

                let payload = iteratorPass(iterator)

                guard delay >= 0, iterator.hasNextPass else { return payload }

                // The payload has to be in place before the continuation can be
                // measured against it: `delay` counts from just below the payload,
                // so delay 0 is `.iteratorPlay`'s placement exactly.
                let before = interpreter.stacks[.exec]!.count
                for router in payload {
                    interpreter.push(router.item, to: router.stack)
                }
                let payloadDepth = interpreter.stacks[.exec]!.count - before

                let target = min(
                    payloadDepth + delay,
                    interpreter.stacks[.exec]!.count
                )
                interpreter.stacks[.exec]!.insert(
                    InstructionItem(
                        .iteratorPlayDelayed,
                        isContingent: iterator.isContingent
                    ),
                    at: target
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
    /// reconstructs it by state — `origin dest stride cursor emits (body)` — and
    /// re-running that reconstruction has to produce the iterator, not run its
    /// loop. Anything that ran the body here would make a crux a side effect.
    ///
    /// Provenance: law 3, the ordinary shape. The arguments are all read off
    /// ordinary stacks, so the record is postfix with the instruction last, which
    /// is what `IteratorItem.reconstruction` writes.
    static let iteratorFromIntRange_Behavior =
        Behavior(
            .iteratorFromIntRange,
            takes: [.int, .int, .int, .int, .bool, .code],
            fxn: { a in
                // `.int` is a stack, so the last argument written is on top:
                // `origin dest stride cursor` arrives reversed.
                let (cursor, stride, destination, origin) = (
                    a[0] as! IntItem, a[1] as! IntItem, a[2] as! IntItem, a[3] as! IntItem
                )
                let (emits, body) = (a[4] as! BoolItem, a[5] as! CodeItem)

                let iterator = IteratorItem(
                    kind: .counting(stride: stride.value),
                    origin: origin,
                    destination: destination,
                    body: body,
                    emits: emits.value,
                    cursor: cursor.value,
                    call: [
                        origin, destination, stride, cursor, emits, body,
                        InstructionItem(.iteratorFromIntRange),
                    ],
                    isContingent: Behavior.netContingency(
                        of: origin, destination, stride, cursor, emits, body
                    )
                )
                return [Router(.iterator, iterator)]
            }
        )


    static let iteratorBehaviors: [PushInstruction: Behavior] =
    [
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
