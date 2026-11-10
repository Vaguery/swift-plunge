//
//  Tags Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/17/26.
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
        let union = InstructionRole.allCases.reduce(into: Set<PushInstruction>()) {
            $0.formUnion(Interpreter.instructions(role: $1))
        }
        #expect(union == Set(Interpreter.language.keys), "every instruction is tagged")

        for a in InstructionRole.allCases {
            for b in InstructionRole.allCases where a != b {
                let overlap = Interpreter.instructions(role: a)
                    .intersection(Interpreter.instructions(role: b))
                #expect(overlap.isEmpty, "\(a) and \(b) both claim \(overlap.map(\.rawValue))")
            }
        }
    }

    /// **The two channels must agree about comparisons.**
    ///
    /// The role answers "where is it defined" and the tag answers "what does it
    /// compute". Every instruction registered as a comparison relates two values of
    /// one type, so it carries the derived `comparison` tag; the tag is wider, since
    /// it also counts containment (`stringContainsRun`, `vecIntIsSubset`). This
    /// catches a non-comparison registered into `comparisonBehaviors`.
    @Test func `every comparison by role carries the comparison tag`() {
        let role = Interpreter.instructions(role: .comparison)
        let tag = InstructionTagging.standard.instructions(tagged: .comparison)
        let roleOnly = role.subtracting(tag).map(\.rawValue).sorted()
        #expect(role.isSubset(of: tag), "role-only: \(roleOnly)")
    }

    /// The specific misclassification this branch existed to fix: `…Eq` was
    /// generated in the same per-stack loop as dup and swap, so the role called it
    /// furniture, and a category built on the role described `.intEq` as "only
    /// shuffling a stack".
    @Test func `equality is not furniture`() {
        for eq: PushInstruction in [.intEq, .boolEq, .stringEq, .codeEq] {
            #expect(Interpreter.instructions(role: .comparison).contains(eq))
            #expect(!Interpreter.instructions(role: .combinator).contains(eq))
            #expect(!InstructionTagging.standard.instructions(tagged: .stackCombinator).contains(eq))
        }
    }

    /// The sizes are worth pinning, not because the numbers are sacred but because
    /// a silent shift means the language changed shape under a diagnostic that
    /// reports in percentages.
    @Test func `the partition sizes are what the notes say`() {
        #expect(Interpreter.instructions(role: .constant).count == 80)
        #expect(Interpreter.instructions(role: .input).count == 10)
        // 168 once the 12 `…Eq` moved to `.comparison`, where they always
        // belonged (`Comparison Behaviors.swift`); 195 with `.binding`'s family (14)
        // and `xDeleteAtDepth` on the 13 family stacks (2026-11-09).
        #expect(Interpreter.instructions(role: .combinator).count == 195)
        // `execEq` was removed; `bindingEq` came with `.binding`.
        #expect(Interpreter.instructions(role: .comparison).count == 40,
                "12 Eq + 28 orderings")

        // The elephant: the furniture is a large minority of everything that is
        // not a constant or an input — which is why it is a partition of its own.
        // (The exact fraction drifts as `.other` grows with each new instruction;
        // the load-bearing facts are the three fixed counts above.)
        let notEnvironment = Interpreter.language.count
            - Interpreter.instructions(role: .constant).count
            - Interpreter.instructions(role: .input).count
        let furniture = Double(Interpreter.instructions(role: .combinator).count)
            / Double(notEnvironment)
        // Lowered from 0.30 on 2026-11-09: that day's additions are all `.other`
        // (0.29 after the set operations, ~0.24 once all of them were built).
        #expect(furniture > 0.20 && furniture < 0.42)
    }

    @Test func `the tags hold what their names claim`() {
        #expect(Interpreter.instructions(role: .constant).contains(.int3))
        #expect(Interpreter.instructions(role: .input).contains(.input7))
        #expect(Interpreter.instructions(role: .combinator).contains(.intDup))
        #expect(Interpreter.instructions(role: .other).contains(.intAdd))

        // And that the remainder really is a remainder: computing instructions
        // land in `.other` whatever stack they belong to.
        #expect(Interpreter.instructions(role: .other).contains(.vecFromIterator))
        #expect(Interpreter.instructions(role: .other).contains(.codeFromIterator))
    }

    /// A `Set` iterates in a per-process random order, so drawing from one is not
    /// reproducible even with a seeded RNG. This is the sorted form that fixes it,
    /// and the test that says it is really sorted.
    @Test func `the sampling form is sorted and complete`() {
        for tag in InstructionRole.allCases {
            let sorted = Interpreter.sortedRoles[tag]!
            #expect(sorted.count == Interpreter.instructions(role: tag).count)
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

    /// **Consuming and reading are now distinct**, and a non-destructive query
    /// belongs to the second. `.intGT` reads two ints and leaves them, so it
    /// consumes neither `.int` nor anything — it only reads.
    @Test func `a non-destructive query reads its argument, it does not consume it`() {
        #expect(Interpreter.instructions(reading: .int).contains(.intGT))
        #expect(!Interpreter.instructions(consuming: .int).contains(.intGT),
                "a query examines its argument; it must not count as eating it")

        // The vector length family reads its vector; contains reads the needle too.
        #expect(Interpreter.instructions(reading: .vecInt).contains(.vecIntLength))
        #expect(Interpreter.instructions(reading: .int).contains(.vecIntContains),
                "contains reads its .int needle non-destructively")

        // A genuine consumer is not a reader: `.intAdd` eats its ints.
        #expect(Interpreter.instructions(consuming: .int).contains(.intAdd))
        #expect(!Interpreter.instructions(reading: .int).contains(.intAdd))

        // Every `…Eq` reads; none consumes (`.execEq`, the destructive one, is gone).
        #expect(Interpreter.instructions(reading: .int).contains(.intEq))
        #expect(!Interpreter.instructions(consuming: .int).contains(.intEq))
    }

    /// "What can never starve?" — a question worth being able to ask in a language
    /// whose defining failure is argument starvation.
    @Test func `the always-satisfied set is the environment and the measurers`() {
        let safe = Interpreter.alwaysSatisfied

        #expect(safe.isSuperset(of: Interpreter.instructions(role: .constant)))
        #expect(safe.isSuperset(of: Interpreter.instructions(role: .input)))
        #expect(safe.contains(.intStackDepth), "measuring an empty stack is a fine answer")
        #expect(safe.contains(.intFlush))
        #expect(safe.contains(.intStackIsEmpty))
        #expect(!safe.contains(.intAdd))
        #expect(!safe.contains(.intDup), "a dup needs something to dup")
    }
}
