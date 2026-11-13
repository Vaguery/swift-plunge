//
//  RunnerConfiguration.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// What every evaluation shares: the interpreter's settings, the recorders that
/// say what to observe, and any instructions to leave out.
///
/// A configuration is set once and used for many pairings. It is `Codable`, so
/// it can be sent with an ``EvaluationRequest``.
public nonisolated struct RunnerConfiguration: Sendable, Codable {
    /// The interpreter's limits and switches. See <doc:LimitsAndGuards>.
    public var settings: InterpreterSettings
    /// What to observe in every run. A run reports nothing but what its recorders
    /// collect, so an empty list gives results with no traces. See
    /// <doc:ObservingARun>.
    public var recorders: [RecorderSpec]
    /// Instructions to leave out of the language. A program that contains one still
    /// runs: the instruction leaves an *unknown instruction* error and does nothing
    /// else.
    public var disabledBehaviors: Set<PushInstruction>
    /// The instructions, usually a problem's inputs, to look for in the crux of
    /// each answer.
    ///
    /// When this is not empty, provenance recording is turned on for the
    /// evaluation, and each ``CaseResult`` reports in
    /// ``CaseResult/cruxMentionsInput`` whether the final item of each item
    /// recorder has any of these instructions in its crux. The check is made as
    /// part of the run, so a caller can find the programs whose answers ignore
    /// their inputs without keeping any items. Left empty, no crux is examined and
    /// nothing is reported.
    public var cruxInputTokens: Set<PushInstruction>
    /// The most pairings to run at once, or `nil` for one for each processor core.
    ///
    /// Evaluation keeps at most this many runs in progress, starting another as
    /// each finishes. Lower it to bound peak memory, since every run in progress
    /// holds its own interpreter, or to limit how much of a shared or metered
    /// machine one batch claims. It is optional so that a configuration encoded
    /// without it still decodes, to the default.
    public var maxConcurrentEvaluations: Int?

    /// Creates a configuration. Every argument has a default: the standard
    /// settings, no recorders, nothing disabled, no crux check, and one run for
    /// each processor core.
    public init(settings: InterpreterSettings = InterpreterSettings(),
         recorders: [RecorderSpec] = [],
         disabledBehaviors: Set<PushInstruction> = [],
         cruxInputTokens: Set<PushInstruction> = [],
         maxConcurrentEvaluations: Int? = nil) {
        self.settings = settings
        self.recorders = recorders
        self.disabledBehaviors = disabledBehaviors
        self.cruxInputTokens = cruxInputTokens
        self.maxConcurrentEvaluations = maxConcurrentEvaluations
    }
}
