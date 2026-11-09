//
//  Runner Acceptance Tests.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 7/14/26.
//
//  Plain import (no @testable): drives the library only through its public
//  surface, the way the search process will. RandomCode is a test helper.

import Foundation
import PushInterpreter
import Testing

@Suite
struct RunnerAcceptanceTests {

    // Fills a per-step trace forward to `length` by repeating its last reading —
    // the "fill missing readings with the final state" step, done consumer-side
    // (the Runner returns raw per-step data; padding is the caller's policy).
    private func filledForward<T>(_ trace: [T?], to length: Int) -> [T?] {
        if trace.count >= length { return Array(trace.prefix(length)) }
        let last: T? = trace.last ?? nil
        return trace + Array(repeating: last, count: length - trace.count)
    }

    // 1. creates a collection of 20 random individuals of ~40 instructions each (built directly from the public language introspection, no genome layer). The programs should all contain at least one instance of `.input0` and `.input1` tokens each. One program should also be modified so that the following tokens are at its tail: `[.input0, .input1, .intMultiply, .int0, .intMultiply]`
    // 2. sets up a collection of 10 training cases, where there are 2 integer inputs x1 = `input0` and x2 = `input1`, with values drawn uniformly from (-100...100), and an expected value of 1964 + 8 * x1 + 11 * x1 * x2
    // 3. set up one set of constants where all 10 .double and .int constants are defined, but none of the thers
    // 4. use 3 Recorders for each evaluation: One that watches the top `.int` item on that stack, one which counts the number of `ErrorItem` entries on the `.error` stack at each step, and one which reports the total number of steps executed running the program (either the number of actual steps, or the time at which the stepLimit triggered). Set the first two to fill in any missing readings with the final state of the program, if it terminates before the limit is triggered, but obviously not the step counter
    // 5. run each case for 500 steps, or until the program is exhausted
    //
    // send each training case and program pair to the Runner
    //
    // assert no errors occur
    // assert all the results return
    //
    // when the results have been received, ensure there is enough information to determine
    // 1. the average `IntItem.value` on every step where there was one present
    // 2. the final `IntItem.value` present at the last step
    // 3. the proportion of time there was a valid `IntItem` present in 200 steps
    // 4. the total number of error messages on the stack at the end of 200 steps
    //
    // these checks do not imply the existence of particular behavior in the receiver, just capacity to produce information useful for some use cases

    @Test func `round trip population example`() async throws {
        let stepLimit = 500
        let window = 200

        // 1. 20 individuals: 38 random instructions drawn from the public language
        // introspection, plus guaranteed .input0/.input1. No genome layer — this
        // test stands in for the search process, which builds programs itself and
        // hands the Runner an already-translated [any Item]. Program 0 gets a
        // modified tail.
        let pool = Runner().definedInstructions
        var programs: [[any Item]] = (0..<20).map { _ in
            var program: [any Item] = (0..<38).map { _ in InstructionItem(pool.randomElement()!) as any Item }
            program.append(InstructionItem(.input0))
            program.append(InstructionItem(.input1))
            return program
        }
        let tail: [PushInstruction] = [.input0, .input1, .intMultiply, .int0, .intMultiply]
        programs[0] += tail.map { InstructionItem($0) }

        // 3. one shared constant set: all ten .int and .double slots (no scalar
        // .bool constants exist in the language). Built in pieces and merged.
        var intConstants: [PushInstruction: any Item] = [:]
        var doubleConstants: [PushInstruction: any Item] = [:]
        for i in 0..<10 {
            intConstants[PushInstruction(rawValue: "int\(i)")!] = IntItem(RandomCode.randomInt(50))
            doubleConstants[PushInstruction(rawValue: "double\(i)")!] = DoubleItem(RandomCode.randomDouble(50))
        }
        let constants = merged(intConstants, doubleConstants)

        let individuals = programs.enumerated().map { index, program in
            Individual(id: "ind\(index)", program: program, constants: constants)
        }

        // 2. 10 training cases; expected values kept caller-side (the Runner never
        // needs them — they belong to the scoring the search process does).
        var cases: [TrainingCase] = []
        var expected: [String: Int] = [:]
        for c in 0..<10 {
            let x1 = RandomCode.randomInt(100)
            let x2 = RandomCode.randomInt(100)
            let id = "case\(c)"
            cases.append(TrainingCase(id: id, inputs: bindings([.input0: x1, .input1: x2])))
            expected[id] = 1964 + 8 * x1 + 11 * x1 * x2
        }

        // 4 & 5. three recorders, 500-step limit.
        var settings = InterpreterSettings()
        settings.stepLimit = stepLimit
        let config = RunnerConfiguration(
            settings: settings,
            recorders: [
                RecorderSpec("topInt", observing: .top(.int)),
                RecorderSpec("errors", observing: .count(.error)),
                RecorderSpec("steps", observing: .counter),
            ]
        )

        // Send every (program, case) pair — 200 pairings.
        let runner = Runner(configuration: config)
        await runner.register(individuals: individuals)
        await runner.register(trainingCases: cases)
        let pairings = individuals.flatMap { individual in
            cases.map { Pairing(individual: individual.id, trainingCase: $0.id) }
        }
        let results = await runner.evaluate(pairings: pairings)

        // assert all results return, and every pairing resolved.
        #expect(results.count == 200)
        #expect(results.allSatisfy { !$0.unresolved })

        // For every result, confirm the four use-case metrics are derivable.
        for result in results {
            guard case let .items(topItems)? = result.traces["topInt"],
                  case let .ints(errorCounts)? = result.traces["errors"],
                  case let .ints(stepTrace)? = result.traces["steps"]
            else {
                Issue.record("a recorder trace was missing or the wrong shape")
                continue
            }

            let ints: [Int?] = topItems.map { ($0?.item as? IntItem)?.value }
            let present = ints.compactMap { $0 }

            // 1. average IntItem.value over steps where one was present
            let average: Double? = present.isEmpty
                ? nil
                : Double(present.reduce(0, +)) / Double(present.count)

            // 2. final IntItem.value present at the last step
            let finalInt: Int? = present.last

            // 3. proportion of the 200-step window with a valid Int (fill-forward)
            let filledInts = filledForward(ints, to: window)
            let proportion = Double(filledInts.filter { $0 != nil }.count) / Double(window)

            // 4. error count at the end of the 200-step window (fill-forward)
            let filledErrors = filledForward(errorCounts, to: window)
            let errorsAtWindowEnd = (filledErrors.last ?? 0) ?? 0

            // total steps run (NOT filled — the true count)
            let totalSteps = stepTrace.count

            // Capacity, not particular values: each metric is well-formed, and
            // the caller's expected value is on hand for scoring.
            #expect(proportion >= 0 && proportion <= 1)
            #expect(errorsAtWindowEnd >= 0)
            #expect(totalSteps <= stepLimit)
            #expect(expected[result.trainingCase] != nil)
            _ = average
            _ = finalInt
        }
    }
}
