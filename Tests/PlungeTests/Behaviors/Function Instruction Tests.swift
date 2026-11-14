//
//  Function Instruction Tests.swift
//  PlungeTests
//
//  Instructions on functions themselves: apply, compose, fill, arity, iterate,
//  iterate until, and binding a function to a key.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct FunctionInstructionTests {

    static func run(_ program: [any Item], recording: Bool = true) -> Interpreter {
        let inty = recording ? Interpreter.recordingProvenance() : Interpreter()
        inty.load(program: program)
        inty.run(stepLimit: 10_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    static func derived(_ items: any Item...) -> [any Item] { [CodeItem(items), op(.codePushAllFunctions)] }

    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        inty.stacks[stack]!.allSatisfy { item in
            let fresh = Interpreter()
            fresh.load(program: item.crux())
            fresh.run(stepLimit: 10_000)
            return fresh.stacks[stack]!.map { $0.pretty() } == [item.pretty()] && fresh.stacks[.error]!.isEmpty
        }
    }

    static func errorKinds(_ inty: Interpreter) -> [ErrorKind] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.kind }
    }

    // MARK: - Apply

    @Test func `apply takes its fillers as the instruction would`() {
        // `.intSubtract` starves and is shelved; applied to 10 3 it gives 10 − 3.
        let inty = Self.run([Self.op(.intSubtract), IntItem(10), IntItem(3), Self.op(.functionApply)])
        #expect(stackString(inty, .int) == "[ 7 ]")
        #expect(inty.stacks[.function]!.isEmpty, "the function is consumed")
        #expect(Self.replays(inty, .int))
    }

    @Test func `apply runs a derived function`() {
        let inty = Self.run(Self.derived(IntItem(2), Self.op(.intMultiply)) + [IntItem(21), Self.op(.functionApply)])
        #expect(stackString(inty, .int) == "[ 42 ]")
        #expect(Self.replays(inty, .int))
    }

    @Test func `apply short of fillers starves, and a result-less one refuses`() {
        let short = Self.run([Self.op(.intAdd), IntItem(1), Self.op(.functionApply)])
        #expect(Self.errorKinds(short).first == .missingArgument)
        #expect(stackString(short, .int) == "[ 1 ]", "nothing taken")

        // x / 0 refuses inside the sandbox, so nothing lands on .int.
        let none = Self.run([Self.op(.intQuot), IntItem(1), IntItem(0), Self.op(.functionApply)])
        #expect(Self.errorKinds(none).first == .notFound)
    }

    /// A function with no output (a bare map's result type depends on its
    /// function) never fits apply or compose: a miss, with the requirements after
    /// the miss still asked of the planner's stand-in (a crash, before).
    @Test func `a miss on the function is a refusal, not a crash`() {
        let shelved: [any Item] = [Self.op(.vecIntMap)]   // starves: a bare map, no output
        let apply = Self.run(shelved + [Self.op(.functionApply)])
        #expect(Self.errorKinds(apply).first == .notFound)
        let compose = Self.run(shelved + shelved + [Self.op(.functionCompose)])
        #expect(Self.errorKinds(compose).first == .notFound)
        let iterate = Self.run(shelved + [IntItem(1), IntItem(2), Self.op(.functionIterate)])
        #expect(Self.errorKinds(iterate).first == .notFound)
        let until = Self.run([Self.op(.intInc), Self.op(.vecIntMap), IntItem(1), Self.op(.functionIterateUntil)])
        #expect(Self.errorKinds(until).first == .notFound, "a step with no predicate below it")
    }

    // MARK: - Compose, fill, arity

    @Test func `compose puts the inner function in the outer's first matching hole`() {
        // f = x 2 * (derived), g = .intInc (bare, shelved on top): f after g = (x + 1) * 2.
        let program = Self.derived(IntItem(2), Self.op(.intMultiply)) + [Self.op(.intInc), Self.op(.functionCompose)]
        let inty = Self.run(program)
        #expect(inty.stacks[.function]!.count == 1)
        let composed = Self.run(program + [IntItem(4), Self.op(.functionApply)])
        #expect(stackString(composed, .int) == "[ 10 ]")
        #expect(Self.replays(inty, .function))
    }

    /// A hole used twice (`x x .intMultiply`) takes two copies of what is composed
    /// into it, so composing such a function with itself grows it geometrically.
    /// Found by the soak (seed 17538, 2.9 s for one composition): the result is
    /// refused from the weights alone, before it is built.
    @Test func `a composition over the size limit is refused before it is built`() {
        let square = FunctionItem(body: [Self.op(.intMultiply)],
                                  holes: [.init(stack: .int, positions: [0, 0])], output: .int)
        let inty = Interpreter.recordingProvenance()
        inty.config.maxItemWeight = 1_000
        let rounds = Array(repeating: [Self.op(.functionDup), Self.op(.functionCompose)] as [any Item], count: 12)
        inty.load(program: [square] + rounds.flatMap { $0 })
        inty.run(stepLimit: 10_000)
        #expect(Self.errorKinds(inty).contains(.sizeRefusal))
        #expect(inty.stacks[.function]!.allSatisfy { $0.weight <= 1_000 })
        #expect(inty.stacks[.function]!.contains { $0.weight > 100 }, "it composed until the limit")
    }

    @Test func `fill binds the first hole wherever it occurs`() {
        // `.intSubtract` with 10 in its first hole: 10 − x.
        let program: [any Item] = [Self.op(.intSubtract), IntItem(10), Self.op(.functionFill)]
        let inty = Self.run(program)
        #expect(stackString(inty, .function) == "[ «fn (int) -> int: 10 $0 .intSubtract» ]")
        #expect(Self.replays(inty, .function))
        let applied = Self.run(program + [IntItem(3), Self.op(.functionApply)])
        #expect(stackString(applied, .int) == "[ 7 ]")

        let squareOf = Self.run(Self.derived(Self.op(.intDup), Self.op(.intMultiply))
                                + [IntItem(5), Self.op(.functionFill)])
        #expect(stackString(squareOf, .function) == "[ «fn () -> int: 5 .intDup .intMultiply» ]")
    }

    /// Filling a bare map (whose result type is not fixed) makes a derived
    /// function with no output; both coders keep it derived.
    @Test func `a derived function with no output encodes as itself`() throws {
        let inty = Self.run([Self.op(.vecIntMap), VecIntItem([1]), Self.op(.functionFill)])
        let filled = try #require(inty.stacks[.function]!.first?.exactly(FunctionItem.self))
        #expect(!filled.isBare && filled.output == nil)
        let any = try JSONDecoder().decode(AnyItem.self, from: JSONEncoder().encode(AnyItem(filled))).item
        #expect(any.isEqual(to: filled))
        let archive = try JSONDecoder().decode(ItemArchive.self, from: JSONEncoder().encode(ItemArchive([filled])))
        #expect(archive.items.first?.isEqual(to: filled) == true)
    }

    @Test func `arity counts holes and reads the function`() {
        let inty = Self.run([Self.op(.intAdd), Self.op(.functionArity)])
        #expect(stackString(inty, .int) == "[ 2 ]")
        #expect(inty.stacks[.function]!.count == 1)
        #expect(Self.replays(inty, .int))
    }

    // MARK: - Iterate

    @Test func `iterate applies a step function n times`() {
        let inty = Self.run([Self.op(.intInc), IntItem(5), IntItem(3), Self.op(.functionIterate)])
        #expect(stackString(inty, .int) == "[ 8 ]")
        #expect(Self.replays(inty, .int))
        let doubled = Self.run(Self.derived(IntItem(2), Self.op(.intMultiply))
                               + [IntItem(1), IntItem(10), Self.op(.functionIterate)])
        #expect(stackString(doubled, .int) == "[ 1024 ]")
        let negative = Self.run([Self.op(.intInc), IntItem(5), IntItem(-1), Self.op(.functionIterate)])
        #expect(Self.errorKinds(negative).first == .badCount)
    }

    @Test func `iterate until gives the orbit up to the first value that holds`() {
        // Halve until 1: the predicate x = 1 below, the step x / 2 on top.
        let isOne = Self.derived(IntItem(1), Self.op(.intEq))
        let halve = Self.derived(IntItem(2), Self.op(.intQuot))
        let inty = Self.run(isOne + halve + [IntItem(16), Self.op(.functionIterateUntil)])
        #expect(stackString(inty, .vecInt) == "[ [16, 8, 4, 2, 1] ]")
        #expect(Self.replays(inty, .vecInt))

        // The seed itself can hold: an orbit of one.
        let already = Self.run(isOne + halve + [IntItem(1), Self.op(.functionIterateUntil)])
        #expect(stackString(already, .vecInt) == "[ [1] ]")

        // Count up from 3 until 5, with a bare step.
        let up = Self.run(Self.derived(IntItem(5), Self.op(.intEq)) + [Self.op(.intInc), IntItem(3),
                                                                        Self.op(.functionIterateUntil)])
        #expect(stackString(up, .vecInt) == "[ [3, 4, 5] ]")
    }

    // MARK: - Loops

    @Test func `a function's body as a block`() {
        let inty = Self.run(Self.derived(IntItem(2), Self.op(.intMultiply)) + [Self.op(.codeFromFunction)])
        #expect(stackString(inty, .code) == "[ ( 2 .intMultiply ) ]")
        #expect(Self.replays(inty, .code))
    }

    @Test func `function loops run the body on the program's stacks`() {
        // A bare .intAdd three times over 1 2 3 4: 10.
        let sum = Self.run([Self.op(.intAdd), IntItem(1), IntItem(2), IntItem(3), IntItem(4), IntItem(3),
                            Self.op(.functionDoTimes)])
        #expect(stackString(sum, .int) == "[ 10 ]")
        #expect(stackString(sum, .code) == "[ ( .intAdd ) ]", "the body returns to .code, as a loop's does")

        let once = Self.run([Self.op(.intInc), IntItem(5), Self.op(.functionDo)])
        #expect(stackString(once, .int) == "[ 6 ]")

        // Count 0, 1, 2 with x 10 * as the body: 0 10 20 on .int.
        let counted = Self.run(Self.derived(IntItem(10), Self.op(.intMultiply)) + [IntItem(3),
                                                                                  Self.op(.functionDoCount)])
        #expect(stackString(counted, .int) == "[ 20 10 0 ]")

        let ranged = Self.run([Self.op(.intInc), IntItem(2), IntItem(5), Self.op(.functionDoRange)])
        #expect(stackString(ranged, .int) == "[ 5 4 3 ]", "each index 2, 3, 4 incremented")
    }

    @Test func `function while and if`() {
        // Run .boolNot while true: the first pass pops true and leaves false.
        let whileLoop = Self.run([Self.op(.boolNot), BoolItem(true), BoolItem(true), Self.op(.functionWhile)])
        #expect(stackString(whileLoop, .bool) == "[ ]")

        let chosen = Self.run([Self.op(.intInc), Self.op(.intNegate), IntItem(5), BoolItem(true),
                               Self.op(.functionIf)])
        #expect(stackString(chosen, .int) == "[ 6 ]", "true runs the deeper (then) function")
        let other = Self.run([Self.op(.intInc), Self.op(.intNegate), IntItem(5), BoolItem(false),
                              Self.op(.functionIf)])
        #expect(stackString(other, .int) == "[ -5 ]")
    }

    // MARK: - Binding

    @Test func `a function can be bound to a key and read back`() {
        // A binder leaves what it binds; the deref is a second copy.
        let inty = Self.run([Self.op(.intAdd), Self.op(.functionRef), Self.op(.bindingDeref)])
        #expect(stackString(inty, .function)
                == "[ «fn (int, int) -> int: $0 $1 .intAdd» "
                + "«fn (int, int) -> int: $0 $1 .intAdd» ]")
    }

    @Test func `values do not depend on recording`() {
        let program: [any Item] = [Self.op(.intSubtract), IntItem(10), Self.op(.functionFill), Self.op(.intInc),
                                   Self.op(.functionCompose), IntItem(4), Self.op(.functionApply),
                                   Self.op(.intInc), IntItem(2), IntItem(5), Self.op(.functionIterate)]
        let on = Self.run(program)
        let off = Self.run(program, recording: false)
        for stack in PushStack.allCases where stack != .function {
            #expect(stackString(on, stack) == stackString(off, stack), "\(stack)")
        }
    }
}
