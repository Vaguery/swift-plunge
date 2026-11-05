//
//  CruxCompression Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/22/26.
//
//  Proves the prototype's central claim: a looped crux can be collapsed to a
//  compact form that RE-RUNS to the same value. Record (the compressed loop node)
//  and reconstruct (running it) round-trip.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct CruxCompressionTests {

    /// Run `program` and return the end-of-run top of `.double`.
    private func topDouble(after program: [any Item]) async -> Double? {
        let config = RunnerConfiguration(settings: .recordingProvenance,
                                         recorders: [RecorderSpec("r", observing: .top(.double))])
        let request = EvaluationRequest(
            individuals: [Individual(id: "i", program: program, constants: [:])],
            trainingCases: [TrainingCase(id: "c", inputs: [:])],
            pairings: [Pairing(individual: "i", trainingCase: "c")],
            configuration: config)
        let results = await PushInterpreter.evaluate(request: request)
        guard case let .items(readings)? = results.first?.traces["r"],
              let item = readings.last ?? nil else { return nil }
        return (item.item as? DoubleItem)?.value
    }

    /// The canonical fold: `0.0  N  ( 1.0 .doubleAdd )  .execDoTimes` → N.
    private func foldProgram(times: Int) -> [any Item] {
        [DoubleItem(0), IntItem(times),
         CodeItem([DoubleItem(1), InstructionItem(.doubleAdd)]),
         InstructionItem(.execDoTimes)]
    }

    private func foldResultItem(times: Int) async -> (any Item)? {
        let config = RunnerConfiguration(settings: .recordingProvenance,
                                         recorders: [RecorderSpec("r", observing: .top(.double))])
        let request = EvaluationRequest(
            individuals: [Individual(id: "i", program: foldProgram(times: times), constants: [:])],
            trainingCases: [TrainingCase(id: "c", inputs: [:])],
            pairings: [Pairing(individual: "i", trainingCase: "c")],
            configuration: config)
        let results = await PushInterpreter.evaluate(request: request)
        guard case let .items(readings)? = results.first?.traces["r"] else { return nil }
        return (readings.last ?? nil)?.item
    }

    @Test func `a looped crux compresses and re-runs to the same value`() async {
        guard let result = await foldResultItem(times: 100) else { Issue.record("no result"); return }
        let value = (result as? DoubleItem)?.value
        #expect(value == 100)                                   // the loop's answer

        let crux = result.crux()
        #expect(crux.count > 100)                               // O(N): seed + body×100

        let compressed = CruxCompression.compressed(crux)
        #expect(compressed.count <= 6)                          // O(body): seed ( body ) N .execDoTimes
        #expect(compressed.count < crux.count)

        // Record → reconstruct: the compact crux re-runs to the same value…
        let fromCompressed = await topDouble(after: compressed)
        #expect(fromCompressed == value)
        // …and so does the original flat crux (sanity that crux() is itself runnable).
        let fromOriginal = await topDouble(after: crux)
        #expect(fromOriginal == value)
    }

    @Test func `compression is a no-op on a crux with no repeat`() {
        let flat: [any Item] = [DoubleItem(3), DoubleItem(4), InstructionItem(.doubleAdd)]
        #expect(CruxCompression.compressed(flat).count == flat.count)
    }
}
