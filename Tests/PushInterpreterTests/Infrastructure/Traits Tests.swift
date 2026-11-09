//
//  Traits Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/22/26.
//
//  Traits are advisory and overlapping, so the load-bearing claims are different
//  from the tag partition's: every trait reports only real instructions, the
//  naming-family derivations land where the language's conventions say they
//  should, and the categories genuinely overlap (they are not a second partition).
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct TraitsTests {

    private var defined: Set<PushInstruction> { Set(Interpreter.language.keys) }

    /// Nothing invented: a trait never reports an instruction the language does
    /// not actually hold.
    @Test func `traits only report defined instructions`() {
        for trait in InstructionTrait.allCases {
            let members = Interpreter.instructions(trait: trait)
            #expect(!members.isEmpty, "\(trait) is empty — a derivation probably broke")
            #expect(members.isSubset(of: defined), "\(trait) names undefined instructions")
        }
    }

    /// The naming families land where they should — the pinned memberships that a
    /// convention change would silently move.
    @Test func `known memberships hold`() {
        #expect(Interpreter.traits(of: .doubleSin).contains(.arithmetic))
        #expect(Interpreter.traits(of: .doubleTan).contains(.arithmetic))
        #expect(Interpreter.traits(of: .intAdd).contains(.arithmetic))
        #expect(Interpreter.traits(of: .intEq).contains(.comparison))
        #expect(Interpreter.traits(of: .stringLTE).contains(.comparison))
        #expect(Interpreter.traits(of: .boolAnd).contains(.logical))
        #expect(Interpreter.traits(of: .boolXor).contains(.logical))
        #expect(Interpreter.traits(of: .stringFromInt).contains(.conversion))
        #expect(Interpreter.traits(of: .intStackDepth).contains(.introspection))
        #expect(Interpreter.traits(of: .stringStackIsEmpty).contains(.introspection))
        #expect(Interpreter.traits(of: .stringIterate).contains(.iteratorCreating))
        #expect(Interpreter.traits(of: .iteratorFromIntRange).contains(.iteratorCreating))
        #expect(Interpreter.traits(of: .intDup).contains(.stackPlumbing))
        #expect(Interpreter.traits(of: .codeIf).contains(.controlFlow))
        // `.query` is authoritative — derived from a behavior's declared `.reads`.
        // `charIsLetter` reads a char nondestructively to test it.
        #expect(Interpreter.traits(of: .charIsLetter).contains(.query))
    }

    /// The transcendental functions the trig-approximation demo wants to silence
    /// are exactly `.arithmetic`, and carry no comparison/logical baggage that a
    /// bulk toggle would also catch.
    @Test func `trig functions are arithmetic and nothing crosscutting`() {
        for f in [PushInstruction.doubleSin, .doubleCos, .doubleTan] {
            let traits = Interpreter.traits(of: f)
            #expect(traits.contains(.arithmetic))
            #expect(!traits.contains(.comparison))
            #expect(!traits.contains(.logical))
            #expect(!traits.contains(.conversion))
        }
    }

    /// Comparisons are exactly the ordering/equality suffixes — no stray member.
    @Test func `comparison membership matches the naming convention`() {
        for instruction in Interpreter.instructions(trait: .comparison) {
            let name = instruction.rawValue
            let looksLikeComparison = ["Eq", "GT", "GTE", "LT", "LTE"].contains { name.hasSuffix($0) }
            #expect(looksLikeComparison, "\(name) is tagged comparison but does not read like one")
        }
    }

    /// Introspection and plumbing still split the combinator role cleanly, but
    /// **introspection is no longer contained by it.**
    ///
    /// It used to be: introspection was exactly the generated
    /// `…StackDepth`/`…StackIsEmpty` pair, which is furniture. The
    /// run-introspection instructions broke that — `pushStepCount` and the three
    /// `errorMissing…Count` report on the run rather than on a stack, and
    /// `errorStackDepth` reads like the family but is hand-written, because
    /// `.error` gets no generated furniture at all (`Introspection
    /// Behaviors.swift`).
    ///
    /// So the invariant is now about the *intersection*: the combinators are
    /// partitioned by plumbing and the introspective furniture, while
    /// introspection itself reaches outside.
    @Test func `introspection and plumbing partition the combinators`() {
        let combinators = Interpreter.instructions(role: .combinator)
        let introspection = Interpreter.instructions(trait: .introspection)
        let plumbing = Interpreter.instructions(trait: .stackPlumbing)

        #expect(plumbing.isSubset(of: combinators))
        #expect(introspection.isDisjoint(with: plumbing))
        #expect(plumbing.union(introspection.intersection(combinators)) == combinators,
                "plumbing and introspective furniture must still cover the role exactly")

        // And the part that reaches outside is exactly the run-introspection set,
        // named so that adding one without thinking fails here.
        #expect(introspection.subtracting(combinators)
                == [.pushStepCount, .errorStackDepth,
                    .errorMissingArgCount, .errorMissingInputCount, .errorMissingConstantCount])
    }

    /// Traits are **not** a partition: categories overlap (a quote is both a
    /// conversion and control flow), which is the whole reason they exist
    /// alongside the tags.
    @Test func `traits genuinely overlap`() {
        let conversion = Interpreter.instructions(trait: .conversion)
        let controlFlow = Interpreter.instructions(trait: .controlFlow)
        #expect(conversion.contains(.execQuote))
        #expect(controlFlow.contains(.execQuote))
        #expect(!conversion.isDisjoint(with: controlFlow), "the quotes should live in both")
    }

    /// `traits(of:)` is the faithful inverse of the trait tables.
    @Test func `traits(of:) inverts the tables`() {
        for trait in InstructionTrait.allCases {
            for member in Interpreter.instructions(trait: trait) {
                #expect(Interpreter.traits(of: member).contains(trait))
            }
        }
    }
}
