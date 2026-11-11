//
//  Function Outcome Pins.swift
//  PlungeTests
//
//  Hand-checked cases that hold the function outcome probe's classifier and
//  variants to what they claim. These run in the ordinary suite; the probe
//  itself (`Function Outcome Probe.swift`) runs only on request.
//

import Testing
@testable import Plunge

@Suite @MainActor
struct FunctionOutcomeProbePins {

    typealias Probe = FunctionOutcome

    static func situation(_ block: [any Item], over values: [Int],
                          constants: [PushInstruction: any Item] = [:],
                          stacks: [PushStack: [any Item]] = [:]) -> Probe.Situation {
        Probe.Situation(natural: true, collection: VecIntItem(values), block: CodeItem(block),
                     inputs: [:], constants: constants, stacks: stacks)
    }

    @Test func `today's rule: a block using input0 depends on the element`() {
        let s = Self.situation([InstructionItem(.input0), IntItem(2), InstructionItem(.intMultiply)], over: [1, 2, 3])
        #expect(Probe.classify(.v0, .map, s) == .dependent)
    }

    @Test func `a block that only pushes a constant is a constant function`() {
        let s = Self.situation([InstructionItem(.int3)], over: [1, 2, 3], constants: [.int3: IntItem(5)])
        #expect(Probe.classify(.v0, .map, s) == .constant)
        #expect(Probe.classify(.v0, .reduce, s) == .constant)
    }

    @Test func `stack-fed, a block needs no input to depend on the element`() {
        let s = Self.situation([IntItem(2), InstructionItem(.intMultiply)], over: [1, 2, 3])
        #expect(Probe.classify(.v0, .map, s) == .constant, "today, 2 is the last push")
        #expect(Probe.classify(.v2, .map, s) == .dependent)
        #expect(Probe.classify(.v3, .map, s) == .dependent)
    }

    @Test func `an empty block is the identity, keeps nothing, and folds to the first`() {
        let s = Self.situation([], over: [1, 2, 3])
        #expect(Probe.classify(.v0, .map, s) == .identity)
        #expect(Probe.classify(.v0, .filter, s) == .empty)
        #expect(Probe.classify(.v0, .reduce, s) == .first)
    }

    @Test func `the lowest-numbered input is the element under V1`() {
        let s = Self.situation([InstructionItem(.input7), IntItem(2), InstructionItem(.intMultiply)], over: [1, 2, 3])
        #expect(Probe.classify(.v0, .map, s) != .dependent)
        #expect(Probe.classify(.v1, .map, s) == .dependent)
    }

    @Test func `a stack-fed block that does nothing folds to the last element`() {
        let s = Self.situation([], over: [1, 2, 3])
        #expect(Probe.classify(.v2, .reduce, s) == .last)
        #expect(Probe.classify(.v3, .reduce, s) == .last)
    }

    @Test func `crux-to-function turns a sum's argument into a hole`() {
        // An int on the stack made by `.int3 .int4 .intAdd`, recorded: its crux
        // with the first int argument a hole is `( .input0 .int4 .intAdd )`.
        let inty = Interpreter()
        inty.config.recordsProvenance = true
        let constants: [PushInstruction: any Item] = [.int3: IntItem(5), .int4: IntItem(10)]
        inty.load(constants: constants, program: [InstructionItem(.int3), InstructionItem(.int4),
                                                  InstructionItem(.intAdd)])
        inty.run()
        let s = Self.situation([], over: [1, 2, 3], constants: constants, stacks: Probe.snapshot(inty))
        #expect(Probe.classify(.v7, .map, s) == .dependent)
    }

    @Test func `typed projection keeps only what is about the element's type`() {
        let s = Self.situation([InstructionItem(.stringReverse), IntItem(2), InstructionItem(.intMultiply),
                                InstructionItem(.boolNot)], over: [1, 2, 3])
        #expect(Probe.projection(of: s.block, onto: .int, s).value.count == 2, "2 and .intMultiply")
    }

    @Test func `typed context gives a binary operation its second argument`() {
        let s = Self.situation([InstructionItem(.intAdd)], over: [1, 2, 3], constants: [.int0: IntItem(100)])
        #expect(Probe.classify(.v3, .map, s) == .identity, "an add starves on the element alone")
        #expect(Probe.classify(.v10, .map, s) == .dependent)
    }

    @Test func `the first working block on code is found`() {
        let working = CodeItem([IntItem(2), InstructionItem(.intMultiply)])
        let s = Self.situation([], over: [1, 2, 3], stacks: [.code: [CodeItem([]), working]])
        #expect(Probe.classify(.v3, .map, s) == .identity)
        #expect(Probe.classify(.v8, .map, s) == .dependent)
    }

    @Test func `the first typed block is found by signature`() {
        let typed = CodeItem([InstructionItem(.intAdd)])
        let s = Self.situation([InstructionItem(.boolNot)], over: [1, 2, 3],
                               constants: [.int0: IntItem(100)],
                               stacks: [.code: [CodeItem([InstructionItem(.boolNot)]), typed]])
        #expect(Probe.classify(.v10, .map, s) == .identity)
        #expect(Probe.classify(.v12, .map, s) == .dependent)
    }

