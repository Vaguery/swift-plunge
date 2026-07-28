//
//  LanguageIntrospection.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/19/26.
//
//  The public, typed view of *what the language contains* — the surface a calling
//  process (the search owner) needs to reason about instructions before it builds
//  a run: the whole set, the named subsets it partitions into, and the stack-usage
//  queries. The rich data lives as `static` members on the internal `Interpreter`;
//  this exposes it through the `Runner`, the library's public boundary, as typed
//  `PushInstruction` / `InstructionTag` values rather than the raw-`String` lists
//  `instructionNames` already offered.
//
//  To choose *which* instructions are active in a call, pair these with
//  `RunnerConfiguration.disabledBehaviors`: read a set here, subtract it from the
//  whole language, and disable the complement. See `RunnerConfiguration`.
//

public extension Runner {

    /// Every instruction the language defines, sorted by raw value for a stable,
    /// reproducible order (unlike `Interpreter.language.keys`, which iterates in a
    /// per-process random order). Language-wide, so `nonisolated`.
    nonisolated var definedInstructions: [PushInstruction] {
        Interpreter.language.keys.sorted { $0.rawValue < $1.rawValue }
    }

    /// The language partitioned by **where each instruction is defined** —
    /// `.constant`, `.input`, `.combinator`, `.comparison`, `.other` — each list
    /// sorted. The five are a true partition: every defined instruction appears in
    /// exactly one. Count them for a by-role breakdown
    /// (`instructionsByRole.mapValues(\.count)`).
    ///
    /// Read `InstructionRole`'s own note before leaning on these as *semantic*
    /// categories: a role is derived from the dictionary that registers a behavior,
    /// so it is honest about the code and only as meaningful as the dictionaries
    /// are curated to be.
    nonisolated var instructionsByRole: [InstructionRole: [PushInstruction]] {
        Interpreter.sortedRoles
    }

    /// The instructions carrying `role`, sorted.
    nonisolated func instructions(role: InstructionRole) -> [PushInstruction] {
        Interpreter.sortedRoles[role] ?? []
    }

    /// The language indexed by **declared tag** — the judgment channel.
    ///
    /// Unlike roles and traits, these are declared at each `Behavior` rather than
    /// derived, so they are the only classification here that can be *wrong*. That
    /// is the price of carrying what `requirements` cannot know: that `.execY` is
    /// risky, or that the iterator constructors starve. Each tag records where its
    /// judgment came from — ask `InstructionTag.provenance` and `.rationale`.
    nonisolated var instructionsByDeclaredTag: [InstructionTag: [PushInstruction]] {
        Interpreter.sortedDeclaredTags
    }

    /// The instructions declaring `tag`, sorted.
    nonisolated func instructions(declaring tag: InstructionTag) -> [PushInstruction] {
        Interpreter.sortedDeclaredTags[tag] ?? []
    }

    /// Every tag `instruction` declares — usually none.
    nonisolated func declaredTags(of instruction: PushInstruction) -> Set<InstructionTag> {
        Interpreter.declaredTags(of: instruction)
    }

    // MARK: - Renamed
    //
    // **Unavailable rather than deprecated, deliberately.** `InstructionTag` used
    // to name this partition and now names a different thing entirely — the
    // declared, overlapping judgment vocabulary. A deprecation warning can be
    // ignored for a release, and ignoring it here would mean a caller keeping a
    // compiling `instructionsByTag` whose meaning had silently changed underneath
    // it. A compile error naming its replacement is much the cheaper outcome, and
    // is the API-level form of the same rule that keeps derived and declared
    // classification in separate channels.

    @available(*, unavailable, renamed: "instructionsByRole",
               message: "renamed: this is the role partition. `InstructionTag` now names the declared judgment tags, which are a different set — see `declaredTags(of:)`.")
    nonisolated var instructionsByTag: [InstructionRole: [PushInstruction]] {
        Interpreter.sortedRoles
    }

    @available(*, unavailable, renamed: "instructions(role:)",
               message: "renamed: this is the role partition. `InstructionTag` now names the declared judgment tags — see `instructions(declaring:)`.")
    nonisolated func instructions(tagged role: InstructionRole) -> [PushInstruction] {
        Interpreter.sortedRoles[role] ?? []
    }

    /// The instructions that **consume** `stack` — pop items from it — sorted.
    /// Computed from each behavior's declared requirements, not from names.
    nonisolated func instructions(consuming stack: PushStack) -> [PushInstruction] {
        Interpreter.instructions(consuming: stack).sorted { $0.rawValue < $1.rawValue }
    }

    /// The instructions that **read** `stack` without consuming it — the
    /// non-destructive queries — sorted.
    nonisolated func instructions(reading stack: PushStack) -> [PushInstruction] {
        Interpreter.instructions(reading: stack).sorted { $0.rawValue < $1.rawValue }
    }

    /// The instructions that need no arguments and so can never starve —
    /// constants, inputs, and the combinators that measure or clear a stack.
    nonisolated var alwaysSatisfiedInstructions: [PushInstruction] {
        Interpreter.alwaysSatisfied.sorted { $0.rawValue < $1.rawValue }
    }

    /// The language categorized by overlapping `InstructionTrait`, each list
    /// sorted. Unlike `instructionsByTag`, these are **advisory and overlapping**:
    /// an instruction may appear in several lists or none. Use them to activate or
    /// silence a whole behavioural class (e.g. `.controlFlow`, `.arithmetic`).
    nonisolated var instructionsByTrait: [InstructionTrait: [PushInstruction]] {
        Interpreter.sortedTraits
    }

    /// The instructions carrying `trait`, sorted.
    nonisolated func instructions(trait: InstructionTrait) -> [PushInstruction] {
        Interpreter.sortedTraits[trait] ?? []
    }

    /// Every trait `instruction` carries — possibly empty, since traits do not
    /// partition the language.
    nonisolated func traits(of instruction: PushInstruction) -> Set<InstructionTrait> {
        Interpreter.traits(of: instruction)
    }
}
