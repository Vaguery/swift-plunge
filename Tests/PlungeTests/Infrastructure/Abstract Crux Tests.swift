//
//  Abstract Crux Tests.swift
//  PlungeTests
//
//  A distilled crux with typed holes for its constants, its inputs in place (the
//  abstract crux), or for its inputs too (the skeleton crux) (`AbstractCrux`,
//  2026-11-15).
//

@testable import Plunge
import Testing

@Suite
struct AbstractCruxTests {

    typealias Distilled = DistilledCruxTests

    static func distilled(_ program: [any Item], on stack: PushStack) -> DistilledCrux {
        Distilled.top(program, on: stack).distilledCrux()
    }

    static func abstract(_ program: [any Item], on stack: PushStack,
                         _ reading: AbstractCrux.Reading = .perDistinct) -> AbstractCrux {
        distilled(program, on: stack).abstracted(reading)!
    }

    static func skeleton(_ program: [any Item], on stack: PushStack,
                         _ reading: AbstractCrux.Reading = .perDistinct) -> AbstractCrux {
        distilled(program, on: stack).skeleton(reading)!
    }

    // MARK: - The abstract crux: constants as holes, inputs in place

    @Test func `constants become typed holes and inputs stay`() {
        let abstract = Self.abstract(Distilled.ins(.input(0), .constant(0), .intAdd), on: .int)
        #expect(abstract.key == "«fn (int) -> int: .input0 $0 .intAdd»")
        guard abstract.roles.count == 1, case .constant(.constant(0)) = abstract.roles[0] else {
            Issue.record("roles \(abstract.roles)")
            return
        }
    }

    @Test func `which constant was read does not change the key, but which input does`() {
        let one = Self.abstract(Distilled.ins(.input(0), .constant(0), .intAdd), on: .int)
        #expect(one.key == Self.abstract(Distilled.ins(.input(0), .constant(1), .intAdd), on: .int).key)
        #expect(one.key != Self.abstract(Distilled.ins(.input(1), .stringLength, .constant(0), .intAdd), on: .int).key)
    }

    @Test func `the same constant used twice is one hole, or two`() {
        let program = Distilled.ins(.constant(0), .input(0), .intMultiply, .constant(0), .intAdd)
        let distinct = Self.abstract(program, on: .int, .perDistinct)
        let perUse = Self.abstract(program, on: .int, .perUse)
        #expect(distinct.key == "«fn (int) -> int: $0 .input0 .intMultiply $0 .intAdd»")
        #expect(perUse.key == "«fn (int, int) -> int: $0 .input0 .intMultiply $1 .intAdd»")
    }

    @Test func `a derived constant is a hole of its own`() {
        let abstract = Self.abstract([IntItem(2), IntItem(3)] + Distilled.ins(.intAdd, .input(0), .intMultiply), on: .int)
        #expect(abstract.key == "«fn (int) -> int: $0 .input0 .intMultiply»")
        guard case .derived(let value) = abstract.roles[0] else {
            Issue.record("roles \(abstract.roles)")
            return
        }
        #expect(value.pretty() == "5")
    }

    @Test func `filling the holes with what was there replays the value`() {
        let item = Distilled.top(Distilled.ins(.constant(0), .constant(1), .intMultiply, .input(0), .intAdd, .input(0), .intMultiply)
                                 + [IntItem(4)] + Distilled.ins(.intSubtract), on: .int)
        for abstract in [item.distilledCrux().abstracted()!, item.distilledCrux().skeleton()!] {
            let program = abstract.program(filling: abstract.originalFillers!)
            #expect(Distilled.replay(program, on: .int)?.pretty() == item.pretty())
        }
    }

    @Test func `other constants give another fit of the same model`() {
        // .input0 is 5.
        let abstract = Self.abstract(Distilled.ins(.input(0), .constant(0), .intAdd), on: .int)
        #expect(Distilled.replay(abstract.program(filling: [IntItem(37)]), on: .int)?.pretty() == "42")
    }

    // MARK: - The skeleton crux: inputs as holes too

    @Test func `a skeleton has holes for inputs and constants alike`() {
        let skeleton = Self.skeleton(Distilled.ins(.input(0), .constant(0), .intAdd), on: .int)
        #expect(skeleton.key == "«fn (int, int) -> int: $0 $1 .intAdd»")
        guard case .input(.input(0)) = skeleton.roles[0], case .constant(.constant(0)) = skeleton.roles[1] else {
            Issue.record("roles \(skeleton.roles)")
            return
        }
    }

    @Test func `which input or constant was read does not change a skeleton`() {
        let one = Self.skeleton(Distilled.ins(.input(0), .constant(0), .intAdd), on: .int)
        let other = Self.skeleton(Distilled.ins(.constant(1), .input(0), .intAdd), on: .int)
        #expect(one.key == other.key)
    }

    @Test func `the same input used twice is one hole, or two`() {
        let program = Distilled.ins(.input(0), .input(0), .intMultiply)
        let distinct = Self.skeleton(program, on: .int, .perDistinct)
        let perUse = Self.skeleton(program, on: .int, .perUse)
        #expect(distinct.key == "«fn (int) -> int: $0 $0 .intMultiply»")
        #expect(perUse.key == "«fn (int, int) -> int: $0 $1 .intMultiply»")
    }

    @Test func `other fillers give another function's value`() {
        let skeleton = Self.skeleton(Distilled.ins(.input(0), .constant(0), .intAdd), on: .int)
        #expect(Distilled.replay(skeleton.program(filling: [IntItem(10), IntItem(32)]), on: .int)?.pretty() == "42")
    }

    @Test func `a skeleton is a function the language can apply`() {
        let skeleton = Self.skeleton(Distilled.ins(.input(0), .constant(0), .intMultiply), on: .int)
        let inty = Interpreter()
        inty.load(stacks: [.function: [skeleton.function!]],
                  program: [IntItem(6), IntItem(7), InstructionItem(.functionApply)])
        inty.run()
        #expect(inty.stacks[.int]!.first?.pretty() == "42")
    }

    @Test func `a subtree can be opened into a hole of its type`() {
        // ( .input0 .constant0 .intAdd ) .input1 .stringLength .intMultiply: open the string length. A
        // length leaves its string, so the crux clears it: `1 .stringPopItems`.
        let item = Distilled.top(Distilled.ins(.input(0), .constant(0), .intAdd, .input(1), .stringLength, .intMultiply), on: .int)
        let skeleton = item.distilledCrux().skeleton()!
        #expect(skeleton.key
                == "«fn (int, int, str) -> int: $0 $1 .intAdd $2 .stringLength 1 .stringPopItems .intMultiply»")
        let body = skeleton.template
        let length = skeleton.subtrees.first { span in
            span.stack == .int && body[span.start..<span.end].contains {
                $0.exactly(InstructionItem.self)?.value == .stringLength
            } && !body[span.start..<span.end].contains { $0.exactly(InstructionItem.self)?.value == .intMultiply }
        }
        let opened = length.flatMap(skeleton.opening)
        #expect(opened?.key == "«fn (int, int, int) -> int: $0 $1 .intAdd $2 .intMultiply»")
        guard let opened, case .open(.int) = opened.roles[2] else {
            Issue.record("opened \(String(describing: opened?.roles))")
            return
        }
        let program = opened.program(filling: [IntItem(1), IntItem(2), IntItem(10)])
        #expect(Distilled.replay(program, on: .int)?.pretty() == "30")
    }
}
