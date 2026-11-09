//
//  Backward Chaining Tests.swift
//  PushInterpreterTests
//
//  The first use of the input-output map (Roadmap #41): chaining backwards from
//  a wanted stack to a problem's inputs and constants. Sampled trees are run, and
//  each must behave as the map says: leave one result on the wanted stack and
//  nothing anywhere else.
//

@testable import PushInterpreter
import Testing

@Suite
struct BackwardChainingTests {

    /// A problem binding an int and a string.
    static let problem: [PushInstruction: PushStack] = [.input0: .int, .input1: .string]

    @Test func `leaves are the problem's inputs and the constants`() {
        let chainer = BackwardChainer(inputs: Self.problem)
        #expect(chainer.count(.int, height: 0) == 11, "input0 and int0…int9")
        #expect(chainer.count(.bool, height: 0) == 0, "no bool input, no bool constants")
        #expect(chainer.count(.bool, height: 1) > 0)
        #expect(BackwardChainer(inputs: Self.problem, constants: false).count(.int, height: 0) == 1)
    }

    @Test func `counts grow with height`() {
        let chainer = BackwardChainer(inputs: Self.problem)
        for stack in [PushStack.int, .bool, .string, .vecInt, .code] {
            #expect(chainer.count(stack, height: 1) <= chainer.count(stack, height: 2))
            #expect(chainer.count(stack, height: 2) < chainer.count(stack, height: 3))
        }
    }

    /// `intGT` reads its two ints and leaves them, so its fragment pops them and
    /// leaves only the bool. (`Behavior.reading`: a query whose result lands on a
    /// stack it read swaps each argument up and pops it instead.)
    @Test func `a query's fragment cleans up what it read`() {
        let greater = BackwardChainer.edge(.intGT, Interpreter.language[.intGT]!)!
        let tree = Derivation.apply(greater, [.leaf(.int1), .leaf(.int2)])
        #expect(CodeItem(tree.program).pretty() == "( .int2 .int1 .intGT 2 .intPopItems )")
        #expect(tree.size == 1)
    }

    /// Every sampled tree, run with the problem's inputs bound, leaves exactly one
    /// item on its goal stack and empties every other, unless some step refused
    /// (then the refusal is on `.error`, and a parent may have starved).
    @Test(arguments: [PushStack.int, .bool, .string, .char, .double, .vecInt, .vecString, .code])
    func `sampled trees leave exactly their result`(_ goal: PushStack) {
        let chainer = BackwardChainer(inputs: Self.problem)
        var rng = SeededRNG(seed: 41)
        var sampler = BehaviorIOSurvey.Sampler(rng: SeededRNG(seed: 7))
        var clean = 0
        let trials = 300
        for trial in 0..<trials {
            guard let tree = chainer.sample(goal, height: 3, using: &rng) else {
                Issue.record("no tree for .\(goal)")
                return
            }
            let inty = Interpreter()
            withFuzzSeed(UInt64(trial)) { RandomCode.setRandomConstants(in: inty) }
            inty.load(inputs: [.input0: IntItem(sampler.int()), .input1: StringItem(sampler.string())],
                      program: tree.program)
            inty.run(stepLimit: 10_000)
            guard inty.stacks[.error]!.isEmpty else { continue }
            clean += 1
            let leftovers = PushStack.allCases.filter { $0 != goal && !inty.stacks[$0]!.isEmpty }
            #expect(inty.stacks[goal]!.count == 1 && leftovers.isEmpty,
                    "\(CodeItem(tree.program).pretty()) left \(inty.stacks[goal]!.count) on .\(goal), and \(leftovers)")
        }
        // Most refusals are #42's errors on random constants ("not found" from an
        // `IndexOf`); enough trees must run clean for the check to mean anything.
        #expect(clean >= 40, "only \(clean) of \(trials) ran without a refusal")
    }
}
