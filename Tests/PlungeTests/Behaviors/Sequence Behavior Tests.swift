//
//  Sequence Behavior Tests.swift
//  PlungeTests
//
//  Collection operations without functions: sort, extremes' positions, product
//  and mean, last occurrence, ranges, rotate, interleave, repeat, frequencies,
//  prefix sums, conversions and digits, ordering vectors of bools, chunks and
//  windows, and the root-level code operations.
//

@testable import Plunge
import Testing

@Suite
struct SequenceBehaviorTests {

    static func run(_ program: [any Item], recording: Bool = true) -> Interpreter {
        let inty = recording ? Interpreter.recordingProvenance() : Interpreter()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// Every item on `stack` re-run from its crux alone: the same value, and no error.
    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        inty.stacks[stack]!.allSatisfy { item in
            let fresh = Interpreter()
            fresh.load(program: item.crux())
            fresh.run(stepLimit: 1_000)
            return fresh.stacks[stack]!.map { $0.pretty() } == [item.pretty()] && fresh.stacks[.error]!.isEmpty
        }
    }

    static func errorKinds(_ inty: Interpreter) -> [ErrorKind] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.kind }
    }

    @Test func `sorts are stable and total`() {
        let ints = Self.run([VecIntItem([3, 1, 2, 1]), Self.op(.vecIntSort)])
        #expect(stackString(ints, .vecInt) == "[ [1, 1, 2, 3] ]")
        #expect(Self.replays(ints, .vecInt))
        let doubles = Self.run([VecDoubleItem([.nan, 2, -1]), Self.op(.vecDoubleSort)])
        #expect(stackString(doubles, .vecDouble) == "[ [-1.0, 2.0, nan] ]")
        let bools = Self.run([VecBoolItem([true, false, true]), Self.op(.vecBoolSort)])
        #expect(stackString(bools, .vecBool) == "[ [false, true, true] ]")
        let text = Self.run([StringItem("banana"), Self.op(.stringSort)])
        #expect(stackString(text, .string) == "[ \"aaabnn\" ]")
    }

    @Test func `sorted elements keep their provenance`() {
        // [10, 20] then 5 appended: sorting moves the appended element first, and
        // taking it out replays as the element that went in.
        let inty = Self.run([VecIntItem([10, 20]), IntItem(2), IntItem(3), Self.op(.intAdd), Self.op(.vecIntConj),
                             Self.op(.vecIntSort), IntItem(0), Self.op(.vecIntNth)])
        #expect(stackString(inty, .int) == "[ 5 ]")
        #expect(CodeItem(inty.stacks[.int]!.first!.crux()).pretty() == "( 2 3 .intAdd )")
    }

    @Test func `positions of the extremes read the vector`() {
        let inty = Self.run([VecIntItem([4, 9, 2, 9]), Self.op(.vecIntIndexOfMax), Self.op(.vecIntIndexOfMin)])
        #expect(stackString(inty, .int) == "[ 2 1 ]", "ties go to the first")
        #expect(inty.stacks[.vecInt]!.count == 1)
        #expect(Self.replays(inty, .int))
        let empty = Self.run([VecDoubleItem([]), Self.op(.vecDoubleIndexOfMax)])
        #expect(Self.errorKinds(empty) == [.emptyCollection])
    }

    @Test func `product and mean`() {
        let inty = Self.run([VecIntItem([2, 3, 4]), Self.op(.vecIntProduct), Self.op(.vecIntMean)])
        #expect(stackString(inty, .int) == "[ 24 ]")
        #expect(stackString(inty, .double) == "[ 3.0 ]")
        #expect(Self.replays(inty, .double))
        let empty = Self.run([VecIntItem([]), Self.op(.vecIntProduct), Self.op(.vecIntMean)])
        #expect(stackString(empty, .int) == "[ 1 ]")
        #expect(Self.errorKinds(empty) == [.emptyCollection])
    }

    @Test func `the last occurrence`() {
        let inty = Self.run([VecIntItem([0, 5, 0, 7]), IntItem(0), Self.op(.vecIntLastIndexOf)])
        #expect(stackString(inty, .int) == "[ 2 0 ]", "the index, above the needle it read")
        let text = Self.run([StringItem("abca"), CharItem("a"), Self.op(.stringLastIndexOf)])
        #expect(stackString(text, .int) == "[ 3 ]")
        let absent = Self.run([VecIntItem([1]), IntItem(0), Self.op(.vecIntLastIndexOf)])
        #expect(Self.errorKinds(absent) == [.notFound])
    }

    @Test func `ranges count toward the end, which is left out`() {
        let up = Self.run([IntItem(2), IntItem(5), Self.op(.vecIntRange)])
        #expect(stackString(up, .vecInt) == "[ [2, 3, 4] ]")
        #expect(Self.replays(up, .vecInt))
        let down = Self.run([IntItem(3), IntItem(0), Self.op(.vecIntRange)])
        #expect(stackString(down, .vecInt) == "[ [3, 2, 1] ]")
        let stepped = Self.run([IntItem(0), IntItem(10), IntItem(3), Self.op(.vecIntRangeBy)])
        #expect(stackString(stepped, .vecInt) == "[ [0, 3, 6, 9] ]")
        let wrongWay = Self.run([IntItem(0), IntItem(10), IntItem(-1), Self.op(.vecIntRangeBy)])
        #expect(wrongWay.stacks[.vecInt]!.isEmpty && wrongWay.stacks[.error]!.count == 1)
        let huge = Self.run([IntItem(0), IntItem(Int.max), Self.op(.vecIntRange)])
        #expect(Self.errorKinds(huge) == [.sizeRefusal], "refused before anything is built")
    }

    @Test func `rotate, interleave and repeat`() {
        let rotated = Self.run([VecIntItem([1, 2, 3, 4]), IntItem(-1), Self.op(.vecIntRotate)])
        #expect(stackString(rotated, .vecInt) == "[ [4, 1, 2, 3] ]")
        let woven = Self.run([StringItem("ace"), StringItem("bd"), Self.op(.stringInterleave)])
        #expect(stackString(woven, .string) == "[ \"abcde\" ]")
        #expect(Self.replays(woven, .string))
        let repeated = Self.run([VecStringItem(["a", "b"]), IntItem(2), Self.op(.vecStringRepeat)])
        #expect(stackString(repeated, .vecString) == "[ [\"a\", \"b\", \"a\", \"b\"] ]")
        let none = Self.run([VecIntItem([1]), IntItem(-3), Self.op(.vecIntRepeat)])
        #expect(stackString(none, .vecInt) == "[ [] ]")
        // Nothing repeated any number of times is nothing, built at once.
        let empty = Self.run([VecBoolItem([]), IntItem(Int.max), Self.op(.vecBoolRepeat),
                              StringItem(""), IntItem(Int.max), Self.op(.stringRepeat)])
        #expect(stackString(empty, .vecBool) == "[ [] ]" && stackString(empty, .string) == "[ \"\" ]")
    }

    @Test func `frequencies give sorted distinct values, then counts`() {
        let words = Self.run([VecStringItem(["b", "a", "b", "c", "b"]), Self.op(.vecStringFrequencies)])
        #expect(stackString(words, .vecString) == "[ [\"a\", \"b\", \"c\"] ]")
        #expect(stackString(words, .vecInt) == "[ [1, 3, 1] ]")
        #expect(Self.replays(words, .vecString) && Self.replays(words, .vecInt))

        // Both on one stack: the values below, the counts on top, each replaying alone.
        let ints = Self.run([VecIntItem([5, 5, 2]), Self.op(.vecIntFrequencies)])
        #expect(stackString(ints, .vecInt) == "[ [1, 2] [2, 5] ]")
        #expect(Self.replays(ints, .vecInt))

        // Anagrams: equal frequencies.
        let anagram = Self.run([StringItem("listen"), Self.op(.stringFrequencies), Self.op(.vecIntPop),
                                StringItem("silent"), Self.op(.stringFrequencies), Self.op(.vecIntPop),
                                Self.op(.stringEq)])
        #expect(stackString(anagram, .bool) == "[ true ]")
    }

    @Test func `prefix sums`() {
        let inty = Self.run([VecIntItem([1, -2, 3]), Self.op(.vecIntPrefixSums)])
        #expect(stackString(inty, .vecInt) == "[ [1, -1, 2] ]")
        let overflow = Self.run([VecIntItem([Int.max, 1]), Self.op(.vecIntPrefixSums)])
        #expect(overflow.stacks[.error]!.count == 1)
    }

    @Test func `conversions and digits`() {
        let digits = Self.run([IntItem(-305), Self.op(.vecIntFromInt)])
        #expect(stackString(digits, .vecInt) == "[ [3, 0, 5] ]")
        let zero = Self.run([IntItem(0), Self.op(.vecIntFromInt)])
        #expect(stackString(zero, .vecInt) == "[ [0] ]")
        let back = Self.run([VecIntItem([3, 0, 5]), Self.op(.intFromVecInt)])
        #expect(stackString(back, .int) == "[ 305 ]")
        let doubles = Self.run([VecIntItem([1, 2]), Self.op(.vecDoubleFromVecInt)])
        #expect(stackString(doubles, .vecDouble) == "[ [1.0, 2.0] ]")
        let truncated = Self.run([VecDoubleItem([2.9, -2.9]), Self.op(.vecIntFromVecDouble)])
        #expect(stackString(truncated, .vecInt) == "[ [2, -2] ]")
        let nan = Self.run([VecDoubleItem([1, .nan]), Self.op(.vecIntFromVecDouble)])
        #expect(nan.stacks[.vecInt]!.isEmpty && nan.stacks[.error]!.count == 1)
        let bools = Self.run([VecBoolItem([true, false]), Self.op(.vecIntFromVecBool)])
        #expect(stackString(bools, .vecInt) == "[ [1, 0] ]")
    }

    /// The user's ruling (2026-11-12): bools order false before true, scalar
    /// and vector alike.
    @Test(arguments: [(PushInstruction.boolLT, [false, true, false, false]),
                      (.boolLTE, [true, true, false, true]),
                      (.boolGT, [false, false, true, false]),
                      (.boolGTE, [true, false, true, true])])
    func `bools compare false before true`(_ name: PushInstruction, _ truth: [Bool]) {
        // (p, q) over (false, false), (false, true), (true, false), (true, true).
        let pairs = [(false, false), (false, true), (true, false), (true, true)]
        for ((p, q), expected) in zip(pairs, truth) {
            let inty = Self.run([BoolItem(p), BoolItem(q), Self.op(name)])
            #expect(stackString(inty, .bool) == "[ \(expected) \(q) \(p) ]", "\(p) \(q) .\(name)")
        }
    }

    @Test func `vectors of bools are ordered false before true`() {
        let inty = Self.run([VecBoolItem([false, true]), VecBoolItem([true]), Self.op(.vecBoolLT),
                             Self.op(.vecBoolMax)])
        #expect(stackString(inty, .bool) == "[ true true ]")
    }

    @Test func `chunks and windows`() {
        let chunks = Self.run([VecIntItem([1, 2, 3, 4, 5]), IntItem(2), Self.op(.vecIntChunks)])
        #expect(stackString(chunks, .code) == "[ ( [1, 2] [3, 4] [5] ) ]")
        #expect(Self.replays(chunks, .code))
        let windows = Self.run([VecIntItem([1, 2, 3]), IntItem(2), Self.op(.vecIntWindows)])
        #expect(stackString(windows, .code) == "[ ( [1, 2] [2, 3] ) ]")
        let words = Self.run([StringItem("abcde"), IntItem(2), Self.op(.stringChunks)])
        #expect(stackString(words, .vecString) == "[ [\"ab\", \"cd\", \"e\"] ]")
        let tooWide = Self.run([VecIntItem([1]), IntItem(3), Self.op(.vecIntWindows)])
        #expect(stackString(tooWide, .code) == "[ ( ) ]")
    }

    @Test func `code at the root`() {
        let block = CodeItem([IntItem(1), CodeItem([IntItem(2)]), IntItem(3)])
        let reversed = Self.run([block, Self.op(.codeReverseRoot)])
        #expect(stackString(reversed, .code) == "[ ( 3 ( 2 ) 1 ) ]")
        let first = Self.run([block, Self.op(.codeFirstRoot)])
        #expect(stackString(first, .code) == "[ ( 1 ) ]")
        let last = Self.run([block, Self.op(.codeLastRoot)])
        #expect(stackString(last, .code) == "[ ( 3 ) ]")
        let taken = Self.run([block, IntItem(2), Self.op(.codeTakeRoot)])
        #expect(stackString(taken, .code) == "[ ( 1 ( 2 ) ) ]")
        let dropped = Self.run([block, IntItem(2), Self.op(.codeDropRoot)])
        #expect(stackString(dropped, .code) == "[ ( 3 ) ]")
        let empty = Self.run([CodeItem([]), Self.op(.codeFirstRoot)])
        #expect(Self.errorKinds(empty) == [.emptyCollection])
    }

    @Test func `values do not depend on recording`() {
        let program: [any Item] = [VecIntItem([3, 1, 3]), Self.op(.vecIntFrequencies), IntItem(1),
                                   Self.op(.vecIntRotate), VecIntItem([9]), Self.op(.vecIntInterleave),
                                   Self.op(.vecIntSort), IntItem(2), Self.op(.vecIntWindows)]
        let on = Self.run(program)
        let off = Self.run(program, recording: false)
        for stack in PushStack.allCases where stack != .function {
            #expect(stackString(on, stack) == stackString(off, stack), "\(stack)")
        }
    }
}
