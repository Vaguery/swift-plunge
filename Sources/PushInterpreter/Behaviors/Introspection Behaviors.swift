//
//  Introspection Behaviors.swift
//  PushInterpreter
//
//  Instructions that let a program ask about the run it is part of: how far it
//  has got, and what has gone wrong so far.
//
//  ## The `.error` rule
//
//  **These are the only instructions that may look at `.error`, and none of them
//  may touch it.** No `errorPop`, `errorDup`, `errorFlush`, `errorSwap`, `errorRot`,
//  `errorYank`, `errorShove` — the whole combinator family is deliberately absent
//  for this one stack, and `errorStackDepth` is the single exception, because
//  counting is not manipulating.
//
//  The reason is that `.error` is the interpreter's account of what a program did
//  wrong, and an account a program can edit is worth nothing. A run that could pop
//  its own errors could hide a failed instruction from anything downstream that
//  scores it; one that could push errors could manufacture failures it never had.
//  So errors arrive on `.error` exactly one way — as a Router a Behavior returns,
//  or as one of the interpreter's own diagnostics at the push boundary — and leave
//  it never.
//
//  That asymmetry is the point rather than an oversight, and it is why this file
//  exists separately from `Combinator Behaviors.swift`: the combinator family is
//  generated for every stack in `PushStack.allStacks`, so an `.error` exception
//  has to live somewhere that a future "add the missing combinators" sweep will
//  not quietly undo. `Introspection Instruction Tests.swift` asserts the absence.
//
//  ## Provenance: all of these record a stand-in
//
//  Every result here reads **transient execution state** — a step count, a stack's
//  depth, a tally of failures — so provenance law 4b applies: each records a
//  stand-in, the literal number marked as observed (`.pushStepCount_actuallyWas_12`).
//  It replays as the literal, and says where it came from. See `StandInItem`.
//
//  Recording the instruction name instead would be a lie of exactly the kind the
//  round-trip sweep exists to catch: `.errorStackDepth` re-run on a fresh
//  interpreter reports 0, because a fresh interpreter has made no mistakes yet, so
//  a crux naming it would reconstruct to the wrong number every time. The same
//  reasoning retired 22 unreproducible `StackDepth` records; see
//  `stackDepthCombinator_Behavior`.
//

import DequeModule

nonisolated extension Interpreter {

    /// How many steps this run has taken — the same counter `stepLimit` bounds.
    ///
    /// Lets a program notice it is running out of room. Nothing acts on that yet,
    /// but the number is the one piece of run state a program had no way to see.
    ///
    /// **It does not count the step that is asking.** `Interpreter.step` increments
    /// `counter` after dispatching, so a Behavior reads the number of steps
    /// *completed before* it — `1 2 3 .pushStepCount` reports 3, not 4. That is the
    /// stabler of the two readings as well as the one that falls out: counting
    /// itself would tie the answer to where the increment happens to sit in the
    /// loop, which is an implementation detail this instruction should not export.
    static let pushStepCount_Behavior =
        Behavior.contextRead(.pushStepCount, produces: .results([.int])) { _, context in
            [Router(.int, IntItem(context.stepCount).observed(by: .pushStepCount, context.recording))]
        }


    /// How many errors are on `.error`. **The one error combinator**, and the only
    /// instruction in the language that names a stack it cannot alter.
    static let errorStackDepth_Behavior =
        Behavior.contextRead(.errorStackDepth, produces: .results([.int])) { _, context in
            let depth = IntItem(context.depth(of: .error))
            return [Router(.int, depth.observed(by: .errorStackDepth, context.recording))]
        }


    /// Counts the errors on `.error` of one kind.
    ///
    /// Filtering on `ErrorKind` rather than on the message text is what makes the
    /// count exact. The prose wordings (`"intAdd missing args: .int"`,
    /// `"No input for input3"`) are diagnostics for a human and nothing enforces
    /// them, so a substring match would have gone quietly wrong the first time one
    /// was reworded — and a tally that drifts is worse than no tally.
    ///
    /// The count comes from `StackSet.errorCount(of:)`, which keeps a running
    /// tally rather than scanning `.error` (unbounded) on every call.
    static func errorCount_Behavior(
        _ name: PushInstruction,
        counting kind: ErrorKind
    ) -> Behavior {
        Behavior.contextRead(name, produces: .results([.int])) { _, context in
            let n = context.errorCount(of: kind)
            return [Router(.int, IntItem(n).observed(by: name, context.recording))]
        }
    }

    /// How many instructions have starved — refused because a stack came up short.
    /// The signal a program would use to tell "my code is wrong" from "my code ran
    /// and gave a poor answer", which are very different things to a search.
    static let errorMissingArgCount_Behavior =
        errorCount_Behavior(.errorMissingArgCount, counting: .missingArgument)

    /// How many `.inputN` reads found no binding.
    static let errorMissingInputCount_Behavior =
        errorCount_Behavior(.errorMissingInputCount, counting: .missingInput)

    /// How many typed-constant reads (`.int3`, `.vecDouble8`) found no binding.
    static let errorMissingConstantCount_Behavior =
        errorCount_Behavior(.errorMissingConstantCount, counting: .missingConstant)


    static let introspectionBehaviors: [PushInstruction: Behavior] =
    [
        .pushStepCount: pushStepCount_Behavior,
        .errorStackDepth: errorStackDepth_Behavior,
        .errorMissingArgCount: errorMissingArgCount_Behavior,
        .errorMissingInputCount: errorMissingInputCount_Behavior,
        .errorMissingConstantCount: errorMissingConstantCount_Behavior,
    ]
}
