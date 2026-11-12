//
//  Crux Sharing Tests.swift
//  PlungeTests
//
//  A crux builds each shared node of its history once and reuses it by dup and
//  yank, as the program did (`CruxSharing`, since 2026-11-07).
//

@testable import Plunge
import Testing

@Suite
struct CruxSharingTests {

    private let bound: [PushInstruction: any Item] = [.input1: IntItem(5), .input2: BoolItem(true)]

    private func run(_ program: [any Item], settings: InterpreterSettings? = nil) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        if let settings { inty.config = settings }
        inty.load(inputs: bound, constants: [:], program: program)
        inty.run(stepLimit: 10_000)
        return inty
    }

    private func holds(_ item: any Item) -> Bool {
        if case .holds = inspectCrux(of: item, inputs: bound, constants: [:],
                                     settings: Interpreter.recordingProvenance().config) {
            return true
        }
        return false
    }

    @Test func `a duplicated value is built once, as the program built it`() {
        let inty = run([InstructionItem(.input1), InstructionItem(.intDup), InstructionItem(.intAdd)])
        let ten = topItem(inty, .int)
        #expect(stackString(inty, .int) == "[ 10 ]")
        #expect(CodeItem(ten.crux()).pretty() == "( .input1 .intDup .intAdd )")
        // The tree still holds the value twice.
        #expect(CodeItem(CruxSharing.flattened(ten)).pretty() == "( .input1 .input1 .intAdd )")
        #expect(holds(ten))
    }

    @Test func `a value a non-destructive read left behind is reused, not rebuilt`() {
        // Each `.boolEq` reads the top two and leaves them, so every result is
        // built from the two before it: fib(N) leaves as a tree, N steps as run.
        let program: [any Item] = [InstructionItem(.input2), InstructionItem(.input2)]
            + Array(repeating: InstructionItem(.boolEq), count: 24)
        let inty = run(program)
        let last = topItem(inty, .bool)
        #expect(CruxSharing.flattened(last).count > 100_000)
        let crux = last.crux()
        #expect(crux.count < 500)
        #expect(last.callWeight == crux.count)        // weighed as its crux at push
        #expect(!crux.contains { $0.exactly(StandInItem.self) != nil })
        #expect(holds(last))
    }

    @Test func `a later use reaches past the items above it`() {
        // [one, six, three, six, .intAdd]: six is built first and kept; its first
        // use copies it from under one, its second moves it from under one, the
        // copy and three.
        let six = IntItem(6, call: [IntItem(5), InstructionItem(.intInc)])
        let one = IntItem(1, call: [IntItem(0), InstructionItem(.intInc)])
        let three = IntItem(3, call: [IntItem(2), InstructionItem(.intInc)])
        let root = IntItem(9, call: [one, six, three, six, InstructionItem(.intAdd)])
        let crux = root.crux()
        #expect(CodeItem(crux).pretty()
                == "( 5 .intInc 0 .intInc 1 .intYankDup 2 .intInc 3 .intYank .intAdd )")
        // Run as written, it leaves 1, 6 and 3 + 6, in that order.
        let inty = Interpreter()
        inty.load(program: crux)
        inty.run(stepLimit: 100)
        #expect(stackString(inty, .int) == "[ 9 6 1 ]")
    }

    @Test func `nodes shared inside other shared nodes are built in order`() {
        let one = IntItem(1)
        let two = IntItem(2, call: [one, InstructionItem(.intInc)])
        let three = IntItem(3, call: [two, one, InstructionItem(.intAdd)])
        let six = IntItem(6, call: [three, three, InstructionItem(.intAdd)])
        let four = IntItem(4, call: [six, two, InstructionItem(.intSubtract)])
        #expect(CodeItem(six.crux()).pretty() == "( 1 .intInc 1 .intAdd .intDup .intAdd )")
        #expect(CodeItem(four.crux()).pretty()
                == "( 1 .intInc .intDup 1 .intAdd .intDup .intAdd .intSwap .intSubtract )")
        let inty = Interpreter()
        inty.load(program: four.crux())
        inty.run(stepLimit: 100)
        #expect(stackString(inty, .int) == "[ 4 ]")
    }

    @Test func `the measure stops at its limit`() {
        let six = IntItem(6, call: [IntItem(5), InstructionItem(.intInc)])
        let doubled = IntItem(12, call: [six, six, InstructionItem(.intAdd)])
        #expect(CruxSharing.crux(of: doubled, limit: 4)?.count == 4)
        #expect(CruxSharing.crux(of: doubled, limit: 3) == nil)
    }

    @Test func `the push boundary keeps a shared history and weighs it by its crux`() {
        var settings = Interpreter.recordingProvenance().config
        settings.maxCallWeight = 200
        let program: [any Item] = [InstructionItem(.input2), InstructionItem(.input2)]
            + Array(repeating: InstructionItem(.boolEq), count: 12)
        let inty = run(program, settings: settings)
        let last = topItem(inty, .bool)
        let crux = last.crux()
        #expect(CruxSharing.flattened(last).count > 200)
        #expect(!crux.contains { $0.exactly(StandInItem.self) != nil })
        #expect(last.callWeight == crux.count)
        #expect(holds(last))
    }
}
