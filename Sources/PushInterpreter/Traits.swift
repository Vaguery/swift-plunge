//
//  Traits.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/22/26.
//
//  The overlapping-trait tables, built beside `language` the same way `Tags.swift`
//  builds the role partition. Two sources feed them, in order of trust:
//
//    1. **Declared requirements** — `.query` is derived from each `Behavior`'s
//       `requirements` (reads/needs without a take), so it can never drift from
//       what the behaviors actually do. This is the same authority `tags` uses.
//
//    2. **Naming families** — the language is spelled with rigid conventions
//       (`…Eq`/`…LT` for comparisons, `…From…` for conversions, `…StackDepth` for
//       introspection, `int…`/`double…` for numerics). The remaining traits are
//       computed from those, then **intersected with the defined language** so a
//       trait never reports an instruction the language does not hold, and pinned
//       by `TraitsTests` so a convention change that silently reshapes a trait is
//       caught. Unlike the role partition, traits are advisory and overlapping,
//       so there is no "every instruction has one" invariant — a plain collection
//       manipulation carries none and is known by its type domain instead.
//
//  Outflow-based traits (a real "converter" that knows its *result* stack) still
//  wait on Behaviors declaring their Routers — see the note in `Tags.swift`.
//

nonisolated extension Interpreter {

    /// The language categorized by overlapping `InstructionTrait`. Built once,
    /// beside `language`. Advisory and overlapping (cf. the `tags` partition).
    static let traits: [InstructionTrait: Set<PushInstruction>] = {
        let defined = Set(language.keys)
        let combinators = Set(combinatorBehaviors.keys)
        let constants = Set(constantBehaviors.keys)

        // Name-family helpers, always narrowed to the defined language.
        func matching(_ predicate: (String) -> Bool) -> Set<PushInstruction> {
            defined.filter { predicate($0.rawValue) }
        }
        func hasSuffix(_ suffixes: String...) -> (String) -> Bool {
            { name in suffixes.contains { name.hasSuffix($0) } }
        }

        let prints = matching { $0.hasSuffix("Print") } .union(defined.contains(.printNewline) ? [.printNewline] : [])
        let comparison = matching(hasSuffix("Eq", "GT", "GTE", "LT", "LTE"))
        // Introspection comes from two places, and only the first is a naming
        // family. The `…StackDepth`/`…StackIsEmpty` pair is generated for every
        // stack and so belongs to the combinator role; the run-introspection
        // instructions are their own small set that no convention picks out —
        // `hasSuffix("Count")` would also catch `execDoCount`, which is a loop.
        // So they are named, the way `.printNewline` is a few lines above.
        //
        // **This is why introspection is no longer a subset of the combinators.**
        // It straddles the two: `errorStackDepth` reads like the family but is
        // hand-written (the `.error` stack gets no generated furniture — see
        // `Introspection Behaviors.swift`), and the counters are not furniture at
        // all. `stackPlumbing` is still exactly the combinators that are not
        // introspective, so the two continue to partition that role between them.
        let runIntrospection: Set<PushInstruction> = [
            .pushStepCount,
            .errorMissingArgCount, .errorMissingInputCount, .errorMissingConstantCount,
        ]
        let introspection = matching(hasSuffix("StackDepth", "StackIsEmpty"))
            .union(runIntrospection.intersection(defined))
        let stackPlumbing = combinators.subtracting(introspection)
        let conversion = matching { name in
            (name.contains("From") && !name.hasPrefix("iteratorFrom"))
                || ["Quote", "PushAll", "Construct", "PushAllChars", "ParseToLetters"].contains { name.hasSuffix($0) }
        }
        let iteratorCreating = matching { name in
            name.hasPrefix("iteratorFrom") || name.hasPrefix("iteratorRepeating") || name.contains("Iterate")
        }
        // Numeric / boolean / control-flow families = "this type's instructions,
        // minus the cross-cutting kinds already named" — so a new int op joins
        // arithmetic automatically, but its comparison / conversion / furniture do not.
        let arithmetic = matching { $0.hasPrefix("int") || $0.hasPrefix("double") }
            .subtracting(comparison).subtracting(conversion).subtracting(combinators)
            .subtracting(constants).subtracting(prints)
        let logical = matching { $0.hasPrefix("bool") }
            .subtracting(comparison).subtracting(conversion).subtracting(combinators).subtracting(prints)
        let controlFlow = matching { $0.hasPrefix("code") || $0.hasPrefix("exec") }
            .subtracting(combinators).subtracting(prints)

        // Authoritative: reads/needs its argument without popping it.
        let query = Set(language.filter { _, behavior in
            !behavior.readStacks.isEmpty
                || (!behavior.requirements.isEmpty && behavior.consumedStacks.isEmpty)
        }.keys)

        return [
            .arithmetic: arithmetic,
            .comparison: comparison,
            .logical: logical,
            .conversion: conversion,
            .query: query,
            .iteratorCreating: iteratorCreating,
            .introspection: introspection,
            .stackPlumbing: stackPlumbing,
            .controlFlow: controlFlow,
        ]
    }()

    /// The instructions carrying each trait, **sorted** — the reproducible form to
    /// draw from (a `Set`'s iteration order is per-process random; see `Tags.swift`).
    static let sortedTraits: [InstructionTrait: [PushInstruction]] =
        traits.mapValues { $0.sorted { $0.rawValue < $1.rawValue } }

    /// The instructions carrying `trait`, for membership and set algebra.
    static func instructions(trait: InstructionTrait) -> Set<PushInstruction> {
        traits[trait] ?? []
    }

    /// Every trait `instruction` carries (possibly none).
    static func traits(of instruction: PushInstruction) -> Set<InstructionTrait> {
        Set(InstructionTrait.allCases.filter { traits[$0]?.contains(instruction) == true })
    }
}
