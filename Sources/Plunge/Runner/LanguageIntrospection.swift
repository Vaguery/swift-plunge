//
//  LanguageIntrospection.swift
//  Plunge
//
//  Created by Bill Tozier on 7/19/26.
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
    /// `.constant`, `.input`, `.stackFamily`, `.comparison`, `.other` — each list
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
    /// Unlike roles and the derived tags, these are declared at each `Behavior`, so
    /// they are the only classification here that can be *wrong*. That
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

    /// What `instruction` does, in one sentence: the summary its definition
    /// declares, as the instruction reference shows it. Nil if the language has
    /// no such instruction.
    nonisolated func summary(of instruction: PushInstruction) -> String? {
        Interpreter.language[instruction]?.summary
    }

    /// What `instruction` takes and gives, read off its declarations — its edge
    /// in the language's input-output map. Nil if the language has
    /// no such instruction.
    nonisolated func signature(of instruction: PushInstruction) -> InstructionSignature? {
        Interpreter.signatures[instruction]
    }

    /// The instructions that can put a value on `stack`, sorted: where chaining
    /// backwards from a wanted output starts. A deferred push (a constant on
    /// `.exec`) counts at the stack it rests on; continuations and inputs, whose
    /// outputs the definition does not fix, are not listed.
    nonisolated func instructions(producing stack: PushStack) -> [PushInstruction] {
        (Interpreter.producers[stack] ?? []).sorted { $0.rawValue < $1.rawValue }
    }

    /// The instructions that need no arguments and so can never starve —
    /// constants, inputs, and the combinators that measure or clear a stack.
    nonisolated var alwaysSatisfiedInstructions: [PushInstruction] {
        Interpreter.alwaysSatisfied.sorted { $0.rawValue < $1.rawValue }
    }

    /// The library's tags (see `InstructionTagging.standard`): declared at the
    /// Behaviors and derived from their declarations. Layer your own over it with
    /// `adding(_:to:)` or `merging(_:)`.
    nonisolated var tagging: InstructionTagging { .standard }

    /// The language indexed by tag, each list sorted. Tags overlap: an instruction
    /// appears under every tag it carries, and every instruction carries at least one.
    nonisolated var instructionsByTag: [InstructionTag: [PushInstruction]] {
        Self.sortedTags
    }

    /// The instructions carrying `tag` in the standard tagging, sorted.
    nonisolated func instructions(tagged tag: InstructionTag) -> [PushInstruction] {
        Self.sortedTags[tag] ?? []
    }

    /// Every tag `instruction` carries in the standard tagging.
    nonisolated func tags(of instruction: PushInstruction) -> Set<InstructionTag> {
        InstructionTagging.standard.tags(of: instruction)
    }

    /// The instructions that take, read, observe, need, give or rearrange `stack`,
    /// sorted: everything that touches it, from the declarations.
    nonisolated func instructions(touching stack: PushStack) -> [PushInstruction] {
        Interpreter.signatures.filter { $0.value.touches(stack) }.keys.sorted { $0.rawValue < $1.rawValue }
    }

    private static let sortedTags: [InstructionTag: [PushInstruction]] =
        InstructionTagging.standard.members.mapValues { $0.sorted { $0.rawValue < $1.rawValue } }
}
