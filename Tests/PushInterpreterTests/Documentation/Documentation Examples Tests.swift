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

    /// *Tagging Instructions*, "Adding your own tags".
    @Test func `tagging: add tags, find neighbors, disable by tag`() async {
        let tagging = InstructionTagging.standard
            .adding("psb:vectorAverage", to: [.vecIntSum, .vecDoubleSum])
            .adding("myProject", to: [.intAdd, .intMultiply])

        _ = tagging.tags(of: .vecIntSum)          // the standard tags, and psb:vectorAverage
        _ = tagging.neighbors(of: .intAdd).first // the instruction sharing most of its tags

        let configuration = RunnerConfiguration(
            disabledBehaviors: tagging.instructions(taggedAnyOf: ["psb:vectorAverage"]))

        // Not in the article: the checks that keep it honest.
        #expect(tagging.tags(of: .vecIntSum).isSuperset(of: ["psb:vectorAverage", .measurement, .collection]))
        #expect(tagging.neighbors(of: .intAdd).first.map { tagging.tags(of: $0).contains("myProject") } == true)
        #expect(configuration.disabledBehaviors == [.vecIntSum, .vecDoubleSum])
        let runner = Runner(configuration: configuration)
        #expect(await !runner.activeInstructionNames.contains("vecIntSum"))
        #expect(runner.instructions(touching: .binding).contains(.intRef))
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

    /// Runs `items` and returns each listed stack's final contents, top first.
    static func finalStacks(_ stacks: [PushStack], after items: [any Item],
                            inputs: [PushInstruction: any Item] = [:]) async -> [PushStack: [String]] {
        // A recorder sees one item per stack position; ask for enough of them.
        let runner = Runner(configuration: RunnerConfiguration(recorders: stacks.flatMap { stack in
            [RecorderSpec("\(stack.rawValue) count", observing: .count(stack), keeping: .finalOnly),
             RecorderSpec("\(stack.rawValue) top", observing: .top(stack), keeping: .finalOnly),
             RecorderSpec("\(stack.rawValue) second", observing: .second(stack), keeping: .finalOnly)]
        }))
        await runner.register(individuals: [Individual(id: "p", program: items)])
        await runner.register(trainingCases: [TrainingCase(id: "c", inputs: inputs)])
        let result = await runner.evaluate(pairings: [Pairing(individual: "p", trainingCase: "c")])[0]
        var found: [PushStack: [String]] = [:]
        for stack in stacks {
            var shown: [String] = []
            for slot in ["top", "second"] {
                if case .items(let values)? = result.traces["\(stack.rawValue) \(slot)"], let last = values.last ?? nil {
                    shown.append(last.item.pretty())
                }
            }
            if case .ints(let counts)? = result.traces["\(stack.rawValue) count"], let count = counts.last ?? nil {
                shown.append("(\(count) items)")
            }
            found[stack] = shown
        }
        return found
    }

    /// *Variables and Bindings*: the examples.
    @Test func `variables: bind, assign, scope`() async {
        let bound = await Self.finalStacks([.binding, .int], after: program {
            7; PushInstruction.intRef
        })
        #expect(bound[.binding] == ["⟨10 ↦ 7⟩", "(1 items)"])
        #expect(bound[.int] == ["10", "7", "(2 items)"])

        let assigned = await Self.finalStacks([.binding], after: program {
            7; 3; PushInstruction.intRefAs; "x"; 3; PushInstruction.stringRefAs
        })
        #expect(assigned[.binding] == ["⟨3 ↦ \"x\"⟩", "⟨3 ↦ 7⟩", "(2 items)"])

        let unpacked = await Self.finalStacks([.binding, .int], after: program {
            7; 3; PushInstruction.intRefAs; PushInstruction.bindingUnpack
        })
        #expect(unpacked[.int] == ["3", "7", "(2 items)"])
        #expect(unpacked[.binding] == ["(0 items)"])

        let scoped = await Self.finalStacks([.code, .binding], after: [
            IntItem(5), CodeItem([InstructionItem(.bindingDerefToCode)]), InstructionItem(.intWith)
        ])
        #expect(scoped[.code] == ["( 5 )", "(1 items)"])
        #expect(scoped[.binding] == ["(0 items)"])
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// *Searching the Stacks*: a lookup, the records on `.code`, and a find.
    @Test func `searching the stacks: lookup, records, find`() async {
        let lookup = await Self.finalStacks([.string, .int], after: program {
            "pear"; "apple pie"; "apple"; PushInstruction.stringLookupPrefix
        })
        #expect(lookup[.string] == ["\"apple pie\"", "\"apple\"", "(4 items)"])
        #expect(lookup[.int] == ["2", "(1 items)"])

        let records = await Self.finalStacks([.int], after: [
            CodeItem([StringItem("a"), IntItem(1)]), CodeItem([StringItem("b"), IntItem(2)]),
            StringItem("a"), Self.op(.stringQuote), Self.op(.codeLookupPrefix), IntItem(1), Self.op(.codeEmitNthRoot)
        ])
        #expect(records[.int]?.first == "1")

        let find = await Self.finalStacks([.int], after: [VecIntItem([3, 9, 14]), IntItem(10), Self.op(.vecIntFindNearest)])
        #expect(find[.int] == ["9", "1", "(3 items)"])
    }

    /// *Functions: Map, Filter and Reduce*: the three examples.
    @Test func `functions: map, filter, reduce`() async {
        let mapped = await Self.finalStacks([.vecInt], after: [
            VecIntItem([1, 2, 3]), CodeItem([Self.op(.input0), IntItem(2), Self.op(.intMultiply)]), Self.op(.vecIntMap)
        ])
        #expect(mapped[.vecInt]?.first == "[2, 4, 6]")
        let filtered = await Self.finalStacks([.vecInt], after: [
            VecIntItem([1, 2, 3, 4]),
            CodeItem([Self.op(.input0), IntItem(2), Self.op(.intMod), IntItem(0), Self.op(.intEq)]),
            Self.op(.vecIntFilter)
        ])
        #expect(filtered[.vecInt]?.first == "[2, 4]")
        let reduced = await Self.finalStacks([.int], after: [
            VecIntItem([1, 2, 3, 4]), CodeItem([Self.op(.input0), Self.op(.input1), Self.op(.intAdd)]),
            Self.op(.vecIntReduce)
        ])
        #expect(reduced[.int] == ["10", "(1 items)"])
    }

    /// *Provenance and the Crux*: an answer explains itself.
    @Test func `provenance: a crux reproduces the answer`() async {
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        let runner = Runner(configuration: RunnerConfiguration(settings: settings, recorders: [
            RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
        ]))
        await runner.register(individuals: [Individual(id: "p", program: program {
            PushInstruction.input0; 10; PushInstruction.intAdd; 99; PushInstruction.input0; PushInstruction.intMultiply
        })])
        await runner.register(trainingCases: [TrainingCase(id: "c", inputs: [.input0: IntItem(4)])])
        let result = await runner.evaluate(pairings: [Pairing(individual: "p", trainingCase: "c")])[0]
        guard case .items(let answers)? = result.traces["answer"], let answer = answers.last ?? nil else {
            Issue.record("no answer"); return
        }
        print(answer.item.pretty(), CodeItem(answer.item.crux()).pretty())
        #expect(answer.item.pretty() == "396")
        #expect(CodeItem(answer.item.crux()).pretty() == "( 99 .input0 .intMultiply )")
    }

    /// *Code and Control* and *Iterators and Loops*: the examples.
    @Test func `code, control and iterators`() async {
        let chosen = await Self.finalStacks([.int, .code], after: [
            BoolItem(true), CodeItem([IntItem(10)]), CodeItem([IntItem(20)]), Self.op(.execIf)
        ])
        #expect(chosen[.int] == ["10", "(1 items)"] && chosen[.code] == ["(0 items)"])
        let repeated = await Self.finalStacks([.int, .code], after: [
            IntItem(1), IntItem(3), CodeItem([IntItem(2), Self.op(.intMultiply)]), Self.op(.execDoTimes)
        ])
        #expect(repeated[.int] == ["8", "(1 items)"] && repeated[.code] == ["( 2 .intMultiply )", "(1 items)"])
        let counted = await Self.finalStacks([.int, .code], after: [
            IntItem(3), CodeItem([]), Self.op(.execDoCount)
        ])
        #expect(counted[.int] == ["2", "1", "(3 items)"])
        let walked = await Self.finalStacks([.int, .iterator, .code], after: [
            VecIntItem([1, 2, 3]), CodeItem([IntItem(10), Self.op(.intMultiply)]), Self.op(.iteratorOverVecInt),
            Self.op(.iteratorPlay)
        ])
        #expect(walked[.int] == ["30", "20", "(3 items)"] && walked[.code] == ["( 10 .intMultiply )", "(1 items)"])
        let collected = await Self.finalStacks([.vecInt, .iterator, .code], after: [
            VecIntItem([1, 2, 3]), CodeItem([IntItem(10), Self.op(.intMultiply)]), Self.op(.iteratorOverVecInt),
            Self.op(.vecFromIterator)
        ])
        #expect(collected[.vecInt] == ["[10, 20, 30]", "(1 items)"])
    }
}
