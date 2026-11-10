//
//  Public API Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/13/26.
//
//  NOTE: this file imports PushInterpreter WITHOUT `@testable`, so it sees only
//  the public surface — exactly what the app's separate module sees. If it
//  compiles, the public API is complete enough to build a program, run it, and
//  read results.

import Foundation
import PushInterpreter
import Testing

@Suite
struct PublicAPITests {

    @Test func `build a program, run it, and read the result — all public`() async {
        // Build a program from the public item types.
        let program: [any Item] = [
            InstructionItem(.input0),
            InstructionItem(.int0),
            InstructionItem(.intAdd)
        ]
        let individual = Individual(id: "add", program: program, constants: [.int0: IntItem(10)])
        let trainingCase = TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])

        var settings = InterpreterSettings()
        settings.stepLimit = 100
        let config = RunnerConfiguration(
            settings: settings,
            recorders: [RecorderSpec("topInt", observing: .top(.int))]
        )

        let runner = Runner(configuration: config)
        await runner.register(individuals: [individual])
        await runner.register(trainingCases: [trainingCase])

        let results = await runner.evaluate(pairings: [Pairing(individual: "add", trainingCase: "c1")])
        #expect(results.count == 1)

        // Read the observation via the public RecordedTrace + AnyItem.
        guard case let .items(items)? = results[0].traces["topInt"] else {
            Issue.record("expected an item trace")
            return
        }
        let last = items.compactMap { $0 }.compactMap { ($0.item as? IntItem)?.value }.last
        #expect(last == 15)
    }

    @Test func `the stateless request path is public`() async {
        let request = EvaluationRequest(
            individuals: [Individual(id: "i", program: [IntItem(7)])],
            trainingCases: [TrainingCase(id: "c")],
            pairings: [Pairing(individual: "i", trainingCase: "c")],
            configuration: RunnerConfiguration(recorders: [RecorderSpec("t", observing: .top(.int))])
        )
        let results = await evaluate(request: request)
        #expect(results.count == 1)
    }

    @Test func `language introspection is public`() async {
        let runner = Runner()
        #expect(runner.instructionNames.contains("intAdd"))

        // The typed introspection surface a caller uses to shape an Experiment:
        // the whole set, and the tag partition (which must sum back to the whole).
        #expect(runner.definedInstructions.contains(.intAdd))
        let byTag = runner.instructionsByRole
        #expect(byTag[.constant]?.isEmpty == false)
        #expect(byTag.values.map(\.count).reduce(0, +) == runner.definedInstructions.count)
    }
}
