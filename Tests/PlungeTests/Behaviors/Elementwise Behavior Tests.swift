//
//  Elementwise Behavior Tests.swift
//  PlungeTests
//
//  Element-wise vector operations: `a b .op`, with `a` the first vector below
//  the top `b` of the same length (the sieve); arithmetic and logic take the
//  pair, dot products and comparisons read it.
//

@testable import Plunge
import Testing

@Suite
struct ElementwiseBehaviorTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// The top of `stack` re-run from its crux on a fresh interpreter: the same
    /// value, nothing else on that stack, and no error.
    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        let top = inty.stacks[stack]!.first!
        let fresh = Interpreter()
        fresh.load(program: top.crux())
        fresh.run(stepLimit: 1_000)
        return fresh.stacks[stack]!.map { $0.pretty() } == [top.pretty()] && fresh.stacks[.error]!.isEmpty
    }

    static func errorKinds(_ inty: Interpreter) -> [ErrorKind] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.kind }
    }

    @Test func `arithmetic combines adjacent vectors in written order`() {
        let inty = Self.run([VecIntItem([10, 20, 30]), VecIntItem([1, 2, 3]), Self.op(.vecIntSubtract)])
        #expect(stackString(inty, .vecInt) == "[ [9, 18, 27] ]")
        #expect(Self.replays(inty, .vecInt))

        let doubles = Self.run([VecDoubleItem([1, 2]), VecDoubleItem([4, 8]), Self.op(.vecDoubleDivide)])
        #expect(stackString(doubles, .vecDouble) == "[ [0.25, 0.25] ]")
    }

    @Test func `the partner is the first same-length vector, past a shorter one`() {
        let inty = Self.run([VecIntItem([100, 200]), VecIntItem([7]), VecIntItem([1, 2]), Self.op(.vecIntAdd)])
        #expect(stackString(inty, .vecInt) == "[ [101, 202] [7] ]", "[7] is passed over and left")
        #expect(Self.replays(inty, .vecInt))
    }

    @Test func `no same-length partner is a miss that still takes the top`() {
        let inty = Self.run([VecIntItem([7]), VecIntItem([1, 2]), Self.op(.vecIntAdd)])
        #expect(stackString(inty, .vecInt) == "[ [7] ]")
        #expect(Self.errorKinds(inty) == [.notFound])
    }

    @Test func `a lone vector starves and is shelved`() {
        let inty = Self.run([VecIntItem([1, 2]), Self.op(.vecIntAdd)])
        #expect(stackString(inty, .vecInt) == "[ [1, 2] ]")
        #expect(Self.errorKinds(inty) == [.missingArgument])
        #expect(stackString(inty, .function) == "[ «fn bare (vecInt, vecInt) -> vecInt: $0 $1 .vecIntAdd» ]")
    }

    @Test func `arithmetic refuses as its scalar does, naming the index`() {
        let zero = Self.run([VecIntItem([4, 6]), VecIntItem([2, 0]), Self.op(.vecIntQuot)])
        #expect(zero.stacks[.vecInt]!.isEmpty, "both taken")
        let message = (zero.stacks[.error]!.first as? ErrorItem)?.value ?? ""
        #expect(message.contains("at index 1") && message.contains("Divide by zero"))

        let overflow = Self.run([VecIntItem([Int.max]), VecIntItem([1]), Self.op(.vecIntAdd)])
        #expect(overflow.stacks[.error]!.count == 1)
        let infinite = Self.run([VecDoubleItem([1]), VecDoubleItem([0]), Self.op(.vecDoubleDivide)])
        #expect(infinite.stacks[.vecDouble]!.isEmpty && infinite.stacks[.error]!.count == 1)
    }

    @Test func `dot products read the pair`() {
        let inty = Self.run([VecIntItem([1, 2, 3]), VecIntItem([4, 5, 6]), Self.op(.vecIntDot)])
        #expect(stackString(inty, .int) == "[ 32 ]")
        #expect(inty.stacks[.vecInt]!.count == 2, "both read and left")
        #expect(Self.replays(inty, .int))

        let empty = Self.run([VecDoubleItem([]), VecDoubleItem([]), Self.op(.vecDoubleDot)])
        #expect(stackString(empty, .double) == "[ 0.0 ]")
    }

    @Test func `comparisons give a vector of bools and leave the pair`() {
        let inty = Self.run([VecIntItem([1, 5, 3]), VecIntItem([2, 5, 1]), Self.op(.vecIntLTEach)])
        #expect(stackString(inty, .vecBool) == "[ [true, false, false] ]")
        #expect(inty.stacks[.vecInt]!.count == 2)
        #expect(Self.replays(inty, .vecBool))

        let strings = Self.run([VecStringItem(["a", "b"]), VecStringItem(["a", "c"]), Self.op(.vecStringEqEach)])
        #expect(stackString(strings, .vecBool) == "[ [true, false] ]")

        // Every NaN is one value, above every number (the vector rules).
        let nan = Self.run([VecDoubleItem([.nan, 1]), VecDoubleItem([.nan, .nan]), Self.op(.vecDoubleEqEach)])
        #expect(stackString(nan, .vecBool) == "[ [true, false] ]")
        let above = Self.run([VecDoubleItem([.nan]), VecDoubleItem([1]), Self.op(.vecDoubleGTEach)])
        #expect(stackString(above, .vecBool) == "[ [true] ]")
    }

    @Test func `a comparison of a pair of bool vectors replays on its own stack`() {
        let inty = Self.run([VecBoolItem([true, false]), VecBoolItem([true, true]), Self.op(.vecBoolEqEach)])
        #expect(stackString(inty, .vecBool) == "[ [true, false] [true, true] [true, false] ]")
        #expect(Self.replays(inty, .vecBool))
    }

    @Test func `logic on vectors of bools`() {
        let inty = Self.run([VecBoolItem([true, true, false]), VecBoolItem([true, false, false]),
                             Self.op(.vecBoolOr), Self.op(.vecBoolNot)])
        #expect(stackString(inty, .vecBool) == "[ [false, false, true] ]")
        #expect(Self.replays(inty, .vecBool))
    }

    @Test func `values do not depend on recording`() {
        let program: [any Item] = [VecIntItem([3, 1]), VecIntItem([9]), VecIntItem([2, 2]),
                                   Self.op(.vecIntMultiply), VecIntItem([1, 1]), Self.op(.vecIntGTEach)]
        let on = Self.run(program)
        let off = Interpreter()
        off.load(program: program)
        off.run(stepLimit: 1_000)
        for stack in PushStack.allCases where stack != .function {
            #expect(stackString(on, stack) == stackString(off, stack), "\(stack)")
        }
    }
}
