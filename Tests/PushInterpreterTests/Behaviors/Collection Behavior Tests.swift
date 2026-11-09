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

    @Test func `sum reads the vector and leaves it`() {
        let inty = Self.run([VecIntItem([4, 6, 8]), InstructionItem(.vecIntSum)])
        #expect(stackString(inty, .int) == "[ 18 ]")
        #expect(stackString(inty, .vecInt) == "[ [4, 6, 8] ]")
        #expect(Self.replays(inty, .int))

        let doubles = Self.run([VecDoubleItem([1.5, 2.5]), InstructionItem(.vecDoubleSum)])
        #expect(stackString(doubles, .double) == "[ 4.0 ]")
        #expect(Self.replays(doubles, .double))
    }

    @Test func `average in three steps, now that sum and length are both queries`() {
        let inty = Self.run([VecIntItem([4, 6, 8]), InstructionItem(.vecIntSum),
                             InstructionItem(.vecIntLength), InstructionItem(.intQuot)])
        #expect(stackString(inty, .int) == "[ 6 ]")
    }

    @Test func `an empty vector sums to zero`() {
        let inty = Self.run([VecIntItem([]), InstructionItem(.vecIntSum)])
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(inty.stacks[.error]!.isEmpty)
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

    // MARK: - Set operations (P1b)

    @Test func `distinct keeps first occurrences`() {
        let inty = Self.run([VecIntItem([3, 1, 3, 2, 1]), InstructionItem(.vecIntDistinct)])
        #expect(stackString(inty, .vecInt) == "[ [3, 1, 2] ]")
        #expect(Self.replays(inty, .vecInt))
        let letters = Self.run([StringItem("banana"), InstructionItem(.stringDistinct)])
        #expect(stackString(letters, .string) == "[ \"ban\" ]")
    }

    @Test func `intersect and difference filter the first by the second`() {
        let vowels = Self.run([StringItem("hello"), StringItem("aeiou"), InstructionItem(.stringDifference)])
        #expect(stackString(vowels, .string) == "[ \"hll\" ]")
        #expect(Self.replays(vowels, .string))

        let kept = Self.run([VecIntItem([3, 1, 3, 2]), VecIntItem([2, 3]), InstructionItem(.vecIntIntersect)])
        #expect(stackString(kept, .vecInt) == "[ [3, 3, 2] ]", "the first's order and repeats")

        let words = Self.run([VecStringItem(["a", "b", "c"]), VecStringItem(["b"]),
                              InstructionItem(.vecStringDifference)])
        #expect(stackString(words, .vecString) == "[ [\"a\", \"c\"] ]")
    }

    @Test func `union is concat then distinct`() {
        let inty = Self.run([VecIntItem([1, 2]), VecIntItem([2, 3]), InstructionItem(.vecIntConcat),
                             InstructionItem(.vecIntDistinct)])
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 3] ]")
    }

    @Test func `isSubset reads both and leaves them`() {
        let inty = Self.run([VecIntItem([2, 2, 1]), VecIntItem([1, 2, 3]), InstructionItem(.vecIntIsSubset)])
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(inty.stacks[.vecInt]!.count == 2)
        #expect(Self.replays(inty, .bool))

        let same = Self.run([StringItem("listen"), StringItem("silent"), InstructionItem(.stringIsSubset),
                             InstructionItem(.stringSwap), InstructionItem(.stringIsSubset),
                             InstructionItem(.boolAnd)])
        #expect(stackString(same, .bool) == "[ true ]", "same letters, in four steps")
    }

    @Test func `code set operations compare root items by value`() {
        let block = CodeItem([IntItem(1), StringItem("a"), IntItem(1), CodeItem([IntItem(2)])])
        let distinct = Self.run([block, InstructionItem(.codeDistinct)])
        #expect(stackString(distinct, .code) == "[ ( 1 \"a\" ( 2 ) ) ]")

        let other = CodeItem([CodeItem([IntItem(2)]), IntItem(1)])
        let both = Self.run([block, other, InstructionItem(.codeIntersect)])
        #expect(stackString(both, .code) == "[ ( 1 1 ( 2 ) ) ]")

        let subset = Self.run([other, block, InstructionItem(.codeIsSubset)])
        #expect(stackString(subset, .bool) == "[ true ]")
    }
}
