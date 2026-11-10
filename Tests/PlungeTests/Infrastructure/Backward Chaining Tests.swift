//
//  Backward Chaining Tests.swift
//  PlungeTests
//
//  The first use of the input-output map: chaining backwards from
//  a wanted stack to a problem's inputs and constants. Sampled trees are run, and
//  each must behave as the map says: leave one result on the wanted stack and
//  nothing anywhere else.
//

@testable import Plunge
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

    /// `intGT` reads its two ints and leaves them. As a whole program that does
    /// no harm, since Push reads the top of `.bool`; as an argument, its fragment
    /// pops them so a sibling int is not displaced.
    @Test func `only a fragment cleans up what it read`() {
        let greater = BackwardChainer.edge(.intGT, Interpreter.language[.intGT]!)!
        let tree = Derivation.apply(greater, [.leaf(.int1), .leaf(.int2)])
        #expect(CodeItem(tree.program).pretty() == "( .int2 .int1 .intGT )")
        #expect(CodeItem(tree.fragment).pretty() == "( .int2 .int1 .intGT 2 .intPopItems )")
        #expect(tree.size == 1)

        let not = BackwardChainer.edge(.boolNot, Interpreter.language[.boolNot]!)!
        #expect(CodeItem(Derivation.apply(not, [tree]).program).pretty()
                == "( .int2 .int1 .intGT 2 .intPopItems .boolNot )")
    }

    /// Where most programs **reach the same result by different routes**. A char
    /// or a double is mostly taken out of a string or vector, and an extracted
    /// element's crux is its address in its source (`.string1 0 .stringNth`,
    /// Containment law 1b), not how its index was computed; random index trees
    /// mostly clamp to 0. So hundreds of programs are a few dozen results.
    /// With constants as parameters (`cruxShape`), measured at height 3: 22
    /// shapes from 167 programs for `.char` (103 of them `( .string0 0 .stringNth )`,
    /// the first letter of some constant), 20 from 173 for `.double`.
    static let distinctFloor: [PushStack: Double] = [.char: 0.08, .double: 0.08]

    /// The share of sampled programs that must reach their goal: a half, except
    /// `.char`, measured at 147 of 300 once the language gained char
    /// producers that refuse more often on random arguments (`stringMax` on an
    /// empty string, `charUpper` of `ß`).
    static let reachFloor: [PushStack: Double] = [.char: 0.45]

    /// Left out of the sample: the `IndexOf…From` queries. Uniform over trees
    /// weights an edge by the product of its subtree counts, so these six
    /// three-argument queries came to root most height-3 `.int` trees, and on
    /// random arguments they mostly find nothing:
    /// reach fell to 74 of 300 for `.int`, 56 for `.char` and 78 for `.double`,
    /// whose trees take ints as indices. The arity bias is the chainer's
    /// (as for the iterator constructors, `cruxOnly`), not the language's.
    static let arityThreeQueries: Set<PushInstruction> = [
        .vecBoolIndexOfFrom, .vecIntIndexOfFrom, .vecDoubleIndexOfFrom, .vecStringIndexOfFrom,
        .stringIndexOfFrom, .stringIndexOfRunFrom
    ]

    /// What a search wants from chaining: each sampled program leaves something on
    /// its goal stack, and the item on top is a result it had not reached before,
    /// told apart by its crux up to the choice of constants (`cruxShape`).
    @Test(arguments: [PushStack.int, .bool, .string, .char, .double, .vecInt, .vecString, .code])
    func `sampled programs reach the goal with distinct cruxes`(_ goal: PushStack) {
        let chainer = BackwardChainer(inputs: Self.problem, excluding: Self.arityThreeQueries)
        var rng = SeededRNG(seed: 41)
        var sampler = BehaviorIOSurvey.Sampler(rng: SeededRNG(seed: 7))
        var reached = 0
        var cruxes: Set<String> = []
        let trials = 300
        for trial in 0..<trials {
            guard let tree = chainer.sample(goal, height: 3, using: &rng) else {
                Issue.record("no tree for .\(goal)")
                return
            }
            let inty = Interpreter.recordingProvenance()
            withFuzzSeed(UInt64(trial)) { RandomCode.setRandomConstants(in: inty) }
            inty.load(inputs: [.input0: IntItem(sampler.int()), .input1: StringItem(sampler.string())],
                      program: tree.program)
            inty.run(stepLimit: 10_000)
            guard let top = inty.stacks[goal]!.first else { continue }
            reached += 1
            cruxes.insert(CodeItem(Interpreter.cruxShape(top.crux())).pretty())
        }
        // A refusal deep in a tree can starve everything above it; most come from
        // refusals on random constants (`IndexOf` finding nothing).
        #expect(Double(reached) >= (Self.reachFloor[goal] ?? 0.5) * Double(trials),
                "only \(reached) of \(trials) reached .\(goal)")
        #expect(Double(cruxes.count) >= (Self.distinctFloor[goal] ?? 0.9) * Double(reached),
                "\(cruxes.count) distinct cruxes from \(reached) programs reaching .\(goal)")
    }

    /// Constants are parameters: renamed in order of first appearance, per type,
    /// at any depth; a repeated constant stays one parameter; inputs stay as they are.
    @Test func `crux shapes are equal up to the choice of constants`() {
        func shape(_ items: [any Item]) -> String { CodeItem(Interpreter.cruxShape(items)).pretty() }
        let add3: [any Item] = [InstructionItem(.int3), InstructionItem(.input0), InstructionItem(.intAdd)]
        let add8: [any Item] = [InstructionItem(.int8), InstructionItem(.input0), InstructionItem(.intAdd)]
        #expect(shape(add3) == shape(add8))
        #expect(shape(add3) == "( .int0 .input0 .intAdd )")

        let once: [any Item] = [InstructionItem(.int3), InstructionItem(.int3), InstructionItem(.intAdd)]
        let twice: [any Item] = [InstructionItem(.int3), InstructionItem(.int8), InstructionItem(.intAdd)]
        #expect(shape(once) == "( .int0 .int0 .intAdd )")
        #expect(shape(twice) == "( .int0 .int1 .intAdd )")

        let inner = CodeItem([InstructionItem(.int5), InstructionItem(.string7)])
        let nested: [any Item] = [InstructionItem(.string7), inner, InstructionItem(.input1)]
        #expect(shape(nested) == "( .string0 ( .int0 .string0 ) .input1 )")
    }
}
