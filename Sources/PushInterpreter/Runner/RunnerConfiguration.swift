//
//  RunnerConfiguration.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
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

    public init(settings: InterpreterSettings = InterpreterSettings(),
         recorders: [RecorderSpec] = [],
         disabledBehaviors: Set<PushInstruction> = [],
         cruxInputTokens: Set<PushInstruction> = []) {
        self.settings = settings
        self.recorders = recorders
        self.disabledBehaviors = disabledBehaviors
        self.cruxInputTokens = cruxInputTokens
    }
}
