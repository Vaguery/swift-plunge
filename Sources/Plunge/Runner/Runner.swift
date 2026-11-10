//
//  Runner.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

import Foundation

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
    configuration: RunnerConfiguration,
    behaviors: BehaviorTable? = nil
) -> CaseResult {
    let interpreter = Interpreter()
    interpreter.config = configuration.settings
    // `cruxMentionsInput` is read off each result's crux, so asking for it means
    // recording provenance for this run, whatever the settings say. Without it
    // every crux would be the bare value and the answer a silent `false`.
    if !configuration.cruxInputTokens.isEmpty {
        interpreter.config.recordsProvenance = true
    }

    // Disabling a behavior leaves its instruction defined-but-unimplemented, so
    // the step loop routes it to an ErrorItem rather than acting on it. A batch
    // builds that table once and passes it in (`behaviorTable(for:)`), so each
    // evaluation shares it instead of editing a copy of its own.
    interpreter.behaviors = behaviors ?? behaviorTable(for: configuration)

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


/// The behavior table a configuration runs with: the whole language, less any
/// `disabledBehaviors`. Shared as-is when nothing is disabled.
nonisolated func behaviorTable(for configuration: RunnerConfiguration) -> BehaviorTable {
    configuration.disabledBehaviors.isEmpty
        ? Interpreter.languageTable
        : BehaviorTable(Interpreter.language, disabling: configuration.disabledBehaviors)
}

/// Whether an item's provenance references any of `tokens` — walking its `crux()`
/// leaves and into any `CodeItem` leaves, since an input-bound block carries its
/// instructions inside. The end-of-run summary behind `CaseResult.cruxMentionsInput`.
nonisolated func cruxMentions(_ item: any Item, anyOf tokens: Set<PushInstruction>) -> Bool {
    func walk(_ items: [any Item]) -> Bool {
        for leaf in items {
            if let instruction = leaf as? InstructionItem, tokens.contains(instruction.value) { return true }
            if let block = leaf.exactly(CodeItem.self), walk(block.value) { return true }
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

    let behaviors = behaviorTable(for: configuration)
    return await withTaskGroup(of: (Int, CaseResult).self) { group in
        let width = concurrencyWidth(configuration, count: resolved.count)
        var next = 0
        func submit() {
            guard next < resolved.count else { return }
            let index = next
            next += 1
            let (pairing, individual, trainingCase) = resolved[index]
            group.addTask {
                guard let individual, let trainingCase else {
                    return (index, CaseResult.unresolved(pairing))
                }
                return (index, evaluateOne(
                    individual: individual,
                    trainingCase: trainingCase,
                    configuration: configuration,
                    behaviors: behaviors
                ))
            }
        }

        // Prime the window, then replace each finished task with the next pairing, so
        // at most `width` runs are ever in flight (bounds peak memory and worker count).
        for _ in 0..<width { submit() }
        var ordered = [CaseResult?](repeating: nil, count: resolved.count)
        while let (index, result) = await group.next() {
            ordered[index] = result
            submit()
        }
        return ordered.compactMap { $0 }
    }
}

/// The evaluation window width: at most this many pairings run concurrently. Honors
/// `RunnerConfiguration.maxConcurrentEvaluations`, defaulting to one per logical core,
/// and never exceeds the pairing count or drops below 1.
private func concurrencyWidth(_ configuration: RunnerConfiguration, count: Int) -> Int {
    let requested = configuration.maxConcurrentEvaluations ?? ProcessInfo.processInfo.activeProcessorCount
    return max(1, min(requested, count))
}


/// The streaming twin of `evaluatePairings`: same concurrent fan-out over fresh
/// interpreters, but each `CaseResult` is yielded the moment its task finishes,
/// **in completion order** rather than request order. Each result carries its own
/// `individual`/`trainingCase` ids, so an unordered stream is enough for a caller
/// filling a grid live (e.g. the population×case heatmap). Canceling the consumer
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

    let behaviors = behaviorTable(for: configuration)
    return AsyncStream { continuation in
        let task = Task {
            await withTaskGroup(of: CaseResult.self) { group in
                let width = concurrencyWidth(configuration, count: resolved.count)
                var next = 0
                func submit() {
                    guard next < resolved.count, !Task.isCancelled else { return }
                    let (pairing, individual, trainingCase) = resolved[next]
                    next += 1
                    group.addTask {
                        guard let individual, let trainingCase else {
                            return CaseResult.unresolved(pairing)
                        }
                        return evaluateOne(
                            individual: individual,
                            trainingCase: trainingCase,
                            configuration: configuration,
                            behaviors: behaviors
                        )
                    }
                }

                // Sliding window: at most `width` runs in flight. On cancellation, stop
                // submitting and cancel the in-flight runs — with the step loop's own
                // cancellation check (Interpreter.run) this stops promptly rather than
                // draining every remaining pairing to completion.
                for _ in 0..<width { submit() }
                while let result = await group.next() {
                    continuation.yield(result)
                    if Task.isCancelled { group.cancelAll(); break }
                    submit()
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
