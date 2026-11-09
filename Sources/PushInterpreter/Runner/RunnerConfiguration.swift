//
//  RunnerConfiguration.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/13/26.
//

/// Shared configuration applied to every evaluation: interpreter limits, the
/// recorders that define what counts as "output", and any behaviors to disable.
///
/// Sent once and reused across many pairings, so the per-request payload stays
/// just the pairings themselves.
public nonisolated struct RunnerConfiguration: Sendable, Codable {
    public var settings: InterpreterSettings
    public var recorders: [RecorderSpec]
    public var disabledBehaviors: Set<PushInstruction>
    /// Instruction tokens (typically a benchmark's inputs) the worker checks each
    /// item-recorder's final item against: it records in `CaseResult.cruxMentionsInput`
    /// whether that item's provenance references any of them. Left empty, no crux is
    /// walked and no summary is produced — so a caller pays for this only when it
    /// wants input-blindness scored without retaining traces. See `CaseResult`.
    public var cruxInputTokens: Set<PushInstruction>
    /// The maximum number of pairings evaluated **concurrently**. The fan-out keeps at
    /// most this many interpreter runs in flight at once (a sliding window), rather than
    /// submitting every pairing as a task up front. `nil` means "one per logical core"
    /// (`ProcessInfo.activeProcessorCount`). Bounding this matters two ways: it caps peak
    /// memory (each in-flight run holds its own interpreter and allocation churn), and on
    /// a metered/serverless host it caps how many workers spin up at once instead of
    /// launching thousands the moment a batch arrives. Optional, so old configs decode to
    /// the core-count default.
    public var maxConcurrentEvaluations: Int?

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
