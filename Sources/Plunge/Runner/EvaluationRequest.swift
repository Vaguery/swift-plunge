//
//  EvaluationRequest.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

/// A whole batch of work in one value: the individuals and training cases, the
/// pairings to run, and the configuration to run them with.
///
/// A request carries everything it refers to, so whoever evaluates it needs to
/// remember nothing between calls. It is `Codable`, so it can be sent to
/// another process or another machine. See <doc:EvaluatingPrograms>.
public nonisolated struct EvaluationRequest: Sendable, Codable {
    /// The individuals the pairings may name. If two share an identifier, the later one is used.
    public var individuals: [Individual]
    /// The training cases the pairings may name. If two share an identifier, the later one is used.
    public var trainingCases: [TrainingCase]
    /// The runs to make.
    public var pairings: [Pairing]
    /// The settings, recorders and disabled instructions for every run.
    public var configuration: RunnerConfiguration

    /// Creates a request.
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


/// Evaluates a request and returns one result for each pairing, in the order
/// given, keeping nothing afterward.
///
/// This is the form to use when each batch stands alone, as it does for a
/// service that decodes a request, evaluates it and encodes the reply. A
/// pairing that names an identifier missing from the request gives a result
/// with ``CaseResult/unresolved`` set.
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


/// Evaluates a request and yields each result as soon as its run finishes.
///
/// Results arrive in the order the runs finish, not the order of the pairings;
/// each carries its own identifiers. Use this to show progress as a batch
/// runs, or to stop early: when the stream is dropped, the runs still in
/// progress are canceled.
public nonisolated func evaluate(streaming request: EvaluationRequest) -> AsyncStream<CaseResult> {
    let individuals = Dictionary(
        request.individuals.map { ($0.id, $0) },
        uniquingKeysWith: { _, last in last }
    )
    let trainingCases = Dictionary(
        request.trainingCases.map { ($0.id, $0) },
        uniquingKeysWith: { _, last in last }
    )
    return evaluatePairingsStream(
        request.pairings,
        individuals: individuals,
        trainingCases: trainingCases,
        configuration: request.configuration
    )
}
