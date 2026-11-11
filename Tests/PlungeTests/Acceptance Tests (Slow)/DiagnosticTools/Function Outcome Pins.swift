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

    @Test func `a filter predicate keeps a proper subset`() {
        let s = Self.situation([IntItem(2), InstructionItem(.intGT)], over: [1, 2, 3])
        #expect(Probe.classify(.v3, .filter, s) == .dependent)
    }
}
