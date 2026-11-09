//
//  Iterator Behavior Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/16/26.
//
//  `IteratorItem` as a first-class type: stepping it, playing it, reading it,
//  and rebuilding it. The point of the type is that a loop's state is its own —
//  so most of these tests are about what does NOT appear on `.int`.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct IteratorBehaviorTests {

    /// `0 → 5` by 1, emitting its index, with a body that pushes one `true`.
    /// Pass `body: nil` for a sequence rather than a loop.
    func counting(
        from origin: Int = 0,
        to destination: Int = 5,
        by stride: Int = 1,
        emits: Bool = true,
        cursor: Int = 0,
        burial: Int = 0,
        body: CodeItem? = CodeItem([BoolItem(true)])
    ) -> IteratorItem {
        IteratorItem(
            kind: .counting(stride: stride),
            origin: IntItem(origin),
            destination: IntItem(destination),
            body: body,
            emits: emits,
            cursor: cursor,
            burial: burial
        )
    }

    func loaded(_ iterator: IteratorItem, exec: [any Item] = []) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.iterator]!.prepend(iterator)
        inty.stacks[.exec] = Deque(exec)
        return inty
    }


    // MARK: - Stepping

    @Test func `iteratorStep runs one pass and does not continue`() {
        let inty = loaded(counting())
        doThis(.iteratorStep, to: inty)

        // The payload, and nothing that would bring the loop back round.
        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        // The iterator advanced and is waiting to be stepped again by hand.
        #expect(stackString(inty, .iterator) == "[ «0→5 by 1 @1 ( true )» ]")
    }

    @Test func `iteratorStep on the last pass consumes the iterator`() {
        // 4 is within one stride of the destination, so this is the final pass.
        let inty = loaded(counting(cursor: 4))
        doThis(.iteratorStep, to: inty)

        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    @Test func `a silent iterator emits no index`() {
        let inty = loaded(counting(emits: false))
        doThis(.iteratorStep, to: inty)

        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `iteratorPopState advances without emitting anything`() {
        let inty = loaded(counting())
        doThis(.iteratorPopState, to: inty)

        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ «0→5 by 1 @1 ( true )» ]")
    }

    @Test func `iteratorPlay puts its next copy under the payload`() {
        let inty = loaded(counting())
        doThis(.iteratorPlay, to: inty)

        // The body runs BETWEEN the payload and the continuation, which is what
        // lets it see the iterator resting on `.iterator`.
        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo .iteratorPlay ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .iterator) == "[ «0→5 by 1 @1 ( true )» ]")
    }

    @Test func `a played loop runs to exhaustion and cleans up after itself`() {
        let inty = loaded(counting(), exec: [InstructionItem(.iteratorPlay)])
        inty.run(stepLimit: 10_000)

        // 0,1,2,3,4 — the destination is excluded (see `hasNextPass`).
        #expect(stackString(inty, .int) == "[ 4 3 2 1 0 ]")
        #expect(inty.stacks[.bool]!.count == 5)
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(inty.stacks[.error]!.isEmpty)
    }

    @Test func `a descending iterator counts down`() {
        let inty = loaded(
            counting(from: 9, to: 4, by: -1),
            exec: [InstructionItem(.iteratorPlay)]
        )
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .int) == "[ 5 6 7 8 9 ]")
    }

    /// Stride is the one thing the `exec` looping instructions cannot reach —
    /// they always build ±1 — but the type carries it, and this is what it does.
    @Test func `a strided iterator steps by more than one`() {
        let inty = loaded(
            counting(from: 0, to: 10, by: 3),
            exec: [InstructionItem(.iteratorPlay)]
        )
        inty.run(stepLimit: 10_000)
        // 9 is within a stride of 10, so it is the last pass.
        #expect(stackString(inty, .int) == "[ 9 6 3 0 ]")
    }


    // MARK: - The delayed loop

    @Test func `iteratorPlayDelayed at zero matches iteratorPlay exactly`() {
        let delayed = loaded(counting())
        delayed.stacks[.int]!.prepend(IntItem(0))
        doThis(.iteratorPlayDelayed, to: delayed)

        // The continuation is a plain `.iteratorPlay`: the burial is on the
        // iterator now, so nothing needs to re-read it.
        #expect(stackString(delayed, .exec) == "[ ( true ) .codeDo .iteratorPlay ]")
        #expect(stackString(delayed, .int) == "[ 0 ]")
        #expect(stackString(delayed, .iterator) == "[ «0→5 by 1 @1 ( true )» ]")
    }

    @Test func `iteratorPlayDelayed shoves its next copy that far down exec`() {
        let inty = loaded(
            counting(),
            exec: [IntItem(91), IntItem(92), IntItem(93)]
        )
        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.iteratorPlayDelayed, to: inty)

        // Two pending items get to run before the loop comes back round: the
        // payload is on top, then 91 and 92, and only then the continuation.
        #expect(
            stackString(inty, .exec)
                == "[ ( true ) .codeDo 91 92 .iteratorPlay 93 ]"
        )
        // …and the depth is now the iterator's own, shown by `⤓`.
        #expect(stackString(inty, .iterator) == "[ «0→5 by 1 @1 ⤓2 ( true )» ]")
    }

    @Test func `iteratorPlayDelayed clamps a delay past the bottom of exec`() {
        let inty = loaded(counting(), exec: [IntItem(91)])
        inty.stacks[.int]!.prepend(IntItem(9_999))
        doThis(.iteratorPlayDelayed, to: inty)

        // Everything pending runs first; the loop resumes last.
        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo 91 .iteratorPlay ]")
    }

    @Test func `a negative delay ends the loop early`() {
        let inty = loaded(counting())
        inty.stacks[.int]!.prepend(IntItem(-1))
        doThis(.iteratorPlayDelayed, to: inty)

        // This pass still happens — only the continuation is dropped, and the
        // iterator goes with it, well short of exhaustion.
        // The body waits under the last pass, and returns to .code after it.
        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo ( true ) ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// A plan is all-or-nothing, so a missing delay costs the loop its pass but
    /// not its state: the iterator is never popped, and can be played again.
    @Test func `iteratorPlayDelayed with no delay stalls without losing the iterator`() {
        let inty = loaded(counting())
        doThis(.iteratorPlayDelayed, to: inty)

        #expect(stackString(inty, .iterator) == "[ «0→5 by 1 @0 ( true )» ]")
        #expect(errorStrings(inty).contains { $0.contains("missing args") })
    }

    /// **The burial is read once and then persists** — this test asserted the
    /// opposite until the rework, and the opposite was the dead end: a loop that
    /// re-read a delay every pass ate one `.int` per pass, so a thousand-pass loop
    /// starved every other instruction of arguments. Argument starvation is the
    /// Push flaw first-class iterators are meant to relieve, not deepen.
    @Test func `a delayed loop reads its burial once and keeps it`() {
        let inty = loaded(
            counting(emits: false),
            exec: [InstructionItem(.iteratorPlayDelayed)]
        )
        inty.stacks[.int] = Deque((0..<5).map { _ in IntItem(0) as any Item })
        inty.run(stepLimit: 10_000)

        #expect(inty.stacks[.bool]!.count == 5)     // five passes, five bodies
        // Four of the five ints are untouched: the loop took exactly one.
        #expect(stackString(inty, .int) == "[ 0 0 0 0 ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// A buried loop stays buried, without asking again — the whole point of
    /// keeping the depth on the iterator.
    @Test func `a burial persists for the life of the loop`() {
        let inty = loaded(
            counting(from: 0, to: 4, emits: false),
            exec: [InstructionItem(.iteratorPlayDelayed)]
        )
        inty.stacks[.int]!.prepend(IntItem(2))
        inty.run(stepLimit: 10_000)

        // It ran to exhaustion on one int, and never touched .int again.
        #expect(inty.stacks[.bool]!.count == 4)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(inty.stacks[.error]!.isEmpty)
    }

    /// The burial survives a round trip through the iterator's own crux, which is
    /// what makes it genuinely part of the iterator's value rather than a passing
    /// argument.
    @Test func `a buried iterator's crux reproduces its burial`() {
        let inty = loaded(counting(), exec: [InstructionItem(.iteratorPlayDelayed)])
        inty.stacks[.int]!.prepend(IntItem(3))
        doThis(.iteratorPlayDelayed, to: inty)

        let live = inty.stacks[.iterator]!.first!
        #expect((live as? IteratorItem)?.burial == 3)

        let rebuilt = rerunTop(live.crux(), on: .iterator) as? IteratorItem
        #expect(rebuilt?.burial == 3)
        #expect(rebuilt?.isEqual(to: live) == true)
    }


    // MARK: - The getters

    @Test func `the getters read an iterator without disturbing it`() {
        let inty = loaded(counting(from: 2, to: 8, by: 3, cursor: 1))

        doThis(.iteratorPeekStart, to: inty)
        #expect(stackString(inty, .int) == "[ 2 ]")
        doThis(.iteratorPeekEnd, to: inty)
        #expect(stackString(inty, .int) == "[ 8 2 ]")
        doThis(.iteratorPeekStride, to: inty)
        #expect(stackString(inty, .int) == "[ 3 8 2 ]")
        doThis(.iteratorPeekBody, to: inty)
        #expect(stackString(inty, .code) == "[ ( true ) ]")

        // Four reads, and the loop is exactly where it was: same cursor, still
        // one iterator. Reading is not stepping.
        #expect(stackString(inty, .iterator) == "[ «2→8 by 3 @1 ( true )» ]")
    }

    /// Law 1b, extended from CodeItems to iterators: the bounds and body come back
    /// out as the items that went in, so they record nothing.
    @Test func `the container getters record no provenance`() {
        let inty = loaded(counting())
        doThis(.iteratorPeekStart, to: inty)
        #expect(topItem(inty, .int).call.isEmpty)

        doThis(.iteratorPeekBody, to: inty)
        #expect(topItem(inty, .code).call.isEmpty)
    }

    /// The exception that shows the rule: there is no contained item to hand back,
    /// so the stride really is produced here and records under law 3.
    @Test func `iteratorPeekStride records where it came from`() {
        let inty = loaded(counting(by: 3))
        doThis(.iteratorPeekStride, to: inty)

        let stride = topItem(inty, .int)
        // `«iter» .iteratorPeekStride 1 .iteratorPopItems` — the getter hands the
        // iterator back, so the crux pops it and the fragment leaves only the fact.
        #expect(stride.call.count == 4)
        #expect(stride.call[1] as? InstructionItem == InstructionItem(.iteratorPeekStride))
        #expect(stride.call.last as? InstructionItem == InstructionItem(.iteratorPopItems))
        #expect((rerunTop(stride.crux(), on: .int) as? IntItem)?.value == 3)

        let redo = Interpreter.recordingProvenance()
        redo.load(program: stride.crux())
        redo.run()
        #expect(redo.stacks[.iterator]!.isEmpty, "the crux leaves no iterator behind")
    }


    // MARK: - Construction, and the crux

    @Test func `iteratorFromIntRange builds an iterator without running it`() {
        let inty = Interpreter.recordingProvenance()
        // origin dest stride cursor burial emits (body)
        inty.load(program: [
            IntItem(2), IntItem(8), IntItem(3), IntItem(1), IntItem(0),
            BoolItem(true),
            CodeItem([BoolItem(true)]),
            InstructionItem(.iteratorFromIntRange),
        ])
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .iterator) == "[ «2→8 by 3 @1 ( true )» ]")
        // Emphatically not a loop: nothing ran, nothing was emitted.
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    /// An empty body is no body: `init` normalizes the two together, which is what
    /// lets one constructor serve both a sequence and a loop. A crux writes `( )`
    /// for a bodyless iterator and gets nil back.
    @Test func `an empty body is normalized to no body`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(0), IntItem(5), IntItem(1), IntItem(0), IntItem(0),
            BoolItem(true),
            CodeItem([]),
            InstructionItem(.iteratorFromIntRange),
        ])
        inty.run(stepLimit: 10_000)

        let built = inty.stacks[.iterator]!.first as? IteratorItem
        #expect(built?.body == nil)
        #expect(built?.isEqual(to: counting(body: nil)) == true)
    }

    /// A bodyless pass emits its element and nothing else — one step, not three.
    @Test func `a bodyless iterator emits only its elements`() {
        let inty = loaded(
            counting(body: nil),
            exec: [InstructionItem(.iteratorPlay)]
        )
        doThis(.iteratorPlay, to: inty)
        #expect(stackString(inty, .exec) == "[ .iteratorPlay .iteratorPlay ]")
        #expect(stackString(inty, .int) == "[ 0 ]")

        let all = loaded(counting(body: nil), exec: [InstructionItem(.iteratorPlay)])
        all.run(stepLimit: 10_000)
        #expect(stackString(all, .int) == "[ 4 3 2 1 0 ]")
        // Five elements in five passes: no `.codeDo` cycles in between.
        #expect(all.counter == 5)
    }

    /// The obligation, for the type that carries a loop: an iterator's crux
    /// rebuilds *that iterator*, mid-flight cursor and all.
    @Test func `an iterator's crux reproduces it`() {
        let inty = loaded(counting(from: 3, to: 40), exec: [InstructionItem(.iteratorPlay)])
        for _ in 0..<12 { inty.step() }

        let live = inty.stacks[.iterator]!.first!
        #expect(live.pretty() == "«3→40 by 1 @3 ( true )»")

        let rebuilt = rerunTop(live.crux(), on: .iterator)
        #expect(rebuilt?.pretty() == live.pretty())
        #expect(rebuilt?.isEqual(to: live) == true)
    }

    /// The whole reason the state is reconstructed rather than traced: an
    /// iterator's record must not grow as its loop runs.
    @Test func `iterator provenance does not grow with the loop`() {
        func iteratorAfter(_ steps: Int) -> any Item {
            let inty = loaded(
                counting(from: 0, to: 10_000, emits: false),
                exec: [InstructionItem(.iteratorPlay)]
            )
            for _ in 0..<steps { inty.step() }
            return inty.stacks[.iterator]!.first!
        }

        let early = iteratorAfter(4)
        let late = iteratorAfter(400)
        #expect(early.callWeight == late.callWeight)
        #expect(early.call.count == late.call.count)
    }


    // MARK: - Living on a shared stack

    /// The iterator is visible to the body, on an ordinary stack, so the body can
    /// take it away. The loop then stops, loudly, rather than hanging.
    @Test func `a body that steals the iterator ends the loop with an error`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(0), IntItem(50),
            CodeItem([InstructionItem(.iteratorFlush)]),
            InstructionItem(.execDoRange),
        ])
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(errorStrings(inty).contains { $0.contains("missing args") })
        // It stopped almost immediately rather than running its 49 passes.
        #expect(inty.stacks[.int]!.count == 1)
    }

    @Test func `iteratorEq compares state, not provenance`() {
        let inty = loaded(counting())
        inty.stacks[.iterator]!.prepend(counting())
        doThis(.iteratorEq, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")

        let other = loaded(counting())
        other.stacks[.iterator]!.prepend(counting(cursor: 2))
        doThis(.iteratorEq, to: other)
        #expect(stackString(other, .bool) == "[ false ]")
    }


    // MARK: - Repeating, and the dup families

    @Test func `a repeating iterator emits its origin over and over`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            CodeItem([IntItem(7)]), IntItem(4), IntItem(0), IntItem(0),
            InstructionItem(.iteratorRepeating),
        ])
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .iterator) == "[ «7→4 @0» ]")

        // Construct only: nothing was emitted until it is played.
        #expect(stackString(inty, .int) == "[ ]")
        inty.stacks[.exec]!.prepend(InstructionItem(.iteratorPlay))
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .int) == "[ 7 7 7 7 ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// The box is what lets one constructor serve all thirteen stacks. Law 1b: an
    /// item that goes into a block and comes back out is the item that went in.
    @Test func `a repeating iterator's crux reproduces it`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            DoubleItem(2.5), IntItem(3), InstructionItem(.doubleDupTimes),
        ])
        inty.run(stepLimit: 4)   // build it, do not finish the loop

        let live = inty.stacks[.iterator]!.first!
        #expect(CodeItem(live.crux()).pretty() == "( ( 2.5 ) 3 1 0 .iteratorRepeating )")

        let rebuilt = rerunTop(live.crux(), on: .iterator)
        #expect(rebuilt?.isEqual(to: live) == true)
    }

    /// A dup changes no value, so law 1 applies: every copy keeps the original's
    /// record untouched, which is why this family needs no `Nth` at all.
    @Test func `dup copies keep the original's provenance`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(2), IntItem(3), InstructionItem(.intAdd),   // 5, with a record
            IntItem(2), InstructionItem(.intDupTimes),
        ])
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .int) == "[ 5 5 5 ]")
        for copy in inty.stacks[.int]! {
            #expect(CodeItem(copy.crux()).pretty() == "( 2 3 .intAdd )")
        }
    }

    /// `execDupItems` boxes its copies in a CodeItem and walks them — which makes
    /// it, in essence, a first `.codeIterate`: iterating a block's contents and
    /// handing back a stack's top few are the same machinery.
    ///
    /// `.exec` is the awkward one, and the reason `into:` exists. Its contents are
    /// heterogeneous *and* pending, so the target cannot be derived from the
    /// element — and `defaultStack(for:)` answers **nil** for an InstructionItem,
    /// which without the `?? .exec` fallback would drop it silently.
    ///
    /// **The copies now interleave with the loop, and that is a deliberate change
    /// of meaning.** Emitting onto `.exec` means *run*, not *place*: each copy
    /// executes before the next is emitted, where they used to be laid down
    /// contiguously and run as a block. Every other stack rests its elements, so
    /// only `.exec` notices. Here `.intInc` is copied and runs before the `7` it
    /// wants arrives — so it complains, and the loop carries on. Accepted as the
    /// price of one uniform mechanism; see "Notes on Push/The first-class
    /// iterator.md".
    @Test func `execDupItems walks a box of heterogeneous pending code`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.exec] = Deque([
            InstructionItem(.execDupItems), IntItem(7), InstructionItem(.intInc),
            BoolItem(true),
        ] as [any Item])
        inty.stacks[.int]!.prepend(IntItem(2))

        inty.step()   // execDupItems: copies the top 2 pending items into a box
        #expect(stackString(inty, .iterator) == "[ «( .intInc 7 ) @0» ]")

        inty.run(stepLimit: 10_000)
        // The copied `.intInc` ran first and found nothing — an instruction with
        // no resting stack executes rather than vanishing, which is the point of
        // the `?? .exec` fallback. Then the copied 7, then the originals: 7 and
        // `.intInc` giving 8.
        #expect(stackString(inty, .int) == "[ 8 7 ]")
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(errorStrings(inty).contains { $0.contains("intInc missing args") })
    }


    // MARK: - Setters

    @Test func `the setters re-aim a live loop`() {
        let inty = loaded(counting(from: 0, to: 20, emits: false))
        inty.stacks[.code]!.prepend(CodeItem([IntItem(9)]))
        doThis(.iteratorSetStart, to: inty)
        #expect(stackString(inty, .iterator) == "[ «9→20 by 1 @0 silent ( true )» ]")

        inty.stacks[.code]!.prepend(CodeItem([IntItem(12)]))
        doThis(.iteratorSetEnd, to: inty)
        #expect(stackString(inty, .iterator) == "[ «9→12 by 1 @0 silent ( true )» ]")

        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.iteratorSetCounter, to: inty)
        #expect(stackString(inty, .iterator) == "[ «9→12 by 1 @2 silent ( true )» ]")

        inty.stacks[.int]!.prepend(IntItem(3))
        doThis(.iteratorSetDepth, to: inty)
        #expect(stackString(inty, .iterator) == "[ «9→12 by 1 @2 silent ⤓3 ( true )» ]")

        // Re-aimed and still runnable: 11 and 12 are within a stride of the end,
        // so from cursor 2 (value 11) exactly one pass remains.
        inty.stacks[.exec]!.prepend(InstructionItem(.iteratorPlay))
        inty.run(stepLimit: 10_000)
        #expect(inty.stacks[.bool]!.count == 1)
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// A re-aimed iterator records the same way a stepped one does — by state —
    /// so its crux still reproduces it exactly.
    @Test func `a re-aimed iterator's crux reproduces it`() {
        let inty = loaded(counting(from: 0, to: 20))
        inty.stacks[.int]!.prepend(IntItem(7))
        doThis(.iteratorSetCounter, to: inty)

        let live = inty.stacks[.iterator]!.first!
        #expect(rerunTop(live.crux(), on: .iterator)?.isEqual(to: live) == true)
    }

    @Test func `carrying the counter past the end destroys the loop`() {
        let inty = loaded(counting(from: 0, to: 5))
        inty.stacks[.int]!.prepend(IntItem(99))
        doThis(.iteratorSetCounter, to: inty)
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(errorStrings(inty).isEmpty)   // finishing is not an error

        // …and so does a negative one.
        let back = loaded(counting(from: 0, to: 5))
        back.stacks[.int]!.prepend(IntItem(-1))
        doThis(.iteratorSetCounter, to: back)
        #expect(stackString(back, .iterator) == "[ ]")
    }

    /// A type the kind cannot use is not refused: it simply leaves the loop with
    /// nothing to emit. Handing a counting iterator a string is a way to stop it.
    @Test func `an unusable start destroys the loop rather than erroring`() {
        let inty = loaded(counting())
        inty.stacks[.code]!.prepend(CodeItem([StringItem("nope")]))
        doThis(.iteratorSetStart, to: inty)
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(errorStrings(inty).isEmpty)
    }

    @Test func `a negative depth ends the loop`() {
        let inty = loaded(counting())
        inty.stacks[.int]!.prepend(IntItem(-1))
        doThis(.iteratorSetDepth, to: inty)
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// A walking iterator's end is its source's own length, not a field — so
    /// setting one is refused rather than stored. Storing it would be a lie the
    /// crux could not carry: a walking constructor takes no bounds, so the
    /// destination would vanish on reconstruction and the round trip would break.
    @Test func `setting the end of a walking iterator is refused`() {
        let inty = loaded(
            IteratorItem(
                kind: .elements(into: nil),
                origin: VecIntItem([1, 2, 3]),
                body: nil,
                emits: true
            )
        )
        inty.stacks[.code]!.prepend(CodeItem([IntItem(99)]))
        doThis(.iteratorSetEnd, to: inty)

        // Handed back untouched, and told why.
        #expect(stackString(inty, .iterator) == "[ «[1, 2, 3] @0» ]")
        #expect(errorStrings(inty).contains { $0.contains("source's length") })
    }

    @Test func `an empty box is refused, and the iterator survives`() {
        let inty = loaded(counting())
        inty.stacks[.code]!.prepend(CodeItem([]))
        doThis(.iteratorSetStart, to: inty)
        #expect(stackString(inty, .iterator) == "[ «0→5 by 1 @0 ( true )» ]")
        #expect(errorStrings(inty).contains { $0.contains("needs an item") })
    }


    // MARK: - Restarting, dying, and the iteration budget

    /// Not `0 .iteratorSetCounter` with fewer keystrokes: it takes **no
    /// arguments**, and `.int` is unmet more often than not, so the setter
    /// frequently cannot fire where this always can.
    @Test func `iteratorRestart rewinds a loop and needs nothing to do it`() {
        let inty = loaded(counting(from: 3, to: 40, by: 2, cursor: 7))
        #expect(stackString(inty, .int) == "[ ]")   // nothing to draw on

        doThis(.iteratorRestart, to: inty)
        // Cursor to 0; start, end, stride and body untouched.
        #expect(stackString(inty, .iterator) == "[ «3→40 by 2 @0 ( true )» ]")
        #expect(errorStrings(inty).isEmpty)
    }

    /// A body that restarts its own loop is a `while true`, bounded by `stepLimit`
    /// — which is what it should be, and is reachable only from inside a body
    /// since a spent iterator does not exist to be restarted.
    @Test func `a body can restart its own loop forever`() {
        let inty = Interpreter.recordingProvenance()
        inty.config.stepLimit = 400
        inty.load(program: [
            IntItem(0), IntItem(4),
            CodeItem([BoolItem(true), InstructionItem(.iteratorRestart)]),
            InstructionItem(.execDoRange),
        ])
        inty.run()

        // It ran out of steps, not out of loop.
        #expect(inty.counter == 400)
        #expect(inty.stacks[.bool]!.count > 40)

        // And it never got anywhere: the cursor is rewound to 0 every pass, so it
        // is only ever 0 or 1 depending on where the step limit fell. A four-pass
        // loop that has run forty-plus bodies has plainly not been advancing.
        let live = inty.stacks[.iterator]!.first as? IteratorItem
        #expect((live?.value ?? 99) <= 1)
        #expect(live?.body?.pretty() == "( true .iteratorRestart )")
    }

    /// A dying loop hands its body back to `.code` — the same courtesy
    /// `execDoCount` already extends when its count is too small to act on, at the
    /// other end of the loop. It is not tidiness: `.code` is the language's
    /// tightest bottleneck, so every loop that ends is a small supply of the
    /// scarcest thing there is.
    @Test func `a dying loop gives its body back`() {
        let inty = loaded(counting(from: 0, to: 3), exec: [InstructionItem(.iteratorPlay)])
        #expect(stackString(inty, .code) == "[ ]")
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .iterator) == "[ ]")   // still dies
        #expect(stackString(inty, .code) == "[ ( true ) ]")
    }

    /// A sequence has no body, so it has nothing to give back and gives nothing.
    @Test func `a dying sequence returns nothing`() {
        let inty = loaded(counting(body: nil), exec: [InstructionItem(.iteratorPlay)])
        inty.run(stepLimit: 10_000)
        #expect(stackString(inty, .code) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// The invariant: **every iterator resting on `.iterator` has something to
    /// emit.** A constructor is the one door a spent one could walk in through,
    /// since it takes its state verbatim rather than deriving it.
    @Test func `a constructor refuses to build a spent iterator`() {
        let inty = Interpreter.recordingProvenance()
        // cursor 99 on a 0→3 range: nothing left to emit.
        inty.load(program: [
            IntItem(0), IntItem(3), IntItem(1), IntItem(99), IntItem(0), BoolItem(true),
            CodeItem([]), InstructionItem(.iteratorFromIntRange),
        ])
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(errorStrings(inty).contains { $0.contains("has nothing to emit") })
    }

    /// A loop's span is whatever the program asked for (there is no iteration
    /// budget since 2026-11-08), and its iterator's crux rebuilds it exactly.
    @Test func `a long range's iterator round-trips through its crux`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(0), IntItem(999_999), CodeItem([]), InstructionItem(.execDoRange),
        ])
        for _ in 0..<4 { inty.step() }

        let live = inty.stacks[.iterator]!.first!
        let rebuilt = rerunTop(live.crux(), on: .iterator)
        #expect(rebuilt?.isEqual(to: live) == true)
    }


    // MARK: - Iterators inside iterators

    /// `.iterator` is an ordinary stack, so an iterator can walk a vector of
    /// nothing in particular while another walks it — and a body can build one.
    /// Nested loops are just two iterators resting on the same stack.
    @Test func `a loop body can run a loop of its own`() {
        let inty = Interpreter.recordingProvenance()
        // Outer: 0 toward 3. Inner, per pass: 0 toward 3 again, pushing a `true` each time.
        inty.load(program: [
            IntItem(0), IntItem(3),
            CodeItem([
                IntItem(0), IntItem(3), CodeItem([BoolItem(true)]),
                InstructionItem(.execDoRange),
            ]),
            InstructionItem(.execDoRange),
        ])
        inty.run(stepLimit: 10_000)

        // Three outer passes (0, 1, 2: the range stops short of 3), each running
        // three inner ones: nine bodies.
        #expect(inty.stacks[.bool]!.count == 9)
        // Both loops finished and cleaned up after themselves.
        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(inty.stacks[.error]!.isEmpty)
    }

    /// The inner loop rests *on top of* the outer one for its duration, and the
    /// outer one is still there underneath, untouched, when it ends.
    @Test func `a nested loop stacks its iterator above the outer one`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(0), IntItem(9),
            CodeItem([
                IntItem(0), IntItem(9), CodeItem([]), InstructionItem(.execDoRange),
            ]),
            InstructionItem(.execDoRange),
        ])
        // Far enough in for the outer loop to have started its inner one.
        for _ in 0..<12 { inty.step() }

        // Two live loops, resting on one ordinary stack.
        #expect(inty.stacks[.iterator]!.count == 2)
        #expect(inty.stacks[.iterator]!.allSatisfy {
            ($0 as? IteratorItem).map { !$0.isSpent } ?? false
        })

        // The inner one is on top, so it is what the next `.iteratorPlay` finds —
        // which is exactly how the nesting works, and exactly what makes an inner
        // loop able to interfere with an outer one.
        let inner = inty.stacks[.iterator]![0] as! IteratorItem
        let outer = inty.stacks[.iterator]![1] as! IteratorItem
        // 9 itself: the range stops short of its end, as the engine does.
        #expect((inner.destination as? IntItem)?.value == 9)
        #expect((outer.destination as? IntItem)?.value == 9)

        // Running on: the inner loop finishes and leaves the outer one behind,
        // untouched and still going.
        for _ in 0..<40 { inty.step() }
        #expect(inty.stacks[.iterator]!.count >= 1)
        #expect(inty.stacks[.int]!.count > 9)   // both loops emitted indices
        _ = outer
    }

    /// The consequence of `.iterator` being ordinary: `.iteratorPlay` takes
    /// whatever is on top, so an inner loop's iterator is what an outer loop's
    /// continuation finds. This is deliberate — the type is first-class so that a
    /// program can get hold of it — and the failure mode is an ErrorItem.
    @Test func `an inner loop can strand the outer one's continuation`() {
        let inty = Interpreter.recordingProvenance()
        // The body flushes `.iterator`, so the outer loop's own iterator goes
        // with it and its continuation finds nothing.
        inty.load(program: [
            IntItem(0), IntItem(50),
            CodeItem([InstructionItem(.iteratorFlush)]),
            InstructionItem(.execDoRange),
        ])
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .iterator) == "[ ]")
        #expect(errorStrings(inty).contains { $0.contains("missing args") })
        #expect(inty.stacks[.int]!.count == 1)   // stopped after one pass
    }

    /// An iterator can be an iterator's origin: `.repeating` takes any item, and
    /// `.iterator` is a stack like any other, so `iteratorDupTimes` copies a live
    /// loop. The copies are independent — each is a value.
    @Test func `an iterator can repeat an iterator`() {
        let inty = loaded(counting(from: 0, to: 3, emits: false))
        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.iteratorDupTimes, to: inty)
        inty.run(stepLimit: 10_000)

        // The original, plus two copies of it.
        #expect(inty.stacks[.iterator]!.count == 3)
        for copy in inty.stacks[.iterator]! {
            #expect(copy.isEqual(to: counting(from: 0, to: 3, emits: false)))
        }

        // Playing the top copy runs it to exhaustion and leaves the other two.
        inty.stacks[.exec]!.prepend(InstructionItem(.iteratorPlay))
        inty.run(stepLimit: 10_000)
        #expect(inty.stacks[.bool]!.count == 3)
        #expect(inty.stacks[.iterator]!.count == 2)
    }

    /// An iterator walking a code block full of iterators. The elements come back
    /// out by law 1b — the items that went in — and land on `.iterator`, derived
    /// from their own type with no `into:` needed.
    @Test func `an iterator can walk a block of iterators`() {
        let inty = Interpreter.recordingProvenance()
        let box = CodeItem([
            counting(from: 0, to: 3),
            counting(from: 7, to: 9),
        ])
        // `origin ( body ) cursor burial emits` — the box of iterators to walk,
        // then an empty body, which makes this a sequence rather than a loop.
        inty.load(program: [
            box, CodeItem([]),
            IntItem(0), IntItem(0), BoolItem(true),
            InstructionItem(.iteratorFromCode),
            InstructionItem(.iteratorPlay),
        ])
        inty.run(stepLimit: 10_000)

        #expect(inty.stacks[.iterator]!.count == 2)
        #expect(stackString(inty, .iterator)
            == "[ «7→9 by 1 @0 ( true )» «0→3 by 1 @0 ( true )» ]")
        #expect(inty.stacks[.error]!.isEmpty)
    }


    // MARK: - Helpers

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    func rerunTop(_ crux: [any Item], on stack: PushStack) -> (any Item)? {
        let redo = Interpreter.recordingProvenance()
        redo.config.stepLimit = 20_000
        redo.load(program: crux)
        redo.run(stepLimit: 20_000)
        return redo.stacks[stack]!.first
    }
}
