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
nonisolated struct RunnerConfiguration: Sendable, Codable {
    var settings: InterpreterSettings
    var recorders: [RecorderSpec]
    var disabledBehaviors: Set<PushInstruction>

    init(settings: InterpreterSettings = InterpreterSettings(),
         recorders: [RecorderSpec] = [],
         disabledBehaviors: Set<PushInstruction> = []) {
        self.settings = settings
        self.recorders = recorders
        self.disabledBehaviors = disabledBehaviors
    }
}
