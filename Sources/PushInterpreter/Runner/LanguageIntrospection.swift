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

    /// The language partitioned into its named subsets — `.constant`, `.input`,
    /// `.combinator`, `.other` — each list sorted. The four are a true partition:
    /// every defined instruction appears in exactly one. Count them for a
    /// by-type breakdown (`instructionsByTag.mapValues(\.count)`).
    nonisolated var instructionsByTag: [InstructionTag: [PushInstruction]] {
        Interpreter.sortedTags
    }

    /// The instructions carrying `tag`, sorted.
    nonisolated func instructions(tagged tag: InstructionTag) -> [PushInstruction] {
        Interpreter.sortedTags[tag] ?? []
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
