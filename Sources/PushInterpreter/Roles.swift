//
//  Tags.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/17/26.
//
//  Named subsets of the language, so that "sample uniformly from the
//  combinators" and "which instructions consume an .int" are questions with
//  answers rather than string-matching exercises.
//

/// **Where an instruction is defined** — the dictionary that registers it — used
/// as the language's role partition.
///
/// **These five partition it**, which is the property that makes them worth
/// having: every instruction is in exactly one, `.other` is the remainder by
/// construction, and a test asserts it. Add a dictionary to `Interpreter.language`
/// without classifying it and the instruction lands in `.other` — never nowhere.
///
/// **A role is only as honest as the dictionaries are.** Being derived from them
/// means it cannot silently drift from what the language holds — but it also means
/// a role says "this is where the behavior was registered", which is a fact about
/// code organization and only *becomes* a fact about instructions if the
/// dictionaries are curated to make it one. That is not automatic, and it was
/// wrong once: every `…Eq` was roled `.combinator` purely because
/// `eqCombinator_Behavior` sat in the same generator loop as dup and swap. Treat
/// these as **provisionally** disjoint — the partition is a property worth keeping,
/// not evidence that the categories are natural.
///
/// Adding a role is one case here and one line in `Interpreter.roles`. Most of the
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
public nonisolated enum InstructionRole: String, Sendable, Codable, Hashable, CaseIterable {
    /// The 80 environment constants — `int0…int9`, `vecString0…9`, and so on.
    /// They read a binding rather than computing anything, and take no arguments,
    /// so they can never starve.
    case constant

    /// The 10 `input0…input9` tokens. Like constants, they read a binding.
    case input

    /// The language's furniture: dup, swap, rot, pop, flush, yank, shove,
    /// stackDepth… — the ~14 that exist for every stack.
    ///
    /// **Furniture only.** `…Eq` used to be generated into this family and so was
    /// roled here; it is a `.comparison` now, and the `.stackPlumbing` trait —
    /// defined as this role minus its introspective measurements — stopped
    /// describing `.intEq` as an instruction that "only shuffles a stack".
    ///
    /// **Worth knowing before drawing uniformly: this is 41% of everything that
    /// is not a constant or an input.** "Sample a random instruction" mostly
    /// samples furniture, which is why it earns a partition of its own rather than
    /// being left in `.other` to dominate it silently.
    case combinator

    /// Ordering and equality — the 11 `…Eq` and the 28 `…GT`/`…GTE`/`…LT`/`…LTE`.
    ///
    /// Exactly the `.comparison` **trait**, which is the point: the two channels
    /// answer "where is it defined" and "what does it compute" and here they agree,
    /// so "is `intGT` a comparison?" has one answer. `Instruction Role Tests`
    /// asserts the equality, which is what catches a comparison registered into the
    /// wrong dictionary.
    case comparison

    /// Everything else — the instructions that actually compute. The remainder,
    /// defined by subtraction so nothing can fall through the cracks.
    case other
}


nonisolated extension Interpreter {

    /// The language, partitioned. Built once, beside `language` itself, and
    /// derived from the behavior dictionaries rather than from name prefixes — so
    /// a tag cannot drift out of step with what the language actually holds.
    static let roles: [InstructionRole: Set<PushInstruction>] = {
        let constants = Set(constantBehaviors.keys)
        let inputs = Set(inputBehaviors.keys)
        let combinators = Set(combinatorBehaviors.keys)
        let comparisons = Set(comparisonBehaviors.keys)
        return [
            .constant: constants,
            .input: inputs,
            .combinator: combinators,
            .comparison: comparisons,
            .other: Set(language.keys)
                .subtracting(constants)
                .subtracting(inputs)
                .subtracting(combinators)
                .subtracting(comparisons),
        ]
    }()

    /// The tokens carrying `role`, **sorted** — the form to draw from.
    ///
    /// A `Set` cannot be sampled reproducibly: its iteration order is per-process
    /// random, exactly like `Dictionary.keys`, so `randomElement(using: seededRNG)`
    /// over one is *not* deterministic across runs. That bug has been paid for
    /// once already (see `RandomCode.allInstructions`). Sorting by `rawValue` is
    /// the fix, and it belongs here rather than at each call site.
    static let sortedRoles: [InstructionRole: [PushInstruction]] =
        roles.mapValues { $0.sorted { $0.rawValue < $1.rawValue } }

    /// The instructions carrying `role`, for membership and set algebra.
    static func instructions(role: InstructionRole) -> Set<PushInstruction> {
        roles[role] ?? []
    }

    /// The instructions that **consume** `stack` — remove items from it —
    /// **computed, not declared.**
    ///
    /// This counts only `.takes`/`.takesMany` (see `Behavior.consumedStacks`), so
    /// a non-destructive query that *reads* the stack does **not** appear here, and
    /// neither does a combinator that reaches in without popping (`.needs`). Ask
    /// `instructions(reading:)` for the readers, or `staticNeeds` for "draws on it
    /// at all".
    ///
    /// The distinction is load-bearing for the economics: once queries stopped
    /// consuming their arguments, a consumer set built on `staticNeeds` would have
    /// kept counting them and reported no change.
    static func instructions(consuming stack: PushStack) -> Set<PushInstruction> {
        Set(language.filter { $0.value.consumedStacks.keys.contains(stack) }.keys)
    }

    /// The instructions that **read** `stack` without consuming it — the
    /// non-destructive queries (`.reads`).
    static func instructions(reading stack: PushStack) -> Set<PushInstruction> {
        Set(language.filter { $0.value.readStacks.keys.contains(stack) }.keys)
    }

    /// The instructions that need nothing and so can never starve — constants,
    /// inputs, and the combinators that measure or clear a stack rather than
    /// reading it. In a language whose defining failure is argument starvation,
    /// "what always fires?" is a question worth being able to ask.
    static let alwaysSatisfied: Set<PushInstruction> =
        Set(language.filter { $0.value.requirements.isEmpty }.keys)
}
