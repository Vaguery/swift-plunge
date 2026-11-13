//
//  CaseResult.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// What one pairing's run reported: a trace for each recorder, and a little
/// about the run itself. See <doc:ObservingARun>.
public nonisolated struct CaseResult: Sendable, Codable {
    /// The identifier of the individual that was run.
    public let individual: String
    /// The identifier of the training case it was run on.
    public let trainingCase: String
    /// What each recorder collected, keyed by the recorder's name. Empty when the
    /// configuration had no recorders or the pairing was unresolved.
    public let traces: [String: RecordedTrace]
    /// For each item recorder, whether the crux of its final item contains any of
    /// the configuration's ``RunnerConfiguration/cruxInputTokens``: that is,
    /// whether the answer depends on the inputs. Keyed by recorder name, and empty
    /// unless `cruxInputTokens` was set.
    public let cruxMentionsInput: [String: Bool]
    /// Whether the pairing named an individual or a training case that was not
    /// available. Nothing ran, and the traces are empty.
    public let unresolved: Bool
    /// How long the run took, by the clock. Zero for an unresolved pairing. Useful
    /// for finding the programs that are slow.
    public let duration: Duration

    /// Creates a result. The library makes these; you rarely need to.
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

    /// The result for a pairing that named an unknown individual or training case.
    public static func unresolved(_ pairing: Pairing) -> CaseResult {
        CaseResult(
            individual: pairing.individual,
            trainingCase: pairing.trainingCase,
            unresolved: true
        )
    }
}
