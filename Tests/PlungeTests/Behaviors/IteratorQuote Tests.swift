//
//  IteratorQuote Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/17/26.
//
//  Parking a live loop on `.code`, and getting it back.
//
//  The other quotes lift a value out of reach of its own stack's combinators.
//  This one lifts a **loop** out of reach of a pending continuation — which
//  matters because `.iteratorPlay` is anonymous: it advances whatever is on top of
//  `.iterator`, so before this the only way to stop a loop being advanced was to
//  own a second loop to displace it with. A lone iterator could be re-aimed or
//  killed, never shelved.
//
//  So the test that matters is not "it makes a block". It is the **round trip**:
//  a loop parked mid-flight comes back at the cursor it left at, and finishes.
//

@testable import Plunge
import Testing
import DequeModule

@Suite @MainActor
struct IteratorQuoteTests {

    func counting(to destination: Int = 4, cursor: Int = 0) -> IteratorItem {
        var iterator = IteratorItem(
            kind: .counting(stride: 1),
            origin: IntItem(0),
            destination: IntItem(destination),
            body: nil,
            emits: true,
            cursor: cursor
        )
        iterator.call = iterator.reconstruction()   // as a constructor would leave it
        return iterator
    }

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }


    // MARK: - out and back

    @Test func `quoting parks the loop on code`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.iterator]!.prepend(counting())
        doThis(.iteratorQuote, to: inty)

        #expect(stackString(inty, .code) == "[ ( «0→4 by 1 @0» ) ]")
        #expect(inty.stacks[.iterator]!.isEmpty, "and off .iterator, which is the point")
    }

    /// **The return trip, and it needed nothing new.** `.codeDo` unwraps the block
    /// onto `.exec`; an iterator is not an instruction, so `pushDefault` routes it
    /// home to `.iterator`.
    @Test func `codeDo gives the loop back`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.iterator]!.prepend(counting(cursor: 2))
        inty.stacks[.exec] = Deque([
            InstructionItem(.iteratorQuote),
            InstructionItem(.codeDo)
        ] as [any Item])
        inty.run()

        let returned = inty.stacks[.iterator]!.first as? IteratorItem
        #expect(returned?.value == 2, "back at the cursor it left at")
        #expect(returned?.isEqual(to: counting(cursor: 2)) == true)
        #expect(stackString(inty, .code) == "[ ]", "and the box is gone")
    }

    /// The whole reason this exists: a pending `.iteratorPlay` cannot reach a
    /// parked loop. Here the token fires while the loop is boxed, finds nothing,
    /// and says so — then the loop comes back and finishes.
    @Test func `a parked loop is out of a pending continuation's reach`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.iterator]!.prepend(counting())
        inty.stacks[.exec] = Deque([
            InstructionItem(.iteratorQuote),
            InstructionItem(.iteratorPlay),     // fires at an empty .iterator
            InstructionItem(.codeDo),           // unpark
            InstructionItem(.iteratorPlay)     // and away it goes
        ] as [any Item])
        inty.run()

        #expect(errorStrings(inty) == ["iteratorPlay missing args: .iterator"],
                "the token could not touch it")
        #expect(stackString(inty, .int) == "[ 3 2 1 0 ]", "and afterwards it ran to completion")
    }

    /// Law 1b, and the reason parking is lossless: an item that goes into a block
    /// and comes back out is the item that went in. A loop keeps its body across
    /// the trip.
    @Test func `a parked loop keeps its body`() {
        var iterator = counting()
        iterator.body = CodeItem([StringItem("tick")])
        iterator.call = iterator.reconstruction()

        let inty = Interpreter.recordingProvenance()
        inty.stacks[.iterator]!.prepend(iterator)
        inty.stacks[.exec] = Deque([
            InstructionItem(.iteratorQuote),
            InstructionItem(.codeDo),
            InstructionItem(.iteratorPlay)
        ] as [any Item])
        inty.run()

        #expect(stackString(inty, .string) == "[ \"tick\" \"tick\" \"tick\" \"tick\" ]")
    }


    // MARK: - provenance

    /// Law 2: relocation across stacks is not free, and it records exactly as the
    /// other quotes do. The iterator's own `call` rebuilds it by state, so the
    /// block reproduces a loop **at the cursor it was parked at** — which is the
    /// whole point of shelving one.
    @Test func `a parked loop reproduces itself, cursor and all`() {
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.iterator]!.prepend(counting(cursor: 2))
        doThis(.iteratorQuote, to: inty)

        let block = inty.stacks[.code]!.first!
        #expect(CodeItem(block.crux()).pretty()
                == "( 0 4 1 ( ) 2 0 true .iteratorFromIntRange .iteratorQuote )")

        let redo = Interpreter.recordingProvenance()
        redo.load(program: block.crux())
        redo.run()

        #expect(stackString(redo, .code) == "[ ( «0→4 by 1 @2» ) ]")
        #expect(CodeItem(redo.stacks[.code]!.first!.crux()).pretty()
                == CodeItem(block.crux()).pretty(), "and is a fixed point")
    }
}
