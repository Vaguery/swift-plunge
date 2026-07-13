//
//  EvaluationRequest.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// A fully self-contained batch of evaluation work: the individuals and training
/// cases it references, the pairings to run, and the configuration to run them
/// under — everything needed to evaluate, in one Codable message.
///
/// This is the request shape a stateless worker consumes: it carries its own
/// pools rather than referencing ones registered earlier, so nothing has to be
/// remembered between calls.
public nonisolated struct EvaluationRequest: Sendable, Codable {
    public var individuals: [Individual]
    public var trainingCases: [TrainingCase]
    public var pairings: [Pairing]
    public var configuration: RunnerConfiguration

    public init(individuals: [Individual],
         trainingCases: [TrainingCase],
         pairings: [Pairing],
         configuration: RunnerConfiguration = RunnerConfiguration()) {
        self.individuals = individuals
        self.trainingCases = trainingCases
        self.pairings = pairings
        self.configuration = configuration
    }
}


/// Evaluates a self-contained request with no shared state — the natural entry
/// point for a serverless/FaaS worker: decode a request, evaluate, encode the
/// results, remember nothing.
///
/// The request's own individuals and training cases form the resolution pools;
/// a pairing naming an id absent from them yields an `unresolved` result. A
/// duplicate id keeps the last occurrence.
public nonisolated func evaluate(request: EvaluationRequest) async -> [CaseResult] {
    let individuals = Dictionary(
        request.individuals.map { ($0.id, $0) },
        uniquingKeysWith: { _, last in last }
    )
    let trainingCases = Dictionary(
        request.trainingCases.map { ($0.id, $0) },
        uniquingKeysWith: { _, last in last }
    )
    return await evaluatePairings(
        request.pairings,
        individuals: individuals,
        trainingCases: trainingCases,
        configuration: request.configuration
    )
}
