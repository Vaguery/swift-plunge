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
    func counting(
        from origin: Int = 0,
        to destination: Int = 5,
        by stride: Int = 1,
        emits: Bool = true,
        cursor: Int = 0
    ) -> IteratorItem {
        IteratorItem(
            kind: .counting(stride: stride),
            origin: IntItem(origin),
            destination: IntItem(destination),
            body: CodeItem([BoolItem(true)]),
            emits: emits,
            cursor: cursor
        )
    }

    func loaded(_ iterator: IteratorItem, exec: [any Item] = []) -> Interpreter {
        let inty = Interpreter()
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

        #expect(stackString(delayed, .exec) == "[ ( true ) .codeDo .iteratorPlayDelayed ]")
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
                == "[ ( true ) .codeDo 91 92 .iteratorPlayDelayed 93 ]"
        )
    }

    @Test func `iteratorPlayDelayed clamps a delay past the bottom of exec`() {
        let inty = loaded(counting(), exec: [IntItem(91)])
        inty.stacks[.int]!.prepend(IntItem(9_999))
        doThis(.iteratorPlayDelayed, to: inty)

        // Everything pending runs first; the loop resumes last.
        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo 91 .iteratorPlayDelayed ]")
    }

    @Test func `a negative delay ends the loop early`() {
        let inty = loaded(counting())
        inty.stacks[.int]!.prepend(IntItem(-1))
        doThis(.iteratorPlayDelayed, to: inty)

        // This pass still happens — only the continuation is dropped, and the
        // iterator goes with it, well short of exhaustion.
        #expect(stackString(inty, .exec) == "[ ( true ) .codeDo ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .iterator) == "[ ]")
    }

    /// `gather` is all-or-nothing, so a missing delay costs the loop its pass but
    /// not its state: the iterator is never popped, and can be played again.
    @Test func `iteratorPlayDelayed with no delay stalls without losing the iterator`() {
        let inty = loaded(counting())
        doThis(.iteratorPlayDelayed, to: inty)

        #expect(stackString(inty, .iterator) == "[ «0→5 by 1 @0 ( true )» ]")
        #expect(errorStrings(inty).contains { $0.contains("missing args") })
    }

    /// The delay is read fresh every pass, so a body that leaves one can change
    /// the loop's own schedule as it runs.
    @Test func `a delayed loop re-reads its delay each pass`() {
        let inty = loaded(
            counting(emits: false),
            exec: [InstructionItem(.iteratorPlayDelayed)]
        )
        // One delay per pass, all zero: five passes, five bodies, none left over.
        inty.stacks[.int] = Deque((0..<5).map { _ in IntItem(0) as any Item })
        inty.run(stepLimit: 10_000)

        #expect(inty.stacks[.bool]!.count == 5)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .iterator) == "[ ]")
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
        #expect(stride.call.count == 2)
        #expect(stride.call.last as? InstructionItem == InstructionItem(.iteratorPeekStride))
        #expect((rerunTop(stride.crux(), on: .int) as? IntItem)?.value == 3)
    }


    // MARK: - Construction, and the crux

    @Test func `iteratorFromIntRange builds an iterator without running it`() {
        let inty = Interpreter()
        inty.load(program: [
            IntItem(2), IntItem(8), IntItem(3), IntItem(1), BoolItem(true),
            CodeItem([BoolItem(true)]),
            InstructionItem(.iteratorFromIntRange),
        ])
        inty.run(stepLimit: 10_000)

        #expect(stackString(inty, .iterator) == "[ «2→8 by 3 @1 ( true )» ]")
        // Emphatically not a loop: nothing ran, nothing was emitted.
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .int) == "[ ]")
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
        let inty = Interpreter()
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


    // MARK: - Helpers

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    func rerunTop(_ crux: [any Item], on stack: PushStack) -> (any Item)? {
        let redo = Interpreter()
        redo.config.stepLimit = 20_000
        redo.load(program: crux)
        redo.run(stepLimit: 20_000)
        return redo.stacks[stack]!.first
    }
}
