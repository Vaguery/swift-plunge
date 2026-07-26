//
//  InstructionSets.swift
//  PushInterpreter
//
//  Semantic groupings of instructions, as static `Set<PushInstruction>`.
//  Deliberately independent of the Plushy layer (which is changing) so these
//  survive that work. Expect siblings here over time — e.g. a symbolic-
//  regression-safe subset, or a string-processing subset — each a plain set
//  the search and analysis layers can intersect against a language.
//

nonisolated public extension PushInstruction {

    /// Instructions that drive iteration by re-pushing a continuation of
    /// themselves onto `.exec`. While such a loop is in flight its instruction
    /// sits somewhere down `.exec`, waiting to run the next pass — the control-
    /// side signal the runaway guard uses to confirm that a fast-filling stack
    /// is being fed by an active loop rather than a large one-shot computation.
    ///
    /// `.execDoCount`/`.execDoRange`/`.execDoTimes` are deliberately **not** here:
    /// they no longer re-push themselves. Each now builds an `IteratorItem` and
    /// hands it to `.iteratorPlay`, so `.iteratorPlay` is what sits on `.exec` for
    /// the life of one of their loops, and it is the signal instead.
    /// `.iteratorPlayDelayed` shoves its next copy further down `.exec` rather than
    /// directly under its payload, which is exactly the shape this set describes.
    static let iterators: Set<PushInstruction> = [
        .execDoWhile, .execWhile, .execY,
        .codeIteratePoints, .codeIterateEmitPoints, .codeIterateDoPoints, .codeIterateRoot,
        .iteratorPlay, .iteratorPlayDelayed,
        .stringIterate,
        .vecBoolIterate, .vecDoubleIterate, .vecIntIterate, .vecStringIterate,
    ]
}
