//
//  Roles.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/17/26.
//
//  The role partition, which shapes random test programs, and the computed
//  stack questions: which instructions consume, read or need a stack.
//

/// **A partition of the language for drawing random test programs** — the fuzz
/// and diagnostic mixes in `RandomCode` — and nothing more.
///
/// Drawing a role first and then an instruction within it gives the sources (the
/// constants and inputs) and the comparisons a far larger share than their
/// numbers would, so a random program has a fighting chance of feeding its
/// instructions instead of starving them. That proportion is chosen for testing.
/// **It is not a description of the language and should not drive a search**;
/// for that, use the tags (`InstructionTagging`), which overlap and are open.
///
/// **Every role is derived, never registered**, so where a Behavior happens to be
/// defined cannot move it: constants and inputs by what they produce, the stack
/// family by the per-stack template that generates it, comparisons by the
/// `comparison` tag. The five partition the language: every instruction is in
/// exactly one, `.other` is the remainder by construction, and a test asserts it.
/// (Until 2026-11-10 roles were the dictionaries that registered each Behavior,
/// which made them a fact about code organization: every `…Eq` was once roled
/// with dup and swap because it sat in the same generator loop.)
public nonisolated enum InstructionRole: String, Sendable, Codable, Hashable, CaseIterable {
    /// The 80 environment constants — `int0…int9`, `vecString0…9`, and so on:
    /// everything that produces a deferred literal. They take no arguments, so
    /// they can never starve.
    case constant

    /// The 10 `input0…input9` tokens: everything that produces an input.
    case input

    /// The family generated for every stack from one template: dup, swap, rot,
    /// pop, flush, yank, shove, `DeleteAtDepth`… and the two measurements
    /// `StackDepth` and `StackIsEmpty`, 15 per stack. This is a fact about how
    /// the definitions are written, not a kind of behavior: the copying,
    /// deleting and reordering ones carry the `stackCombinator` tag, and the two
    /// measurements do not. (Earlier Push implementations called the whole
    /// family "combinators"; the tag keeps that word for the rearrangements.)
    ///
    /// **Worth knowing before drawing uniformly: this is about a quarter of everything
    /// that is not a constant or an input.** "Sample a random instruction" would
    /// mostly sample this furniture, which is why it is a role of its own rather
    /// than left in `.other` to dominate it silently.
    case stackFamily

    /// Everything carrying the derived `comparison` tag: ordering, equality and
    /// containment, two items of one stack to a bool (`intLT`, `stringEq`,
    /// `stringContainsRun`).
    case comparison

    /// Everything else — the instructions that actually compute. The remainder,
    /// defined by subtraction so nothing can fall through the cracks.
    case other
}


nonisolated extension Interpreter {

    /// The language, partitioned. Built once, beside `language` itself, and
    /// derived from the Behaviors' declarations (and the per-stack template)
    /// rather than from where they are registered or what they are named.
    static let roles: [InstructionRole: Set<PushInstruction>] = {
        let constants = Set(language.filter { if case .deferred = $0.value.produces { true } else { false } }.keys)
        let inputs = Set(language.filter { $0.value.produces == .input }.keys)
        let stackFamily = Set(stackFamilyBehaviors.keys)
        let comparisons = InstructionTagging.standard.instructions(tagged: .comparison)
            .subtracting(constants).subtracting(inputs).subtracting(stackFamily)
        return [
            .constant: constants,
            .input: inputs,
            .stackFamily: stackFamily,
            .comparison: comparisons,
            .other: Set(language.keys)
                .subtracting(constants)
                .subtracting(inputs)
                .subtracting(stackFamily)
                .subtracting(comparisons)
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
