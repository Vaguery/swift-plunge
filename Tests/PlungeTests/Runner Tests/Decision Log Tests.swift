//
//  Decision Log Tests.swift
//  PlungeTests
//
//  `.decisions`: every choice a conditional made during a run, with the
//  Boolean that decided and the code each way would run (swift-plunge #57,
//  2026-11-17).
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct DecisionLogTests {

    static func run(_ program: [any Item], input: Int = 7,
                    recorders: [RecorderSpec] = [RecorderSpec("decided", observing: .decisions)]) -> CaseResult {
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        return evaluateOne(individual: Individual(id: "p", program: program, constants: [:]),
                           trainingCase: TrainingCase(id: "c", inputs: [.input(0): IntItem(input)]),
                           configuration: RunnerConfiguration(settings: settings, recorders: recorders))
    }

    static func decisions(_ result: CaseResult) -> [Decision] {
        guard case .decisions(let log)? = result.traces["decided"] else { return [] }
        return log
    }

    func i(_ instruction: PushInstruction) -> any Item { InstructionItem(instruction) }

    static func text(_ item: AnyItem?) -> String? { item.map { ($0.item as? CodeItem)?.pretty() ?? "" } }

    /// `input0 > 5`, then "big" or "small".
    static let sizing: [any Item] = [InstructionItem(.input(0)), IntItem(5), InstructionItem(.intGT),
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
            let program: [any Item] = [i(.input(0)), IntItem(5), i(.intGT), CodeItem([IntItem(1)]),
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
        let log = Self.decisions(Self.run([i(.input(0)), IntItem(3), body, i(.execDoTimes)], input: 9))
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

/// Counterfactual runs (`InterpreterSettings.flippedDecisions`, 2026-11-19): a
/// decision taken the other way, to see the branch the run did not take.
@Suite
struct FlippedDecisionTests {

    static func run(_ program: [any Item], input: Int, flipping: Set<Int>?,
                    recorders: [RecorderSpec] = [RecorderSpec("decided", observing: .decisions),
                                                 RecorderSpec("answer", observing: .top(.string),
                                                              keeping: .finalOnly)]) -> CaseResult {
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        settings.flippedDecisions = flipping
        return evaluateOne(individual: Individual(id: "p", program: program, constants: [:]),
                           trainingCase: TrainingCase(id: "c", inputs: [.input(0): IntItem(input)]),
                           configuration: RunnerConfiguration(settings: settings, recorders: recorders))
    }

    static func answer(_ result: CaseResult) -> String? {
        guard case .items(let readings)? = result.traces["answer"], let last = readings.last else { return nil }
        return last?.item.pretty()
    }

    @Test func `a flipped decision runs the other branch and is logged as flipped`() throws {
        let plain = Self.run(DecisionLogTests.sizing, input: 7, flipping: nil)
        let flipped = Self.run(DecisionLogTests.sizing, input: 7, flipping: [0])
        #expect(Self.answer(plain) == "\"big\"")
        #expect(Self.answer(flipped) == "\"small\"")
        let decision = try #require(DecisionLogTests.decisions(flipped).first)
        #expect(decision.flipped && !decision.tookTrue)
        // The Boolean keeps its value and history: the condition is the plain run's.
        #expect(decision.condition == DecisionLogTests.decisions(plain).first?.condition)
        #expect(CodeItem(decision.condition.item.crux()).pretty() == "( .input0 5 .intGT 2 .intPopItems )")
    }

    @Test func `decisions are counted in the order they are made, and only the named one flips`() {
        // Two conditionals in a row, both deciding on x > 5.
        let program = DecisionLogTests.sizing + DecisionLogTests.sizing
        let log = DecisionLogTests.decisions(Self.run(program, input: 7, flipping: [1]))
        #expect(log.map(\.tookTrue) == [true, false])
        #expect(log.map(\.flipped) == [false, true])
    }

    @Test func `flipping needs no decision recorder`() {
        let result = Self.run(DecisionLogTests.sizing, input: 3, flipping: [0],
                              recorders: [RecorderSpec("answer", observing: .top(.string), keeping: .finalOnly)])
        #expect(Self.answer(result) == "\"big\"")
    }

    @Test func `a decision saved before flipping existed decodes as not flipped`() throws {
        let decision = try #require(DecisionLogTests.decisions(Self.run(DecisionLogTests.sizing, input: 7,
                                                                        flipping: nil)).first)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(decision))
                                  as? [String: Any])
        object["flipped"] = nil
        let decoded = try JSONDecoder().decode(Decision.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(!decoded.flipped && decoded.tookTrue)
    }
}

/// Selections (2026-11-19): a stack instruction that picks by a computed depth, a
/// lookup by a computed key, or a code point run by a computed index is a choice
/// the crux doesn't see, logged with its options and forced, like a flipped
/// conditional, for a counterfactual run.
@Suite
struct SelectionLogTests {

    /// `10 20 30`, then the depth `x`, then `.intYank`: the item at depth x
    /// (clamped into the three left) comes to the top.
    static let yank: [any Item] = [IntItem(10), IntItem(20), IntItem(30), InstructionItem(.input(0)),
                                   InstructionItem(.intYank)]

