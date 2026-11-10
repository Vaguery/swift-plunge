//
//  CaseResult.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// The outcome of evaluating one pairing: the recorded observations, keyed by
/// recorder name.
///
/// `unresolved` is `true` when the pairing referenced an unknown individual or
/// training-case id; the Runner reports the miss rather than trapping, so a bad
/// reference degrades one result instead of the whole batch.
public nonisolated struct CaseResult: Sendable, Codable {
    public let individual: String
    public let trainingCase: String
    public let traces: [String: RecordedTrace]
    /// Per item-recorder, whether the final recorded item's provenance (`crux`)
    /// references any of the configuration's `cruxInputTokens` — computed in the
    /// worker, while the item is still live, so a caller can score input-blindness
    /// without holding the trace or walking a crux itself. Keyed by recorder name;
    /// empty unless `cruxInputTokens` was set. See `RunnerConfiguration`.
    public let cruxMentionsInput: [String: Bool]
    public let unresolved: Bool
    /// Wall-clock time the evaluation's run took. `.zero` for an unresolved
    /// pairing. Lets a caller flag pathologically slow cases.
    public let duration: Duration

    public init(individual: String,
         trainingCase: String,
         traces: [String: RecordedTrace] = [:],
         cruxMentionsInput: [String: Bool] = [:],
         unresolved: Bool = false,
         duration: Duration = .zero) {
        self.individual = individual
        self.trainingCase = trainingCase
        self.traces = traces
        self.cruxMentionsInput = cruxMentionsInput
        self.unresolved = unresolved
        self.duration = duration
    }

    public static func unresolved(_ pairing: Pairing) -> CaseResult {
        CaseResult(
            individual: pairing.individual,
            trainingCase: pairing.trainingCase,
            unresolved: true
        )
    }
}
