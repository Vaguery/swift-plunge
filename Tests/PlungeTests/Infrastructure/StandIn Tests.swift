//
//  StandIn Tests.swift
//  PlungeTests
//
//  A stand-in marks a literal that stands in for a lost history: it runs as that
//  literal, names its cause, and survives into every downstream crux. See
//  `StandInItem`.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct StandInTests {

    /// Runs `program` on a fresh recording interpreter.
    private func run(_ program: [any Item], settings: InterpreterSettings? = nil) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        if let settings { inty.config = settings }
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    @Test func `a state read's crux names its cause and replays to the same item`() {
        let inty = run([BoolItem(true), BoolItem(false), BoolItem(true), InstructionItem(.boolStackDepth)])
        let depth = topItem(inty, .int)
        #expect(depth.pretty() == "3")
        #expect(CodeItem(depth.crux()).pretty() == "( .boolStackDepth_actuallyWas_3 )")

        // The crux alone, on a fresh interpreter: the value, its history, and
        // nothing else on any stack (the composition invariant).
        let replay = run(depth.crux())
        #expect(stackString(replay, .int) == "[ 3 ]")
        #expect(callString(topItem(replay, .int)) == callString(depth))
        #expect(stackString(replay, .bool) == "[ ]")
    }

    @Test func `a stand-in carries into the crux of what is computed from it`() {
        let inty = run([IntItem(7), IntItem(8), InstructionItem(.intStackDepth), InstructionItem(.intAdd)])
        let sum = topItem(inty, .int)
        #expect(sum.pretty() == "10")
        #expect(CodeItem(sum.crux()).pretty() == "( 8 .intStackDepth_actuallyWas_2 .intAdd )")
    }

    @Test func `elision leaves a stand-in that replays to the same item`() {
        var settings = Interpreter.recordingProvenance().config
        settings.maxCallWeight = 5
        // A chain whose history outgrows a 5-weight budget part-way through. Its
        // levels alternate, so it is not a loop's chain and does not fold.
        var program: [any Item] = [IntItem(1)]
        for step in 0..<6 { program += [IntItem(step % 2 + 1), InstructionItem(.intAdd)] }
        let inty = run(program, settings: settings)
        let total = topItem(inty, .int)
        #expect(total.pretty() == "10")
        let leaves = total.crux()
        #expect(leaves.contains { ($0 as? StandInItem)?.reason == .elided },
                "an over-budget history should leave an elided stand-in, got \(CodeItem(leaves).pretty())")

        let replay = run(leaves, settings: settings)
        #expect(topItem(replay, .int).pretty() == "10")
        #expect(callString(topItem(replay, .int)) == callString(total))
    }

    @Test func `a missing-args error names the starved instruction and replays`() {
        let inty = run([InstructionItem(.intAdd)])
        let error = topItem(inty, .error)
        #expect(CodeItem(error.crux()).pretty() == "( .intAdd_actuallyWas_« ‼️ intAdd missing args: .int » )")
        let replay = run(error.crux())
        #expect(topItem(replay, .error).pretty() == error.pretty())
    }

    @Test func `an interpreter diagnostic is a stand-in with no source`() {
        var settings = Interpreter.recordingProvenance().config
        settings.maxStringLength = 3
        let inty = run([StringItem("abcdef")], settings: settings)
        let refusal = topItem(inty, .error)
        #expect(callString(refusal).hasPrefix("( .interpreter_actuallyWas_"))
    }

    @Test func `with recording off nothing is built`() {
        let inty = Interpreter()
        inty.load(program: [BoolItem(true), InstructionItem(.boolStackDepth), InstructionItem(.intAdd)])
        inty.run(stepLimit: 100)
        #expect(topItem(inty, .int).call.isEmpty)
        #expect(topItem(inty, .error).call.isEmpty)
    }

    @Test func `a stand-in in a program runs as a labeled constant`() {
        let five = StandInItem(standingInFor: IntItem(5), source: .intStackDepth, reason: .observed)
        let three = StandInItem(standingInFor: IntItem(3), source: nil, reason: .elided)
        let inty = run([five, three, InstructionItem(.intAdd)])
        #expect(stackString(inty, .int) == "[ 8 ]")
        #expect(three.pretty() == ".interpreter_elidedAs_3")
        // It has no stack of its own, and is a literal leaf.
        #expect(PushStack.defaultStack(for: five) == nil)
        #expect(five.call.isEmpty && five.crux().count == 1)
    }

    @Test func `a stand-in survives the item envelope, alone and inside a block`() throws {
        let standIn = StandInItem(standingInFor: StringItem("hi"), source: .stringStackDepth, reason: .observed)
        let block = CodeItem([IntItem(1), standIn, InstructionItem(.intAdd)])
        for item in [standIn, block] as [any Item] {
            let data = try JSONEncoder().encode(AnyItem(item))
            let decoded = try JSONDecoder().decode(AnyItem.self, from: data).item
            #expect(decoded.pretty() == item.pretty())
            #expect(decoded.isEqual(to: item))
        }
    }
}
