//
//  Streaming Evaluate Tests.swift
//  PlungeTests
//
//  evaluate(streaming:) is the completion-order twin of evaluate(request:): it must
//  yield exactly the same results, just as they finish rather than all at once.
//

@testable import Plunge
import Testing

@Suite
struct StreamingEvaluateTests {

    private func request(count: Int) -> EvaluationRequest {
        let individuals = (0..<count).map { n in
            Individual(id: "i\(n)", program: [InstructionItem(.input0), InstructionItem(.int0), InstructionItem(.intAdd)],
                       constants: [.int0: IntItem(n)])
        }
        let cases = [TrainingCase(id: "c0", inputs: [.input0: IntItem(5)]),
                     TrainingCase(id: "c1", inputs: [.input0: IntItem(9)])]
        let pairings = individuals.flatMap { ind in cases.map { Pairing(individual: ind.id, trainingCase: $0.id) } }
        let config = RunnerConfiguration(recorders: [RecorderSpec("result", observing: .top(.int), keeping: .finalOnly)])
        return EvaluationRequest(individuals: individuals, trainingCases: cases, pairings: pairings, configuration: config)
    }

    private func key(_ r: CaseResult) -> String { "\(r.individual)|\(r.trainingCase)" }

    @Test func `streaming yields the same result set as the batch`() async {
        let req = request(count: 20)

        let batch = await evaluate(request: req)
        var streamed: [CaseResult] = []
        for await result in evaluate(streaming: req) { streamed.append(result) }

        #expect(streamed.count == batch.count)
        #expect(Set(streamed.map(key)) == Set(batch.map(key)))

        // Same value per pairing, however the two orderings differ.
        func topInt(_ r: CaseResult) -> Int? {
            guard case let .items(items)? = r.traces["result"] else { return nil }
            return items.compactMap { $0 }.compactMap { ($0.item as? IntItem)?.value }.last
        }
        let batchByKey = Dictionary(uniqueKeysWithValues: batch.map { (key($0), topInt($0)) })
        for result in streamed {
            #expect(topInt(result) == batchByKey[key(result)])
        }
    }

    @Test func `an empty request finishes with no elements`() async {
        let req = EvaluationRequest(individuals: [], trainingCases: [], pairings: [])
        var count = 0
        for await _ in evaluate(streaming: req) { count += 1 }
        #expect(count == 0)
    }
}
