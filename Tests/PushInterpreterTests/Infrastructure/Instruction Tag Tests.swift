//
//  Instruction Tag Tests.swift
//  PushInterpreterTests
//
//  The declared channel — the only classification here that *can* be wrong, which
//  is what these are for.
//
//  Two kinds of check, and the difference is the point:
//
//  - A tag that duplicates something already derived must be **asserted to agree
//    with it**. Those are checkable and so must be checked rather than trusted.
//  - A tag that is a judgment — `.risky` — cannot be *proved* by a unit test, but
//    that is not the same as unfalsifiable. `InstructionRiskProfile` measures how
//    often a program containing an instruction ends badly, and the numbers are
//    recorded in the tag's rationale. What does not belong here is a fast
//    assertion pretending to settle it; what does belong is the membership check
//    below, which pins the *decision* the measurement led to.
//

@testable import PushInterpreter
import Testing
import DequeModule


@Suite @MainActor
struct InstructionTagTests {

    // MARK: - The channel itself

    /// Every shipped tag says what it means and where its judgment came from —
    /// the rule for `Interpreter`'s limits, applied to categories. A tag with no
    /// stated reason is indistinguishable from cargo.
    @Test func `every shipped tag records a rationale`() {
        for tag in InstructionTag.known {
            #expect(!tag.summary.isEmpty, "\(tag.rawValue) has no summary")
            #expect(!tag.rationale.contains("No rationale recorded"),
                    "\(tag.rawValue) has no rationale")
            // `complicated` is the catch-all, and may well be empty.
            #expect(tag == .complicated || !InstructionTagging.standard.instructions(tagged: tag).isEmpty,
                    "\(tag.rawValue) carries nothing: either tag something or drop it")
        }
    }

    /// The vocabulary is open, so a caller can mint one for a single experiment
    /// without a library release. An unknown tag is not an error; it simply has
    /// nothing declared and says so.
    @Test func `a locally minted tag is legal and empty`() {
        let mine = InstructionTag("myExperiment")
        #expect(Interpreter.instructions(declaring: mine).isEmpty)
        #expect(mine.provenance == .chosen, "someone made it up on purpose")
        #expect(mine.rationale.contains("No rationale recorded"))
    }

    /// Tags overlap — the whole reason they are not a partition. `iteratorRepeating`
    /// both starves in practice and refuses empty blocks.
    @Test func `tags overlap`() {
        let both = Interpreter.declaredTags(of: .iteratorRepeating)
        #expect(both.contains(.cruxOnly))
        #expect(both.contains(.fallible))
    }


    // MARK: - reEntrant, and the set it replaced

    /// `.reEntrant` is exactly what `PushInstruction.iterators` used to spell out by
    /// hand, which is the check that the retirement lost nothing; this also pins
    /// that the runaway guard (`Interpreter.reEntrantInstructions`) still sees the
    /// same instructions it always did.
    @Test func `reEntrant is the set the hand-written list used to hold`() {
        let expected: Set<PushInstruction> = [
            .execDoWhile, .execWhile, .execY,
            .codeIterate, .codeIterateEmit, .codeIterateDo, .codeIterateRoot,
            .iteratorPlay, .iteratorPlayDelayed,
            .stringIterate,
            .vecBoolIterate, .vecDoubleIterate, .vecIntIterate, .vecStringIterate,
        ]
        #expect(Interpreter.instructions(declaring: .reEntrant) == expected)
        #expect(Interpreter.reEntrantInstructions == expected, "the runaway guard's set agrees")
    }

    /// Every re-entrant instruction drives a loop, so every one of them should also
    /// carry the `.looping` tag.
    @Test func `reEntrant instructions are looping`() {
        let declared = Interpreter.instructions(declaring: .reEntrant)
        let derived = InstructionTagging.standard.instructions(tagged: .looping)
        let strays = declared.subtracting(derived).map(\.rawValue).sorted()
        #expect(strays.isEmpty, "declared re-entrant but not derived as looping: \(strays)")
    }


    /// The decision the measurement led to, pinned so it cannot drift back.
    ///
    /// `.execS` is the interesting one: it reads like `.execY`'s sibling, sits
    /// beside it in the enum, and a downstream app had already quarantined the two
    /// together. It duplicates its argument but never re-pushes itself, so it
    /// cannot iterate — and it measures at z = 1.0 against baseline, which is
    /// noise. See `InstructionRiskProfile` for the numbers.
    @Test func `risky is execY and deliberately not execS`() {
        let risky = Interpreter.instructions(declaring: .risky)
        #expect(risky.contains(.execY))
        #expect(!risky.contains(.execS),
                "execS duplicates but does not re-enter; measured indistinguishable from baseline")
        #expect(!risky.contains(.execK))
        #expect(InstructionTag.risky.provenance == .measured,
                "no longer merely inherited — the numbers are in the rationale")
    }


    // MARK: - cruxOnly

    /// The iterator constructors want so many arguments that they
    /// starve in practice. Blocked for a long time on having nowhere to declare it.
    @Test func `cruxOnly covers the iterator constructors`() {
        let tagged = Interpreter.instructions(declaring: .cruxOnly)
        #expect(tagged.count == 15, "13 iteratorFrom… plus 2 iteratorRepeating…")
        for name in tagged {
            #expect(name.rawValue.hasPrefix("iteratorFrom")
                    || name.rawValue.hasPrefix("iteratorRepeating"),
                    "\(name) is tagged cruxOnly but is not a constructor")
        }
    }

    /// The claim behind the tag, checked rather than asserted: these really do want
    /// far more arguments than anything else in the language.
    @Test func `the cruxOnly constructors really are argument-hungry`() {
        for name in Interpreter.instructions(declaring: .cruxOnly) {
            let wanted = Interpreter.language[name]!.staticNeeds.values.reduce(0, +)
            #expect(wanted >= 4, "\(name) wants only \(wanted) — is it really dead weight?")
        }
    }


    // MARK: - fallible, and the line it draws

    /// `.fallible` is refusal **after** the body runs; starvation is refusal
    /// before it, and is computed from the requirements. Two questions, and the
    /// declared one is not a restatement of something already computable.
    @Test func `fallible and starvation are different questions`() {
        let fallible = Interpreter.instructions(declaring: .fallible)
        let starve = Set(Interpreter.language.filter { !$0.value.requirements.isEmpty }.keys)

        #expect(fallible.contains(.intQuot), "divide by zero")
        #expect(fallible.contains(.doubleDivide), "divide by zero")
        #expect(fallible.contains(.intAdd), "overflow")
        #expect(fallible.contains(.charFromDouble), "overflow converting a double")
        #expect(!fallible.contains(.intDup), "a dup cannot refuse anything")

        // Starving is the exact complement of alwaysSatisfied.
        #expect(starve.isDisjoint(with: Interpreter.alwaysSatisfied))
        #expect(starve.union(Interpreter.alwaysSatisfied) == Set(Interpreter.language.keys))

        // They overlap heavily and neither contains the other, which is what makes
        // them worth having separately.
        #expect(!fallible.isSubset(of: Interpreter.alwaysSatisfied))
    }

    /// **The combinators are deliberately not fallible.** Five families carry an
    /// "on empty stack" guard in their bodies, but each declares
    /// `alsoNeeds: [stack: 2]`, so the Planner refuses first and the guard cannot
    /// fire. Tagging them would describe a branch no program can reach — which is
    /// why this tag is `.inspected` rather than something a grep for `ErrorItem`
    /// could have produced.
    @Test func `unreachable error branches are not tagged fallible`() {
        for name: PushInstruction in [.intYank, .doubleShove, .stringYankDup, .codeDeepDup] {
            #expect(!Interpreter.declaredTags(of: name).contains(.fallible),
                    "\(name)'s empty-stack guard sits behind alsoNeeds and cannot fire")
        }
    }
}
