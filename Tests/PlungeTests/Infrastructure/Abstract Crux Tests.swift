//
//  Abstract Crux Tests.swift
//  PlungeTests
//
//  A distilled crux with typed holes for its inputs, constants and values
//  (`AbstractCrux`, 2026-11-15).
//

@testable import Plunge
import Testing

@Suite
struct AbstractCruxTests {

    typealias Distilled = DistilledCruxTests

    static func abstract(_ program: [any Item], on stack: PushStack,
                         _ reading: AbstractCrux.Reading = .perDistinct) -> AbstractCrux {
        Distilled.top(program, on: stack).distilledCrux().abstracted(reading)!
    }

    @Test func `inputs and constants become typed holes`() {
        let abstract = Self.abstract(Distilled.ins(.input0, .int0, .intAdd), on: .int)
        #expect(abstract.key == "«fn (int, int) -> int: $0 $1 .intAdd»")
        #expect(abstract.roles.count == 2)
        guard case .input(.input0) = abstract.roles[0], case .constant(.int0) = abstract.roles[1] else {
            Issue.record("roles \(abstract.roles)")
            return
        }
    }

    @Test func `which input or constant was read does not change the key`() {
        let one = Self.abstract(Distilled.ins(.input0, .int0, .intAdd), on: .int)
        let other = Self.abstract(Distilled.ins(.int1, .input0, .intAdd), on: .int)
        #expect(one.key == other.key)
    }

    @Test func `the same input used twice is one hole, or two`() {
        let program = Distilled.ins(.input0, .input0, .intMultiply)
        let distinct = Self.abstract(program, on: .int, .perDistinct)
        let perUse = Self.abstract(program, on: .int, .perUse)
        #expect(distinct.function.holes.count == 1)
        #expect(distinct.key == "«fn (int) -> int: $0 $0 .intMultiply»")
        #expect(perUse.function.holes.count == 2)
        #expect(perUse.key == "«fn (int, int) -> int: $0 $1 .intMultiply»")
    }

    @Test func `a derived constant is a hole of its own`() {
        let abstract = Self.abstract([IntItem(2), IntItem(3)] + Distilled.ins(.intAdd, .input0, .intMultiply), on: .int)
        #expect(abstract.key == "«fn (int, int) -> int: $0 $1 .intMultiply»")
        guard case .derived(let value) = abstract.roles[0] else {
            Issue.record("roles \(abstract.roles)")
            return
        }
        #expect(value.pretty() == "5")
    }

    @Test func `filling the holes with what was there replays the value`() {
        let item = Distilled.top(Distilled.ins(.int0, .int1, .intMultiply, .input0, .intAdd, .input0, .intMultiply)
                                 + [IntItem(4)] + Distilled.ins(.intSubtract), on: .int)
        let abstract = item.distilledCrux().abstracted()!
        let program = abstract.program(filling: abstract.originalFillers!)
        #expect(Distilled.replay(program, on: .int)?.pretty() == item.pretty())
    }

    @Test func `other fillers give another function's value`() {
        let abstract = Self.abstract(Distilled.ins(.input0, .int0, .intAdd), on: .int)
        let program = abstract.program(filling: [IntItem(10), IntItem(32)])
        #expect(Distilled.replay(program, on: .int)?.pretty() == "42")
    }

    @Test func `an abstract crux is a function the language can apply`() {
        let abstract = Self.abstract(Distilled.ins(.input0, .int0, .intMultiply), on: .int)
        let inty = Interpreter()
        inty.load(stacks: [.function: [abstract.function]],
                  program: [IntItem(6), IntItem(7), InstructionItem(.functionApply)])
        inty.run()
        #expect(inty.stacks[.int]!.first?.pretty() == "42")
    }

    @Test func `a subtree can be opened into a hole of its type`() {
        // ( .input0 .int0 .intAdd ) .input1 .stringLength .intMultiply: open the string length. A
        // length leaves its string, so the crux clears it: `1 .stringPopItems`.
        let item = Distilled.top(Distilled.ins(.input0, .int0, .intAdd, .input1, .stringLength, .intMultiply), on: .int)
        let abstract = item.distilledCrux().abstracted()!
        #expect(abstract.key
                == "«fn (int, int, str) -> int: $0 $1 .intAdd $2 .stringLength 1 .stringPopItems .intMultiply»")
        let body = abstract.function.value
        let length = abstract.subtrees.first { span in
            span.stack == .int && body[span.start..<span.end].contains {
                $0.exactly(InstructionItem.self)?.value == .stringLength
            } && !body[span.start..<span.end].contains { $0.exactly(InstructionItem.self)?.value == .intMultiply }
        }
        let opened = length.flatMap(abstract.opening)
        #expect(opened?.key == "«fn (int, int, int) -> int: $0 $1 .intAdd $2 .intMultiply»")
        guard let opened, case .open(.int) = opened.roles[2] else {
            Issue.record("opened \(String(describing: opened?.roles))")
            return
        }
        let program = opened.program(filling: [IntItem(1), IntItem(2), IntItem(10)])
        #expect(Distilled.replay(program, on: .int)?.pretty() == "30")
    }
}
