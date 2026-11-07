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
    /// The role answers "where is it defined" and the trait answers "what does it
    /// compute", and for this one category they are deliberately the same set — so
    /// "is `intGT` a comparison?" has one answer rather than two. Nothing enforces
    /// that automatically: the role comes from `comparisonBehaviors`, a curated
    /// dictionary, and the trait from a name suffix. This is the check that catches
    /// a comparison registered into the wrong dictionary, which is the one failure
    /// the arrangement is open to.
    @Test func `the comparison role and the comparison trait are the same set`() {
        let role = Interpreter.instructions(role: .comparison)
        let trait = Interpreter.instructions(trait: .comparison)
        let roleOnly = role.subtracting(trait).map(\.rawValue).sorted()
        let traitOnly = trait.subtracting(role).map(\.rawValue).sorted()
        #expect(role == trait, "role-only: \(roleOnly); trait-only: \(traitOnly)")
    }

    /// The specific misclassification this branch existed to fix: `…Eq` was
    /// generated in the same per-stack loop as dup and swap, so the role called it
    /// furniture and `.stackPlumbing` — *combinators minus introspection* —
    /// inherited that and described `.intEq` as "only shuffling a stack".
    @Test func `equality is not furniture`() {
        for eq: PushInstruction in [.intEq, .boolEq, .stringEq, .codeEq] {
            #expect(Interpreter.instructions(role: .comparison).contains(eq))
            #expect(!Interpreter.instructions(role: .combinator).contains(eq))
            #expect(!Interpreter.instructions(trait: .stackPlumbing).contains(eq))
        }
    }

    /// The sizes are worth pinning, not because the numbers are sacred but because
    /// a silent shift means the language changed shape under a diagnostic that
    /// reports in percentages.
    @Test func `the partition sizes are what the notes say`() {
        #expect(Interpreter.instructions(role: .constant).count == 80)
        #expect(Interpreter.instructions(role: .input).count == 10)
        // 168, not the 180 it was: the 12 `…Eq` moved to `.comparison`, where they
        // always belonged. See `Comparison Behaviors.swift`.
        #expect(Interpreter.instructions(role: .combinator).count == 168)
        // 39, not 40: `execEq` was removed (Roadmap #26).
        #expect(Interpreter.instructions(role: .comparison).count == 39,
                "11 Eq + 28 orderings")

        // The elephant: the furniture is a large minority of everything that is
        // not a constant or an input — which is why it is a partition of its own.
        // (The exact fraction drifts as `.other` grows with each new instruction;
        // the load-bearing facts are the three fixed counts above.)
        let notEnvironment = Interpreter.language.count
            - Interpreter.instructions(role: .constant).count
            - Interpreter.instructions(role: .input).count
        let furniture = Double(Interpreter.instructions(role: .combinator).count)
            / Double(notEnvironment)
        #expect(furniture > 0.30 && furniture < 0.42)
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
