//
//  Item Archive Tests.swift
//  PlungeTests
//
//  Opt-in history encoding: `ItemArchive` carries items with their histories,
//  writing each shared node once.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct ItemArchiveTests {

    private func encoded(_ items: [any Item]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(ItemArchive(items))
    }

    private func decoded(_ data: Data) throws -> [any Item] {
        try JSONDecoder().decode(ItemArchive.self, from: data).items
    }

    private func table(_ items: [any Item]) throws -> ArchiveTable {
        try JSONDecoder().decode(ArchiveTable.self, from: try encoded(items))
    }

    /// The same value, the same crux and the same measures.
    private func expectSame(_ original: any Item, _ copy: any Item, _ comment: Comment? = nil) {
        #expect(copy.isEqual(to: original), comment)
        #expect(CodeItem(copy.crux()).pretty() == CodeItem(original.crux()).pretty(), comment)
        #expect(copy.callWeight == original.callWeight, comment)
        #expect(copy.callDepth == original.callDepth, comment)
    }

    private func run(_ program: [any Item], inputs: [PushInstruction: any Item] = [:]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, constants: [:], program: program)
        inty.run(stepLimit: 2_000)
        return inty
    }

    @Test func `a history survives encoding, where AnyItem drops it`() throws {
        let inty = run([IntItem(0), CodeItem([IntItem(1), InstructionItem(.intAdd)]), IntItem(5),
                        InstructionItem(.execDoTimes), InstructionItem(.intInc)])
        let six = topItem(inty, .int)
        #expect(six.crux().count > 5, "a loop's history, not a literal")

        let copy = try #require(try decoded(try encoded([six])).first)
        expectSame(six, copy)

        // The value-only envelope is unchanged: a literal comes back.
        let plain = try JSONDecoder().decode(AnyItem.self, from: try JSONEncoder().encode(AnyItem(six))).item
        #expect(plain.isEqual(to: six))
        #expect(plain.call.isEmpty)
    }

    /// Each value built from the two before it: a tree of 2^30 leaves, a table of
    /// a few dozen nodes.
    @Test func `a shared history is written once per node`() throws {
        var item = IntItem(1)
        for _ in 1...30 {
            item = IntItem(item.value * 2, call: [item, item, InstructionItem(.intAdd)])
        }
        // Weighed with each reuse counted once (`CallMeasure.withReuse`), not as
        // the tree's 2^30 leaves.
        #expect(item.callWeight < 1_000)

        let nodes = try table([item]).nodes
        #expect(nodes.count == 32, "30 levels, the leaf 1, and one .intAdd")
        let copy = try #require(try decoded(try encoded([item])).first)
        expectSame(item, copy)
    }

    /// Decoding shares what the original shared, so encoding again gives the same
    /// table: across items, too.
    @Test func `encoding is a fixed point`() throws {
        let inty = run([IntItem(3), InstructionItem(.intDup), InstructionItem(.intDup), InstructionItem(.intMultiply),
                        InstructionItem(.intAdd), InstructionItem(.intDup), InstructionItem(.intInc)])
        let items = inty.stacks[.int]!.map { $0 }
        let first = try encoded(items)
        let copies = try decoded(first)
        #expect(try encoded(copies) == first)
        for (original, copy) in zip(items, copies) { expectSame(original, copy) }
    }

    @Test func `members, nested histories, stand-ins and laps all come back`() throws {
        // A vector whose element was computed: its members.
        let vector = topItem(run([VecIntItem([9]), IntItem(2), IntItem(3), InstructionItem(.intAdd),
                                  InstructionItem(.vecIntConj)]), .vecInt)
        // A block whose contents carry their histories, and a stand-in.
        let block = CodeItem([IntItem(5, call: [IntItem(2), IntItem(3), InstructionItem(.intAdd)]),
                              StandInItem(standingInFor: IntItem(4), source: .boolStackDepth, reason: .observed)])
        // A cycling walk over a computed vector.
        let walk = IteratorItem(kind: .elements(into: nil), origin: vector, body: CodeItem([InstructionItem(.intInc)]),
                                emits: true, cursor: 2, laps: 3, burial: 1)
        let copies = try decoded(try encoded([vector, block, walk]))
        #expect(copies.count == 3)
        for (original, copy) in zip([vector, block, walk] as [any Item], copies) { expectSame(original, copy) }

        let members = try #require((copies[0] as? VecIntItem)?.members)
        let first = try #require((vector as? VecIntItem)?.members)
        #expect(members.count == first.count)
        let five = try #require((copies[0] as? VecIntItem)?.traced(at: 1, .on))
        #expect(CodeItem(five.crux()).pretty() == "( 2 3 .intAdd )")
        let contents = try #require(copies[1].exactly(CodeItem.self)?.value)
        #expect(CodeItem(contents[0].crux()).pretty() == "( 2 3 .intAdd )")
        #expect(contents[1].pretty() == StandInItem(standingInFor: IntItem(4), source: .boolStackDepth,
                                                   reason: .observed).pretty())
        #expect((copies[2] as? IteratorItem)?.laps == 3)
        #expect(try #require((copies[2] as? IteratorItem)?.origin).callWeight == vector.callWeight)
    }

    /// `AnyItem` dropped `laps` until 2026-11-08, so a cycling walk came back as
    /// one lap.
    @Test func `the value-only envelope keeps an iterator's laps`() throws {
        let walk = IteratorItem(kind: .elements(into: nil), origin: VecIntItem([1, 2]), emits: true, laps: 4)
        let copy = try JSONDecoder().decode(AnyItem.self, from: try JSONEncoder().encode(AnyItem(walk))).item
        #expect((copy as? IteratorItem)?.laps == 4)
    }

    /// The weight the push boundary measured (a shared history weighed as its
    /// crux) is kept, not recomputed from the tree.
    @Test func `a remeasured weight is kept`() throws {
        let inty = Interpreter.recordingProvenance()
        inty.config.maxCallWeight = 100
        var item = IntItem(1)
        for _ in 1...12 { item = IntItem(item.value * 2, call: [item, item, InstructionItem(.intAdd)]) }
        inty.push(item, to: .int)
        let kept = topItem(inty, .int)
        #expect(kept.callWeight < item.callWeight)
        let copy = try #require(try decoded(try encoded([kept])).first)
        #expect(copy.callWeight == kept.callWeight)
    }

    @Test func `a reference to a later node is refused`() throws {
        let json = #"{"nodes":[{"call":[1],"scalar":{"type":"int","value":1}},"#
            + #"{"scalar":{"type":"int","value":2}}],"roots":[0]}"#
        #expect(throws: ArchiveError.badReference(1, inNode: 0)) {
            try JSONDecoder().decode(ItemArchive.self, from: Data(json.utf8))
        }
    }

    /// Every item random programs leave, on every stack, comes back with the same
    /// value, crux and measures, and encodes again to the same table.
    @Test(arguments: [("equal shares", InstructionMix.equalShares), ("loop-heavy", InstructionMix.loopHeavy),
                      ("container-heavy", InstructionMix.containerHeavy)])
    func `random programs' items round-trip`(name: String, mix: InstructionMix) throws {
        var checked = 0
        try withFuzzSeed(22) {
            for _ in 0..<30 {
                let program = FibonacciGenome.translate(RandomCode.randomProgram(150, mix: mix))
                let inty = Interpreter.recordingProvenance()
                inty.load(program: program)
                RandomCode.setRandomInputs(in: inty)
                RandomCode.setRandomConstants(in: inty)
                inty.run(stepLimit: 1_000)

                let items = PushStack.allStacks.flatMap { inty.stacks[$0]! }
                let first = try encoded(items)
                let copies = try decoded(first)
                #expect(try encoded(copies) == first, "\(name)")
                for (original, copy) in zip(items, copies) { expectSame(original, copy, "\(name)") }
                checked += items.count
            }
        }
        #expect(checked > 100)
    }
}
