//
//  SourceTraceTests.swift
//  PlungeTests
//
//  The source trace's positions, steps and reaches on hand-written programs.
//

import Testing
@testable import Plunge

@Suite("Source trace")
struct SourceTraceTests {

    private func trace(_ program: [any Item], inputs: [PushInstruction: any Item] = [:]) -> SourceTrace {
        SourceTrace(individual: Individual(id: "p", program: program),
                    trainingCase: TrainingCase(id: "c", inputs: inputs),
                    configuration: RunnerConfiguration())
    }

    @Test("A flat program's answer reaches its literals by tag and its instructions by step")
    func flat() {
        // 0: 1   1: 2   2: .intAdd   3: 3   4: .intMultiply   5: true (unrelated)
        let result = trace([IntItem(1), IntItem(2), InstructionItem(.intAdd), IntItem(3),
                            InstructionItem(.intMultiply), BoolItem(true)])
        #expect(result.positions.count == 6)
        #expect(result.steps.map(\.position) == [0, 1, 2, 3, 4, 5])
        #expect(result.finished)
        let top = result.tops.first { $0.stack == .int }
        #expect(top?.item.value as? Int == 9)
        #expect(top?.reach.literals == [0, 1, 3])
        #expect(top?.reach.instructions == [2, 4])
        #expect(top?.reach.untraced == 0)
        #expect(result.steps[4].sources == [0, 1, 2, 3])
        #expect(result.tops.first { $0.stack == .bool }?.reach.literals == [5])
    }

    @Test("An instruction's node is placed at its program position; input reads are slots")
    func inputs() {
        // 0: .input0   1: 2   2: .intMultiply
        let result = trace([InstructionItem(.input(0)), IntItem(2), InstructionItem(.intMultiply)],
                           inputs: [.input(0): IntItem(5)])
        let top = result.tops.first { $0.stack == .int }
        #expect(top?.item.value as? Int == 10)
        #expect(top?.reach.literals == [1])
        #expect(top?.reach.instructions == [0, 2])
        #expect(top?.reach.slots == [.input(0)])
        #expect(top?.reach.untraced == 0)
        #expect(result.steps[0].slots == [.input(0)])
        // `.input0` puts the input on `.exec`, and the next step moves it to `.int`.
        #expect(result.steps.map(\.position) == [0, nil, 1, 2])
        #expect(result.steps[1].sources == [0])
        #expect(result.steps[3].sources == [0, 1])
    }

    @Test("Code block contents keep their positions when .codeDo runs them")
    func codeBlock() {
        // 0: ( 1: 4  2: 5  3: .intAdd )   4: .codeDo
        let block = CodeItem([IntItem(4), IntItem(5), InstructionItem(.intAdd)])
        let result = trace([block, InstructionItem(.codeDo)])
        #expect(result.positions.map(\.depth) == [0, 1, 1, 1, 0])
        #expect(result.positions.map(\.parent) == [nil, 0, 0, 0, nil])
        #expect(result.positions[0].isCodeBlock)
        let top = result.tops.first { $0.stack == .int }
        #expect(top?.item.value as? Int == 9)
        #expect(top?.reach.literals == [1, 2])
        #expect(top?.reach.instructions == [3])
        // The block ran from `.code`, so its contents' steps carry their own positions.
        #expect(result.steps.compactMap(\.position).contains(3))
    }

    @Test("Tagging leaves the run's values unchanged")
    func parity() async {
        let program: [any Item] = [CodeItem([IntItem(4), InstructionItem(.intDup), InstructionItem(.intAdd)]),
                                   InstructionItem(.codeDo), InstructionItem(.input(0)), InstructionItem(.intMultiply)]
        let traced = trace(program, inputs: [.input(0): IntItem(3)])
        let results = await evaluate(request: EvaluationRequest(
            individuals: [Individual(id: "p", program: program)],
            trainingCases: [TrainingCase(id: "c", inputs: [.input(0): IntItem(3)])],
            pairings: [Pairing(individual: "p", trainingCase: "c")],
            configuration: RunnerConfiguration(recorders: [RecorderSpec("int", observing: .top(.int))])))
        let plain = results.first.flatMap { trace in
            if case let .items(readings) = trace.traces["int"], let last = readings.last { return last?.item }
            return nil
        }
        #expect(traced.tops.first { $0.stack == .int }?.item.value as? Int == 24)
        #expect(plain?.value as? Int == 24)
    }
}
