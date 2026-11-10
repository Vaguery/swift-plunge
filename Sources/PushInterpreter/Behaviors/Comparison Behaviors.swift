//
//  Comparison Behaviors.swift
//  PushInterpreter
//
//  **The instructions that order or equate two values of one stack and hand back
//  a `.bool`**: the 12 generated `…Eq` (whose factory is at the end of this file)
//  and the 28 orderings `…GT`/`…GTE`/`…LT`/`…LTE`.
//
//  The orderings are written in `Int`/`Double`/`Char`/`String`/`Vector
//  Behaviors.swift`, beside the operations they relate to (`intGT` next to
//  `intAdd`), and only registered here. This dictionary no longer decides
//  anything: since 2026-11-10 the `.comparison` role is derived from the
//  `comparison` tag, which also counts containment tests. `Roles Tests` checks
//  that everything registered here carries that tag.
//
//  `…Eq` was once generated in the same per-stack loop as dup and swap, and so
//  was roled as stack furniture; that is why its factory lives here now.
//

import DequeModule

nonisolated extension Interpreter {

    /// The comparisons: the 12 `…Eq`, generated per stack, and the 28 orderings.
    static var comparisonBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]

        // `…Eq` exists for every stack that holds comparable items, so it is
        // generated rather than typed out — the same factory as before, called from
        // here instead of from `stackFamily(for:)`.
        //
        // `.error` is absent, as it is from the stack family: the error stack
        // gets no generated family at all (see `Introspection Behaviors.swift`).
        // `.exec` is absent too: `execEq` was removed, since `( A ) ( B ) .codeEq`
        // asks the same question now that blocks land on `.code`.
        for stack in Self.generatedFamilyStacks where stack != .exec {
            eqComparison_Behavior(for: stack, into: &result)
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
            .vecStringLTE: vecStringLTE_Behavior
        ], uniquingKeysWith: { first, _ in first })

        return result
    }

    /// `xEq` for one stack: whether the top two items are equal, compared at
    /// every level (`isEqual(to:)`), leaving both.
    static func eqComparison_Behavior(
        for stack: PushStack,
        into result: inout [PushInstruction: Behavior]
    ) {
        let type = stack.rawValue
        let name: PushInstruction
        var inst: Behavior

        name = PushInstruction(rawValue: "\(type)Eq")!
        // Every Eq is a non-destructive query: it reads its two operands and
        // leaves them. (`.execEq`, the one destructive form, was removed; see
        // `comparisonBehaviors`.)
        inst = Behavior(
            name,
            requires: [Requirement.reads(stack), Requirement.reads(stack)],
            produces: .results([.bool]),
            fxn: { a, recording in
                let isSame = a[0].isEqual(to: a[1])
                // The crux cleans up the two operands it read, so it reproduces
                // just the bool (`Behavior.reading`).
                return [
                    Router(
                        .bool,
                        BoolItem(
                            isSame,
                            call: recording(Behavior.reading(
                                [stack: 2],
                                producing: .bool,
                                from: [a[1], a[0], InstructionItem(name)]
                            )))
                    )
                ]
            }
        )
        .described("Pushes whether the top two \(stack.plural) are equal, leaving both.")
        result[name] = inst
    }
}
