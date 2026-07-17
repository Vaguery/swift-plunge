//
//  Tags.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/17/26.
//
//  Named subsets of the language, so that "sample uniformly from the
//  combinators" and "which instructions consume an .int" are questions with
//  answers rather than string-matching exercises.
//

/// A named subset of the language.
///
/// **These four partition it**, which is the property that makes them worth
/// having: every instruction is in exactly one, `.other` is the remainder by
/// construction, and a test asserts it. Add a dictionary to `Interpreter.language`
/// without tagging it and the instruction lands in `.other` — never nowhere.
///
/// Adding a tag is one case here and one line in `Interpreter.tags`. Most of the
/// interesting ones need no declaration at all: **anything about what an
/// instruction *needs* is already computable**, because a Behavior's
/// `requirements` say so (see `instructions(consuming:)`).
///
/// The exception, and it is a real gap: **anything about what an instruction
/// *makes* is not.** A Behavior declares what it takes and nothing about its
/// results — those are `Router`s computed at run time. So a `.converter` tag
/// ("moves a value from one stack to another"), or a computed producers/consumers
/// ratio for "Stack economics", would need Behaviors to declare their result
/// stacks. Worth doing one day: the robustness sweep already drives every
/// behavior in the language, so a declaration that lied about its Routers could
/// be caught there rather than trusted.
public nonisolated enum InstructionTag: String, Sendable, Codable, Hashable, CaseIterable {
    /// The 80 environment constants — `int0…int9`, `vecString0…9`, and so on.
    /// They read a binding rather than computing anything, and take no arguments,
    /// so they can never starve.
    case constant

    /// The 10 `input0…input9` tokens. Like constants, they read a binding.
    case input

    /// The language's furniture: dup, swap, rot, pop, flush, yank, shove,
    /// stackDepth… — the ~15 that exist for every stack, 180 in all.
    ///
    /// **Worth knowing before drawing uniformly: this is 41% of everything that
    /// is not a constant or an input.** "Sample a random instruction" mostly
    /// samples furniture, which is why it earns a partition of its own rather than
    /// being left in `.other` to dominate it silently.
    case combinator

    /// Everything else — the instructions that actually compute. The remainder,
    /// defined by subtraction so nothing can fall through the cracks.
    case other
}


nonisolated extension Interpreter {

    /// The language, partitioned. Built once, beside `language` itself, and
    /// derived from the behavior dictionaries rather than from name prefixes — so
    /// a tag cannot drift out of step with what the language actually holds.
    static let tags: [InstructionTag: Set<PushInstruction>] = {
        let constants = Set(constantBehaviors.keys)
        let inputs = Set(inputBehaviors.keys)
        let combinators = Set(combinatorBehaviors.keys)
        return [
            .constant: constants,
            .input: inputs,
            .combinator: combinators,
            .other: Set(language.keys)
                .subtracting(constants)
                .subtracting(inputs)
                .subtracting(combinators),
        ]
    }()

    /// The tokens carrying `tag`, **sorted** — the form to draw from.
    ///
    /// A `Set` cannot be sampled reproducibly: its iteration order is per-process
    /// random, exactly like `Dictionary.keys`, so `randomElement(using: seededRNG)`
    /// over one is *not* deterministic across runs. That bug has been paid for
    /// once already (see `RandomCode.allInstructions`). Sorting by `rawValue` is
    /// the fix, and it belongs here rather than at each call site.
    static let sortedTags: [InstructionTag: [PushInstruction]] =
        tags.mapValues { $0.sorted { $0.rawValue < $1.rawValue } }

    /// The instructions carrying `tag`, for membership and set algebra.
    static func instructions(tagged tag: InstructionTag) -> Set<PushInstruction> {
        tags[tag] ?? []
    }

    /// The instructions that draw on `stack` — **computed, not declared.**
    ///
    /// The Planner already knows: a Behavior's requirements say which stacks it
    /// reaches for. `staticNeeds` is a lower bound on *how many* (a `.takesMany`
    /// count depends on an argument), but it names the stacks exactly, which is
    /// all this asks.
    static func instructions(consuming stack: PushStack) -> Set<PushInstruction> {
        Set(language.filter { $0.value.staticNeeds.keys.contains(stack) }.keys)
    }

    /// The instructions that need nothing and so can never starve — constants,
    /// inputs, and the combinators that measure or clear a stack rather than
    /// reading it. In a language whose defining failure is argument starvation,
    /// "what always fires?" is a question worth being able to ask.
    static let alwaysSatisfied: Set<PushInstruction> =
        Set(language.filter { $0.value.requirements.isEmpty }.keys)
}
