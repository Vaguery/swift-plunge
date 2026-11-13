//
//  Documentation Usage Examples Tests.swift
//  PlungeTests
//
//  The code in the DocC articles about using the library (writing programs,
//  inputs and constants, evaluating, observing, errors, limits), compiled and
//  run, so an example cannot drift from the library. Like "Documentation
//  Examples Tests", this file imports the module *without* `@testable`.
//
//  Each test names the article its code comes from; keep the two identical.
//

import Foundation
import Plunge
import Testing

@Suite
struct DocumentationUsageExamplesTests {
    /// One run through the stateless entry point, with the given recorders.
    static func result(of items: [any Item], settings: InterpreterSettings = InterpreterSettings(),
                       recorders: [RecorderSpec], inputs: [PushInstruction: any Item] = [:],
                       constants: [PushInstruction: any Item] = [:],
                       disabling disabled: Set<PushInstruction> = []) async -> CaseResult {
        await evaluate(request: EvaluationRequest(
            individuals: [Individual(id: "p", program: items, constants: constants)],
            trainingCases: [TrainingCase(id: "c", inputs: inputs)],
            pairings: [Pairing(individual: "p", trainingCase: "c")],
            configuration: RunnerConfiguration(settings: settings, recorders: recorders,
                                               disabledBehaviors: disabled)))[0]
    }

    /// The final reading of an item recorder, printed, or nil.
    static func last(_ name: String, in result: CaseResult) -> String? {
        guard case .items(let readings)? = result.traces[name], let reading = readings.last ?? nil else { return nil }
        return reading.item.pretty()
    }

    /// The final reading of an int recorder, or nil.
    static func lastInt(_ name: String, in result: CaseResult) -> Int? {
        guard case .ints(let readings)? = result.traces[name] else { return nil }
        return readings.last ?? nil
    }

    /// The final error's kind and message, or nil.
    static func lastError(in result: CaseResult) -> ErrorItem? {
        guard case .items(let readings)? = result.traces["last error"] else { return nil }
        return (readings.last ?? nil)?.item as? ErrorItem
    }

