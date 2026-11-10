//
//  Function Behavior Tests.swift
//  PushInterpreterTests
//
//  Map, filter and reduce: a function is a block
//  with `.inputN` holes, run in a sub-interpreter; its result is the last value
//  it pushed; sub-run steps are charged to the program.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct FunctionBehaviorTests {

    static func run(_ program: [any Item], inputs: [PushInstruction: any Item] = [:],
                    stepLimit: Int = 10_000) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, program: program)
        inty.run(stepLimit: stepLimit)
        return inty
    }

    static func block(_ items: any Item...) -> CodeItem { CodeItem(items) }
    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// The top of `stack` re-run from its crux: the same value, nothing else.
    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        let top = inty.stacks[stack]!.first!
        let fresh = Interpreter()
        fresh.load(program: top.crux())
        fresh.run(stepLimit: 10_000)
        return fresh.stacks[stack]!.count == 1 && fresh.stacks[stack]!.first!.pretty() == top.pretty()
            && PushStack.allCases.filter { $0 != stack && $0 != .exec }.allSatisfy { fresh.stacks[$0]!.isEmpty }
    }

    @Test func `map applies a function with an input hole to each element`() {
        let double = Self.block(Self.op(.input0), IntItem(2), Self.op(.intMultiply))
        let inty = Self.run([VecIntItem([1, 2, 3]), double, Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [2, 4, 6] ]")
        #expect(stackString(inty, .code) == "[ ]", "the function is consumed")
        #expect(Self.replays(inty, .vecInt))
    }

    @Test func `the result type follows the last value pushed`() {
        let toDouble = Self.block(Self.op(.input0), Self.op(.doubleFromInt))
        let doubles = Self.run([VecIntItem([1, 2]), toDouble, Self.op(.vecIntMap)])
        #expect(stackString(doubles, .vecDouble) == "[ [1.0, 2.0] ]", "one map closes the conversion grid")

        // Query debris on .int does not matter: the last push is the bool.
        let isEven = Self.block(Self.op(.input0), IntItem(2), Self.op(.intMod), IntItem(0), Self.op(.intEq))
        let bools = Self.run([VecIntItem([1, 2, 3, 4]), isEven, Self.op(.vecIntMap)])
        #expect(stackString(bools, .vecBool) == "[ [false, true, false, true] ]")

        let upper = Self.run([StringItem("abc"), Self.block(Self.op(.input0), Self.op(.charUpper)),
                              Self.op(.stringMap)])
        #expect(stackString(upper, .string) == "[ \"ABC\" ]", "chars collect into a string")
    }

    @Test func `an element with no result passes through`() {
        let nothing = Self.block()
        let inty = Self.run([VecIntItem([7, 8]), nothing, Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [7, 8] ]")
    }

    @Test func `mixed result types are refused`() {
        // Elements above 1 become doubles; the rest stay ints.
        let mixed = Self.block(Self.op(.input0), IntItem(1), Self.op(.intGT),
                               Self.block(Self.op(.input0), Self.op(.doubleFromInt)),
                               Self.block(Self.op(.input0)), Self.op(.execIf))
        let inty = Self.run([VecIntItem([1, 2]), mixed, Self.op(.vecIntMap)])
        #expect(inty.stacks[.vecInt]!.isEmpty && inty.stacks[.vecDouble]!.isEmpty)
        #expect(inty.stacks[.error]!.contains { $0.pretty().contains("one collectable type") })
    }

    @Test func `filter keeps the elements whose function gives true`() {
        let isEven = Self.block(Self.op(.input0), IntItem(2), Self.op(.intMod), IntItem(0), Self.op(.intEq))
        let inty = Self.run([VecIntItem([1, 2, 3, 4]), isEven, Self.op(.vecIntFilter)])
        #expect(stackString(inty, .vecInt) == "[ [2, 4] ]")
        #expect(Self.replays(inty, .vecInt))

        let noVowels = Self.block(StringItem("aeiou"), Self.op(.input0), Self.op(.stringContains),
                                  Self.op(.boolNot))
        let text = Self.run([StringItem("hello"), noVowels, Self.op(.stringFilter)])
        #expect(stackString(text, .string) == "[ \"hll\" ]")
    }

    @Test func `filter counts no result as false`() {
        let inty = Self.run([VecIntItem([1, 2]), Self.block(), Self.op(.vecIntFilter)])
        #expect(stackString(inty, .vecInt) == "[ [] ]")
    }

    @Test func `reduce folds from the first element`() {
        let add = Self.block(Self.op(.input0), Self.op(.input1), Self.op(.intAdd))
        let inty = Self.run([VecIntItem([1, 2, 3, 4]), add, Self.op(.vecIntReduce)])
        #expect(stackString(inty, .int) == "[ 10 ]")
        #expect(Self.replays(inty, .int))

        let largest = Self.run([VecIntItem([3, 9, 2]), Self.block(Self.op(.input0), Self.op(.input1), Self.op(.intMax)),
                                Self.op(.vecIntReduce)])
        #expect(stackString(largest, .int) == "[ 9 ]")

        let joined = Self.run([VecStringItem(["a", "b", "c"]),
                               Self.block(Self.op(.input0), Self.op(.input1), Self.op(.stringConcat)),
                               Self.op(.vecStringReduce)])
        #expect(stackString(joined, .string) == "[ \"abc\" ]")

        let empty = Self.run([VecIntItem([]), add, Self.op(.vecIntReduce)])
        #expect(empty.stacks[.int]!.isEmpty)
        #expect(empty.stacks[.error]!.count == 1)
    }

    @Test func `the function sees the program's other inputs`() {
        let addInput1 = Self.block(Self.op(.input0), Self.op(.input1), Self.op(.intAdd))
        let inty = Self.run([VecIntItem([1, 2]), addInput1, Self.op(.vecIntMap)], inputs: [.input1: IntItem(100)])
        #expect(stackString(inty, .vecInt) == "[ [101, 102] ]")
    }

    @Test func `sub-run steps are charged to the program`() {
        let double = Self.block(Self.op(.input0), IntItem(2), Self.op(.intMultiply))
        let inty = Self.run([VecIntItem([1, 2, 3]), double, Self.op(.vecIntMap)])
        // Three loading steps, then three applications of four steps each.
        #expect(inty.counter > 3 + 3 * 3)
    }

    @Test func `a map that would exceed the budget is refused`() {
        let spin = Self.block(Self.op(.input0), IntItem(1000), Self.block(), Self.op(.execDoTimes))
        let inty = Self.run([VecIntItem([1, 2, 3]), spin, Self.op(.vecIntMap)], stepLimit: 500)
        #expect(inty.stacks[.vecInt]!.isEmpty)
        #expect(inty.stacks[.error]!.contains { $0.pretty().contains("out of steps") })
        #expect(inty.counter >= 500)
    }
}
