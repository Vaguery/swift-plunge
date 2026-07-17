//
//  CodeFromIterator Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/17/26.
//
//  The general form of collecting: box everything an iterator emits into one
//  block.
//
//  The claim worth testing is **totality**. A CodeItem is the vector-of-anything,
//  so every iterator that emits anything at all has an answer here — most of these
//  tests are cases `.vecFromIterator` has to turn away, collecting without
//  complaint. Read the pair the right way round and the asymmetry disappears: a
//  vector is the special case where the emissions are uniform scalars.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeFromIteratorTests {

    func loaded(_ iterator: IteratorItem) -> Interpreter {
        let inty = Interpreter()
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


    // MARK: - it never refuses

    /// Everything `.vecFromIterator` turns away, collected without complaint —
    /// which is the whole point of the pair existing.
    @Test func `the cases no vector holds all collect into a block`() {
        let cases: [(String, IteratorItem, String)] = [
            (
                "a string's chars, which have no vector at all",
                walking(StringItem("abc")),
                "[ ( 'a' 'b' 'c' ) ]"
            ),
            (
                "a mixed block",
                walking(CodeItem([IntItem(1), BoolItem(true)])),
                "[ ( 1 true ) ]"
            ),
            (
                "a block of blocks — what a tree walk will emit",
                walking(CodeItem([CodeItem([IntItem(1)]), CodeItem([IntItem(2)])])),
                "[ ( ( 1 ) ( 2 ) ) ]"
            ),
            (
                "instructions, which are pending work rather than values",
                walking(CodeItem([InstructionItem(.intAdd), InstructionItem(.intSubtract)])),
                "[ ( .intAdd .intSubtract ) ]"
            ),
            (
                "a repeating iterator carrying a block",
                IteratorItem(
                    kind: .repeating(into: nil),
                    origin: CodeItem([IntItem(9)]),
                    destination: IntItem(2),
                    body: nil,
                    emits: true
                ),
                "[ ( ( 9 ) ( 9 ) ) ]"
            ),
            (
                "vectors, which have no vector of their own",
                IteratorItem(
                    kind: .repeating(into: nil),
                    origin: VecIntItem([1, 2]),
                    destination: IntItem(2),
                    body: nil,
                    emits: true
                ),
                "[ ( [1, 2] [1, 2] ) ]"
            ),
        ]
        for (what, iterator, expected) in cases {
            let inty = loaded(iterator)
            doThis(.codeFromIterator, to: inty)
            #expect(stackString(inty, .code) == expected, "\(what)")
            #expect(errorStrings(inty).isEmpty, "\(what): nothing to complain about")
        }
    }

    /// And the cases a vector *does* hold collect here too — this is the general
    /// form, not the leftovers.
    @Test func `a scalar sequence collects into a block as readily`() {
        let inty = loaded(walking(VecIntItem([1, 2, 3])))
        doThis(.codeFromIterator, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 2 3 ) ]")
    }

    /// One of the few genuine producers of `.code` — the language's structurally
    /// scarcest resource. Two ints in, a four-point block out, and nothing on the
    /// stack it came from.
    @Test func `a counting iterator makes code out of ints`() {
        let inty = Interpreter()
        inty.load(program: [
            IntItem(0), IntItem(4), IntItem(1),
            IntItem(0), IntItem(0),
            BoolItem(true), CodeItem([]),
            InstructionItem(.iteratorFromIntRange),
            InstructionItem(.codeFromIterator),
        ])
        inty.run()

        #expect(stackString(inty, .code) == "[ ( 0 1 2 3 ) ]")
        #expect(stackString(inty, .int) == "[ ]")
    }

    /// `( )` is a perfectly good value, which is exactly the difference from the
    /// vector form: an empty vector of *no particular type* is a question with no
    /// answer, so that one has to refuse where this one does not.
    @Test func `an empty collect is the empty block`() {
        // A counting iterator whose projection overflows emits nothing at all —
        // the only way to reach an empty collect, since a spent iterator cannot
        // rest on a stack to be collected.
        let inty = loaded(
            IteratorItem(
                kind: .counting(stride: Int.max),
                origin: IntItem(Int.max),
                destination: IntItem(Int.max),
                body: nil,
                emits: true,
                cursor: 3
            )
        )
        doThis(.codeFromIterator, to: inty)

        #expect(stackString(inty, .code) == "[ ( ) ]")
        #expect(errorStrings(inty).isEmpty)
    }


    // MARK: - what it does to the loop

    /// The body is handed back — the same farewell every ending pays — but the
    /// **result lands on top of it**. Both go to `.code`, and a crux fragment has
    /// to leave its value where the next instruction will find it.
    @Test func `the collected block lands on top of the body it hands back`() {
        let inty = loaded(walking(VecIntItem([1, 2]), body: CodeItem([IntItem(99)])))
        doThis(.codeFromIterator, to: inty)

        #expect(stackString(inty, .code) == "[ ( 1 2 ) ( 99 ) ]")
        #expect(inty.stacks[.iterator]!.isEmpty, "collected to exhaustion, so gone")
        #expect(stackString(inty, .int) == "[ ]", "the body is handed back unrun")
    }


    // MARK: - provenance

    /// Law 3, exactly as the vector form: the block records its iterator and this
    /// instruction, and the iterator's record rebuilds it at its cursor.
    @Test func `a collected block reproduces itself`() {
        var iterator = walking(VecIntItem([4, 5, 6]))
        iterator.call = iterator.reconstruction()
        let inty = loaded(iterator)
        doThis(.codeFromIterator, to: inty)

        let block = inty.stacks[.code]!.first!
        #expect(CodeItem(block.crux()).pretty()
                == "( [4, 5, 6] 0 0 true ( ) .iteratorFromVecInt .codeFromIterator )")

        let redo = Interpreter()
        redo.load(program: block.crux())
        redo.run()
        #expect(stackString(redo, .code) == "[ ( 4 5 6 ) ]")
        #expect(CodeItem(redo.stacks[.code]!.first!.crux()).pretty()
                == CodeItem(block.crux()).pretty(), "and is a fixed point")
    }

    /// The elements keep their own `call`s, so the block's contents can still say
    /// where each of them came from — this is law 1b working in the collector's
    /// favour rather than against it.
    @Test func `the collected elements keep their own provenance`() {
        var iterator = walking(VecIntItem([4, 5, 6]))
        iterator.call = iterator.reconstruction()
        let inty = loaded(iterator)
        doThis(.codeFromIterator, to: inty)

        let block = inty.stacks[.code]!.first as! CodeItem
        #expect(CodeItem(block.value[1].crux()).pretty() == "( [4, 5, 6] 1 .vecIntNth )")
    }


    // MARK: - size

    /// "Sometimes large" is the push gate's business, and it already has two
    /// numbers for it. Nothing here truncates.
    @Test func `an oversized block is refused by the push gate`() {
        let inty = loaded(walking(VecIntItem(Array(1...500))))
        var settings = InterpreterSettings()
        settings.maxCodePoints = 100
        inty.config = settings

        doThis(.codeFromIterator, to: inty)

        #expect(stackString(inty, .code) == "[ ]")
        #expect(errorStrings(inty).contains { $0.contains("maxCodePoints") })
    }
}