    static let errorRecorders = [
        RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly),
        RecorderSpec("errors", observing: .count(.error), keeping: .finalOnly),
        RecorderSpec("last error", observing: .top(.error), keeping: .finalOnly)
    ]

    /// *Getting Started*, "When a program goes wrong".
    @Test func `getting started: a starved instruction leaves an error and the run goes on`() async {
        let result = await Self.result(of: program {
            PushInstruction.intMultiply
            PushInstruction.input0
        }, recorders: [
            RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly),
            RecorderSpec("errors", observing: .count(.error), keeping: .finalOnly)
        ], inputs: [.input0: IntItem(3)])
        #expect(Self.last("answer", in: result) == "3")
        #expect(Self.lastInt("errors", in: result) == 1)
    }

    /// *Writing Programs in Swift*: the builder, blocks, raw values, printing.
    @Test func `writing programs: builder, blocks, raw values, printing`() {
        let small = program {
            3
            4
            PushInstruction.intAdd
            2.5
            "hi"
            true
        }
        let more = program {
            CharItem("x")
            VecIntItem([1, 2, 3])
            PushInstruction.vecIntSum
        }
        let nested = program {
            CodeItem(program { 1; PushInstruction.intAdd })
            3
            PushInstruction.codeDo
        }
        let flat = program([3, 4, PushInstruction.intAdd, "x", Character("c"), [1.5, 2.5]])
        let dotted = program { 3; 4; .intAdd }

        #expect(CodeItem(small).pretty() == "( 3 4 .intAdd 2.5 \"hi\" true )")
        #expect(CodeItem(more).pretty() == "( 'x' [1, 2, 3] .vecIntSum )")
        #expect(CodeItem(nested).pretty() == "( ( 1 .intAdd ) 3 .codeDo )")
        #expect(CodeItem(flat).pretty() == "( 3 4 .intAdd \"x\" 'c' [1.5, 2.5] )")
        #expect(CodeItem(dotted).pretty() == "( 3 4 .intAdd )")
        // A value `pushItem` can't convert is left out.
        #expect(program([1, 7 as UInt8, 2]).count == 2)
        #expect(pushItem(7 as UInt8) == nil)
    }

    /// *Writing Programs in Swift*, "Asking what the language contains".
    @Test func `writing programs: asking what the language contains`() {
        let runner = Runner()
        #expect(runner.definedInstructions.count == PushInstruction.allCases.count)
        #expect(runner.summary(of: .intSubtract) == "Subtracts: `a b .intSubtract` gives a − b; refuses on overflow.")
        #expect(runner.signature(of: .intGT)?.reads == [.int: 2])
        #expect(!runner.instructions(producing: .vecBool).isEmpty)
        #expect(runner.instructions(touching: .binding).contains(.intRef))
        #expect(runner.alwaysSatisfiedInstructions.contains(.input0))
        #expect(runner.signature(of: .intQuot)?.isPartial == true)
    }

    /// *Inputs and Constants*: the examples, and what a missing or mistyped one leaves.
    @Test func `inputs and constants: bind, merge, miss`() async {
        let trainingCase = TrainingCase(id: "case 1", inputs: bindings([
            .input0: 5,
            .input1: [1, 2, 3]
        ]))
        let individual = Individual(
            id: "candidate 1",
            program: program { PushInstruction.input0; PushInstruction.int0; PushInstruction.intAdd },
            constants: bindings([.int0: 10]))
        let results = await evaluate(request: EvaluationRequest(
            individuals: [individual], trainingCases: [trainingCase],
            pairings: [Pairing(individual: individual.id, trainingCase: trainingCase.id)],
            configuration: RunnerConfiguration(recorders: Self.errorRecorders)))
        #expect(Self.last("answer", in: results[0]) == "15")
        #expect(trainingCase.inputs[.input1]?.pretty() == "[1, 2, 3]")

        let shared = bindings([.int0: 10, .int1: 100, .string0: "seed"])
        let constants = merged(shared, bindings([.int0: 42]))   // int0 is 42
        #expect(constants[.int0]?.pretty() == "42" && constants[.int1]?.pretty() == "100")

        // An input with nothing bound, a constant with nothing bound, and a
        // constant of the wrong type for its slot.
        let noInput = await Self.result(of: program { PushInstruction.input2 }, recorders: Self.errorRecorders)
        #expect(Self.lastError(in: noInput)?.kind == .missingInput)
        let noConstant = await Self.result(of: program { PushInstruction.int3 }, recorders: Self.errorRecorders)
        #expect(Self.lastError(in: noConstant)?.kind == .missingConstant)
        let wrongType = await Self.result(of: program { PushInstruction.int3 }, recorders: Self.errorRecorders,
                                          constants: [.int3: StringItem("no")])
        #expect(Self.lastError(in: wrongType)?.kind == .missingConstant)

        // A block bound to an input comes to rest on `.code`.
        let block = await Self.result(of: program { PushInstruction.input0 }, recorders: [
            RecorderSpec("code", observing: .top(.code), keeping: .finalOnly)
        ], inputs: [.input0: CodeItem([IntItem(1)])])
        #expect(Self.last("code", in: block) == "( 1 )")

        // The slots are whatever the language has; today, ten inputs and eight types of constant.
        let runner = Runner()
        #expect(runner.instructions(role: .input).contains(.input0))
        let constantTypes = Set(runner.instructions(role: .constant).map { String($0.rawValue.dropLast()) })
        #expect(constantTypes == ["int", "double", "char", "string", "vecInt", "vecDouble", "vecString", "vecBool"])
    }

    /// *Observing a Run*: the recorders, reading a trace, and the two details.
    @Test func `observing a run: recorders and traces`() async {
        let configuration = RunnerConfiguration(recorders: [
            RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly),
            RecorderSpec("errors", observing: .count(.error), keeping: .finalOnly),
            RecorderSpec("steps", observing: .counter, keeping: .finalOnly),
            RecorderSpec("finished", observing: .isEmpty(.exec), keeping: .finalOnly)
        ])
        let runner = Runner(configuration: configuration)
        await runner.register(individuals: [Individual(id: "p", program: program { 3; 4; PushInstruction.intAdd })])
        await runner.register(trainingCases: [TrainingCase(id: "c")])
        let pairing = Pairing(individual: "p", trainingCase: "c")

        let result = await runner.evaluate(pairings: [pairing])[0]

        var printed: [String] = []
        if case .items(let readings)? = result.traces["answer"],
           let answer = readings.last ?? nil {
            printed.append(answer.item.pretty())
            if let int = answer.item as? IntItem { printed.append("\(int.value + 1)") }
        }
        if case .ints(let counts)? = result.traces["errors"], let errors = counts.last ?? nil {
            printed.append("\(errors)")
        }
        #expect(printed == ["7", "8", "0"])
        #expect(Self.lastInt("steps", in: result) == 3)
        #expect(result.traces["finished"] == .bools([true]))
        #expect(!result.unresolved)

        // Every step: the reading at index i is the state after step i + 1.
        let traced = await Self.result(of: program { 3; 4; PushInstruction.intAdd }, recorders: [
            RecorderSpec("top", observing: .top(.int)),
            RecorderSpec("below", observing: .nth(.int, depth: 1))
        ])
        guard case .items(let tops)? = traced.traces["top"], case .items(let below)? = traced.traces["below"] else {
            Issue.record("no traces"); return
        }
        #expect(tops.map { $0?.item.pretty() } == ["3", "4", "7"])
        #expect(below.map { $0?.item.pretty() } == [nil, "3", nil])

        // A run that takes no steps records nothing, even with `.finalOnly`.
        let empty = await Self.result(of: [], recorders: Self.errorRecorders)
        #expect(empty.traces["answer"] == .items([]))

        // Printed output: the items on `.print`, top first, so the latest first.
        let printing = await Self.result(of: program { 3; PushInstruction.intPrint; "a"; PushInstruction.stringPrint },
                                         recorders: [
                                            RecorderSpec("printed", observing: .stack(.print), keeping: .finalOnly),
                                            RecorderSpec("how many", observing: .count(.print), keeping: .finalOnly),
                                            RecorderSpec("ints", observing: .count(.int), keeping: .finalOnly)
                                         ])
        guard case .itemLists(let readings)? = printing.traces["printed"], let printed = readings.last ?? nil else {
            Issue.record("nothing recorded from .print"); return
        }
        #expect(printed.map { $0.item.pretty() } == ["\"a\"", "3"])
        #expect(printed.reversed().map { $0.item.pretty() } == ["3", "\"a\""], "in the order printed")
        #expect(Self.lastInt("how many", in: printing) == 2)
        #expect(Self.lastInt("ints", in: printing) == 0)
    }

    /// *Evaluating Programs*: a full grid, a request sent as JSON, a stream.
    @Test func `evaluating programs: runner, request, stream`() async throws {
        let individuals = [
            Individual(id: "double", program: program { PushInstruction.input0; 2; PushInstruction.intMultiply }),
            Individual(id: "next", program: program { PushInstruction.input0; 1; PushInstruction.intAdd })
        ]
        let trainingCases = [
            TrainingCase(id: "five", inputs: bindings([.input0: 5])),
            TrainingCase(id: "ten", inputs: bindings([.input0: 10]))
        ]
        let configuration = RunnerConfiguration(recorders: [
            RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
        ])

        let pairings = individuals.flatMap { individual in
            trainingCases.map { Pairing(individual: individual.id, trainingCase: $0.id) }
        }

        let runner = Runner(configuration: configuration)
        await runner.register(trainingCases: trainingCases)
        await runner.register(individuals: individuals)
        let results = await runner.evaluate(pairings: pairings)
        #expect(results.map { Self.last("answer", in: $0) } == ["10", "20", "6", "11"])

        // An unknown identifier gives an unresolved result, in its place.
        let mixed = await runner.evaluate(pairings: [Pairing(individual: "nobody", trainingCase: "five"), pairings[0]])
        #expect(mixed.map(\.unresolved) == [true, false])

        let request = EvaluationRequest(
            individuals: individuals,
            trainingCases: trainingCases,
            pairings: pairings,
            configuration: configuration)
        let direct = await evaluate(request: request)
        #expect(direct.map { Self.last("answer", in: $0) } == ["10", "20", "6", "11"])

        let data = try JSONEncoder().encode(request)
        // … elsewhere …
        let received = try JSONDecoder().decode(EvaluationRequest.self, from: data)
        let answers = await evaluate(request: received)
        let reply = try JSONEncoder().encode(answers)
        let decoded = try JSONDecoder().decode([CaseResult].self, from: reply)
        #expect(decoded.map { Self.last("answer", in: $0) } == ["10", "20", "6", "11"])

        var streamed: [String: String] = [:]
        for await result in evaluate(streaming: request) {
            streamed["\(result.individual) \(result.trainingCase)"] = Self.last("answer", in: result)
        }
        #expect(streamed == ["double five": "10", "double ten": "20", "next five": "6", "next ten": "11"])
    }
}

