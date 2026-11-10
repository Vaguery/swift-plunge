//
//  Builders Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 7/13/26.
//
//  Plain import: verifies the builders are public and ergonomic from outside.

import Plunge
import Testing

@Suite
struct BuildersTests {

    @Test func `pushItem wraps raw values and passes items through`() {
        #expect((pushItem(5) as? IntItem)?.value == 5)
        #expect((pushItem("hi") as? StringItem)?.value == "hi")
        #expect((pushItem(true) as? BoolItem)?.value == true)
        #expect((pushItem([1, 2, 3]) as? VecIntItem)?.value == [1, 2, 3])
        #expect((pushItem(PushInstruction.intAdd) as? InstructionItem)?.value == .intAdd)
        // an existing item passes through unchanged
        #expect((pushItem(IntItem(9)) as? IntItem)?.value == 9)
        // unsupported type
        #expect(pushItem(3.5 as Float) == nil)
    }

    @Test func `bindings builds an instruction-keyed map from raw values`() {
        let inputs = bindings([.input0: 5, .input1: [1, 2, 3]])
        #expect((inputs[.input0] as? IntItem)?.value == 5)
        #expect((inputs[.input1] as? VecIntItem)?.value == [1, 2, 3])
    }

    @Test func `program result builder mixes literals and instructions`() {
        let p = program {
            PushInstruction.input0
            10
            PushInstruction.intAdd
        }
        #expect(p.count == 3)
        #expect((p[0] as? InstructionItem)?.value == .input0)
        #expect((p[1] as? IntItem)?.value == 10)
        #expect((p[2] as? InstructionItem)?.value == .intAdd)
    }

    @Test func `program from a flat token list converts each value`() {
        let p = program([1, "two", PushInstruction.intAdd])
        #expect(p.count == 3)
        #expect((p[0] as? IntItem)?.value == 1)
        #expect((p[2] as? InstructionItem)?.value == .intAdd)
    }

    // End to end using only builders to construct the request.
    @Test func `an individual built entirely with builders evaluates`() async {
        let individual = Individual(
            id: "add",
            program: program {
                PushInstruction.input0
                PushInstruction.int0
                PushInstruction.intAdd
            },
            constants: bindings([.int0: 10])
        )
        let trainingCase = TrainingCase(id: "c1", inputs: bindings([.input0: 5]))

        let runner = Runner(
            configuration: RunnerConfiguration(recorders: [RecorderSpec("topInt", observing: .top(.int))])
        )
        await runner.register(individuals: [individual])
        await runner.register(trainingCases: [trainingCase])
        let results = await runner.evaluate(pairings: [Pairing(individual: "add", trainingCase: "c1")])

        guard case let .items(items)? = results[0].traces["topInt"] else {
            Issue.record("expected an item trace")
            return
        }
        #expect(items.compactMap { $0 }.compactMap { ($0.item as? IntItem)?.value }.last == 15)
    }
}
