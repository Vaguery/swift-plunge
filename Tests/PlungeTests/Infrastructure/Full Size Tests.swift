//
//  Full Size Tests.swift
//  PlungeTests
//
//  A history's full size: every compression undone in the count, so a crux is
//  as big as the work it records however it is written (2026-11-20).
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct FullSizeTests {

    static let inputs: [PushInstruction: any Item] = [.input(0): IntItem(5)]

    static func top(_ program: [any Item], maxCallWeight: Int? = nil) -> any Item {
        let inty = Interpreter.recordingProvenance()
        if let maxCallWeight { inty.config.maxCallWeight = maxCallWeight }
        inty.load(inputs: inputs, constants: [:], program: program)
        inty.run(stepLimit: 100_000)
        return inty.stacks[.int]!.first!
    }

    static func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }

    /// `.input0`, then `passes` passes of `3 .intAdd`.
    static func loop(_ passes: Int) -> [any Item] {
        ins(.input(0)) + [IntItem(passes), CodeItem([IntItem(3)] + ins(.intAdd))] + ins(.execDoTimes)
    }

    @Test func `a history with nothing compressed is as big as its crux`() {
        let item = Self.top(Self.ins(.input(0)) + [IntItem(2)] + Self.ins(.intAdd, .input(0), .intMultiply))
        #expect(item.fullSize == item.crux().count)
    }

    @Test func `a value used twice counts once, as the crux builds it once`() {
        // x·x·x·x by dup: the tree writes x four times, the crux once.
        let item = Self.top(Self.ins(.input(0), .intDup, .intMultiply, .intDup, .intMultiply))
        #expect(item.fullSize == 3)
    }

    @Test func `a folded loop counts every pass, so more passes are bigger`() {
        // A small budget folds the chain into `seed ( body ) K .execDoTimes`.
        let hundred = Self.top(Self.loop(100), maxCallWeight: 40)
        let threeHundred = Self.top(Self.loop(300), maxCallWeight: 40)
        #expect(hundred.crux().contains { $0.exactly(InstructionItem.self)?.value == .execDoTimes })
        // Folded, both cruxes are within the budget, whatever the passes.
        #expect(hundred.crux().count <= 40 && threeHundred.crux().count <= 40)
        // Unfolded, each pass is `3 .intAdd`, after the input.
        #expect(hundred.fullSize == 1 + 2 * 100)
        #expect(threeHundred.fullSize == 1 + 2 * 300)
        // The same loop, never folded, measures the same.
        #expect(Self.top(Self.loop(100)).fullSize == hundred.fullSize)
    }

    @Test func `a crux's full size counts a counted loop's body once per pass`() {
        let crux = Self.ins(.input(0)) + [CodeItem([IntItem(3)] + Self.ins(.intAdd)), IntItem(300)]
            + Self.ins(.execDoTimes, .codePop)
        #expect(CruxCompression.fullSize(crux) == 1 + 2 * 300)
    }

    @Test func `an elided stand-in counts the history it replaced`() {
        // Steps that differ, so no loop folds them and the budget elides them.
        let steps: [any Item] = (1...30).flatMap { n -> [any Item] in [IntItem(n), InstructionItem(.intAdd)] }
        let elided = Self.top(Self.ins(.input(0)) + steps, maxCallWeight: 20)
        let kept = Self.top(Self.ins(.input(0)) + steps)
        #expect(elided.crux().contains { $0.exactly(StandInItem.self)?.reason == .elided })
        #expect(elided.crux().count < 10)
        #expect(elided.fullSize >= kept.fullSize - 20, "the elided part is counted at the size it had")
        #expect(kept.fullSize == 1 + 2 * 30)
    }

    @Test func `distilling changes how a crux is written, not its full size`() {
        let item = Self.top([IntItem(2), IntItem(3)] + Self.ins(.intAdd, .intDup, .intMultiply, .input(0), .intAdd))
        let distilled = item.distilledCrux()
        #expect(distilled.program.count < item.crux().count)
        #expect(distilled.item.fullSize == item.fullSize)
    }

    @Test func `a stand-in's replaced size survives encoding`() throws {
        let worked = Self.top(Self.loop(10))
        let standIn = StandInItem(standingInFor: worked, source: .intAdd, reason: .elided)
        #expect(standIn.replacedSize == worked.fullSize)
        let decoded = try JSONDecoder().decode(AnyItem.self, from: JSONEncoder().encode(AnyItem(standIn))).item
        #expect((decoded as? StandInItem)?.replacedSize == worked.fullSize)
        let observed = StandInItem(standingInFor: worked, source: .intStackDepth, reason: .observed)
        #expect(observed.replacedSize == 1)
    }
}
