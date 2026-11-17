//
//  Decision Log Tests.swift
//  PlungeTests
//
//  `.decisions`: every choice a conditional made during a run, with the
//  Boolean that decided and the code each way would run (swift-plunge #57,
//  2026-11-17).
//

@testable import Plunge
import Testing

@Suite
struct DecisionLogTests {

    static func run(_ program: [any Item], input: Int = 7,
                    recorders: [RecorderSpec] = [RecorderSpec("decided", observing: .decisions)]) -> CaseResult {
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        return evaluateOne(individual: Individual(id: "p", program: program, constants: [:]),
                           trainingCase: TrainingCase(id: "c", inputs: [.input0: IntItem(input)]),
                           configuration: RunnerConfiguration(settings: settings, recorders: recorders))
    }

    static func decisions(_ result: CaseResult) -> [Decision] {
        guard case .decisions(let log)? = result.traces["decided"] else { return [] }
        return log
    }

    func i(_ instruction: PushInstruction) -> any Item { InstructionItem(instruction) }

    static func text(_ item: AnyItem?) -> String? { item.map { ($0.item as? CodeItem)?.pretty() ?? "" } }

    /// `input0 > 5`, then "big" or "small".
    static let sizing: [any Item] = [InstructionItem(.input0), IntItem(5), InstructionItem(.intGT),
                                     CodeItem([StringItem("big")]), CodeItem([StringItem("small")]),
                                     InstructionItem(.execIf)]

    @Test func `execIf logs its condition's crux, both blocks, and which way it went`() throws {
        for (input, expected) in [(7, true), (3, false)] {
            let log = Self.decisions(Self.run(Self.sizing, input: input))
            let decision = try #require(log.first)
            #expect(log.count == 1)
            #expect(decision.instruction == .execIf)
            #expect(decision.tookTrue == expected)
            // Comparisons read their arguments and leave them, so the crux clears them.
            #expect(CodeItem(decision.condition.item.crux()).pretty() == "( .input0 5 .intGT 2 .intPopItems )")
            #expect(Self.text(decision.whenTrue) == "( \"big\" )")
            #expect(Self.text(decision.whenFalse) == "( \"small\" )")
        }
    }

    @Test func `execWhen and codeDoIf log one block, and nothing for false`() throws {
        for conditional in [PushInstruction.execWhen, .codeDoIf] {
            let program: [any Item] = [i(.input0), IntItem(5), i(.intGT), CodeItem([IntItem(1)]),
                                       i(conditional)]
            let decision = try #require(Self.decisions(Self.run(program, input: 3)).first)
            #expect(decision.instruction == conditional && !decision.tookTrue)
            #expect(Self.text(decision.whenTrue) == "( 1 )" && decision.whenFalse == nil)
        }
    }

    @Test func `a conditional that refuses for want of arguments decides nothing`() {
        // No Boolean; then a Boolean but only one block for execIf.
        #expect(Self.decisions(Self.run([CodeItem([]), CodeItem([]), i(.execIf)])).isEmpty)
        let oneBlock: [any Item] = [BoolItem(true), CodeItem([]), i(.execIf)]
        #expect(Self.decisions(Self.run(oneBlock)).isEmpty)
    }

    @Test func `a conditional inside a loop logs each pass, in order`() {
        // Three passes, each deciding on the loop's growing int.
        let body = CodeItem([i(.intDup), IntItem(10), i(.intGT), CodeItem([IntItem(1)]),
                             CodeItem([IntItem(2)]), i(.execIf), i(.intAdd)])
        let log = Self.decisions(Self.run([i(.input0), IntItem(3), body, i(.execDoTimes)], input: 9))
        #expect(log.count == 3)
        #expect(log.map(\.tookTrue) == [false, true, true])
        #expect(log.map(\.step) == log.map(\.step).sorted() && Set(log.map(\.step)).count == 3)
    }

    @Test func `without a decisions recorder there is no log, and other recorders read as before`() {
        let result = Self.run(Self.sizing, recorders: [RecorderSpec("top", observing: .top(.string),
                                                                    keeping: .finalOnly)])
        #expect(result.traces["decided"] == nil)
        guard case .items(let readings)? = result.traces["top"] else { Issue.record("no top"); return }
        #expect((readings.last??.item as? StringItem)?.value == "big")
    }
}
