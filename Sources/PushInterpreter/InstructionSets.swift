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

    // TODO: a `contingencySources` sibling — the instructions whose results are
    // contingent *in themselves*, rather than because an argument was.
    //
    // Contingency divides cleanly into two groups today, and only the first is
    // worth naming as a set:
    //
    //  - **Sources**, which set `isContingent = true` regardless of their
    //    arguments: the ten `.inputN`, and — for every stack — `DeepDup`,
    //    `Shove`, `Yank`, `YankDup`, `StackDepth`, `StackIsEmpty`. What unites
    //    them is that the result depends on runtime *state* (which binding is
    //    supplied, how deep a stack happens to be, where an item happens to sit)
    //    rather than on the values handed to the instruction.
    //  - **Propagators**, which is everything else: `Behavior.netContingency(of:)`
    //    over the arguments, so a result is contingent exactly when some argument
    //    was. Nothing to enumerate — it is the default.
    //
    // Two things to settle while building it:
    //
    //  - `DupItems`/`DupTimes` are unresolved. The comment on
    //    `dupItemsCombinator_Behavior` has stood since it was written: it
    //    "introduces some tacit contingency into execution, but it's not entirely
    //    clear if it is making these results contingent in themselves". Today they
    //    re-route arguments verbatim and mark nothing, so they are currently
    //    propagators by omission rather than by decision.
    //  - The set nearly — but not exactly — coincides with provenance law 4b
    //    (Items.swift), which says a result read from transient execution state
    //    records no `call`. `StackDepth`/`StackIsEmpty` are in both. The
    //    combinators are contingency sources but law 1 (a within-stack move
    //    records nothing). The inputs are contingency sources yet record
    //    `[.inputN]`, because a binding is *environment* state that is re-supplied
    //    when a crux is re-run. So the two axes are close cousins, not the same
    //    question: 4b asks "does the VALUE depend on transient state?", this asks
    //    "does the result's presence or position?". Worth stating explicitly in
    //    the doc comment so the sets do not get conflated later.
}
