//
//  Collection Behavior Tests.swift
//  PushInterpreterTests
//
//  Reductions over whole collections (Behavior coverage audit, P1): facts
//  read and leave, and Max and Min are member reads.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct CollectionBehaviorTests {

    /// Runs `program` on a provenance-recording interpreter.
    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    /// Re-runs the crux of `stack`'s top item on a fresh interpreter: it must
    /// leave that value and nothing else (the composition invariant).
    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        let top = inty.stacks[stack]!.first!
        let fresh = Interpreter()
        fresh.load(program: top.crux())
        fresh.run(stepLimit: 1_000)
        let others = PushStack.allCases.filter { $0 != stack && $0 != .exec }
        return fresh.stacks[stack]!.count == 1
            && fresh.stacks[stack]!.first!.pretty() == top.pretty()
            && others.allSatisfy { fresh.stacks[$0]!.isEmpty }
    }

    @Test func `sum and mean read the vector and leave it`() {
        let inty = Self.run([VecIntItem([4, 6, 8]), InstructionItem(.vecIntSum)])
        #expect(stackString(inty, .int) == "[ 18 ]")
        #expect(stackString(inty, .vecInt) == "[ [4, 6, 8] ]")
        #expect(Self.replays(inty, .int))

        let mean = Self.run([VecIntItem([4, 6, 8]), InstructionItem(.vecIntMean)])
        #expect(stackString(mean, .double) == "[ 6.0 ]")
        #expect(Self.replays(mean, .double))

        let doubles = Self.run([VecDoubleItem([1.5, 2.5]), InstructionItem(.vecDoubleSum),
                                InstructionItem(.vecDoubleMean)])
        #expect(stackString(doubles, .double) == "[ 2.0 4.0 ]")
    }

    @Test func `average in three steps, now that sum and length are both queries`() {
        let inty = Self.run([VecIntItem([4, 6, 8]), InstructionItem(.vecIntSum),
                             InstructionItem(.vecIntLength), InstructionItem(.intQuot)])
        #expect(stackString(inty, .int) == "[ 6 ]")
    }

    @Test func `an empty vector sums to zero and has no mean`() {
        let inty = Self.run([VecIntItem([]), InstructionItem(.vecIntSum), InstructionItem(.vecIntMean)])
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .double) == "[ ]")
        #expect(inty.stacks[.error]!.count == 1)
    }

    @Test func `sum refuses overflow`() {
        let inty = Self.run([VecIntItem([Int.max, 1]), InstructionItem(.vecIntSum)])
        #expect(stackString(inty, .int) == "[ ]")
        #expect(inty.stacks[.error]!.count == 1)
    }

    @Test func `max and min read out the first greatest and least element`() {
        let inty = Self.run([VecIntItem([3, 9, 2, 9]), InstructionItem(.vecIntMax), InstructionItem(.vecIntMin)])
        #expect(stackString(inty, .int) == "[ 2 9 ]")
        #expect(stackString(inty, .vecInt) == "[ [3, 9, 2, 9] ]")

        let words = Self.run([VecStringItem(["pear", "apple", "zoo"]), InstructionItem(.vecStringMax)])
        #expect(stackString(words, .string) == "[ \"zoo\" ]")

        let letters = Self.run([StringItem("hello"), InstructionItem(.stringMin)])
        #expect(stackString(letters, .char) == "[ 'e' ]")
        #expect(Self.replays(letters, .char))
    }

    @Test func `max of an empty vector is an error`() {
        let inty = Self.run([VecDoubleItem([]), InstructionItem(.vecDoubleMax)])
        #expect(stackString(inty, .double) == "[ ]")
        #expect(inty.stacks[.error]!.count == 1)
    }

    @Test func `NaN counts as the greatest`() {
        let max = Self.run([VecDoubleItem([2.0, .nan, -1.0]), InstructionItem(.vecDoubleMax)])
        #expect(stackString(max, .double) == "[ nan ]")
    }
}
