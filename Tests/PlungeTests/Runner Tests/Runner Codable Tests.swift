//
//  Runner Codable Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/13/26.
//

import Foundation
@testable import PushInterpreter
import Testing

@Suite
struct RunnerCodableTests {

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    private func sameBindings(
        _ a: [PushInstruction: any Item],
        _ b: [PushInstruction: any Item]
    ) -> Bool {
        Set(a.keys) == Set(b.keys)
            && a.allSatisfy { key, value in b[key]?.isEqual(to: value) ?? false }
    }

    @Test func `Individual round-trips through JSON`() throws {
        let individual = Individual(
            id: "add",
            program: [
                InstructionItem(.input0),
                InstructionItem(.int0),
                InstructionItem(.intAdd),
                CodeItem([IntItem(1), StringItem("x")])
            ],
            constants: [.int0: IntItem(10), .string3: StringItem("hi")]
        )
        let restored = try roundTrip(individual)

        #expect(restored.id == "add")
        #expect(restored.program == individual.program)
        #expect(sameBindings(restored.constants, individual.constants))
    }

    @Test func `TrainingCase round-trips through JSON`() throws {
        let trainingCase = TrainingCase(
            id: "c1",
            inputs: [.input0: IntItem(5), .input1: VecIntItem([1, 2, 3])]
        )
        let restored = try roundTrip(trainingCase)

        #expect(restored.id == "c1")
        #expect(sameBindings(restored.inputs, trainingCase.inputs))
    }

    @Test func `CaseResult round-trips through JSON`() throws {
        let result = CaseResult(
            individual: "i",
            trainingCase: "c",
            traces: [
                "topInt": .items([nil, AnyItem(IntItem(15))]),
                "count": .ints([2, 1]),
                "out": .strings(["", "7"])
            ]
        )
        let restored = try roundTrip(result)

        #expect(restored.individual == "i")
        #expect(restored.trainingCase == "c")
        #expect(restored.unresolved == false)
        #expect(restored.traces == result.traces)
    }

    @Test func `RunnerConfiguration round-trips through JSON`() throws {
        var settings = InterpreterSettings()
        settings.stepLimit = 250
        let config = RunnerConfiguration(
            settings: settings,
            recorders: [RecorderSpec("topInt", observing: .top(.int))],
            disabledBehaviors: [.intAdd, .intSubtract]
        )
        let restored = try roundTrip(config)

        #expect(restored.settings.stepLimit == 250)
        #expect(restored.recorders.map(\.name) == ["topInt"])
        #expect(restored.disabledBehaviors == [.intAdd, .intSubtract])
    }

    // The wire boundary end to end: encode a request's individual and case,
    // decode them on "the Runner side", evaluate, and confirm the result.
    @Test func `a decoded individual and case evaluate correctly`() async throws {
        let individual = Individual(
            id: "add",
            program: [InstructionItem(.input0), InstructionItem(.int0), InstructionItem(.intAdd)],
            constants: [.int0: IntItem(10)]
        )
        let trainingCase = TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])

        let decodedIndividual = try roundTrip(individual)
        let decodedCase = try roundTrip(trainingCase)

        let runner = Runner(
            configuration: RunnerConfiguration(recorders: [RecorderSpec("topInt", observing: .top(.int))])
        )
        await runner.register(individuals: [decodedIndividual])
        await runner.register(trainingCases: [decodedCase])

        let results = await runner.evaluate(pairings: [Pairing(individual: "add", trainingCase: "c1")])

        guard case let .items(items)? = results[0].traces["topInt"] else {
            Issue.record("expected an item trace")
            return
        }
        let lastInt = items.compactMap { $0 }.compactMap { ($0.item as? IntItem)?.value }.last
        #expect(lastInt == 15)
    }
}
