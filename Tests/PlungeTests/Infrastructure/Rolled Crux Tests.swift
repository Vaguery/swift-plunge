//
//  Rolled Crux Tests.swift
//  PlungeTests
//
//  The abstract, tunable and skeleton cruxes are built on the rolled form:
//  repeats in the history rolled back into counted loops, so a constant in a
//  loop's body is one hole for every pass (2026-11-15).
//

@testable import Plunge
import Testing

@Suite
struct RolledCruxTests {

    typealias Distilled = DistilledCruxTests

    static func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }

    /// `0 ( .input0 .intAdd 12 .intMin ) 50 .execDoTimes`: adds the input (5)
    /// fifty times, never past 12.
    static let loop: [any Item] = [IntItem(0), CodeItem(ins(.input(0), .intAdd) + [IntItem(12)] + ins(.intMin)),
                                   IntItem(50), InstructionItem(.execDoTimes)]

    static func distilled(_ program: [any Item]) -> DistilledCrux {
        Distilled.top(program, on: .int).distilledCrux()
    }

    @Test func `a loop's body constant is one hole for every pass`() {
        let abstract = Self.distilled(Self.loop).abstracted()!
        #expect(abstract.key
                == "«fn (int, int, int) -> int: $0 ( .input0 .intAdd $1 .intMin ) $2 .execDoTimes .codePop»")
        let roles = abstract.roles.map { role -> String in
            if case .literal(let value) = role { return value.pretty() }
            return "?"
        }
        #expect(roles == ["0", "12", "50"])
        #expect(Distilled.replay(abstract.program(filling: abstract.originalFillers!), on: .int)?.pretty() == "12")
        // Another cap, fewer passes.
        let refitted = abstract.program(filling: [IntItem(1), IntItem(30), IntItem(4)])
        #expect(Distilled.replay(refitted, on: .int)?.pretty() == "21")
    }

    @Test func `the tunable crux decorates the loop's input once, for every pass`() {
        let tunable = Self.distilled(Self.loop).tunable()!
        #expect(tunable.key == "«fn (int, int, int, int, int) -> int: "
                + "$0 ( .input0 $1 .intMultiply $2 .intAdd .intAdd $3 .intMin ) $4 .execDoTimes .codePop»")
        #expect(Distilled.replay(tunable.program(filling: tunable.originalFillers!), on: .int)?.pretty() == "12")
    }

    @Test func `the skeleton makes the loop's input a hole too`() {
        let skeleton = Self.distilled(Self.loop).skeleton()!
        #expect(skeleton.key
                == "«fn (int, int, int, int) -> int: $0 ( $1 .intAdd $2 .intMin ) $3 .execDoTimes .codePop»")
    }

    @Test func `a structure with holes in a loop's body is a function the language can run`() {
        let abstract = Self.distilled(Self.loop).abstracted()!
        let function = abstract.function!
        #expect(function.pretty() == "«fn (int, int, int) -> int: $0 ( .input0 .intAdd ) $1 .intQuote .codeConcat "
                + "( .intMin ) .codeConcat $2 .execDoTimes .codePop»")
        let program = function.filled(with: [IntItem(0), IntItem(12), IntItem(50)])
        #expect(Distilled.replay(program, on: .int)?.pretty() == "12")
    }

    @Test func `repeats written out by hand are rolled too`() {
        let program: [any Item] = Self.ins(.input(0)) + [IntItem(1), InstructionItem(.intAdd), IntItem(1),
                                                       InstructionItem(.intAdd), IntItem(1), InstructionItem(.intAdd)]
        let abstract = Self.distilled(program).abstracted()!
        #expect(abstract.key == "«fn (int, int) -> int: .input0 ( $0 .intAdd ) $1 .execDoTimes .codePop»")
    }

    @Test func `two passes roll when the body is long enough`() {
        let short: [any Item] = Self.ins(.input(0)) + [IntItem(1), InstructionItem(.intAdd), IntItem(1),
                                                     InstructionItem(.intAdd)]
        #expect(Self.distilled(short).abstracted()!.key == "«fn (int, int) -> int: .input0 $0 .intAdd $1 .intAdd»")
        let pass: [any Item] = [IntItem(2), InstructionItem(.intMultiply), IntItem(1), InstructionItem(.intAdd)]
        let long = Self.distilled(Self.ins(.input(0)) + pass + pass).abstracted()!
        #expect(long.key
                == "«fn (int, int, int) -> int: .input0 ( $0 .intMultiply $1 .intAdd ) $2 .execDoTimes .codePop»")
    }
}
