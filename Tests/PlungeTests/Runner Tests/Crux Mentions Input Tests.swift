//
//  Crux Mentions Input Tests.swift
//  PushInterpreterTests
//
//  The worker summarizes input-blindness at evaluation time — walking the final
//  result item's crux for the configured input tokens — so a caller can score it
//  from `CaseResult.cruxMentionsInput` without holding the trace or walking a crux
//  itself. Covers the walk (relocated from the app's own `mentionsInput` test) and
//  the end-to-end reporting through `evaluate`.
//

@testable import PushInterpreter
import Testing

@Suite
struct CruxMentionsInputTests {

    // MARK: - The walk (relocated from PlungeGP's SearchEngine.mentionsInput test)

    @Test func `crux walk finds an input at a leaf, buried in a code block, or nowhere`() {
        let tokens: Set<PushInstruction> = [.input0, .input1]
        // Direct leaf.
        let direct = DoubleItem(3, call: [DoubleItem(1), InstructionItem(.input0), InstructionItem(.doubleAdd)])
        #expect(cruxMentions(direct, anyOf: tokens))
        // Buried inside a CodeItem leaf.
        let buried = DoubleItem(3, call: [CodeItem([InstructionItem(.input1)]), InstructionItem(.doubleAdd)])
        #expect(cruxMentions(buried, anyOf: tokens))
        // No inputs anywhere.
        let blind = DoubleItem(3, call: [DoubleItem(1), DoubleItem(2), InstructionItem(.doubleAdd)])
        #expect(!cruxMentions(blind, anyOf: tokens))
    }

    // MARK: - End-to-end reporting through the worker

    private func config(cruxInputTokens: Set<PushInstruction>) -> RunnerConfiguration {
        RunnerConfiguration(
            recorders: [RecorderSpec("result", observing: .top(.int), keeping: .finalOnly)],
            cruxInputTokens: cruxInputTokens
        )
    }

    @Test func `reports true when the result derives from an input`() async {
        let runner = Runner(configuration: config(cruxInputTokens: [.input0]))
        // input0 + int0 → the top item's crux references .input0
        let individual = Individual(
            id: "add", program: [InstructionItem(.input0), InstructionItem(.int0), InstructionItem(.intAdd)],
            constants: [.int0: IntItem(10)]
        )
        await runner.register(individuals: [individual])
        await runner.register(trainingCases: [TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])])

        let results = await runner.evaluate(pairings: [Pairing(individual: "add", trainingCase: "c1")])
        #expect(results[0].cruxMentionsInput["result"] == true)
    }

    @Test func `reports false for a constant program that ignores its input`() async {
        let runner = Runner(configuration: config(cruxInputTokens: [.input0]))
        let individual = Individual(id: "const", program: [InstructionItem(.int0)], constants: [.int0: IntItem(42)])
        await runner.register(individuals: [individual])
        await runner.register(trainingCases: [TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])])

        let results = await runner.evaluate(pairings: [Pairing(individual: "const", trainingCase: "c1")])
        #expect(results[0].cruxMentionsInput["result"] == false)
    }

    @Test func `stays empty — no crux walked — when no tokens are requested`() async {
        let runner = Runner(configuration: config(cruxInputTokens: []))
        let individual = Individual(
            id: "add", program: [InstructionItem(.input0), InstructionItem(.int0), InstructionItem(.intAdd)],
            constants: [.int0: IntItem(10)]
        )
        await runner.register(individuals: [individual])
        await runner.register(trainingCases: [TrainingCase(id: "c1", inputs: [.input0: IntItem(5)])])

        let results = await runner.evaluate(pairings: [Pairing(individual: "add", trainingCase: "c1")])
        #expect(results[0].cruxMentionsInput.isEmpty)
    }
}