    static func run(_ program: [any Item], input: Int, forcing: [Int: Int]? = nil) -> CaseResult {
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        settings.forcedChoices = forcing
        return evaluateOne(individual: Individual(id: "p", program: program, constants: [:]),
                           trainingCase: TrainingCase(id: "c", inputs: [.input(0): IntItem(input)]),
                           configuration: RunnerConfiguration(settings: settings, recorders: [
                               RecorderSpec("decided", observing: .decisions),
                               RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)]))
    }

    static func answer(_ result: CaseResult) -> String? {
        guard case .items(let readings)? = result.traces["answer"], let last = readings.last else { return nil }
        return last?.item.pretty()
    }

    @Test func `a yank by a computed depth logs its depth, its options and the one it took`() throws {
        let result = Self.run(Self.yank, input: 1)
        #expect(Self.answer(result) == "20")
        let decision = try #require(DecisionLogTests.decisions(result).first)
        #expect(decision.isSelection && decision.instruction == .intYank)
        #expect(decision.options == [0, 1, 2])
        #expect(decision.chosen == 1 && decision.outcome == 1 && !decision.flipped)
        #expect(decision.whenTrue == nil && decision.whenFalse == nil)
        #expect(CodeItem(decision.condition.item.crux()).pretty() == "( .input0 )")
    }

    @Test(arguments: [(-4, 0), (0, 0), (2, 2), (99, 2)])
    func `a depth outside the stack takes the option it is clamped to`(_ depth: Int, _ option: Int) throws {
        let decision = try #require(DecisionLogTests.decisions(Self.run(Self.yank, input: depth)).first)
        #expect(decision.chosen == option)
    }

    @Test func `a forced choice picks another option, the depth keeping its history`() throws {
        let plain = Self.run(Self.yank, input: 1)
        let forced = Self.run(Self.yank, input: 1, forcing: [0: 2])
        #expect(Self.answer(forced) == "10")
        let decision = try #require(DecisionLogTests.decisions(forced).first)
        #expect(decision.flipped && decision.chosen == 2)
        #expect(decision.condition == DecisionLogTests.decisions(plain).first?.condition)
        // Forcing the option it took anyway forces nothing.
        let same = try #require(DecisionLogTests.decisions(Self.run(Self.yank, input: 1, forcing: [0: 1])).first)
        #expect(!same.flipped && same.chosen == 1)
    }

    @Test func `a depth that can do only one thing is not a choice`() {
        // With nothing on `.bool`, `.boolPopItems` does nothing, whatever the count.
        let program: [any Item] = [InstructionItem(.input(0)), InstructionItem(.boolPopItems)]
        #expect(DecisionLogTests.decisions(Self.run(program, input: 3)).isEmpty)
    }

    @Test func `selections and conditionals share one count of places`() throws {
        // A yank, then x > 5 deciding: place 0 is the yank, place 1 the conditional.
        let program = Self.yank + DecisionLogTests.sizing
        let log = DecisionLogTests.decisions(Self.run(program, input: 7, forcing: [1: 0]))
        #expect(log.map(\.isSelection) == [true, false])
        #expect(!log[1].flipped, "a forced choice at a conditional's place forces nothing")
    }

    /// 100 bound to key 7, then 200 to key 8; then the key x, looked up.
    static let lookup: [any Item] = [IntItem(100), IntItem(7), InstructionItem(.intRefAs), IntItem(200),
                                     IntItem(8), InstructionItem(.intRefAs), InstructionItem(.input(0)),
                                     InstructionItem(.bindingDeref)]

    @Test func `a lookup by a computed key logs the keys bound, top first, and the one it took`() throws {
        let result = Self.run(Self.lookup, input: 8)
        #expect(Self.answer(result) == "200")
        let decision = try #require(DecisionLogTests.decisions(result).first)
        #expect(decision.isSelection && decision.naming == .key)
        // Key 0 is the input's own binding, below the program's two.
        #expect(decision.options == [8, 7, 0] && decision.chosen == 0)
        #expect(CodeItem(decision.condition.item.crux()).pretty() == "( .input0 )")
    }

    @Test func `an unbound key is the option past the last`() throws {
        let decision = try #require(DecisionLogTests.decisions(Self.run(Self.lookup, input: 9)).first)
        #expect(decision.chosen == 3 && decision.outcome == 3)
    }

    @Test func `a forced lookup takes another key, then puts the key back`() throws {
        let forced = Self.run(Self.lookup, input: 8, forcing: [0: 1])
        #expect(Self.answer(forced) == "100")
        #expect(try #require(DecisionLogTests.decisions(forced).first).flipped)
        // The key is left under the answer: the plain run's, not the forced one.
        let key = Self.run(Self.lookup + [InstructionItem(.intSwap)], input: 8, forcing: [0: 1])
        #expect(Self.answer(key) == "8")
    }

    @Test func `a code point run by a computed index is a selection`() throws {
        let program: [any Item] = [CodeItem([IntItem(100), IntItem(200), IntItem(300)]), InstructionItem(.input(0)),
                                   InstructionItem(.codeDoNthRoot)]
        let plain = Self.run(program, input: 1)
        #expect(Self.answer(plain) == "200")
        let decision = try #require(DecisionLogTests.decisions(plain).first)
        #expect(decision.naming == .position && decision.options == [0, 1, 2] && decision.chosen == 1)
        #expect(Self.answer(Self.run(program, input: 1, forcing: [0: 2])) == "300")
    }

    @Test func `the selections are the stack instructions that take a depth or count`() {
        #expect(Decision.selections.isSuperset(of: [.intYank, .codeShove, .boolPopItems, .doubleDeleteAtDepth,
                                                    .stringYankDup]))
        #expect(Decision.selections.isSuperset(of: [.bindingDeref, .bindingDo, .codeDoNth, .codeEmitNthRoot]))
        #expect(Decision.selections.isDisjoint(with: [.intAdd, .intSwap, .intPop, .execIf]))
    }
}
