//
//  Tags Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/17/26.
//
//  The tags exist so that "sample uniformly from the combinators" is a question
//  with an answer. The property that makes them trustworthy is that **they
//  partition the language** — so most of this file is that one claim, said in the
//  ways it could fail.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct TagsTests {

    /// **The load-bearing property.** Every instruction is in exactly one tag, and
    /// `.other` is the remainder — so an untagged dictionary added to the language
    /// lands there rather than vanishing. If this fails, every mix built on the
    /// tags is measuring something other than what it says.
    @Test func `the tags partition the language`() {
        let union = InstructionTag.allCases.reduce(into: Set<PushInstruction>()) {
            $0.formUnion(Interpreter.instructions(tagged: $1))
        }
        #expect(union == Set(Interpreter.language.keys), "every instruction is tagged")

        for a in InstructionTag.allCases {
            for b in InstructionTag.allCases where a != b {
                let overlap = Interpreter.instructions(tagged: a)
                    .intersection(Interpreter.instructions(tagged: b))
                #expect(overlap.isEmpty, "\(a) and \(b) both claim \(overlap.map(\.rawValue))")
            }
        }
    }

    /// The sizes are worth pinning, not because the numbers are sacred but because
    /// a silent shift means the language changed shape under a diagnostic that
    /// reports in percentages.
    @Test func `the partition sizes are what the notes say`() {
        #expect(Interpreter.instructions(tagged: .constant).count == 80)
        #expect(Interpreter.instructions(tagged: .input).count == 10)
        #expect(Interpreter.instructions(tagged: .combinator).count == 180)

        // The elephant: the furniture is 41% of everything that is not a constant
        // or an input, which is why it is a partition of its own.
        let notEnvironment = Interpreter.language.count
            - Interpreter.instructions(tagged: .constant).count
            - Interpreter.instructions(tagged: .input).count
        let furniture = Double(Interpreter.instructions(tagged: .combinator).count)
            / Double(notEnvironment)
        #expect(furniture > 0.40 && furniture < 0.42)
    }

    @Test func `the tags hold what their names claim`() {
        #expect(Interpreter.instructions(tagged: .constant).contains(.int3))
        #expect(Interpreter.instructions(tagged: .input).contains(.input7))
        #expect(Interpreter.instructions(tagged: .combinator).contains(.intDup))
        #expect(Interpreter.instructions(tagged: .other).contains(.intAdd))

        // And that the remainder really is a remainder: computing instructions
        // land in `.other` whatever stack they belong to.
        #expect(Interpreter.instructions(tagged: .other).contains(.vecFromIterator))
        #expect(Interpreter.instructions(tagged: .other).contains(.codeFromIterator))
    }

    /// A `Set` iterates in a per-process random order, so drawing from one is not
    /// reproducible even with a seeded RNG. This is the sorted form that fixes it,
    /// and the test that says it is really sorted.
    @Test func `the sampling form is sorted and complete`() {
        for tag in InstructionTag.allCases {
            let sorted = Interpreter.sortedTags[tag]!
            #expect(sorted.count == Interpreter.instructions(tagged: tag).count)
            #expect(sorted == sorted.sorted { $0.rawValue < $1.rawValue }, "\(tag) is not sorted")
        }
    }


    // MARK: - the derived questions

    /// Not declared anywhere: the Planner already knows what everything needs, so
    /// this falls out of the requirements.
    @Test func `instructions consuming a stack are computed from requirements`() {
        let intEaters = Interpreter.instructions(consuming: .int)

        #expect(intEaters.contains(.intAdd))
        #expect(intEaters.contains(.intYank), "its index is an .int")
        #expect(intEaters.contains(.vecIntConstruct), "a dynamic need is still a named stack")
        #expect(!intEaters.contains(.boolAnd))
        #expect(!intEaters.contains(.int3), "a constant reads a binding; it takes nothing")

        // .int is the most-demanded stack in the language (Stack economics), and
        // this is the structural version of that claim.
        #expect(intEaters.count > Interpreter.instructions(consuming: .bool).count)
    }

    /// "What can never starve?" — a question worth being able to ask in a language
    /// whose defining failure is argument starvation.
    @Test func `the always-satisfied set is the environment and the measurers`() {
        let safe = Interpreter.alwaysSatisfied

        #expect(safe.isSuperset(of: Interpreter.instructions(tagged: .constant)))
        #expect(safe.isSuperset(of: Interpreter.instructions(tagged: .input)))
        #expect(safe.contains(.intStackDepth), "measuring an empty stack is a fine answer")
        #expect(safe.contains(.intFlush))
        #expect(safe.contains(.intStackIsEmpty))
        #expect(!safe.contains(.intAdd))
        #expect(!safe.contains(.intDup), "a dup needs something to dup")
    }
}
