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
        program: individual.program,
        recorders: configuration.recorders.map(AnyRecorder.init)
    )
    let clock = ContinuousClock()
    let started = clock.now
    interpreter.run()
    let duration = clock.now - started

    var traces: [String: RecordedTrace] = [:]
    for spec in configuration.recorders {
        if let raw = interpreter.recordedData(spec.name) {
            traces[spec.name] = RecordedTrace(target: spec.target, raw: raw)
        }
    }

    // Summarize input-blindness here, while the result item and its provenance are
    // still live, so the caller never has to hold the trace or walk a crux itself.
    var cruxMentionsInput: [String: Bool] = [:]
    if !configuration.cruxInputTokens.isEmpty {
        for (name, trace) in traces {
            guard case let .items(readings) = trace,
                  let lastReading = readings.last, let item = lastReading?.item
            else { continue }
            cruxMentionsInput[name] = cruxMentions(item, anyOf: configuration.cruxInputTokens)
        }
    }

    return CaseResult(
        individual: individual.id,
        trainingCase: trainingCase.id,
        traces: traces,
        cruxMentionsInput: cruxMentionsInput,
        duration: duration
    )
}


/// Whether an item's provenance references any of `tokens` — walking its `crux()`
/// leaves and into any `CodeItem` leaves, since an input-bound block carries its
/// instructions inside. The end-of-run summary behind `CaseResult.cruxMentionsInput`.
nonisolated func cruxMentions(_ item: any Item, anyOf tokens: Set<PushInstruction>) -> Bool {
    func walk(_ items: [any Item]) -> Bool {
        for leaf in items {
            if let instruction = leaf as? InstructionItem, tokens.contains(instruction.value) { return true }
            if let block = leaf as? CodeItem, walk(block.value) { return true }
        }
        return false
    }
    return walk(item.crux())
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
public actor Runner {
    private var configuration: RunnerConfiguration
    private var individuals: [String: Individual] = [:]
    private var trainingCases: [String: TrainingCase] = [:]

    public init(configuration: RunnerConfiguration = RunnerConfiguration()) {
        self.configuration = configuration
    }

    // MARK: Configuration (interaction modes 3 & 4)

    public func configure(_ configuration: RunnerConfiguration) {
        self.configuration = configuration
    }

    public var currentConfiguration: RunnerConfiguration { configuration }

    // MARK: Language introspection (interaction modes 1 & 2)

    /// Every instruction the language defines. Static, so `nonisolated`.
    public nonisolated var instructionNames: [String] {
        Interpreter.language.keys.map(\.rawValue).sorted()
    }

    /// Instructions currently active: defined and not disabled by the config.
    public var activeInstructionNames: [String] {
        let disabled = configuration.disabledBehaviors
        return Interpreter.language.keys
            .filter { !disabled.contains($0) }
            .map(\.rawValue)
            .sorted()
    }

    // MARK: Pools (interaction modes 5 & 6)

    public func register(individuals newOnes: [Individual]) {
        for individual in newOnes { individuals[individual.id] = individual }
    }

    public func register(trainingCases newOnes: [TrainingCase]) {
        for trainingCase in newOnes { trainingCases[trainingCase.id] = trainingCase }
    }

    public var individualCount: Int { individuals.count }
    public var trainingCaseCount: Int { trainingCases.count }

    // MARK: Evaluation

    /// Evaluates the requested pairings against this Runner's pools, concurrently
    /// and in request order. Unknown ids yield an `unresolved` result rather than
    /// an error, so one bad reference never fails the batch.
    public func evaluate(pairings: [Pairing]) async -> [CaseResult] {
        await evaluatePairings(
            pairings,
            individuals: individuals,
            trainingCases: trainingCases,
            configuration: configuration
        )
    }
}


/// The shared fan-out: resolve each pairing against the given pools and evaluate
/// the resolved ones concurrently over fresh interpreters, preserving input
/// order. Unknown ids become `unresolved` results. Used by both the stateful
/// `Runner` actor and the stateless `evaluate(request:)` entry point.
nonisolated func evaluatePairings(
    _ pairings: [Pairing],
    individuals: [String: Individual],
    trainingCases: [String: TrainingCase],
    configuration: RunnerConfiguration
) async -> [CaseResult] {
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


/// The streaming twin of `evaluatePairings`: same concurrent fan-out over fresh
/// interpreters, but each `CaseResult` is yielded the moment its task finishes,
/// **in completion order** rather than request order. Each result carries its own
/// `individual`/`trainingCase` ids, so an unordered stream is enough for a caller
/// filling a grid live (e.g. the population×case heatmap). Cancelling the consumer
/// (dropping the stream) cancels the in-flight work.
nonisolated func evaluatePairingsStream(
    _ pairings: [Pairing],
    individuals: [String: Individual],
    trainingCases: [String: TrainingCase],
    configuration: RunnerConfiguration
) -> AsyncStream<CaseResult> {
    let resolved = pairings.map { pairing in
        (pairing, individuals[pairing.individual], trainingCases[pairing.trainingCase])
    }

    return AsyncStream { continuation in
        let task = Task {
            await withTaskGroup(of: CaseResult.self) { group in
                for (pairing, individual, trainingCase) in resolved {
                    group.addTask {
                        guard let individual, let trainingCase else {
                            return CaseResult.unresolved(pairing)
                        }
                        return evaluateOne(
                            individual: individual,
                            trainingCase: trainingCase,
                            configuration: configuration
                        )
                    }
                }
                for await result in group {
                    continuation.yield(result)
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
