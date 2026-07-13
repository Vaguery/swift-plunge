//
//  Runner Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/13/26.
//

@testable import PushInterpreter
import Testing

@Suite
struct RunnerTests {

    /// The last non-nil integer value observed in an item-valued trace.
    private func lastInt(_ trace: RecordedTrace?) -> Int? {
        guard case let .items(items)? = trace else { return nil }
        return items.compactMap { $0 }.compactMap { ($0.item as? IntItem)?.value }.last
    }

    private func topIntConfig() -> RunnerConfiguration {
        RunnerConfiguration(recorders: [RecorderSpec("topInt", observing: .top(.int))])
    }

    @Test func `evaluates a pairing using inputs and constants`() async {
        let runner = Runner(configuration: topIntConfig())
        // input0 + int0  →  5 + 10 = 15
        let individual = Individual(
            id: "add",
            genome: [InstructionItem(.input0), InstructionItem(.int0), InstructionItem(.intAdd)],
            constants: [.int0: IntItem(10)]
        )
        let trainingCase = TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])
        await runner.register(individuals: [individual])
        await runner.register(trainingCases: [trainingCase])

        let results = await runner.evaluate(pairings: [Pairing(individual: "add", trainingCase: "c1")])

        #expect(results.count == 1)
        #expect(results[0].individual == "add")
        #expect(results[0].trainingCase == "c1")
        #expect(results[0].unresolved == false)
        #expect(lastInt(results[0].traces["topInt"]) == 15)
    }

    @Test func `an unknown id yields an unresolved result, not a crash`() async {
        let runner = Runner(configuration: topIntConfig())
        let results = await runner.evaluate(
            pairings: [Pairing(individual: "ghost", trainingCase: "nope")]
        )
        #expect(results.count == 1)
        #expect(results[0].unresolved)
        #expect(results[0].traces.isEmpty)
    }

    @Test func `results preserve request order across a batch`() async {
        let runner = Runner(configuration: topIntConfig())
        let individuals = (0..<3).map { n in
            Individual(
                id: "i\(n)",
                genome: [InstructionItem(.int0)],
                constants: [.int0: IntItem(n * 100)]
            )
        }
        await runner.register(individuals: individuals)
        await runner.register(trainingCases: [TrainingCase(id: "c0")])
        let pairings = (0..<3).map { Pairing(individual: "i\($0)", trainingCase: "c0") }

        let results = await runner.evaluate(pairings: pairings)

        #expect(results.map(\.individual) == ["i0", "i1", "i2"])
        #expect((0..<3).allSatisfy { lastInt(results[$0].traces["topInt"]) == $0 * 100 })
    }

    @Test func `disabled behaviors are dropped from the active set`() async {
        let runner = Runner(configuration: RunnerConfiguration(disabledBehaviors: [.intAdd]))
        let active = await runner.activeInstructionNames
        #expect(!active.contains("intAdd"))
        // still part of the language overall, just inactive here
        #expect(runner.instructionNames.contains("intAdd"))
    }

    @Test func `a disabled behavior does not act during evaluation`() async {
        // With intAdd disabled, the add never happens: the two operands remain
        // and the top of .int stays the second operand (10), not the sum.
        let config = RunnerConfiguration(
            settings: InterpreterSettings(),
            recorders: [RecorderSpec("topInt", observing: .top(.int))],
            disabledBehaviors: [.intAdd]
        )
        let runner = Runner(configuration: config)
        let individual = Individual(
            id: "add",
            genome: [InstructionItem(.input0), InstructionItem(.int0), InstructionItem(.intAdd)],
            constants: [.int0: IntItem(10)]
        )
        await runner.register(individuals: [individual])
        await runner.register(trainingCases: [TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])])

        let results = await runner.evaluate(pairings: [Pairing(individual: "add", trainingCase: "c1")])
        #expect(lastInt(results[0].traces["topInt"]) == 10)
    }

    @Test func `pools report their counts`() async {
        let runner = Runner()
        await runner.register(individuals: [Individual(id: "a", genome: [])])
        await runner.register(trainingCases: [TrainingCase(id: "x"), TrainingCase(id: "y")])
        #expect(await runner.individualCount == 1)
        #expect(await runner.trainingCaseCount == 2)
    }

    @Test func `configuration round-trips through configure`() async {
        let runner = Runner()
        let config = RunnerConfiguration(recorders: [RecorderSpec("c", observing: .counter)])
        await runner.configure(config)
        let current = await runner.currentConfiguration
        #expect(current.recorders.map(\.name) == ["c"])
    }
}
