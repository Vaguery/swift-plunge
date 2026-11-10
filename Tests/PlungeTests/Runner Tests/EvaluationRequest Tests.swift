//
//  EvaluationRequest Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/13/26.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct EvaluationRequestTests {

    /// The last non-nil integer value observed in an item-valued trace.
    private func lastInt(_ trace: RecordedTrace?) -> Int? {
        guard case let .items(items)? = trace else { return nil }
        return items.compactMap { $0 }.compactMap { ($0.item as? IntItem)?.value }.last
    }

    private func addRequest() -> EvaluationRequest {
        EvaluationRequest(
            individuals: [
                Individual(
                    id: "add",
                    program: [InstructionItem(.input0), InstructionItem(.int0), InstructionItem(.intAdd)],
                    constants: [.int0: IntItem(10)]
                )
            ],
            trainingCases: [TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])],
            pairings: [Pairing(individual: "add", trainingCase: "c1")],
            configuration: RunnerConfiguration(recorders: [RecorderSpec("topInt", observing: .top(.int))])
        )
    }

    @Test func `a self-contained request evaluates statelessly`() async {
        let results = await evaluate(request: addRequest())
        #expect(results.count == 1)
        #expect(lastInt(results[0].traces["topInt"]) == 15)
    }

    @Test func `EvaluationRequest round-trips through JSON`() throws {
        let data = try JSONEncoder().encode(addRequest())
        let restored = try JSONDecoder().decode(EvaluationRequest.self, from: data)
        #expect(restored.individuals.map(\.id) == ["add"])
        #expect(restored.trainingCases.map(\.id) == ["c1"])
        #expect(restored.pairings == [Pairing(individual: "add", trainingCase: "c1")])
        #expect(restored.configuration.recorders.map(\.name) == ["topInt"])
    }

    // The whole serverless path: bytes in, decode, evaluate, results out.
    @Test func `the full decode-evaluate path produces the right answer`() async throws {
        let requestBytes = try JSONEncoder().encode(addRequest())

        let request = try JSONDecoder().decode(EvaluationRequest.self, from: requestBytes)
        let results = await evaluate(request: request)
        let responseBytes = try JSONEncoder().encode(results)

        // a caller decoding the response sees the computed value
        let decodedResults = try JSONDecoder().decode([CaseResult].self, from: responseBytes)
        #expect(lastInt(decodedResults[0].traces["topInt"]) == 15)
    }

    @Test func `an unresolved pairing degrades one result, not the batch`() async {
        var request = addRequest()
        request.pairings = [
            Pairing(individual: "add", trainingCase: "c1"),
            Pairing(individual: "ghost", trainingCase: "c1")
        ]
        let results = await evaluate(request: request)

        #expect(results.count == 2)
        #expect(results[0].unresolved == false)
        #expect(lastInt(results[0].traces["topInt"]) == 15)
        #expect(results[1].unresolved)
    }
}
