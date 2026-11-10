//
//  Comparison Behaviors.swift
//  PushInterpreter
//
//  **The 39 instructions that order or equate two values and hand back a `.bool`.**
//
//  This file holds no behavior bodies. It is a *registration* file, and that is the
//  whole point of it: `InstructionRole` is derived from which dictionary defines an
//  instruction, so the dictionary an instruction is registered in **is** its role.
//  Collecting the comparisons here is what makes the role true.
//
//  ## Why this exists
//
//  Every `…Eq` was roled `.combinator` — the language's furniture — because
//  `eqCombinator_Behavior` happened to sit in the same per-stack generator loop as
//  dup, pop, swap and rot. `Eq` was among the first families to be generated, and
//  the rest of the furniture was added around it. Nothing about equality is
//  furniture, but the role said so, and a category built on the role inherited the
//  mistake and described `.intEq` as an instruction "that only shuffles a stack".
//
//  ## Why the bodies stay where they are
//
//  The 28 orderings are still written in `Int`/`Double`/`Char`/`String`/`Vector
//  Behaviors.swift`, beside the operations they relate to — `intGT` next to
//  `intAdd`, where a reader looking at integer arithmetic will find it. Moving the
//  source would have bought nothing: a role is about classification, not about
//  which file a `static let` is typed into.
//
//  So the registrations move and the definitions do not. Every instruction with
//  the `.comparison` **role** carries the derived `comparison` **tag**, which is
//  wider (it counts containment too); `Roles Tests` asserts that, which is what
//  catches a non-comparison registered into this dictionary.
//

import DequeModule

nonisolated extension Interpreter {

    /// The 39 comparisons: 11 `…Eq`, generated per stack, and 28 orderings.
    static var comparisonBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]

        // `…Eq` exists for every stack that holds comparable items, so it is
        // generated rather than typed out — the same factory as before, called from
        // here instead of from `combinators(for:)`.
        //
        // `.error` is absent, as it is from the combinator loop: the error stack
        // gets no generated family at all (see `Introspection Behaviors.swift`).
        // `.exec` is absent too: `execEq` was removed, since `( A ) ( B ) .codeEq`
        // asks the same question now that blocks land on `.code`.
        for stack in Self.generatedFamilyStacks where stack != .exec {
            eqCombinator_Behavior(for: stack, into: &result)
        }

        // The orderings. Only types with a meaningful `<` have them, which is why
        // `.bool`, `.code`, `.exec`, `.iterator` and `.vecBool` carry `Eq` alone.
        result.merge([
            .charGT: charGT_Behavior,
            .charGTE: charGTE_Behavior,
            .charLT: charLT_Behavior,
            .charLTE: charLTE_Behavior,

            .doubleGT: doubleGT_Behavior,
            .doubleGTE: doubleGTE_Behavior,
            .doubleLT: doubleLT_Behavior,
            .doubleLTE: doubleLTE_Behavior,

            .intGT: intGT_Behavior,
            .intGTE: intGTE_Behavior,
            .intLT: intLT_Behavior,
            .intLTE: intLTE_Behavior,

            .stringGT: stringGT_Behavior,
            .stringGTE: stringGTE_Behavior,
            .stringLT: stringLT_Behavior,
            .stringLTE: stringLTE_Behavior,

            .vecDoubleGT: vecDoubleGT_Behavior,
            .vecDoubleGTE: vecDoubleGTE_Behavior,
            .vecDoubleLT: vecDoubleLT_Behavior,
            .vecDoubleLTE: vecDoubleLTE_Behavior,

            .vecIntGT: vecIntGT_Behavior,
            .vecIntGTE: vecIntGTE_Behavior,
            .vecIntLT: vecIntLT_Behavior,
            .vecIntLTE: vecIntLTE_Behavior,

            .vecStringGT: vecStringGT_Behavior,
            .vecStringGTE: vecStringGTE_Behavior,
            .vecStringLT: vecStringLT_Behavior,
            .vecStringLTE: vecStringLTE_Behavior,
        ], uniquingKeysWith: { first, _ in first })

        return result
    }
}
