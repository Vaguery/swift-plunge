//
//  CaseResult.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// The outcome of evaluating one pairing: the recorded observations, keyed by
/// recorder name.
///
/// `unresolved` is `true` when the pairing referenced an unknown individual or
/// training-case id; the Runner reports the miss rather than trapping, so a bad
/// reference degrades one result instead of the whole batch.
nonisolated struct CaseResult: Sendable {
    let individual: String
    let trainingCase: String
    let traces: [String: RecordedTrace]
    let unresolved: Bool

    init(individual: String,
         trainingCase: String,
         traces: [String: RecordedTrace] = [:],
         unresolved: Bool = false) {
        self.individual = individual
        self.trainingCase = trainingCase
        self.traces = traces
        self.unresolved = unresolved
    }

    static func unresolved(_ pairing: Pairing) -> CaseResult {
        CaseResult(
            individual: pairing.individual,
            trainingCase: pairing.trainingCase,
            unresolved: true
        )
    }
}
