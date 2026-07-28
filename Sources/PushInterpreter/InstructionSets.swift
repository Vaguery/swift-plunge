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
    /// themselves onto `.exec` — **now derived from the `.reEntrant` tag**, which
    /// each such behavior declares at its own definition.
    ///
    /// This used to be typed out here by hand, which is the drift problem the tag
    /// channel exists to fix: a set living far from the definitions it describes
    /// has no way to notice when one of them changes. It survives as a name because
    /// the runaway guard and four test files read it; they can move to
    /// `Interpreter.instructions(declaring: .reEntrant)` separately rather than in
    /// the same change that moved the judgment.
    ///
    /// Computed once, not per call: `RunawayGuard` asks this on every step.
    static let iterators: Set<PushInstruction> =
        Interpreter.instructions(declaring: .reEntrant)
}
