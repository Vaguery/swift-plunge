//
//  Runner.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// Evaluates one resolved pairing on a fresh, single-use `Interpreter`.
///
/// Pure and `nonisolated`: it shares no mutable state, constructs its
/// interpreter locally, and never lets it escape, so any number of these can
/// run concurrently — each confined to its own task. This is the reusable heart
/// that both the stateful `Runner` actor and a future stateless FaaS handler
/// build on.
nonisolated func evaluateOne(
    individual: Individual,
    trainingCase: TrainingCase,
    configuration: RunnerConfiguration
) -> CaseResult {
    let interpreter = Interpreter()
    interpreter.config = configuration.settings

    // Disabling a behavior leaves its instruction defined-but-unimplemented, so
    // the step loop routes it to an ErrorItem rather than acting on it.
    for disabled in configuration.disabledBehaviors {
        interpreter.behaviors[disabled] = nil
    }

    interpreter.load(
        inputs: trainingCase.inputs,
        constants: individual.constants,
        program: individual.genome,
        recorders: configuration.recorders.map(AnyRecorder.init)
    )
    interpreter.run()

    var traces: [String: RecordedTrace] = [:]
    for spec in configuration.recorders {
        if let raw = interpreter.recordedData(spec.name) {
            traces[spec.name] = RecordedTrace(target: spec.target, raw: raw)
        }
    }

    return CaseResult(
        individual: individual.id,
        trainingCase: trainingCase.id,
        traces: traces
    )
}


/// A stateful evaluation coordinator.
///
/// It holds shared configuration and pools of individuals and training cases
/// (addressed by id), and evaluates the exact pairings it is asked to — fanning
/// them out concurrently over fresh interpreters. It is transport-agnostic: a
/// local app awaits it directly, while a REST or FaaS front end wraps it.
///
/// Concurrency: the actor's own state is the only thing serialized. The CPU work
/// runs *off* the actor, in child tasks that each build and discard their own
/// `Interpreter`; nothing mutable crosses a task boundary, so the fan-out is
/// data-race-free by construction.
actor Runner {
    private var configuration: RunnerConfiguration
    private var individuals: [String: Individual] = [:]
    private var trainingCases: [String: TrainingCase] = [:]

    init(configuration: RunnerConfiguration = RunnerConfiguration()) {
        self.configuration = configuration
    }

    // MARK: Configuration (interaction modes 3 & 4)

    func configure(_ configuration: RunnerConfiguration) {
        self.configuration = configuration
    }

    var currentConfiguration: RunnerConfiguration { configuration }

    // MARK: Language introspection (interaction modes 1 & 2)

    /// Every instruction the language defines. Static, so `nonisolated`.
    nonisolated var instructionNames: [String] {
        Interpreter.language.keys.map(\.rawValue).sorted()
    }

    /// Instructions currently active: defined and not disabled by the config.
    var activeInstructionNames: [String] {
        let disabled = configuration.disabledBehaviors
        return Interpreter.language.keys
            .filter { !disabled.contains($0) }
            .map(\.rawValue)
            .sorted()
    }

    // MARK: Pools (interaction modes 5 & 6)

    func register(individuals newOnes: [Individual]) {
        for individual in newOnes { individuals[individual.id] = individual }
    }

    func register(trainingCases newOnes: [TrainingCase]) {
        for trainingCase in newOnes { trainingCases[trainingCase.id] = trainingCase }
    }

    var individualCount: Int { individuals.count }
    var trainingCaseCount: Int { trainingCases.count }

    // MARK: Evaluation

    /// Evaluates the requested pairings concurrently, returning results in the
    /// same order as the input. Unknown ids yield an `unresolved` result rather
    /// than an error, so one bad reference never fails the batch.
    func evaluate(pairings: [Pairing]) async -> [CaseResult] {
        let configuration = self.configuration
        let resolved = pairings.map { pairing in
            (pairing, individuals[pairing.individual], trainingCases[pairing.trainingCase])
        }

        return await withTaskGroup(of: (Int, CaseResult).self) { group in
            for (index, entry) in resolved.enumerated() {
                let (pairing, individual, trainingCase) = entry
                group.addTask {
                    guard let individual, let trainingCase else {
                        return (index, CaseResult.unresolved(pairing))
                    }
                    return (index, evaluateOne(
                        individual: individual,
                        trainingCase: trainingCase,
                        configuration: configuration
                    ))
                }
            }

            var ordered = [CaseResult?](repeating: nil, count: resolved.count)
            for await (index, result) in group {
                ordered[index] = result
            }
            return ordered.compactMap { $0 }
        }
    }
}
