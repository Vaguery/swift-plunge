//
//  Unbounded Collection Tests.swift
//  PlungeTests
//
//  Regression for a search-killing hang (2026-11-04). A counting iterator with
//  stride 0 never moves, so it never reaches its end; `promisedPasses` had no span
//  to measure, so `clamped(toPasses:)` never capped it; and `.codeFromIterator`
//  drives an iterator to exhaustion *inside one step*, where `stepLimit` cannot see
//  it. One evolved program doing `… 0 … .iteratorFromIntRange .codeFromIterator`
//  pinned every core and grew memory without bound, and the generation (or the
//  seed) waiting on it never finished.
//
//  Two fixes, tested separately: the constructor refuses stride 0, and collecting
//  has a backstop (`IteratorItem.collectionLimit`) for any iterator that reaches a
//  stack some other way.
//

@testable import Plunge
import Testing
import DequeModule

@Suite @MainActor
struct UnboundedCollectionTests {

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    /// The exact shape the hung search evolved, run end to end.
    @Test func `a stride-0 range is refused, so collecting it finishes`() {
        let inty = Interpreter()
        inty.load(program: [
            // origin dest stride cursor burial
            IntItem(0), IntItem(10), IntItem(0), IntItem(0), IntItem(0),
            BoolItem(false), CodeItem([]),
            InstructionItem(.iteratorFromIntRange),
            InstructionItem(.codeFromIterator)
        ])
        inty.run()

        #expect(inty.stacks[.iterator]!.isEmpty, "no iterator was built")
        #expect(errorStrings(inty).contains { $0.hasPrefix("Zero stride .iteratorFromIntRange") })
    }

    /// A stride-0 counter that never reaches its end, placed directly on `.iterator`:
    /// the way one might still arrive (a decoded state, a future constructor).
    func neverArriving() -> IteratorItem {
        IteratorItem(
            kind: .counting(stride: 0),
            origin: IntItem(0),
            destination: IntItem(10),
            emits: true
        )
    }

    @Test func `collecting an endless iterator into code refuses instead of hanging`() {
        let inty = Interpreter()
        inty.stacks[.iterator]!.prepend(neverArriving())
        doThis(.codeFromIterator, to: inty)

        #expect(inty.stacks[.iterator]!.count == 1, "the iterator is handed back")
        #expect(inty.stacks[.code]!.isEmpty, "nothing was collected")
        #expect(errorStrings(inty).contains { $0.contains("emits more than") })
    }

    @Test func `collecting an endless iterator into a vector refuses instead of hanging`() {
        let inty = Interpreter()
        inty.stacks[.iterator]!.prepend(neverArriving())
        doThis(.vecFromIterator, to: inty)

        #expect(inty.stacks[.iterator]!.count == 1, "the iterator is handed back")
        #expect(inty.stacks[.vecInt]!.isEmpty, "nothing was collected")
        #expect(errorStrings(inty).contains { $0.contains("emits more than") })
    }

    /// A loop buried `Int.max` deep used to overflow `payload + burial` and trap
    /// the process. It now lands at the bottom of `.exec`, and the loop runs.
    @Test func `an Int.max burial does not trap`() {
        let inty = Interpreter()
        inty.stacks[.iterator]!.prepend(IteratorItem(
            kind: .counting(stride: 1),
            origin: IntItem(0),
            destination: IntItem(3),
            body: CodeItem([IntItem(7)]),
            emits: false,
            burial: Int.max
        ))
        doThis(.iteratorPlay, to: inty)
        inty.run()
        #expect(inty.stacks[.int]!.count == 3, "three passes, each pushing 7")
    }

    /// The backstop changes nothing a legitimate iterator produces: under default
    /// settings a collection that long would already be refused at push by weight.
    @Test func `the backstop sits at the default item-weight cap`() {
        #expect(IteratorItem.collectionLimit == InterpreterSettings().maxItemWeight)
    }
}
