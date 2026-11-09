//
//  InstructionTrait.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/22/26.
//
//  Overlapping "kind" categories of instruction, cutting across the type-domain
//  (which stack it works on) and the `InstructionTag` role partition. Where
//  `InstructionTag` is a strict partition — every instruction in exactly one —
//  traits are **advisory and overlapping**: one instruction can carry several
//  (an `.arithmetic` op is often also a `.query`; a quote is `.conversion` and
//  `.controlFlow`), and some instructions carry none (a plain string manipulation
//  is neither of these kinds; its identity is its type domain).
//
//  Traits answer "which instructions compute in this style?" so a search owner —
//  or the Language-tab UI — can activate or silence a whole behavioural class at
//  once ("no transcendental functions", "no control flow", "only nondestructive
//  queries") rather than naming instructions one by one.
//

/// A named, overlapping behavioural category of `PushInstruction`. Unlike
/// `InstructionTag`, traits do **not** partition the language: an instruction may
/// carry several traits or none. See `Runner.instructions(trait:)` /
/// `Runner.traits(of:)`.
public nonisolated enum InstructionTrait: String, Sendable, Codable, Hashable, CaseIterable {
    /// Numeric computation on `.int` / `.double` — add, multiply, mod, min/max,
    /// inc/dec, and the transcendental `.doubleSin` / `.doubleCos` / `.doubleTan`.
    case arithmetic
    /// Ordering and equality — `…Eq`, `…LT`, `…LTE`, `…GT`, `…GTE` — producing a
    /// `.bool` from two values of a type.
    case comparison
    /// Boolean logic — and/or/not and the full two-input truth-function family.
    case logical
    /// Moves a value from one type to another (`…From…`), boxes a value as code
    /// (the quotes), or explodes/assembles a vector (`…PushAll` / `…Construct`).
    case conversion
    /// Nondestructive — reads or measures its argument without consuming it
    /// (`.reads`, or a requirement met without a `.takes`). The stack-depth /
    /// is-empty measurements and the iterator `Peek` getters live here.
    case query
    /// Builds an iterator (`iteratorFrom…`, `iteratorRepeating…`, `…Iterate`) —
    /// the constructs that turn a range, collection, or code block into a loop.
    case iteratorCreating
    /// Reports runtime dynamics rather than problem data — a stack's depth or
    /// emptiness (and, once it exists, the step counter).
    case introspection
    /// The furniture that only shuffles a stack — dup, swap, rot, pop, flush,
    /// yank, shove — the `.combinator` role minus its introspective measurements.
    case stackPlumbing
    /// Manipulates `.code` / `.exec` — the conditionals, combinators (K/S/Y), and
    /// looping forms that make control flow, plus the quotes that feed them.
    ///
    /// Deliberately kept as the **union** of `.looping`, `.branching` and the rest
    /// of the `code`/`exec` families, rather than being narrowed when those two
    /// were split out of it, so nothing that asked for "control flow" quietly
    /// started getting less.
    case controlFlow
    /// Runs its argument more than once — the `…Iterate` families, the `execDo…`
    /// forms, `execWhile`/`execDoWhile`/`execY`, and the iterator's own play
    /// tokens. A subset of `.controlFlow`.
    case looping
    /// Chooses between two continuations — `execIf`, `execWhen`, `codeIf`. Also a
    /// subset of `.controlFlow`, and disjoint from `.looping`.
    case branching
    /// Works on a `vec…` stack. A type domain rather than a style, and included
    /// because "silence the vectors" is a thing a search owner actually asks for.
    case vector
    /// Works on a collection — `.vector` plus the `string…` family. Strictly
    /// contains `.vector`.
    case collection
    /// **Can be refused before it runs**, for want of the arguments it declares.
    ///
    /// Exactly the complement of `Interpreter.alwaysSatisfied`, and derived from
    /// `requirements`, so it cannot drift. The other half of "can raise an error"
    /// is `InstructionTag.fallible` — refusal *after* the body runs — which is a
    /// judgment and lives in the declared channel.
    case canStarve

    /// A one-line description, for tooltips / legends in a UI.
    public var summary: String {
        switch self {
        case .arithmetic:       "Numeric computation on int and double."
        case .comparison:       "Ordering and equality, producing a bool."
        case .logical:          "Boolean logic (and / or / not, …)."
        case .conversion:       "Move a value between types, box, or (un)pack a vector."
        case .query:            "Reads or measures without consuming its argument."
        case .iteratorCreating: "Builds an iterator from a range, collection, or code."
        case .introspection:    "Reports runtime dynamics (stack depth / emptiness)."
        case .stackPlumbing:    "Shuffles a stack: dup, swap, rot, pop, flush, …"
        case .controlFlow:      "Manipulates code / exec: conditionals, loops, quotes."
        case .looping:          "Runs its argument more than once."
        case .branching:        "Chooses between two continuations."
        case .vector:           "Works on a vector stack."
        case .collection:       "Works on a collection: vectors and strings."
        case .canStarve:        "Can be refused before it runs, for want of arguments."
        }
    }
}