    @Test func `the per-family lookup passes over a block that only takes the type`() {
        // Both blocks take ints; only the second gives one back.
        let comparing = CodeItem([InstructionItem(.intGT)])
        let doubling = CodeItem([IntItem(2), InstructionItem(.intMultiply)])
        let s = Self.situation([], over: [1, 2, 3], stacks: [.code: [comparing, doubling]])
        #expect(Probe.lookup(.map, s, criteria: [.takesType])?.value.count == 1)
        #expect(Probe.lookup(.map, s, criteria: [.doesFamilyJob])?.value.count == 2)
        #expect(Probe.lookup(.filter, s, criteria: [.doesFamilyJob])?.value.count == 1)
        #expect(Probe.classify(.v15, .map, s) == .dependent)
    }

    @Test func `a transformer maps ints to doubles when the first run fixes the type`() {
        let s = Self.situation([InstructionItem(.doubleFromInt)], over: [1, 2, 3])
        #expect(Probe.classify(.v14, .map, s) == .identity, "the typed top reads the int stack")
        #expect(Probe.classify(.v17, .map, s) == .dependentRetyped)
    }

    @Test func `the hybrid keeps blocks written with input0 working`() {
        let doubling = Self.situation([InstructionItem(.input0), IntItem(2), InstructionItem(.intMultiply)],
                                      over: [1, 2, 3])
        #expect(Probe.classify(.v13, .map, doubling) == .dependent)
        let sum = Self.situation([InstructionItem(.input0), InstructionItem(.input1), InstructionItem(.intAdd)],
                                 over: [1, 2, 3])
        #expect(Probe.classify(.v13, .reduce, sum) == .dependent)
        let stackFed = Self.situation([IntItem(2), InstructionItem(.intMultiply)], over: [1, 2, 3])
        #expect(Probe.classify(.v13, .map, stackFed) == .dependent)
    }

    @Test func `an add folds stack-fed and in one sandbox`() {
        let s = Self.situation([InstructionItem(.intAdd)], over: [1, 2, 3])
        #expect(Probe.classify(.v2, .reduce, s) == .dependent)
        #expect(Probe.classify(.v6, .reduce, s) == .dependent)
        #expect(Probe.classify(.v5, .reduce, s) == .dependent)
    }

    @Test func `a block yields the functions its leftovers compute`() {
        let s = Self.situation([], over: [1, 2, 3])
        func functions(_ block: [any Item]) -> [Probe.BlockFunction] {
            Probe.convert(CodeItem(block), in: s).functions
        }
        let doubling = functions([InstructionItem(.intDup), InstructionItem(.intAdd)])
        #expect(doubling.map(\.signature) == ["(int) → int"])
        #expect(doubling.first?.shape == "⟨int0⟩ .intDup .intAdd")
        #expect(functions([InstructionItem(.intPop)]).isEmpty, "a pop pushes nothing")
        let chain = functions([InstructionItem(.intDup), InstructionItem(.intAdd), InstructionItem(.intInc),
                               InstructionItem(.intPop)])
        #expect(chain.map(\.shape) == ["⟨int0⟩ .intDup .intAdd", "⟨int0⟩ .intDup .intAdd .intInc"],
                "consumed items count too, in the order they were pushed")
        #expect(functions([InstructionItem(.intGT)]).map(\.signature) == ["(int, int) → bool"])
        #expect(functions([InstructionItem(.doubleFromInt)]).map(\.signature) == ["(int) → double"])
    }

    @Test func `the function stack maps, filters and folds`() {
        let transformer = Self.situation([InstructionItem(.doubleFromInt)], over: [1, 2, 3])
        #expect(Probe.classify(.v18, .map, transformer) == .dependentRetyped)
        let doubling = Self.situation([InstructionItem(.intDup), InstructionItem(.intAdd)], over: [1, 2, 3])
        #expect(Probe.classify(.v18, .map, doubling) == .dependent)
        let sum = Self.situation([InstructionItem(.intAdd)], over: [1, 2, 3])
        #expect(Probe.classify(.v18, .reduce, sum) == .dependent)
        let predicate = Self.situation([IntItem(2), InstructionItem(.intGT)], over: [1, 2, 3])
        #expect(Probe.classify(.v18, .filter, predicate) == .dependent)
    }

    @Test func `a bool that is its own verdict keeps the trues`() {
        let s = Probe.Situation(natural: true, collection: VecBoolItem([false, true, true, false]),
                                block: CodeItem([]), inputs: [:], constants: [:], stacks: [:])
        #expect(Probe.classify(.v3, .filter, s) == .keptTrues)
        var negated = s
        negated.block = CodeItem([InstructionItem(.boolNot)])
        #expect(Probe.classify(.v3, .filter, negated) == .keptFalses)
    }

    @Test func `a filter predicate keeps a proper subset`() {
        let s = Self.situation([IntItem(2), InstructionItem(.intGT)], over: [1, 2, 3])
        #expect(Probe.classify(.v3, .filter, s) == .dependent)
    }
}
