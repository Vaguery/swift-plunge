//
//  Index Rolling Tests.swift
//  PlungeTests
//
//  Passes that differ by an index, rolled into a counted loop
//  (`CruxCompression.rolledByIndex`, 2026-11-20). Each rolled crux is replayed
//  to the value of the crux it came from.
//

@testable import Plunge
import Testing

@Suite
struct IndexRollingTests {

    static let inputs: [PushInstruction: any Item] = [.input(0): VecIntItem([5, 6, 7, 8, 9]), .input(1): IntItem(4)]

    static func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }
    static func printed(_ crux: [any Item]) -> String { CodeItem(crux).pretty() }

    /// The top int `program` leaves, with its history.
    static func top(_ program: [any Item]) -> any Item {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, constants: [:], program: program)
        inty.run(stepLimit: 10_000)
        return inty.stacks[.int]!.first!
    }

    static func uses(_ crux: [any Item], _ instruction: PushInstruction) -> Bool {
        crux.contains { item in
            (item as? InstructionItem)?.value == instruction
                || ((item as? CodeItem).map { uses($0.value, instruction) } ?? false)
        }
    }

    @Test func `identical passes roll anywhere in a crux, not only at its end`() {
        let crux = Self.ins(.input(1)) + [IntItem(3)] + Self.ins(.intAdd) + [IntItem(3)] + Self.ins(.intAdd)
            + [IntItem(3)] + Self.ins(.intAdd) + [IntItem(5)] + Self.ins(.intMultiply)
        let rolled = CruxCompression.rolledByIndex(crux)
        #expect(Self.printed(rolled) == "( .input1 ( 3 .intAdd ) 3 .execDoTimes .codePop 5 .intMultiply )")
        #expect(Self.top(rolled).pretty() == Self.top(crux).pretty())
    }

    @Test func `a loop's counter read first in each pass becomes the loop's own index`() {
        // The sum of 0 to 7 onto the input, each pass's counter written out as a
        // join writes it: the loop's minted start, plus the pass.
        let start = StandInItem(standingInFor: IntItem(0), source: .execDoCount, reason: .minted)
        let crux = Self.ins(.input(1)) + [start] + Self.ins(.intAdd) + (1..<8).flatMap { pass -> [any Item] in
            [start, IntItem(pass)] + Self.ins(.intAdd, .intAdd)
        }
        let rolled = CruxCompression.rolledByIndex(crux)
        #expect(Self.printed(rolled) == "( .input1 8 ( .intAdd ) .execDoCount .codePop )")
        #expect(Self.top(rolled).pretty() == "32")
    }

    @Test func `a crux whose counter is shared still rolls to the same value`() {
        let item = Self.top(Self.ins(.input(1)) + [IntItem(8), CodeItem(Self.ins(.intAdd))] + Self.ins(.execDoCount))
        let rolled = CruxCompression.rolledByIndex(item.crux())
        #expect(Self.top(rolled).pretty() == item.pretty())
    }

    @Test func `a pass may start at its index`() {
        // input1 + v[0] + v[1] + v[2] + v[3] + v[4], each element fetched by a
        // literal index: passes taken from the index on need no lookup.
        let crux = Self.ins(.input(1)) + (0..<5).flatMap { index -> [any Item] in
            Self.ins(.input(0)) + [IntItem(index)] + Self.ins(.vecIntNth, .intAdd)
        }
        let rolled = CruxCompression.rolledByIndex(crux)
        #expect(Self.uses(rolled, .execDoCount), "\(Self.printed(rolled))")
        #expect(rolled.count < crux.count)
        #expect(Self.top(rolled).pretty() == "39")
        #expect(Self.top(crux).pretty() == "39")
    }

    @Test func `an index counting down rolls into a range`() {
        // Elements 4 down to 1, each subtracted in turn.
        let crux = Self.ins(.input(1)) + [4, 3, 2, 1].flatMap { index -> [any Item] in
            Self.ins(.input(0)) + [IntItem(index)] + Self.ins(.vecIntNth, .intSubtract)
        }
        let rolled = CruxCompression.rolledByIndex(crux)
        #expect(Self.uses(rolled, .execDoRange), "\(Self.printed(rolled))")
        #expect(Self.top(rolled).pretty() == Self.top(crux).pretty())
    }

    @Test func `an index read twice is bound, and an int a fixed distance off is the index plus it`() {
        // v[i] · v[i + 1] for i = 0 to 3, summed onto input1.
        let crux = Self.ins(.input(1)) + (0..<4).flatMap { index -> [any Item] in
            Self.ins(.input(0)) + [IntItem(index)] + Self.ins(.vecIntNth, .input(0)) + [IntItem(index + 1)]
                + Self.ins(.vecIntNth, .intMultiply, .intAdd)
        }
        let rolled = CruxCompression.rolledByIndex(crux)
        #expect(Self.uses(rolled, .bindingDeref), "\(Self.printed(rolled))")
        #expect(rolled.count < crux.count)
        #expect(Self.top(rolled).pretty() == Self.top(crux).pretty())
    }

    @Test func `passes are not rolled when that would not shorten the crux`() {
        let crux = Self.ins(.input(1)) + [IntItem(0)] + Self.ins(.intAdd) + [IntItem(1)] + Self.ins(.intAdd)
        #expect(Self.printed(CruxCompression.rolledByIndex(crux)) == Self.printed(crux))
    }

    @Test func `passes inside a code block roll too`() {
        let inner = Self.ins(.input(1)) + [IntItem(2)] + Self.ins(.intMultiply) + [IntItem(2)]
            + Self.ins(.intMultiply) + [IntItem(2)] + Self.ins(.intMultiply) + [IntItem(2)] + Self.ins(.intMultiply)
        let crux: [any Item] = [CodeItem(inner)] + Self.ins(.codeDo)
        let rolled = CruxCompression.rolledByIndex(crux)
        #expect(Self.printed(rolled) == "( ( .input1 ( 2 .intMultiply ) 4 .execDoTimes .codePop ) .codeDo )")
        #expect(Self.top(rolled).pretty() == "64")
    }

    @Test func `a block that looks up the index runs in its own pass`() {
        // Five blocks, each run by the `.codeDo` after it; the first fetches its
        // element differently, so a run cut from the first `.codeDo` would leave
        // each block to run in the next pass, after the index had moved on.
        let crux = Self.ins(.input(1)) + [CodeItem(Self.ins(.input(0), .vecIntFirst, .intAdd))] + Self.ins(.codeDo)
            + (1..<5).flatMap { index -> [any Item] in
                [CodeItem(Self.ins(.input(0)) + [IntItem(index)] + Self.ins(.vecIntNth, .intAdd))] + Self.ins(.codeDo)
            }
        let rolled = CruxCompression.rolledByIndex(crux)
        #expect(Self.uses(rolled, .bindingDeref), "\(Self.printed(rolled))")
        #expect(Self.top(rolled).pretty() == Self.top(crux).pretty())
        #expect(Self.top(crux).pretty() == "39")
    }
}
