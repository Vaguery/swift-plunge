//
//  VecFromIterator Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/17/26.
//
//  The second of the three ways to make a vector: drive an iterator to
//  exhaustion and keep what it emitted.
//
//  The interesting claims are not "it makes a vector":
//
//  1. **the result's type is the argument's**, which is what lets it exist
//     without a sieve — nothing can ask `.iterator` for an Int-emitter, so this
//     takes what is there and answers in kind;
//  2. **it opens the closed system.** `.vecXConstruct` needs a vector to shape a
//     vector; this makes one out of two ints;
//  3. **nothing here picks a length.** Every kind was already bounded, by two
//     different rules for two different reasons, before it could ever be an
//     argument.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VecFromIteratorTests {

    func loaded(_ iterator: IteratorItem) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.iterator]!.prepend(iterator)
        return inty
    }

    func walking(_ origin: any Item, body: CodeItem? = nil, laps: Int = 1) -> IteratorItem {
        IteratorItem(
            kind: .elements(into: nil),
            origin: origin,
            body: body,
            emits: true,
            laps: laps
        )
    }

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }


    // MARK: - the result type is the argument's

    /// A counting iterator emits ints, so a vecInt comes back — **and the whole
    /// thing was built from two ints.** `.vecIntConstruct` cannot do this: it
    /// needs a vecInt to shape a vecInt. This is the instruction that opens the
    /// closed system (Stack economics, part 1).
    @Test func `a counting iterator collects into a vecInt`() {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: [
            IntItem(0), IntItem(4), IntItem(1),     // 0 → 4 by 1
            IntItem(0), IntItem(0),                 // cursor, burial
            BoolItem(true), CodeItem([]),           // emits, no body
            InstructionItem(.iteratorFromIntRange),
            InstructionItem(.vecFromIterator),
        ])
        inty.run()

        // Four, not five: `execDoRange` is deliberately not inclusive of its
        // destination, and collecting follows the same protocol a pass does.
        #expect(stackString(inty, .vecInt) == "[ [0, 1, 2, 3] ]")
        #expect(stackString(inty, .int) == "[ ]", "the loop's mechanics never touch .int")
    }

    /// Same instruction, four different result stacks, chosen by what the iterator
    /// emits and nothing else.
    @Test func `the result stack follows the iterator, not the instruction`() {
        let cases: [(any Item, PushStack, String)] = [
            (VecBoolItem([true, false]), .vecBool, "[ [true, false] ]"),
            (VecDoubleItem([1.5, 2.5]), .vecDouble, "[ [1.5, 2.5] ]"),
            (VecIntItem([1, 2, 3]), .vecInt, "[ [1, 2, 3] ]"),
            (VecStringItem(["a", "b"]), .vecString, "[ [\"a\", \"b\"] ]"),
        ]
        for (origin, resting, expected) in cases {
            let inty = loaded(walking(origin))
            doThis(.vecFromIterator, to: inty)
            #expect(stackString(inty, resting) == expected)
        }
    }

    /// Walking a vector and collecting it gives the vector back — an identity, and
    /// a dull one, but it says the order is the emission order rather than a stack
    /// order. A `pushAll` would have reversed it.
    @Test func `collecting preserves the emission order`() {
        let inty = loaded(walking(VecIntItem([3, 1, 2])))
        doThis(.vecFromIterator, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [3, 1, 2] ]")
    }

    /// One-character *strings*, so this collects; `.elements` over the same string
    /// would emit chars and be refused. That difference is the whole reason
    /// `.letters` exists as its own kind.
    @Test func `a letters iterator collects into a vecString`() {
        let inty = loaded(
            IteratorItem(kind: .letters, origin: StringItem("abc"), body: nil, emits: true)
        )
        doThis(.vecFromIterator, to: inty)
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"b\", \"c\"] ]")
    }

    /// The type is read off what came out, not off the kind — so a uniform block
    /// collects even though `.code` can hold anything.
    @Test func `a uniform code walk collects; a mixed one does not`() {
        let uniform = loaded(walking(CodeItem([IntItem(1), IntItem(2)])))
        doThis(.vecFromIterator, to: uniform)
        #expect(stackString(uniform, .vecInt) == "[ [1, 2] ]")

        let mixed = loaded(walking(CodeItem([IntItem(1), BoolItem(true)])))
        doThis(.vecFromIterator, to: mixed)
        #expect(stackString(mixed, .vecInt) == "[ ]")
        #expect(errorStrings(mixed).contains { $0.contains("which no vector holds") })
    }

    /// A cycling walk collects its laps, because collecting is just the sequence
    /// written down.
    @Test func `a cycling walk collects every lap`() {
        let inty = loaded(walking(VecIntItem([1, 2]), laps: 3))
        doThis(.vecFromIterator, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 1, 2, 1, 2] ]")
    }


    // MARK: - refusals

    /// There is no vector of chars, and saying so is better than inventing one.
    @Test func `an iterator over a string's elements is refused`() {
        let inty = loaded(walking(StringItem("abc")))
        doThis(.vecFromIterator, to: inty)

        #expect(errorStrings(inty).contains { $0.contains("which no vector holds") })
        #expect(inty.stacks[.iterator]!.count == 1, "a refusal hands the loop back")
    }

    /// A block of instructions is pending work rather than values, so there is
    /// nothing to collect — and it is the **contents** that say so, not the
    /// `IntoExec` aim. `into:` decides where a *played* pass sends its element;
    /// a collector never plays, so a block of ints aimed at `.exec` collects like
    /// any other block of ints (below).
    @Test func `a block of instructions has nothing to collect`() {
        let inty = loaded(
            IteratorItem(
                kind: .elements(into: .exec),
                origin: CodeItem([InstructionItem(.intAdd), InstructionItem(.intSubtract)]),
                body: nil,
                emits: true
            )
        )
        doThis(.vecFromIterator, to: inty)

        #expect(errorStrings(inty).contains { $0.contains("which no vector holds") })
        #expect(inty.stacks[.iterator]!.count == 1, "a refusal hands the loop back")
    }

    /// The aim is not the contents: these are ints, wherever a pass would have
    /// sent them.
    @Test func `an exec-aimed walk over ints collects like any other`() {
        let inty = loaded(
            IteratorItem(
                kind: .elements(into: .exec),
                origin: CodeItem([IntItem(1), IntItem(2)]),
                body: nil,
                emits: true
            )
        )
        doThis(.vecFromIterator, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2] ]")
    }

    /// **An iterator emitting CodeItems**, which is not hypothetical: `.repeating`
    /// takes any item at all as its origin, and a walk over a block of blocks
    /// emits blocks. There is no vector of code, so it refuses — and hands the
    /// loop back, which is the only reason the refusal is cheap.
    @Test func `an iterator emitting code blocks is refused`() {
        let repeated = loaded(
            IteratorItem(
                kind: .repeating(into: nil),
                origin: CodeItem([IntItem(1), IntItem(2)]),
                destination: IntItem(3),
                body: nil,
                emits: true
            )
        )
        doThis(.vecFromIterator, to: repeated)
        #expect(errorStrings(repeated).contains { $0.contains("which no vector holds") })
        #expect(repeated.stacks[.iterator]!.count == 1)
        #expect(stackString(repeated, .code) == "[ ]", "and nothing leaks onto .code")

        let nested = loaded(walking(CodeItem([CodeItem([IntItem(1)]), CodeItem([IntItem(2)])])))
        doThis(.vecFromIterator, to: nested)
        #expect(errorStrings(nested).contains { $0.contains("which no vector holds") })
        #expect(nested.stacks[.iterator]!.count == 1)
    }

    /// A repeating iterator over a *vector* emits vectors, and there is no vector
    /// of vectors — but over an int it emits ints, and there is.
    @Test func `a repeating iterator collects only if it repeats a scalar`() {
        let scalars = loaded(
            IteratorItem(
                kind: .repeating(into: nil),
                origin: IntItem(7),
                destination: IntItem(3),
                body: nil,
                emits: true
            )
        )
        doThis(.vecFromIterator, to: scalars)
        #expect(stackString(scalars, .vecInt) == "[ [7, 7, 7] ]")

        let vectors = loaded(
            IteratorItem(
                kind: .repeating(into: nil),
                origin: VecIntItem([1, 2]),
                destination: IntItem(2),
                body: nil,
                emits: true
            )
        )
        doThis(.vecFromIterator, to: vectors)
        #expect(errorStrings(vectors).contains { $0.contains("which no vector holds") })
    }


    // MARK: - what it does to the loop

    /// Exhausting the iterator is the whole job, so it goes — but its body comes
    /// back to `.code` rather than being destroyed with it. That is the same
    /// courtesy every other ending pays, and `.code` is the
    /// language's tightest channel.
    @Test func `a collected loop is spent, and hands its body back`() {
        let inty = loaded(walking(VecIntItem([1, 2]), body: CodeItem([IntItem(99)])))
        doThis(.vecFromIterator, to: inty)

        // Since 2026-11-09 a body's results are what is collected:
        // `( 99 )` makes 99 of each element. It runs in a sub-interpreter, so this
        // run's stacks never see it.
        #expect(stackString(inty, .vecInt) == "[ [99, 99] ]")
        #expect(inty.stacks[.iterator]!.isEmpty, "collected to exhaustion, so gone")
        #expect(stackString(inty, .code) == "[ ( 99 ) ]", "the body is handed back")
        #expect(stackString(inty, .int) == "[ ]", "and this run's stacks never see it run")
    }

    /// The stack-fed map: each element is executed, then the body,
    /// and the last value pushed is collected. No `.inputN` hole is needed.
    @Test func `with a body, it collects what the body makes`() {
        let squares = loaded(walking(VecIntItem([1, 2, 3]),
                                     body: CodeItem([InstructionItem(.intDup), InstructionItem(.intMultiply)])))
        doThis(.vecFromIterator, to: squares)
        #expect(stackString(squares, .vecInt) == "[ [1, 4, 9] ]")

        let halves = loaded(walking(VecIntItem([1, 2]), body: CodeItem([InstructionItem(.doubleFromInt)])))
        doThis(.vecFromIterator, to: halves)
        #expect(stackString(halves, .vecDouble) == "[ [1.0, 2.0] ]", "the type follows the body's results")
    }

    /// Collecting is not playing, so `emits` — which exists to keep a counted
    /// loop's index off `.int` while its body runs — has nothing to say. The
    /// projections are what the sequence *contains*.
    @Test func `a silent iterator still collects`() {
        let inty = loaded(
            IteratorItem(
                kind: .elements(into: nil),
                origin: VecIntItem([1, 2]),
                body: nil,
                emits: false
            )
        )
        doThis(.vecFromIterator, to: inty)
        #expect(stackString(inty, .vecInt) == "[ [1, 2] ]")
    }

    /// A collector that read `isSpent` instead of following the pass protocol
    /// would run one further than the same iterator does when played — and
    /// `execDoRange` is deliberately not inclusive of its destination. The two
    /// must agree or the language contradicts itself.
    @Test func `collecting emits exactly what playing emits`() {
        let counter = IteratorItem(
            kind: .counting(stride: 1),
            origin: IntItem(0),
            destination: IntItem(4),
            body: nil,
            emits: true
        )

        let played = loaded(counter)
        played.stacks[.exec] = Deque([InstructionItem(.iteratorPlay)] as [any Item])
        played.run()

        let collected = loaded(counter)
        doThis(.vecFromIterator, to: collected)

        // Played, they pile up on a stack newest-first; collected, they are in
        // emission order. Same four items, and four is the point: not five.
        #expect(stackString(played, .int) == "[ 3 2 1 0 ]")
        #expect(stackString(collected, .vecInt) == "[ [0, 1, 2, 3] ]")
    }


    // MARK: - length

    /// **Nothing here picks a length.** A wild counting loop that provably emits
    /// more than `IteratorItem.collectionLimit` is refused before any walking,
    /// rather than collected and truncated. (Until 2026-11-08 `maxIterations`
    /// clamped the claim to 100 passes at `push` first.)
    @Test func `a wild claim is refused by the collection limit`() {
        let inty = Interpreter.recordingProvenance()
        inty.push(
            IteratorItem(
                kind: .counting(stride: 1),
                origin: IntItem(0),
                destination: IntItem(4_000_000),
                body: nil,
                emits: true
            ),
            to: .iterator
        )
        doThis(.vecFromIterator, to: inty)

        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(inty.stacks[.iterator]!.count == 1, "the iterator is handed back")
        #expect(errorStrings(inty).contains { $0.contains("emits more than \(IteratorItem.collectionLimit)") })
    }

    /// The other rule: a walk's length is a fact about data, bounded by
    /// `maxVectorLength` — so this collects 500, exactly as walking it would emit
    /// 500.
    @Test func `a fact is bounded by the collection budget, not the loop budget`() {
        let inty = loaded(walking(VecIntItem(Array(1...500))))
        doThis(.vecFromIterator, to: inty)

        #expect((inty.stacks[.vecInt]!.first as? VecIntItem)?.value.count == 500)
    }

    /// And the push gate measures the result on the way out, so an over-long
    /// collect errors like any oversized push rather than being silently cut.
    @Test func `an over-long collect is refused by the push gate`() {
        let inty = loaded(walking(VecIntItem(Array(1...1_000)), laps: 2))
        // Two laps of 1000: 2000 items, over the vector cap either way.
        #expect(inty.stacks[.iterator]!.count == 1)

        var settings = InterpreterSettings()
        settings.maxVectorLength = 999
        inty.config = settings
        doThis(.vecFromIterator, to: inty)

        #expect(stackString(inty, .vecInt) == "[ ]")
        #expect(errorStrings(inty).contains { $0.contains("maxVectorLength") })
    }


    // MARK: - provenance

    /// Law 3: a new value records its argument and the instruction. The iterator's
    /// own record rebuilds it *at its cursor*, so re-running collects from the
    /// same place and gets the same vector.
    @Test func `a collected vector reproduces itself`() {
        var iterator = walking(VecIntItem([4, 5, 6]))
        iterator.call = iterator.reconstruction()   // as its constructor would leave it
        let inty = loaded(iterator)
        doThis(.vecFromIterator, to: inty)

        let vector = inty.stacks[.vecInt]!.first!
        #expect(CodeItem(vector.crux()).pretty()
                == "( [4, 5, 6] 0 0 true ( ) .iteratorFromVecInt .vecFromIterator )")

        let redo = Interpreter.recordingProvenance()
        redo.load(program: vector.crux())
        redo.run()
        #expect(stackString(redo, .vecInt) == "[ [4, 5, 6] ]")
        #expect(CodeItem(redo.stacks[.vecInt]!.first!.crux()).pretty()
                == CodeItem(vector.crux()).pretty(), "and is a fixed point")
    }

    /// Collected from a half-run loop, the record names the cursor it started at —
    /// so the crux collects the same tail, not the whole source.
    @Test func `a partly-run loop collects and reproduces its tail`() {
        var iterator = walking(VecIntItem([1, 2, 3, 4]))
        iterator.call = iterator.reconstruction()
        iterator = iterator.stepped(recording: .on).stepped(recording: .on)
        let inty = loaded(iterator)
        doThis(.vecFromIterator, to: inty)

        #expect(stackString(inty, .vecInt) == "[ [3, 4] ]")

        let redo = Interpreter.recordingProvenance()
        redo.load(program: inty.stacks[.vecInt]!.first!.crux())
        redo.run()
        #expect(stackString(redo, .vecInt) == "[ [3, 4] ]")
    }
}
