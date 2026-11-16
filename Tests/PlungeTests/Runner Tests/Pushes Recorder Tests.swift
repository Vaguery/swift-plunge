//
//  Pushes Recorder Tests.swift
//  PlungeTests
//
//  `.pushes(stack)`: every distinct item pushed onto a stack during a run, the
//  intermediate results as well as the final ones (swift-plunge #57,
//  2026-11-16).
//

@testable import Plunge
import Testing

@Suite
struct PushesRecorderTests {

    static func run(_ program: [any Item], input: Int = 5, provenance: Bool = true,
                    recorders: [RecorderSpec] = [RecorderSpec("pushed", observing: .pushes(.int))])
        -> CaseResult {
        var settings = InterpreterSettings()
        settings.recordsProvenance = provenance
        return evaluateOne(individual: Individual(id: "p", program: program, constants: [:]),
                           trainingCase: TrainingCase(id: "c", inputs: [.input0: IntItem(input)]),
                           configuration: RunnerConfiguration(settings: settings, recorders: recorders))
    }

    static func pushed(_ result: CaseResult, _ name: String = "pushed") -> [any Item] {
        guard case .itemLists(let readings) = result.traces[name], readings.count == 1, let items = readings[0]
        else { return [] }
        return items.map(\.item)
    }

    static func values(_ items: [any Item]) -> [Int] { items.compactMap { ($0 as? IntItem)?.value } }

    /// `input0`, then three passes of `2 .intMultiply`.
    static let doubling: [any Item] = [InstructionItem(.input0), IntItem(3),
                                       CodeItem([IntItem(2), InstructionItem(.intMultiply)]),
                                       InstructionItem(.execDoTimes)]

    @Test func `a loop's every partial result is collected, in the order made`() {
        let items = Self.pushed(Self.run(Self.doubling))
        let products = items.filter { $0.cruxDependence.contains(.input) }
        #expect(Self.values(products) == [5, 10, 20, 40])
        // The literals too, each value once: the count, and the 2 each pass pushes.
        #expect(Self.values(items.filter { !$0.cruxDependence.contains(.input) }) == [3, 2])
    }

    @Test func `copies made by dup are one item, collected once`() {
        let items = Self.pushed(Self.run([InstructionItem(.input0), InstructionItem(.intDup),
                                          InstructionItem(.intAdd)]))
        #expect(Self.values(items) == [5, 10])
    }

    @Test func `without provenance, each distinct value is collected once`() {
        let items = Self.pushed(Self.run([InstructionItem(.input0), InstructionItem(.intDup), InstructionItem(.intAdd),
                                          IntItem(10)], provenance: false))
        #expect(Self.values(items) == [5, 10])
        #expect(items.allSatisfy { $0.call.isEmpty })
    }

    @Test func `other recorders read as before, and other stacks are not collected`() {
        let recorders = [RecorderSpec("pushed", observing: .pushes(.int)),
                         RecorderSpec("bools", observing: .pushes(.bool)),
                         RecorderSpec("top", observing: .top(.int), keeping: .finalOnly)]
        let with = Self.run(Self.doubling, recorders: recorders)
        let without = Self.run(Self.doubling, recorders: [recorders[2]])
        #expect(with.traces["top"] == without.traces["top"])
        #expect(Self.pushed(with, "bools").isEmpty)
    }

    @Test func `a reused interpreter starts each run's collection empty`() {
        let interpreter = Interpreter()
        let spec = RecorderSpec("pushed", observing: .pushes(.int))
        interpreter.load(inputs: [.input0: IntItem(5)], program: Self.doubling, recorders: [AnyRecorder(spec)])
        interpreter.run()
        interpreter.load(inputs: [.input0: IntItem(1)], program: [InstructionItem(.input0)],
                         recorders: [AnyRecorder(spec)])
        interpreter.run()
        let raw = interpreter.recordedData("pushed")?.first as? [any Item]
        #expect(Self.values(raw ?? []) == [1])
    }
}
