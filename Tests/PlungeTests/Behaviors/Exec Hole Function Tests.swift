//
//  Exec Hole Function Tests.swift
//  PlungeTests
//
//  A function made by starving an instruction that rearranges `.exec`
//  (`.execSwap`, `.execDup`) has a hole on `.exec`, and no filler can fill it:
//  the next item of the program is not an argument. In an ordinary run such a
//  function only appears once `.exec` is empty, but a crux brings it back
//  mid-program as a stand-in. `.functionApply` then crashed on a missing filler
//  (found 2026-11-13, transplanting a result's crux into its own program, with
//  the since-removed `.execQuote`). Every function instruction's sieve now passes
//  over it.
//

@testable import Plunge
import Testing

@Suite
struct ExecHoleFunctionTests {

    /// `«fn (exec, exec) -> exec: $0 $1 .execSwap»`: holes on `.exec`, an output.
    static let swap = FunctionItem(bare: InstructionItem(.execSwap))
    /// `«fn (exec) -> exec: $0 .execDup»`: a hole of its own output's type, so it
    /// would pass for a step function.
    static let dup = FunctionItem(bare: InstructionItem(.execDup))

    static func run(_ program: [any Item], with function: FunctionItem) -> Interpreter {
        let inty = Interpreter()
        inty.load(stacks: [.function: [function]], program: program)
        inty.run()
        return inty
    }

    @Test func `a function with a hole on exec is not applicable`() {
        #expect(Self.swap.holes.map(\.stack) == [.exec, .exec])
        #expect(Self.swap.output == .exec)
        #expect(!Self.swap.isApplicable)
        #expect(!Self.dup.isApplicable)
        #expect(FunctionItem(bare: InstructionItem(.intAdd)).isApplicable)
    }

    @Test(arguments: [
        PushInstruction.functionApply, .functionFill, .functionCompose, .functionIterate, .functionIterateUntil,
        .vecIntMap, .vecIntFilter, .vecIntReduce, .codeFromFunction
    ])
    func `function instructions pass over it`(_ instruction: PushInstruction) {
        for function in [Self.swap, Self.dup] {
            let inty = Self.run([VecIntItem([1, 2]), IntItem(3), InstructionItem(instruction)], with: function)
            #expect(inty.stacks[.exec]!.isEmpty)
            if instruction != .codeFromFunction {
                #expect(inty.stacks[.function]!.contains { $0.isEqual(to: function) },
                        "\(instruction) took \(function.pretty())")
            }
        }
    }

    /// The route the crash took: a crux replays the function as a stand-in, and
    /// a function instruction runs after it.
    @Test func `a crux can bring it back mid-program`() {
        let standIn = StandInItem(standingInFor: Self.swap, source: .execSwap, reason: .observed)
        let inty = Interpreter()
        inty.load(program: [standIn, IntItem(4), InstructionItem(.functionApply), InstructionItem(.functionFill)])
        inty.run()
        #expect(inty.stacks[.function]!.first?.isEqual(to: Self.swap) == true)
        #expect(inty.stacks[.int]!.first?.pretty() == "4")
    }
}
