//
//  Input Slot Tests.swift
//  PlungeTests
//
//  Declared inputs (2026-11-19, #55): a name to show and a type to check, slot by
//  slot. The input and constant families themselves are in `Instruction Family
//  Tests`.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct InputSlotTests {

    // MARK: - Labels

    private let x1x2 = RunnerConfiguration(inputSlots: [InputSlot("x1", stack: .int), InputSlot("x2", stack: .int)])

    @Test func `a labeled program shows each named input by its name`() {
        let program: [any Item] = [InstructionItem(.input(0)), InstructionItem(.input(1)), InstructionItem(.intAdd),
                                   CodeItem([InstructionItem(.input(1)), InstructionItem(.input(2))])]
        #expect(x1x2.labeled(program) == ".input-x1 .input-x2 .intAdd ( .input-x2 .input2 )")
        // Only for people: pretty() and the instructions themselves are unchanged.
        #expect(program.map { $0.pretty() }.joined(separator: " ") == ".input0 .input1 .intAdd ( .input1 .input2 )")
    }

    @Test func `an input without a name keeps its slot instruction`() {
        let config = RunnerConfiguration(inputSlots: [InputSlot(stack: .int), InputSlot("b")])
        let program: [any Item] = [InstructionItem(.input(0)), InstructionItem(.input(1))]
        #expect(config.labeled(program) == ".input0 .input-b")
        #expect(RunnerConfiguration().labeled(InstructionItem(.input(0))) == ".input0")
    }

    @Test func `the runner labels with its configuration`() async {
        let runner = Runner(configuration: x1x2)
        #expect(await runner.labeled(CodeItem([InstructionItem(.input(1))])) == "( .input-x2 )")
    }

    @Test func `declarations with problems are described`() {
        let config = RunnerConfiguration(inputSlots: [InputSlot("a"), InputSlot("a"), InputSlot("b c"), InputSlot("")])
        #expect(config.inputSlotIssues == [
            "the name \"a\" is declared more than once",
            "input 2's name, \"b c\", contains white space",
            "input 3's name is empty"
        ])
        // Any number of inputs can be declared: the family has no last member.
        let many = RunnerConfiguration(inputSlots: (0..<40).map { InputSlot("x\($0)") })
        #expect(many.inputSlotIssues.isEmpty)
        #expect(x1x2.inputSlotIssues.isEmpty)
    }

    // MARK: - Types

    @Test func `a case is checked against the declared types`() {
        let good = TrainingCase(id: "good", inputs: [.input(0): IntItem(1), .input(1): IntItem(2)])
        #expect(x1x2.mismatches(in: good).isEmpty)

        let bad = TrainingCase(id: "bad", inputs: [.input(0): StringItem("1"), .input(2): IntItem(3)])
        #expect(x1x2.mismatches(in: bad) == [
            InputMismatch(trainingCase: "bad", input: .input(0), reason: .wrongType(declared: .int, found: .string)),
            InputMismatch(trainingCase: "bad", input: .input(2), reason: .undeclared)
        ])
        // Declaring nothing allows anything, as before.
        #expect(RunnerConfiguration().mismatches(in: bad).isEmpty)
    }

    @Test func `a binding slot takes values of mixed types`() {
        let config = RunnerConfiguration(inputSlots: [InputSlot("v", stack: .binding)])
        let asInt = TrainingCase(id: "i", inputs: [.input(0): BindingItem(key: 0, bound: IntItem(4))])
        let asString = TrainingCase(id: "s", inputs: [.input(0): BindingItem(key: 0, bound: StringItem("four"))])
        let bare = TrainingCase(id: "b", inputs: [.input(0): IntItem(4)])
        #expect(config.mismatches(in: asInt).isEmpty)
        #expect(config.mismatches(in: asString).isEmpty)
        #expect(config.mismatches(in: bare).map(\.reason) == [.wrongType(declared: .binding, found: .int)])
    }

    @Test func `the runner refuses cases that don't fit, and says why`() async {
        let runner = Runner(configuration: x1x2)
        let refused = await runner.register(trainingCases: [
            TrainingCase(id: "ok", inputs: [.input(0): IntItem(1), .input(1): IntItem(2)]),
            TrainingCase(id: "no", inputs: [.input(0): DoubleItem(1)])
        ])
        #expect(refused.map(\.trainingCase) == ["no"])
        #expect(refused.first?.description == "case no binds .input0 to a double item, but it is declared int")
        #expect(await runner.trainingCaseCount == 1)
    }

    @Test func `a run leaves an input of the wrong type unbound`() async {
        // Registered before the declarations, then evaluated under them.
        let runner = Runner()
        await runner.register(trainingCases: [TrainingCase(id: "c", inputs: [.input(0): StringItem("x")])])
        await runner.register(individuals: [Individual(id: "p", program: [InstructionItem(.input(0))])])
        await runner.configure(RunnerConfiguration(
            recorders: [RecorderSpec("s", observing: .top(.string), keeping: .finalOnly),
                        RecorderSpec("e", observing: .top(.error), keeping: .finalOnly)],
            inputSlots: [InputSlot("n", stack: .int)]))
        let result = await runner.evaluate(pairings: [Pairing(individual: "p", trainingCase: "c")])[0]
        #expect(result.traces["s"] == .items([nil]))
        guard case .items(let errors) = result.traces["e"], let error = errors.last??.item as? ErrorItem else {
            Issue.record("no error recorded")
            return
        }
        #expect(error.kind == .missingInput)
    }

    // MARK: - Signatures

    @Test func `a typed input's signature names its stack`() throws {
        let config = RunnerConfiguration(inputSlots: [InputSlot("n", stack: .int), InputSlot("any"),
                                                      InputSlot("block", stack: .code)])
        #expect(try #require(config.signature(of: .input(0))).produces == .deferred(.int))
        #expect(try #require(config.signature(of: .input(1))).produces == .input)
        #expect(try #require(config.signature(of: .input(2))).produces == .input)
        #expect(try #require(config.signature(of: .input(3))).produces == .input)
        #expect(config.signature(of: .intAdd) == Runner().signature(of: .intAdd))
    }

    // MARK: - Encoding

    @Test func `declared inputs round-trip, and an older configuration still decodes`() throws {
        let restored = try JSONDecoder().decode(RunnerConfiguration.self, from: JSONEncoder().encode(x1x2))
        #expect(restored.inputSlots == x1x2.inputSlots)

        var older = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(RunnerConfiguration()))
                                     as? [String: Any])
        older["inputSlots"] = nil
        let decoded = try JSONDecoder().decode(RunnerConfiguration.self,
                                               from: JSONSerialization.data(withJSONObject: older))
        #expect(decoded.inputSlots.isEmpty)
    }
}
