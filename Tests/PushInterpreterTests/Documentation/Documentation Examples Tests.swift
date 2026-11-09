//
//  Documentation Examples Tests.swift
//  PushInterpreterTests
//
//  The code in the DocC articles, compiled and run, so an example cannot drift
//  from the library. This file imports the module *without* `@testable`: an
//  example may use only the public API, as a reader's code would.
//
//  Each test names the article and section its code comes from; keep the two
//  identical.
//

import PushInterpreter
import Testing

@Suite
struct DocumentationExamplesTests {

    /// *Getting Started*, "Run a program".
    @Test func `getting started: square an input`() async throws {
        let square = Individual(id: "square", program: program {
            PushInstruction.input0
            PushInstruction.input0
            PushInstruction.intMultiply
        })
        let cases = [
            TrainingCase(id: "three", inputs: [.input0: IntItem(3)]),
            TrainingCase(id: "minus five", inputs: [.input0: IntItem(-5)]),
        ]

        let runner = Runner(configuration: RunnerConfiguration(recorders: [
            RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
        ]))
        await runner.register(individuals: [square])
        await runner.register(trainingCases: cases)

        let results = await runner.evaluate(pairings: cases.map {
            Pairing(individual: square.id, trainingCase: $0.id)
        })
        for result in results {
            if case .items(let answers)? = result.traces["answer"], let answer = answers.last ?? nil {
                print(result.trainingCase, answer.item.pretty())   // three 9, minus five 25
            }
        }

        // Not in the article: the check that keeps it honest.
        let answers = results.map { result -> String? in
            guard case .items(let answers)? = result.traces["answer"], let last = answers.last ?? nil else { return nil }
            return last.item.pretty()
        }
        #expect(answers == ["9", "25"])
    }

    /// Runs `items` through the public API and returns the final top of `stack`.
    static func finalTop(of stack: PushStack, after items: [any Item]) async -> String? {
        let runner = Runner(configuration: RunnerConfiguration(recorders: [
            RecorderSpec("top", observing: .top(stack), keeping: .finalOnly)
        ]))
        await runner.register(individuals: [Individual(id: "p", program: items)])
        await runner.register(trainingCases: [TrainingCase(id: "c")])
        let result = await runner.evaluate(pairings: [Pairing(individual: "p", trainingCase: "c")])[0]
        guard case .items(let tops)? = result.traces["top"], let last = tops.last ?? nil else { return nil }
        return last.item.pretty()
    }

    /// *The Push Language*, "Programs".
    @Test func `the push language: three small programs`() async {
        let sum = await Self.finalTop(of: .int, after: program {
            3; 4; PushInstruction.intAdd; 2; PushInstruction.intMultiply
        })
        #expect(sum == "14")
        let length = await Self.finalTop(of: .int, after: program { "hello"; PushInstruction.stringLength })
        #expect(length == "5")
        let ran = await Self.finalTop(of: .int, after: [
            CodeItem([IntItem(1), InstructionItem(.intAdd)]), IntItem(3), InstructionItem(.codeDo)
        ])
        #expect(ran == "4")
    }
}