extension DocumentationUsageExamplesTests {

    /// *Errors, Starvation and Refusals*: each example, its error's kind, and what is left.
    @Test func `errors: starving, refusing, missing`() async {
        let recorders = Self.errorRecorders + [
            RecorderSpec("ints", observing: .count(.int), keeping: .finalOnly),
            RecorderSpec("vectors", observing: .count(.vecInt), keeping: .finalOnly),
            RecorderSpec("function", observing: .top(.function), keeping: .finalOnly)
        ]
        let starved = await Self.result(of: program { 1; PushInstruction.intAdd }, recorders: recorders)
        #expect(Self.lastError(in: starved)?.kind == .missingArgument)
        #expect(Self.lastError(in: starved)?.value == "intAdd missing args: .int")
        #expect(Self.last("answer", in: starved) == "1")
        #expect(Self.last("function", in: starved) == "ƒ( ⟨int⟩ ⟨int⟩ .intAdd )")

        let refused = await Self.result(of: program { 1; 0; PushInstruction.intQuot }, recorders: recorders)
        #expect(Self.lastError(in: refused)?.kind == .other)
        #expect(Self.lastInt("ints", in: refused) == 0)

        let missed = await Self.result(of: [VecIntItem([7]), VecIntItem([1, 2]), InstructionItem(.vecIntAdd)],
                                       recorders: recorders)
        #expect(Self.lastError(in: missed)?.kind == .notFound)
        #expect(Self.lastInt("vectors", in: missed) == 1)

        let unconverted = await Self.result(of: program { "abc"; PushInstruction.intFromString }, recorders: recorders)
        #expect(Self.lastError(in: unconverted)?.kind == .conversion)
        let empty = await Self.result(of: [VecIntItem([]), InstructionItem(.vecIntFirst)], recorders: recorders)
        #expect(Self.lastError(in: empty)?.kind == .emptyCollection)

        // A disabled instruction leaves an error and takes nothing.
        let disabled = await Self.result(of: program { 1; 2; PushInstruction.intAdd }, recorders: recorders,
                                         disabling: [.intAdd])
        #expect(Self.lastError(in: disabled)?.value == "intAdd is an unknown instruction")
        #expect(Self.lastInt("ints", in: disabled) == 2)

        // The snippet under "What a search can see".
        let result = starved
        var printed = ""
        if case .items(let readings)? = result.traces["last error"],
           let error = (readings.last ?? nil)?.item as? ErrorItem {
            printed = "\(error.kind) \(error.value)"   // missingArgument intAdd missing args: .int
        }
        #expect(printed == "missingArgument intAdd missing args: .int")
    }

