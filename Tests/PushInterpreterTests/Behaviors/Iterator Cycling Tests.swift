//
//  Iterator Cycling Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/17/26.
//
//  `laps`: a walking iterator that goes round its source more than once.
//
//  Two claims are being tested, and the second is the one that would be easy to
//  get wrong and never notice:
//
//  1. the projection wraps — `[1 2 3]` cycled three times emits nine items;
//  2. **the cursor does not.** It climbs past the source's length forever, and
//     only the *index* wraps. That is what keeps the crux a fixed point, since an
//     iterator's record names its cursor: a cursor that rewound would rebuild an
//     iterator that had done no laps.
//
//  And one that costs nothing but would hurt: cycling is what drags a walk across
//  the line in Design Principles §12 — a lap the program *asked* for is a claim,
//  so `maxIterations` starts applying where it deliberately did not before.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct IteratorCyclingTests {

    /// A bodyless walk over `[1 2 3]`, cycling `laps` times.
    func cycling(_ laps: Int, over vector: [Int] = [1, 2, 3], cursor: Int = 0) -> IteratorItem {
        IteratorItem(
            kind: .elements(into: nil),
            origin: VecIntItem(vector),
            body: nil,
            emits: true,
            cursor: cursor,
            laps: laps
        )
    }

    func loaded(_ iterator: IteratorItem) -> Interpreter {
        let inty = Interpreter()
        inty.stacks[.iterator]!.prepend(iterator)
        inty.stacks[.exec] = Deque([InstructionItem(.iteratorPlay)] as [any Item])
        return inty
    }

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }


    // MARK: - going round

    /// The whole feature, at the only level that matters: what comes out.
    @Test func `a cycling walk emits its source again`() {
        let inty = loaded(cycling(3))
        inty.run()

        // Nine emissions, in order, three laps of three. `.int` is a stack, so
        // the last one out is on top.
        #expect(stackString(inty, .int) == "[ 3 2 1 3 2 1 3 2 1 ]")
        #expect(inty.stacks[.iterator]!.isEmpty, "spent, and so gone")
    }

    /// One lap is what every walk did before `laps` existed, and must still do.
    @Test func `one lap is exactly the old behaviour`() {
        let inty = loaded(cycling(1))
        inty.run()
        #expect(stackString(inty, .int) == "[ 3 2 1 ]")
    }

    /// **The cursor climbs; the index wraps.** After four passes of a 3-element
    /// source the cursor reads 4 — not 1 — and the element it names is `[1]`.
    /// This is the invariant the crux rests on.
    @Test func `the cursor is monotone and only the projection wraps`() {
        var iterator = cycling(3)
        for _ in 0..<4 { iterator = iterator.stepped() }

        #expect(iterator.value == 4, "four passes taken, not one lap and one over")
        #expect(iterator.wrappedCursor == 1)
        #expect((iterator.projection() as? IntItem)?.value == 2, "element 1 of [1, 2, 3]")
    }

    /// An element of the third lap records exactly what an element of the first
    /// does — because it *is* the same element, and `origin 1 .vecIntNth` says so
    /// without caring how many passes have run. Cycling costs provenance nothing.
    @Test func `a wrapped element records the same Nth as its first lap`() {
        let first = cycling(3, cursor: 1).projection()
        let third = cycling(3, cursor: 7).projection()

        #expect(first!.isEqual(to: third!))
        #expect(CodeItem(third!.crux()).pretty() == "( [1, 2, 3] 1 .vecIntNth )")
    }

    /// `laps` is the one piece of state no constructor takes, so a cycling walk
    /// records a two-instruction rebuild — and only when it cycles.
    @Test func `a cycling walk rebuilds itself through its setter`() {
        let plain = CodeItem(cycling(1).reconstruction()).pretty()
        #expect(!plain.contains(".iteratorSetLaps"),
                "an iterator that never asked pays nothing for the feature")

        let cycler = cycling(4, cursor: 2)
        let inty = Interpreter()
        inty.load(program: cycler.reconstruction())
        inty.run()

        guard let rebuilt = inty.stacks[.iterator]!.first as? IteratorItem else {
            Issue.record("the record did not rebuild an iterator: \(stackString(inty, .error))")
            return
        }
        #expect(rebuilt.laps == 4)
        #expect(rebuilt.value == 2)
        #expect(rebuilt.isEqual(to: cycler), "reconstruction is by state, and the state is all of it")
    }


    // MARK: - the setter

    @Test func `setLaps sends a walk round again`() {
        let inty = loaded(cycling(1))
        inty.stacks[.int]!.prepend(IntItem(2))
        doThis(.iteratorSetLaps, to: inty)
        inty.run()

        #expect(stackString(inty, .int) == "[ 3 2 1 3 2 1 ]")
    }

    /// Their length is in `destination` already; a second number for it would be a
    /// lie the crux would have to carry.
    @Test func `setLaps is refused by the kinds that were told how far to go`() {
        let counter = IteratorItem(
            kind: .counting(stride: 1),
            origin: IntItem(0),
            destination: IntItem(5),
            body: nil,
            emits: true
        )
        let inty = loaded(counter)
        inty.stacks[.int]!.prepend(IntItem(3))
        doThis(.iteratorSetLaps, to: inty)

        #expect((inty.stacks[.iterator]!.first as? IteratorItem)?.laps == 1, "handed back untouched")
        #expect(errorStrings(inty).contains { $0.contains("destination") })
    }

    /// Nothing special is done about zero laps: `isSpent` agrees there is nothing
    /// to emit, and the setter family already knows what to do with a finished
    /// loop. A negative depth ends one the same way.
    @Test func `zero laps ends the loop like any other emptying change`() {
        let inty = loaded(cycling(1))
        inty.stacks[.int]!.prepend(IntItem(0))
        doThis(.iteratorSetLaps, to: inty)

        #expect(inty.stacks[.iterator]!.isEmpty, "a spent iterator is not a thing")
    }

    @Test func `peekLaps reads the count without eating the loop`() {
        let inty = loaded(cycling(4))
        doThis(.iteratorPeekLaps, to: inty)

        #expect(stackString(inty, .int) == "[ 4 ]")
        #expect(inty.stacks[.iterator]!.count == 1, "Peek hands the loop back")
    }


    // MARK: - the budget

    /// **The point of cycling being an attribute.** A walk of one lap is a fact
    /// about data the program was handed, and `promisedPasses` returns nil so the
    /// clamp leaves it alone. Ask for a second lap and the number is a claim the
    /// program made up — so it is measurable, and `maxIterations` starts applying
    /// to a kind it deliberately never touched.
    @Test func `cycling moves a walk from fact to claim`() {
        #expect(cycling(1).promisedPasses == nil, "one lap is a fact about the data")
        #expect(cycling(3).promisedPasses == 9, "three laps is a claim, and claims are counted")
    }

    /// The clamp cuts the laps, never the source: 40 laps of 3 is 120 emissions,
    /// so it comes back to 33 — 99, the most whole laps that fit under 100.
    @Test func `a wildly cycling walk is clamped at push`() {
        let inty = Interpreter()
        inty.push(cycling(40), to: .iterator)

        #expect((inty.stacks[.iterator]!.first as? IteratorItem)?.laps == 33)
    }

    /// The other side of the same rule. One lap of a 1000-element vector is 1000
    /// emissions and is **allowed** — that lap was never this budget's to cut
    /// (`maxVectorLength` bounds it instead). So a cycling walk over a source
    /// already longer than the ceiling falls back to a single lap rather than to
    /// nothing.
    /// **A clamp must never leave a resting iterator spent.**
    ///
    /// `iteratorBuilt` approves a live iterator, and only then does the push
    /// boundary clamp it — so a clamp measured from the loop's *start* could shrink
    /// the end to somewhere the cursor had already passed, and the result came to
    /// rest with nothing to emit. Its crux then could not rebuild it, which is how
    /// a 40-seed sweep found this: 2 broken claims in 154,364, both
    /// `.iteratorRepeatingIntoExec`.
    ///
    /// The budget is now "at most `maxIterations` **more** passes", measured from
    /// the cursor. For a cursor of 0 — every loop that was stepped rather than
    /// hand-built — nothing changes, which is why this went unseen.
    @Test func `clamping a hand-built cursor does not strand it`() {
        let inty = Interpreter()
        inty.config.maxIterations = 100
        inty.stacks[.code]!.prepend(CodeItem([IntItem(7)]))
        // takes: [.code, .int, .int, .int] — written deepest-first: count, cursor, burial.
        inty.stacks[.int]!.prepend(contentsOf:
            [IntItem(88), IntItem(25_046), IntItem(30_000)] as [any Item])
        doThis(.iteratorRepeatingIntoExec, to: inty)

        let landed = inty.stacks[.iterator]!.first as! IteratorItem
        #expect(!landed.isSpent, "a resting iterator has something to emit")
        #expect(landed.promisedPasses == 100, "100 more passes, not 100 in total")
        #expect((landed.destination as? IntItem)?.value == 25_146)
        #expect(landed.value == 25_046, "and the cursor is where the program put it")

        // The crux of an iterator that can exist must rebuild it.
        let redo = Interpreter()
        redo.config.maxIterations = 100
        redo.load(program: landed.crux())
        redo.run()
        #expect(stackString(redo, .iterator) == stackString(inty, .iterator))
    }

    /// The clamp stays a fixed point: having budgeted from the cursor, asking
    /// again finds nothing left to cut.
    @Test func `clamping is idempotent from a moved cursor`() {
        let inty = Interpreter()
        inty.config.maxIterations = 100
        inty.stacks[.code]!.prepend(CodeItem([IntItem(7)]))
        inty.stacks[.int]!.prepend(contentsOf:
            [IntItem(0), IntItem(25_046), IntItem(30_000)] as [any Item])
        doThis(.iteratorRepeatingIntoExec, to: inty)

        let landed = inty.stacks[.iterator]!.first as! IteratorItem
        #expect(landed.clamped(toPasses: 100) == nil,
                "already within budget, so nothing to clamp — and no wasted copy")
    }

    @Test func `a source longer than the ceiling falls back to one lap, not none`() {
        let inty = Interpreter()
        inty.push(cycling(2, over: Array(1...1_000)), to: .iterator)

        let landed = inty.stacks[.iterator]!.first as? IteratorItem
        #expect(landed?.laps == 1)
        #expect(landed?.promisedPasses == nil, "and is a fact again, so nothing clamps it further")
    }

    /// Clamping has to be idempotent or `crux()` breaks: a record is re-run
    /// through `push`, so an iterator that changed on the way back in would not
    /// reproduce itself.
    @Test func `clamping a clamped iterator changes nothing`() {
        #expect(cycling(40).clamped(toPasses: 100)?.laps == 33)
        #expect(cycling(33).clamped(toPasses: 100) == nil, "already under; nothing to do")
    }


    // MARK: - the edges

    /// `x % 0` **traps**, and a trap is a crashed interpreter rather than an
    /// ErrorItem (§14). A cycle over nothing emits nothing, and nothing may
    /// compute the index to find that out.
    @Test func `cycling an empty source does not divide by zero`() {
        let empty = cycling(5, over: [])

        #expect(empty.isSpent)
        #expect(empty.wrappedCursor == nil)
        #expect(empty.projection() == nil)

        // And the whole way through the interpreter, which is where a trap would
        // actually be fatal.
        let inty = loaded(empty)
        inty.run()
        #expect(stackString(inty, .int) == "[ ]")
    }

    /// A cursor put past the end by a setter is finished, laps or no laps.
    @Test func `a cursor carried past the last lap is spent`() {
        #expect(cycling(3, cursor: 8).isSpent == false, "the ninth and last emission")
        #expect(cycling(3, cursor: 9).isSpent)
        #expect(cycling(3, cursor: -1).isSpent, "a negative cursor is nonsense in every kind")
    }

    /// Laps multiply a source, and a big enough pair overflows. A count too large
    /// to compute is larger than any budget, so it saturates rather than traps.
    @Test func `an overflowing lap count saturates`() {
        let absurd = cycling(Int.max, over: [1, 2, 3])
        #expect(absurd.totalEmissions == Int.max)
        #expect(!absurd.isSpent, "still has plenty to emit")

        let inty = Interpreter()
        inty.push(absurd, to: .iterator)
        #expect((inty.stacks[.iterator]!.first as? IteratorItem)?.laps == 33, "and the clamp catches it")
    }
}
