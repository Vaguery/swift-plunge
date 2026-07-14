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
    static let iterators: Set<PushInstruction> = [
        .execDoCount, .execDoRange, .execDoTimes, .execDoWhile, .execWhile, .execY,
        .codeIteratePoints, .codeIterateRoot,
        .stringIterate,
        .vecBoolIterate, .vecDoubleIterate, .vecIntIterate, .vecStringIterate,
    ]
}
