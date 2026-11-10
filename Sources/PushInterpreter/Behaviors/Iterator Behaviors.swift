//
//  Iterator Behaviors.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/16/26.
//

import DequeModule

nonisolated extension Interpreter {

    // MARK: - Stepping

    /// The payload of one pass, as Routers: the projected item (when the iterator
    /// emits one), then — if it has a body — the body and the `.codeDo` that runs
    /// it.
    ///
    /// **The emitted item comes first, wherever it goes.** One that rests on a data
    /// stack is there before the body runs. One that runs (an instruction walked
    /// out of a block, a point unwrapped by `.codeDo`, anything an `…IntoExec`
    /// iterator sends to `.exec`) is placed *above* the body, so it runs first
    /// too: `.exec` ends up top→bottom `item…, body, .codeDo, …`. Routers land in
    /// order, so that means routing it after the body. (Until 2026-11-09 it was
    /// routed first and so ran after the body, against this comment.)
    ///
    /// The body then runs between the payload and whatever continuation the caller
    /// buries below it. That is what lets the body see — or steal — the iterator
    /// resting on `.iterator`.
    ///
    /// **A bodyless iterator emits only its element.** Those are the sequences —
    /// `stringPushAll` and the dup families — which have no mouse to run, and
    /// pushing an empty block for them would cost two wasted steps per element.
    ///
    /// Provenance: the body copy is combinatory (laws 1 and 1b) and the `.codeDo`
    /// token is freshly minted (law 4), so neither records anything. The
    /// projection carries its own record; see `IteratorItem.projection`.
    static func iteratorPass(_ iterator: IteratorItem, recording: ProvenanceRecording) -> [Router] {
        var results = [Router]()
        var runsFirst = [Router]()   // emitted items bound for `.exec`: routed last, so they run first

        if iterator.emits, let projected = iterator.projection(recording: recording) {
            if case .points(.unwrapped) = iterator.kind {
                // Do: the boxed point runs. A block met on `.exec` only rests on
                // `.code` (it does not spill), so `.codeDo` is what unwraps it —
                // the same mechanism `codeDoNthPoint` uses. A leaf's box `( x )`
                // spills to `x`, so leaves behave as `whole` does.
                runsFirst.append(Router(.exec, InstructionItem(.codeDo)))
                runsFirst.append(Router(.exec, projected))
            } else {
                // `?? .exec` because `defaultStack(for:)` answers nil for an
                // InstructionItem — it executes rather than lands. Without the
                // fallback an instruction walked out of a code block would be
                // silently dropped, which is exactly what a points traversal would
                // meet: most leaves of a block ARE instructions. An instruction with
                // no resting place should run, and `.exec` is where running happens.
                let resting = iterator.target
                    ?? PushStack.defaultStack(for: projected)
                    ?? .exec
                if resting == .exec {
                    runsFirst.append(Router(resting, projected))
                } else {
                    results.append(Router(resting, projected))
                }
            }
        }

        if let body = iterator.body {
            let bodyCopy = body
            results.append(Router(.exec, InstructionItem(.codeDo)))
            results.append(Router(.exec, bodyCopy))
        }
        return results + runsFirst
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

        // Saturating: a program can set any burial up to `Int.max`, and a plain `+`
        // would trap the whole process. A depth that large means "at the bottom",
        // which the `min` already says.
        let (depth, overflowed) = payloadDepth.addingReportingOverflow(max(0, burial))
        let target = min(overflowed ? Int.max : depth, interpreter.stacks[.exec]!.count)
        interpreter.insert(token, at: target, on: .exec)
    }

    /// Every iterator that comes to rest on `.iterator` **has something to
    /// emit** — that is the type's invariant, and this is where it is kept.
    ///
    /// A spent iterator is not a thing. A loop's last pass simply does not
    /// re-push, so an exhausted iterator is consumed by its own final act and
    /// never rests; a setter that finishes one destroys it; and a constructor
    /// asked to build one refuses. Nothing anywhere has to ask "is this one still
    /// alive?" before using it.
    ///
    /// **Dying returns the body to `.code`.** An instruction that consumed
    /// something and then finished with it should not also destroy it —
    /// `execDoCount` and `execDoTimes` hand their body back when their count is too
    /// small to act on, and this is the same courtesy at the other end of the loop.
    /// It is not tidiness: `.code` is the language's tightest
    /// bottleneck, so every loop that ends is a small supply of the scarcest
    /// thing there is.
    ///
    /// Only the body, and deliberately. Returning the *bounds* too sounds
    /// symmetrical and is not: `xDupTimes` and `xDupItems` **read** their origin
    /// off the stack without popping it, so handing it back would mint a copy
    /// that was never taken. A body is the one thing every kind genuinely
    /// consumed, from one stack, every time.
    static func iteratorFarewell(_ iterator: IteratorItem) -> [Router] {
        iterator.body.map { [Router(.code, $0)] } ?? []
    }

    /// The last pass, `payload`, and then the farewell: the body goes onto `.exec`
    /// *under* the pass, and lands on `.code` (a block met on `.exec` rests there)
    /// once the pass has run. **After, not with.** Handed straight to `.code`, it
    /// sat on top of `.code` all through the last pass, so a body that reads
    /// `.code` read its own loop's body on that pass and no other: `B` run `K`
    /// times by a loop was not `B` written `K` times. Found 2026-11-07 when a
    /// folded crux (`CruxCompression.folded`) replayed a `.codeNthPoint` chain one
    /// level short.
    static func iteratorFarewell(_ iterator: IteratorItem, after payload: [Router]) -> [Router] {
        guard let body = iterator.body else { return payload }
        return [Router(.exec, body)] + payload
    }

    /// One pass, by hand — no continuation. A program driving a loop itself calls
    /// this as often as it wants a pass.
    static let iteratorStep_Behavior =
        Behavior.control(
            .iteratorStep,
            takes: [.iterator],
            fxn: { a, recording in
                let iterator = a[0] as! IteratorItem
                guard !iterator.isSpent else { return iteratorFarewell(iterator) }

                var results = iteratorPass(iterator, recording: recording)
                if iterator.hasNextPass {
                    results.append(Router(.iterator, iterator.stepped(recording: recording)))
                } else {
                    results = iteratorFarewell(iterator, after: results)
                }
                return results
            }
        )
        .described(
            "Runs one pass by hand, emitting the current item and running the body, and leaves the advanced "
            + "iterator; after the last pass the iterator goes and its body returns to `.code`.")

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
        Behavior.control(.iteratorPlay, takes: [.iterator], tags: [.reEntrant]) { collectedItems, recording in
            let iterator = collectedItems[0] as! IteratorItem
            guard !iterator.isSpent else { return iteratorFarewell(iterator).map { .result($0) } }

            let payload = iteratorPass(iterator, recording: recording)
            guard iterator.hasNextPass else {
                return iteratorFarewell(iterator, after: payload).map { .result($0) }
            }

            return [
                .bury(InstructionItem(.iteratorPlay), depth: iterator.burial, under: payload),
                .result(Router(.iterator, iterator.stepped(recording: recording))),
            ]
        }
        .described(
            "Plays the loop out: each pass emits the current item, runs the body, and queues the next pass at the "
            + "iterator's depth in `.exec`; at the end the body returns to `.code`.")

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
    /// Note a plan is all-or-nothing, so meeting an empty `.int` leaves the
    /// iterator un-popped: the loop stalls with its state intact rather than
    /// vanishing, and can be played again.
    static let iteratorPlayDelayed_Behavior =
        Behavior.control(.iteratorPlayDelayed, takes: [.int, .iterator], tags: [.reEntrant]) { collectedItems, recording in
                let burial = (collectedItems[0] as! IntItem).value
                var iterator = collectedItems[1] as! IteratorItem
                guard !iterator.isSpent else { return iteratorFarewell(iterator).map { .result($0) } }

                let payload = iteratorPass(iterator, recording: recording)
                guard burial >= 0, iterator.hasNextPass else {
                    return iteratorFarewell(iterator, after: payload).map { .result($0) }
                }

                iterator.burial = burial
                // (No `call` here: `stepped` below records the new state anyway.)

                // The continuation is a plain `.iteratorPlay`: it will read the
                // burial now stored on the iterator, and consume no more ints.
                return [
                    .bury(InstructionItem(.iteratorPlay), depth: burial, under: payload),
                    .result(Router(.iterator, iterator.stepped(recording: recording))),
                ]
        }
        .described(
            "Sets the depth, then plays: `n .iteratorPlayDelayed` stores n as the iterator's depth in `.exec` and "
            + "plays as `.iteratorPlay` does; a negative n makes this pass the last.")

    /// Advance the cursor without emitting anything — skip a pass.
    static let iteratorPopState_Behavior =
        Behavior(
            .iteratorPopState,
            takes: [.iterator],
            produces: .alternatives([[.iterator]] + Produces.loopEnds),
            fxn: { a, recording in
                let iterator = a[0] as! IteratorItem
                guard !iterator.isSpent, iterator.hasNextPass else {
                    return iteratorFarewell(iterator)
                }
                return [Router(.iterator, iterator.stepped(recording: recording))]
            }
        )
        .described(
            "Skips a pass, advancing the cursor without emitting or running the body; skipping the last pass ends "
            + "the loop and returns its body to `.code`.")


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
        produces: Produces,
        reading field: @escaping @Sendable (IteratorItem, ProvenanceRecording) -> (any Item)?
    ) -> Behavior {
        Behavior(
            name,
            takes: [.iterator],
            produces: produces,
            fxn: { a, recording in
                let iterator = a[0] as! IteratorItem
                var results = [Router(.iterator, iterator)]
                if let item = field(iterator, recording),
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
        iteratorGetter_Behavior(.iteratorPeekStart, produces: .iteratorAnd(Produces.anyItem)) { iterator, _ in iterator.origin }
        .described(
            "Pushes where the loop starts (the first int of a count, the source of a walk, or the repeated item) "
            + "onto its stack, leaving the iterator.")

    /// Where the loop ends. A `.elements` iterator has no end bound of its own —
    /// its end is its source's length — so this emits nothing for one.
    static let iteratorPeekEnd_Behavior =
        iteratorGetter_Behavior(.iteratorPeekEnd, produces: .iteratorAnd([.int])) { iterator, _ in iterator.destination }
        .described(
            "Pushes the loop's end bound (the count, for a repeating iterator), leaving the iterator; pushes "
            + "nothing for an iterator that walks a source.")

    /// The step between passes; `1` for an iterator walking a collection.
    ///
    /// The one getter that records provenance: there is no contained item to hand
    /// back, so the `IntItem` really is produced here, from the iterator, and law 3
    /// applies — argument first, instruction last.
    ///
    /// It records through `reading` because the getter hands its iterator back: a
    /// bare `«iter» .iteratorPeekStride` reproduces the stride *and* leaves the
    /// iterator on `.iterator`, which a same-stack sibling would then read. The
    /// crux pops it, so the fragment leaves only the fact.
    static let iteratorPeekStride_Behavior =
        iteratorGetter_Behavior(.iteratorPeekStride, produces: .results([.iterator, .int])) { iterator, recording in
            IntItem(
                iterator.stride,
                call: recording(Behavior.reading(
                    [.iterator: 1],
                    producing: .int,
                    from: [iterator, InstructionItem(.iteratorPeekStride)])))
        }
        .described("Pushes the step between passes, 1 for any but a counting iterator, leaving the iterator.")

    /// The block this iterator emits each pass. Lands on `.code` as data — running
    /// it is `.codeDo`'s job.
    static let iteratorPeekBody_Behavior =
        iteratorGetter_Behavior(.iteratorPeekBody, produces: .iteratorAnd([.code])) { iterator, _ in iterator.body }
        .described(
            "Pushes a copy of the body onto `.code` without running it, leaving the iterator; pushes nothing for a "
            + "bodyless iterator.")

    /// How many times this iterator goes round its source — `1` for anything that
    /// does not cycle, which is most iterators and every counting one.
    ///
    /// Records like `.iteratorPeekStride`, and for the same reason: there is no
    /// contained item to hand back, so the `IntItem` really is produced here and
    /// law 3 applies — including the `reading` cleanup that pops the iterator the
    /// getter hands back.
    static let iteratorPeekLaps_Behavior =
        iteratorGetter_Behavior(.iteratorPeekLaps, produces: .results([.iterator, .int])) { iterator, recording in
            IntItem(
                iterator.laps,
                call: recording(Behavior.reading(
                    [.iterator: 1],
                    producing: .int,
                    from: [iterator, InstructionItem(.iteratorPeekLaps)])))
        }
        .described(
            "Pushes how many times the iterator goes round its source, 1 for one that does not cycle, leaving the "
            + "iterator.")


    // MARK: - Setters

    /// Re-aim one field of a live iterator.
    ///
    /// These are **not** `Peek`: they consume their new value and hand the
    /// iterator back changed. The narrow Peek exception was always expected to
    /// widen; this is the widening, and it is narrow in the other direction —
    /// only the iterator survives, and only because re-aiming a loop you cannot
    /// keep would be pointless.
    ///
    /// **If the change finishes the loop, the iterator is destroyed.** There is no
    /// third state: a spent iterator is not a thing, and every other path in the
    /// language already drops one rather than hand back something with nothing
    /// left to emit. That covers more than it looks — carrying the counter past
    /// the end, handing a counting iterator a string to count from (its
    /// projection stops computing), or setting a negative depth.
    ///
    /// Provenance: a re-aimed iterator is a genuinely new value, and records the
    /// same way a stepped one does — by state, via its constructor. O(1), like
    /// everything else here.
    static func iteratorSetter_Behavior(
        _ name: PushInstruction,
        takes source: PushStack,
        setting: @escaping @Sendable (inout IteratorItem, any Item) -> String?
    ) -> Behavior {
        Behavior(
            name,
            takes: [source, .iterator],
            // Every setter can refuse the value it was handed — `iteratorSetEnd`
            // on a walking iterator has no end to set — so the whole family is
            // fallible, tagged once here.
            tags: [.fallible],
            produces: .alternatives([[.iterator]] + Produces.loopEnds),
            fxn: { a, recording in
                var iterator = a[1] as! IteratorItem

                // A refusal hands the iterator back untouched and says why: the
                // program asked for something this kind of loop does not have.
                if let complaint = setting(&iterator, a[0]) {
                    return [
                        Router(.iterator, iterator),
                        Router(.error, ErrorItem(complaint).observed(by: name, recording)),
                    ]
                }
                // Nothing left to emit, so the loop is over — and hands its body
                // back on the way out, like any other ending.
                guard !iterator.isSpent, iterator.burial >= 0 else {
                    return iteratorFarewell(iterator)
                }

                iterator.call = recording(iterator.reconstruction())
                return iteratorBuilt(iterator, by: name, recording)
            }
        )
    }

    /// Rewind a loop to its start. Cursor to 0; start, end, stride and body
    /// untouched.
    ///
    /// Reachable only from inside a body, since a spent iterator does not exist to
    /// be restarted — so a body that restarts its own loop is a `while true`,
    /// bounded by `stepLimit`. Put a guard in front of it (`.execIf`, `.execWhen`)
    /// and it is a do-while, built from pieces that already exist.
    static let iteratorRestart_Behavior =
        Behavior(
            .iteratorRestart,
            takes: [.iterator],
            tags: [.fallible],
            produces: .results([.iterator]),
            fxn: { a, recording in
                var iterator = a[0] as! IteratorItem
                iterator.value = 0
                // A loop can always run its first pass — an iterator with nothing
                // to emit at cursor 0 could never have been built.
                iterator.call = recording(iterator.reconstruction())
                return iteratorBuilt(iterator, by: .iteratorRestart, recording)
            }
        )
        .described(
            "Rewinds the cursor to the first pass of the first lap, keeping the start, end, stride, laps, depth and "
            + "body; refuses if that leaves nothing to emit.")

    /// Every constructor's last act, and the other half of the invariant that
    /// `iteratorFarewell` keeps: **an iterator that comes to rest has something to
    /// emit.**
    ///
    /// Constructors are the one door a spent iterator could walk in through — a
    /// cursor past the end, a start of the wrong type — because they take their
    /// state verbatim rather than deriving it. Refuse, and the invariant is exact
    /// everywhere: nothing has to ask whether a resting iterator is still alive.
    ///
    /// Nothing is lost by refusing. A spent iterator cannot exist, so no crux ever
    /// needs to reproduce one.
    ///
    /// The refusal is recorded as observed by the constructor (a stand-in), like
    /// every other refusal: its crux replays the error and names its cause.
    static func iteratorBuilt(
        _ iterator: IteratorItem, by name: PushInstruction, _ recording: ProvenanceRecording
    ) -> [Router] {
        guard !iterator.isSpent else {
            return [Router(.error, ErrorItem("\(iterator.pretty()) has nothing to emit").observed(by: name, recording))]
        }
        return [Router(.iterator, iterator)]
    }

    /// The item a boxed setter argument carries, or nil for an empty block.
    ///
    /// `origin` and `destination` can be any type at all — an int for a counting
    /// loop, a vector or a string for a walking one — but `takes:` is declared
    /// statically and cannot ask the iterator what it wants. So the new value
    /// arrives boxed in a code block, the same universal channel
    /// `.iteratorRepeating` uses, and law 1b hands back exactly what went in.
    static func unboxed(_ item: any Item) -> (any Item)? {
        (item.exactly(CodeItem.self))?.value.first
    }

    /// Where the loop counts from, or the collection it walks. `( 5 ) …`
    ///
    /// A type the kind cannot use is not refused — it simply leaves the loop with
    /// nothing to emit, and the iterator goes. Handing a counting iterator a
    /// string is a way to stop it.
    static let iteratorSetStart_Behavior =
        iteratorSetter_Behavior(.iteratorSetStart, takes: .code) { iterator, boxed in
            guard let item = unboxed(boxed) else {
                return "iteratorSetStart needs an item in its block"
            }
            iterator.origin = item
            return nil
        }
        .described(
            "Re-aims the start: `( x ) .iteratorSetStart` makes x the start or source; refuses an empty block; a "
            + "start leaving nothing to emit ends the loop, returning its body to `.code`.")

    /// Where the loop ends. `( 20 ) …`
    ///
    /// Refused for a walking iterator, whose end is its source's own length and is
    /// not a field at all — storing one would be a lie its crux could not carry.
    static let iteratorSetEnd_Behavior =
        iteratorSetter_Behavior(.iteratorSetEnd, takes: .code) { iterator, boxed in
            switch iterator.kind {
            case .counting, .repeating: break
            default:
                return "iteratorSetEnd: a walking iterator's end is its source's length"
            }
            guard let item = unboxed(boxed) else {
                return "iteratorSetEnd needs an item in its block"
            }
            iterator.destination = item
            return nil
        }
        .described(
            "Re-aims the end: `( x ) .iteratorSetEnd` makes x the end bound; refuses an empty block or a walking "
            + "iterator; an end leaving nothing to emit ends the loop, returning its body to `.code`.")

    /// How far along the loop is. Carrying it past the end finishes it.
    static let iteratorSetCounter_Behavior =
        iteratorSetter_Behavior(.iteratorSetCounter, takes: .int) { iterator, n in
            iterator.value = (n as! IntItem).value
            return nil
        }
        .described(
            "Moves the cursor: `n .iteratorSetCounter` makes n the passes taken; a cursor below 0 or past the end "
            + "ends the loop, returning its body to `.code`.")

    /// How deep in `.exec` the loop hides its next copy — the field
    /// `.iteratorPlayDelayed` sets once. This is the "separate instruction" that
    /// lets an algorithm re-aim it mid-loop without paying an argument per pass.
    ///
    /// A negative depth ends the loop, exactly as it does at
    /// `.iteratorPlayDelayed`: that is the only other place a negative depth can
    /// appear, and it means the same thing in both.
    static let iteratorSetDepth_Behavior =
        iteratorSetter_Behavior(.iteratorSetDepth, takes: .int) { iterator, n in
            iterator.burial = (n as! IntItem).value
            return nil
        }
        .described(
            "Sets how deep in `.exec` each pass queues the next: `n .iteratorSetDepth`; a negative n ends the loop, "
            + "returning its body to `.code`.")

    /// How many times the loop goes round its source. `3 …` walks it three times.
    ///
    /// Refused for the kinds that were *told* how far to go — theirs is in
    /// `destination`, and a second number for the same thing is a lie the crux
    /// would have to carry.
    ///
    /// Zero or fewer laps leaves nothing to emit, so the iterator dies, exactly as
    /// a negative depth or an over-carried counter does. Nothing special is done
    /// about it here; `isSpent` simply agrees, and the setter family already knows
    /// what to do with a loop that is over.
    static let iteratorSetLaps_Behavior =
        iteratorSetter_Behavior(.iteratorSetLaps, takes: .int) { iterator, n in
            guard iterator.kind.cycles else {
                return "iteratorSetLaps: a counting or repeating loop's length is its destination"
            }
            iterator.laps = (n as! IntItem).value
            return nil
        }
        .described(
            "Sets how many times a walk goes round its source: `n .iteratorSetLaps`; refuses a counting or "
            + "repeating iterator; n < 1 ends the loop, returning its body to `.code`.")


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
            // Measured to starve close to 100% of the time in random
            // programs — ~7 arguments is more than a genome reliably assembles. Still
            // correct, and still what a hand-built crux uses; just dead weight in a
            // draw. Tagged in the factory so the whole family moves together.
            tags: [.cruxOnly, .fallible],
            produces: .results([.iterator]),
            fxn: { a, recording in
                // `.int` is a stack, so the last argument written is on top:
                // `origin dest stride cursor burial` arrives reversed.
                let (burial, cursor, stride, destination, origin) = (
                    a[0] as! IntItem, a[1] as! IntItem, a[2] as! IntItem,
                    a[3] as! IntItem, a[4] as! IntItem
                )
                let (emits, body) = (a[5] as! BoolItem, a[6] as! CodeItem)

                // A counter that never moves never arrives: with stride 0 the value
                // stays at `origin` forever, and `.codeFromIterator` once collected one until the process ran
                // out of memory. `execDoRange` can never build one (it steps by ±1),
                // so this constructor is the only door, and it stays shut.
                // An explicit error result, as `.intQuot` gives for a zero divisor:
                // the arguments are consumed and the refusal records them.
                guard stride.value != 0 else {
                    return [
                        Router(
                            .error,
                            ErrorItem(
                                "Zero stride .iteratorFromIntRange: \(origin.value) to \(destination.value) by 0",
                                call: recording([
                                    origin, destination, stride, cursor, burial, emits, body,
                                    InstructionItem(.iteratorFromIntRange)
                                ]))
                        )
                    ]
                }

                let iterator = IteratorItem(
                    kind: .counting(stride: stride.value),
                    origin: origin,
                    destination: destination,
                    body: body,
                    emits: emits.value,
                    cursor: cursor.value,
                    burial: burial.value,
                    call: recording([
                        origin, destination, stride, cursor, burial, emits, body,
                        InstructionItem(.iteratorFromIntRange),
                    ]))
                return iteratorBuilt(iterator, by: .iteratorFromIntRange, recording)
            }
        )
        .described(
            "Builds an unplayed counting iterator: `a b s i d e ( body )` counts from a toward b by step s, "
            + "stopping short of b (one pass when a = b), from pass i at depth d, emitting if e; refuses s = 0 or "
            + "nothing to emit.")


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
            // Measured to starve close to 100% of the time in random
            // programs — ~7 arguments is more than a genome reliably assembles. Still
            // correct, and still what a hand-built crux uses; just dead weight in a
            // draw. Tagged in the factory so the whole family moves together.
            // `.fallible`: `iteratorBuilt` refuses an iterator with nothing to emit.
            tags: [.cruxOnly, .fallible],
            produces: .results([.iterator]),
            fxn: { a, recording in
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
                    call: recording([
                        origin, cursor, burial, emits, body,
                        InstructionItem(name),
                    ]))
                return iteratorBuilt(iterator, by: name, recording)
            }
        )
    }

    static let iteratorFromString_Behavior =
        iteratorWalking_Behavior(.iteratorFromString, over: .string) { _ in
            .elements(into: nil)
        }
        .described(
            "Builds an unplayed iterator over a string's chars: `s i d e ( body )` starts at pass i at depth d, "
            + "emitting if e; an empty body makes a bare sequence; refuses if nothing is left to emit.")

    static let iteratorFromStringLetters_Behavior =
        iteratorWalking_Behavior(.iteratorFromStringLetters, over: .string) { _ in
            .letters
        }
        .described(
            "Builds an unplayed iterator over a string's chars, each as a one-char string: `s i d e ( body )` "
            + "starts at pass i at depth d, emitting if e; refuses if nothing is left to emit.")

    static let iteratorFromStringWords_Behavior =
        iteratorWalking_Behavior(.iteratorFromStringWords, over: .string) { _ in
            .words
        }
        .described(
            "Builds an unplayed iterator over a string's whitespace-separated words: `s i d e ( body )` starts at "
            + "pass i at depth d, emitting if e; refuses if nothing is left to emit.")

    static func iteratorFromVector_Behavior<V: VectorItem>(
        _ name: PushInstruction,
        over itemType: V.Type
    ) -> Behavior {
        iteratorWalking_Behavior(name, over: V.pushStack) { _ in .elements(into: nil) }
            .described(
                "Builds an unplayed iterator over a \(V.pushStack.noun)'s elements: `v i d e ( body )` starts at "
                + "pass i at depth d, emitting if e; an empty body makes a bare sequence; refuses if nothing is "
                + "left to emit.")
    }

    /// **The short constructors**: an iterator over
    /// a whole collection from the collection and a body alone, `v ( body )`,
    /// with the cursor at the start, nothing buried and every element emitted.
    /// Two arguments, as `vecXIterate` takes, so a random program can actually
    /// build one; the long forms above (`.cruxOnly`) set the rest. An empty body
    /// makes a sequence. `iteratorPlay` then runs the body per element, and
    /// `vecFromIterator` collects what it makes.
    static func iteratorOver_Behavior(_ name: PushInstruction, over source: PushStack) -> Behavior {
        Behavior(
            name,
            takes: [source, .code],
            tags: [.fallible],
            produces: .results([.iterator]),
            fxn: { a, recording in
                // A code source shares `.code` with the body, which is written last
                // and so arrives first.
                let (origin, body) = source == .code
                    ? (a[1], a[0] as! CodeItem)
                    : (a[0], a[1] as! CodeItem)
                let iterator = IteratorItem(
                    kind: .elements(into: nil),
                    origin: origin,
                    body: body,
                    emits: true,
                    cursor: 0,
                    burial: 0,
                    call: recording([origin, body, InstructionItem(name)]))
                return iteratorBuilt(iterator, by: name, recording)
            }
        )
        .described(
            "Builds an iterator over a \(source.noun)'s "
            + (source == .string ? "chars" : source == .code ? "top-level items" : "elements")
            + (source == .code ? " and a body, written `( x ) ( body )`," : " and a body,")
            + " ready to play from the first, emitting each; an empty body makes a bare sequence; refuses an "
            + "empty \(source.noun).")
    }

    static let iteratorOverString_Behavior = iteratorOver_Behavior(.iteratorOverString, over: .string)
    static let iteratorOverVecBool_Behavior = iteratorOver_Behavior(.iteratorOverVecBool, over: .vecBool)
    static let iteratorOverVecInt_Behavior = iteratorOver_Behavior(.iteratorOverVecInt, over: .vecInt)
    static let iteratorOverVecDouble_Behavior = iteratorOver_Behavior(.iteratorOverVecDouble, over: .vecDouble)
    static let iteratorOverVecString_Behavior = iteratorOver_Behavior(.iteratorOverVecString, over: .vecString)
    static let iteratorOverCode_Behavior = iteratorOver_Behavior(.iteratorOverCode, over: .code)

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
            // Measured to starve close to 100% of the time in random
            // programs — ~7 arguments is more than a genome reliably assembles. Still
            // correct, and still what a hand-built crux uses; just dead weight in a
            // draw. Tagged in the factory so the whole family moves together.
            // `.fallible`: `iteratorBuilt` refuses an iterator with nothing to emit.
            tags: [.cruxOnly, .fallible],
            produces: .results([.iterator]),
            fxn: { a, recording in
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
                    call: recording([
                        origin, cursor, burial, emits, body,
                        InstructionItem(name),
                    ]))
                return iteratorBuilt(iterator, by: name, recording)
            }
        )
        .described(
            "Builds an unplayed iterator over a block's top-level items: `( x ) ( body ) i d e` starts at pass i at "
            + "depth d, emitting if e"
            + (into == .exec
                ? ", each sent to `.exec` to run before the body"
                : ", each landing on its stack (instructions run)")
            + "; refuses if nothing is left to emit.")
    }

    static let iteratorFromCode_Behavior =
        iteratorFromCode_Behavior(.iteratorFromCode, into: nil)
    static let iteratorFromCodeIntoExec_Behavior =
        iteratorFromCode_Behavior(.iteratorFromCodeIntoExec, into: .exec)

    /// Construct-only: rebuild a **points** iterator by state. Same shape as
    /// `iteratorFromCode`, but the walk is pre-order over the whole tree, not the
    /// root — so `crux()` for a points iterator names this. One per `PointsEmission`
    /// mode, because the mode is part of the iterator's identity and a rebuilt copy
    /// must carry it.
    static func iteratorFromCodePoints_Behavior(_ instruction: PushInstruction, _ mode: PointsEmission) -> Behavior {
        Behavior(
            instruction,
            takes: [.code, .code, .int, .int, .bool],
            // Measured to starve close to 100% of the time in random
            // programs — ~7 arguments is more than a genome reliably assembles. Still
            // correct, and still what a hand-built crux uses; just dead weight in a
            // draw. Tagged in the factory so the whole family moves together.
            // `.fallible`: `iteratorBuilt` refuses an iterator with nothing to emit.
            tags: [.cruxOnly, .fallible],
            produces: .results([.iterator]),
            fxn: { a, recording in
                let (body, origin) = (a[0] as! CodeItem, a[1] as! CodeItem)
                let (burial, cursor) = (a[2] as! IntItem, a[3] as! IntItem)
                let emits = a[4] as! BoolItem
                let iterator = IteratorItem(
                    kind: .points(mode),
                    origin: origin,
                    body: body,
                    emits: emits.value,
                    cursor: cursor.value,
                    burial: burial.value,
                    call: recording([origin, cursor, burial, emits, body, InstructionItem(instruction)]))
                return iteratorBuilt(iterator, by: instruction, recording)
            }
        )
        .described(
            "Builds an unplayed iterator over every point of a block, pre-order from the whole block: "
            + "`( x ) ( body ) i d e` starts at pass i at depth d, emitting if e, each point "
            + (mode == .boxed ? "boxed onto `.code`" : mode == .whole ? "routed as it is" : "run, before the body")
            + "; refuses if nothing is left to emit.")
    }

    static let iteratorFromCodePoints_Behavior =
        iteratorFromCodePoints_Behavior(.iteratorFromCodePoints, .boxed)
    static let iteratorFromCodeEmitPoints_Behavior =
        iteratorFromCodePoints_Behavior(.iteratorFromCodeEmitPoints, .whole)
    static let iteratorFromCodeDoPoints_Behavior =
        iteratorFromCodePoints_Behavior(.iteratorFromCodeDoPoints, .unwrapped)

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
            // `.fallible` too: it refuses an empty block.
            // Measured to starve close to 100% of the time in random
            // programs — ~7 arguments is more than a genome reliably assembles. Still
            // correct, and still what a hand-built crux uses; just dead weight in a
            // draw. Tagged in the factory so the whole family moves together.
            tags: [.cruxOnly, .fallible],
            produces: .results([.iterator]),
            fxn: { a, recording in
                let box = a[0] as! CodeItem
                let (burial, cursor, count) = (
                    a[1] as! IntItem, a[2] as! IntItem, a[3] as! IntItem
                )
                guard let origin = box.value.first else {
                    return [Router(.error, ErrorItem("\(name) needs an item in its block")
                        .observed(by: name, recording))]
                }

                let iterator = IteratorItem(
                    kind: .repeating(into: into),
                    origin: origin,
                    destination: count,
                    body: nil,
                    emits: true,
                    cursor: cursor.value,
                    burial: burial.value,
                    call: recording([
                        box, count, cursor, burial,
                        InstructionItem(name),
                    ]))
                return iteratorBuilt(iterator, by: name, recording)
            }
        )
        .described(
            "Builds an unplayed iterator that emits x n times: `( x ) n i d` starts at pass i at depth d, each copy "
            + (into == .exec ? "sent to `.exec`" : "landing on its stack")
            + "; refuses an empty block or nothing left to emit.")
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
        .iteratorFromCodePoints : iteratorFromCodePoints_Behavior,
        .iteratorFromCodeEmitPoints : iteratorFromCodeEmitPoints_Behavior,
        .iteratorFromCodeDoPoints : iteratorFromCodeDoPoints_Behavior,
        .iteratorRepeating : iteratorRepeating_Behavior,
        .iteratorRepeatingIntoExec : iteratorRepeatingIntoExec_Behavior,
        .iteratorFromString : iteratorFromString_Behavior,
        .iteratorFromStringLetters : iteratorFromStringLetters_Behavior,
        .iteratorFromStringWords : iteratorFromStringWords_Behavior,
        .iteratorFromVecBool : iteratorFromVecBool_Behavior,
        .iteratorFromVecDouble : iteratorFromVecDouble_Behavior,
        .iteratorFromVecInt : iteratorFromVecInt_Behavior,
        .iteratorOverString : iteratorOverString_Behavior,
        .iteratorOverVecBool : iteratorOverVecBool_Behavior,
        .iteratorOverVecInt : iteratorOverVecInt_Behavior,
        .iteratorOverVecDouble : iteratorOverVecDouble_Behavior,
        .iteratorOverVecString : iteratorOverVecString_Behavior,
        .iteratorOverCode : iteratorOverCode_Behavior,
        .iteratorFromVecString : iteratorFromVecString_Behavior,
        .iteratorPeekBody : iteratorPeekBody_Behavior,
        .iteratorPeekLaps : iteratorPeekLaps_Behavior,
        .iteratorRestart : iteratorRestart_Behavior,
        .iteratorSetStart : iteratorSetStart_Behavior,
        .iteratorSetEnd : iteratorSetEnd_Behavior,
        .iteratorSetCounter : iteratorSetCounter_Behavior,
        .iteratorSetDepth : iteratorSetDepth_Behavior,
        .iteratorSetLaps : iteratorSetLaps_Behavior,
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
