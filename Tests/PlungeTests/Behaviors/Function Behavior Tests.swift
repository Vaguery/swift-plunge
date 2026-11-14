//
//  Function Behavior Tests.swift
//  PlungeTests
//
//  Map, filter and reduce: each takes its collection and the topmost function
//  on `.function` that fits; the element fills the function's first hole of its
//  type, every other hole is read (and left) from the run's stacks; the result is
//  the top of the function's output stack; sub-run steps are charged to the
//  program. Functions come from `codePushAllFunctions` and from starvation.
//

@testable import Plunge
import Testing

@Suite
struct FunctionBehaviorTests {

    static func run(_ program: [any Item], inputs: [PushInstruction: any Item] = [:],
                    stepLimit: Int = 10_000) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, program: program)
        inty.run(stepLimit: stepLimit)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// `items` as a block, converted into its functions.
    static func derived(_ items: any Item...) -> [any Item] { [CodeItem(items), op(.codePushAllFunctions)] }

    /// The top of `stack` re-run from its crux: the same value, and no error.
    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        let top = inty.stacks[stack]!.first!
        let fresh = Interpreter()
        fresh.load(program: top.crux())
        fresh.run(stepLimit: 10_000)
        return fresh.stacks[stack]!.first?.pretty() == top.pretty() && fresh.stacks[.error]!.isEmpty
    }

    @Test func `map applies a derived function to each element`() {
        let double = Self.derived(IntItem(2), Self.op(.intMultiply))
        let inty = Self.run(double + [VecIntItem([1, 2, 3]), Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [2, 4, 6] ]")
        #expect(stackString(inty, .function) == "[ ]", "the function is consumed")
        #expect(Self.replays(inty, .vecInt))
    }

    @Test func `the result type is the function's output`() {
        let doubles = Self.run(Self.derived(Self.op(.doubleFromInt)) + [VecIntItem([1, 2]), Self.op(.vecIntMap)])
        #expect(stackString(doubles, .vecDouble) == "[ [1.0, 2.0] ]", "one map closes the conversion grid")

        // `( 2 .intMod 0 .intEq )` yields an int function, then a bool one on top.
        let isEven = Self.derived(IntItem(2), Self.op(.intMod), IntItem(0), Self.op(.intEq))
        let bools = Self.run(isEven + [VecIntItem([1, 2, 3, 4]), Self.op(.vecIntMap)])
        #expect(stackString(bools, .vecBool) == "[ [false, true, false, true] ]")

        let upper = Self.run(Self.derived(Self.op(.charUpper)) + [StringItem("abc"), Self.op(.stringMap)])
        #expect(stackString(upper, .string) == "[ \"ABC\" ]", "chars collect into a string")
    }

    @Test func `other holes are read from the run's stacks and left there`() {
        // `.intAdd` starves and is shelved bare; 10 fills its second hole.
        let inty = Self.run([Self.op(.intAdd), IntItem(10), VecIntItem([1, 2, 3]), Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [11, 12, 13] ]")
        #expect(stackString(inty, .int) == "[ 10 ]", "read, not taken")
        #expect(Self.replays(inty, .vecInt))
    }

    @Test func `the topmost function that fits is the one taken`() {
        // `.boolNot` is on top but has no int hole; `.intAdd` below it fits.
        let inty = Self.run([Self.op(.intAdd), Self.op(.boolNot), IntItem(10), VecIntItem([1, 2]),
                             Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [11, 12] ]")
        #expect(stackString(inty, .function)
                == "[ «fn (bool) -> bool: $0 .boolNot» ]", "the one that did not fit stays")
    }

    @Test func `an element with no result passes through`() {
        // x / 0 refuses, so the output stack is empty after each application.
        let inty = Self.run([Self.op(.intQuot), IntItem(0), VecIntItem([7, 8]), Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [7, 8] ]")
    }

    @Test func `mixed result types are refused`() {
        // A negative's square root refuses, so -1 passes through as an int.
        let inty = Self.run(Self.derived(Self.op(.doubleFromInt), Self.op(.doubleSqrt))
                            + [VecIntItem([-1, 4]), Self.op(.vecIntMap)])
        #expect(inty.stacks[.vecInt]!.isEmpty && inty.stacks[.vecDouble]!.isEmpty)
        #expect(inty.stacks[.error]!.contains { $0.errorMessage.contains("one collectable type") })
    }

    @Test func `an empty function stack is a missing argument`() {
        let inty = Self.run([VecIntItem([1, 2]), Self.op(.vecIntMap)])
        #expect(stackString(inty, .vecInt) == "[ [1, 2] ]", "nothing taken")
        #expect((inty.stacks[.error]!.first as? ErrorItem)?.kind == .missingArgument)
        #expect(stackString(inty, .function) == "[ «fn (vecInt, fn): $0 $1 .vecIntMap» ]",
                "the starved map is shelved like any instruction")
    }

    @Test func `nothing that fits is a miss`() {
        let inty = Self.run([Self.op(.boolNot), VecIntItem([1, 2]), Self.op(.vecIntMap)])
        #expect(inty.stacks[.vecInt]!.isEmpty, "the collection is consumed")
        #expect(stackString(inty, .function) == "[ «fn (bool) -> bool: $0 .boolNot» ]")
        #expect((inty.stacks[.error]!.first as? ErrorItem)?.kind == .notFound)
    }

    @Test func `filler that runs short is a miss, after the arguments are taken`() {
        // `.intAdd` needs a second int, and `.int` is empty.
        let inty = Self.run([Self.op(.intAdd), VecIntItem([1, 2]), Self.op(.vecIntMap)])
        #expect(inty.stacks[.vecInt]!.isEmpty && inty.stacks[.function]!.isEmpty, "both arguments consumed")
        #expect((inty.stacks[.error]!.first as? ErrorItem)?.kind == .notFound)
    }

    @Test func `filter keeps the elements whose function gives true`() {
        let isEven = Self.derived(IntItem(2), Self.op(.intMod), IntItem(0), Self.op(.intEq))
        let inty = Self.run(isEven + [VecIntItem([1, 2, 3, 4]), Self.op(.vecIntFilter)])
        #expect(stackString(inty, .vecInt) == "[ [2, 4] ]")
        #expect(Self.replays(inty, .vecInt))

        let letters = Self.run(Self.derived(Self.op(.charIsLetter)) + [StringItem("a1b2"), Self.op(.stringFilter)])
        #expect(stackString(letters, .string) == "[ \"ab\" ]")
    }

    @Test func `reduce folds from the first element`() {
        let inty = Self.run(Self.derived(Self.op(.intAdd)) + [VecIntItem([1, 2, 3, 4]), Self.op(.vecIntReduce)])
        #expect(stackString(inty, .int) == "[ 10 ]")
        #expect(Self.replays(inty, .int))

        let largest = Self.run(Self.derived(Self.op(.intMax)) + [VecIntItem([3, 9, 2]), Self.op(.vecIntReduce)])
        #expect(stackString(largest, .int) == "[ 9 ]")

        let joined = Self.run(Self.derived(Self.op(.stringConcat))
                              + [VecStringItem(["a", "b", "c"]), Self.op(.vecStringReduce)])
        #expect(stackString(joined, .string) == "[ \"abc\" ]")

        let empty = Self.run(Self.derived(Self.op(.intAdd)) + [VecIntItem([]), Self.op(.vecIntReduce)])
        #expect(empty.stacks[.int]!.isEmpty)
        #expect(empty.stacks[.error]!.count == 1)
    }

    /// The user's ruling: a selection is a generalized reduction.
    @Test func `a bare swap folds to the first element`() {
        let inty = Self.run([Self.op(.intSwap), VecIntItem([3, 1, 4]), Self.op(.vecIntReduce)])
        #expect(stackString(inty, .int) == "[ 3 ]")
    }

    @Test func `the function sees the program's inputs`() {
        let addInput = Self.derived(Self.op(.input1), Self.op(.intAdd))
        let inty = Self.run(addInput + [VecIntItem([1, 2]), Self.op(.vecIntMap)], inputs: [.input1: IntItem(100)])
        #expect(stackString(inty, .vecInt) == "[ [101, 102] ]")
    }

    @Test func `sub-run steps are charged to the program`() {
        let double = Self.derived(IntItem(2), Self.op(.intMultiply))
        let inty = Self.run(double + [VecIntItem([1, 2, 3]), Self.op(.vecIntMap)])
        // Four loading steps, then three applications of three steps each.
        #expect(inty.counter > 4 + 3 * 3)
    }

    @Test func `a map that would exceed the budget is refused`() {
        let inty = Self.run(Self.derived(IntItem(2), Self.op(.intMultiply))
                            + [VecIntItem(Array(1...100)), Self.op(.vecIntMap)], stepLimit: 60)
        #expect(inty.stacks[.vecInt]!.isEmpty)
        #expect(inty.stacks[.error]!.contains { $0.errorMessage.contains("out of steps") })
        #expect(inty.counter >= 60)
    }
}