    /// *Limits and Guards*: a size refusal, and telling a finished run from one cut short.
    @Test func `limits: size refusals and the step limit`() async {
        var settings = InterpreterSettings()
        settings.stepLimit = 2_000
        settings.maxVectorLength = 200
        let configuration = RunnerConfiguration(settings: settings)
        #expect(configuration.settings.stepLimit == 2_000)
        #expect(InterpreterSettings().stepLimit == 10_000)

        var small = InterpreterSettings()
        small.maxStringLength = 5
        let refused = await Self.result(of: program { "abcd"; "efgh"; PushInstruction.stringConcat }, settings: small,
                                        recorders: Self.errorRecorders)
        #expect(Self.lastError(in: refused)?.kind == .sizeRefusal)

        var short = InterpreterSettings()
        short.stepLimit = 100
        let cut = await Self.result(of: [CodeItem([IntItem(1)]), InstructionItem(.execY)], settings: short, recorders: [
            RecorderSpec("steps", observing: .counter, keeping: .finalOnly),
            RecorderSpec("finished", observing: .isEmpty(.exec), keeping: .finalOnly),
            RecorderSpec("errors", observing: .count(.error), keeping: .finalOnly),
            RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
        ])
        #expect(Self.lastInt("steps", in: cut) == 100)
        #expect(cut.traces["finished"] == .bools([false]))
        #expect(Self.lastInt("errors", in: cut) == 0)
        #expect(Self.last("answer", in: cut) == "1")

        // The relaxed settings for replaying a crux leave the step and history limits alone.
        let relaxed = InterpreterSettings().reconstructing
        #expect(relaxed.maxVectorLength > InterpreterSettings().maxVectorLength)
        #expect(relaxed.stepLimit == InterpreterSettings().stepLimit)
        #expect(relaxed.maxCallWeight == InterpreterSettings().maxCallWeight)
    }

    /// *Provenance and the Crux*, "Keeping histories": an archive keeps a crux that `AnyItem` drops.
    @Test func `provenance: an archive keeps the history`() async throws {
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        let result = await Self.result(of: program {
            PushInstruction.input0; 10; PushInstruction.intAdd; 99; PushInstruction.input0; PushInstruction.intMultiply
        }, settings: settings, recorders: [
            RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly),
            RecorderSpec("below", observing: .second(.int), keeping: .finalOnly)
        ], inputs: [.input0: IntItem(4)])
        guard case .items(let answers)? = result.traces["answer"], let answer = answers.last ?? nil else {
            Issue.record("no answer"); return
        }
        #expect(Self.last("below", in: result) == "14")

        let data = try JSONEncoder().encode(ItemArchive([answer.item]))
        let restored = try JSONDecoder().decode(ItemArchive.self, from: data).items
        // restored[0].crux() is the crux the original had
        #expect(CodeItem(restored[0].crux()).pretty() == "( 99 .input0 .intMultiply )")

        let plain = try JSONDecoder().decode(AnyItem.self, from: try JSONEncoder().encode(answer))
        #expect(CodeItem(plain.item.crux()).pretty() == "( 396 )")
    }
}
