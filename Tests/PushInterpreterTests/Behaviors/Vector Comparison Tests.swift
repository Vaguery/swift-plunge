//
//  Vector Comparison Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/18/26.
//
//  Lexicographic ordering for `vecInt` / `vecDouble` / `vecString` — the vector
//  analog of `stringLT`/`stringGT`. Two claims: the order is Swift's built-in
//  lexicographic array order (element-by-element, length only breaks ties), and
//  the comparison is a **non-destructive query** — both operands survive and the
//  crux pops the two it read.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct VectorComparisonTests {

    /// Push `y` (deeper) and `x` (on top), run the instruction, return the bool.
    /// The behavior compares `y OP x`.
    func compareInt(_ y: [Int], _ x: [Int], _ instr: PushInstruction) -> Bool {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem(x), VecIntItem(y)] as [any Item])
        doThis(instr, to: inty)
        return (topItem(inty, .bool) as! BoolItem).value
    }

    @Test func `vecInt order is lexicographic, not shortlex`() {
        // [9] > [1,1,1] — the first element decides, length is irrelevant here.
        #expect(compareInt([9], [1, 1, 1], .vecIntGT))
        #expect(compareInt([1, 1, 1], [9], .vecIntLT))
        // A prefix is less than its extension: [1,2] < [1,2,3].
        #expect(compareInt([1, 2], [1, 2, 3], .vecIntLT))
        #expect(compareInt([1, 2, 3], [1, 2], .vecIntGT))
        // Equal vectors: LTE and GTE hold, strict LT/GT do not.
        #expect(compareInt([5, 5], [5, 5], .vecIntLTE))
        #expect(compareInt([5, 5], [5, 5], .vecIntGTE))
        #expect(!compareInt([5, 5], [5, 5], .vecIntLT))
        #expect(!compareInt([5, 5], [5, 5], .vecIntGT))
        // Empty is least.
        #expect(compareInt([], [0], .vecIntLT))
    }

    @Test func `a comparison survives both operands and cleans up its crux`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([9]), VecIntItem([1, 1, 1])] as [any Item])
        // x = [9] (top), y = [1,1,1]. GT asks "y > x": [1,1,1] > [9] is false.
        doThis(.vecIntGT, to: inty)
        #expect((topItem(inty, .bool) as! BoolItem).value == false)
        #expect(stackString(inty, .vecInt) == "[ [9] [1, 1, 1] ]", "both operands survive the read")
        #expect(callString(topItem(inty, .bool)) == "( [1, 1, 1] [9] .vecIntGT 2 .vecIntPopItems )")
    }

    @Test func `a comparison crux reproduces debris-free`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([1, 2]), VecIntItem([1, 2, 3])] as [any Item])
        doThis(.vecIntLT, to: inty)   // y=[1,2,3], x=[1,2]; "y < x" false
        let result = topItem(inty, .bool)

        let redo = Interpreter()
        redo.load(program: result.crux())
        redo.run()
        #expect(stackString(redo, .bool) == "[ false ]")
        #expect(redo.stacks[.vecInt]!.isEmpty, "the crux popped both operands")
    }

    @Test func `contingency propagates from either operand`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(contentsOf:
            [VecIntItem([1]), VecIntItem([2], isContingent: true)] as [any Item])
        doThis(.vecIntLTE, to: inty)
        #expect(topItem(inty, .bool).isContingent)
    }

    @Test func `vecDouble and vecString compare lexicographically too`() {
        let d = Interpreter()
        d.stacks[.vecDouble]!.prepend(contentsOf:
            [VecDoubleItem([0.0, 0.0, 0.0]), VecDoubleItem([9.9, 8.8])] as [any Item])
        // x = [0,0,0] top, y = [9.9,8.8]. GT: y > x → [9.9,8.8] > [0,0,0] → true.
        doThis(.vecDoubleGT, to: d)
        #expect((topItem(d, .bool) as! BoolItem).value)
        #expect(callString(topItem(d, .bool)) == "( [9.9, 8.8] [0.0, 0.0, 0.0] .vecDoubleGT 2 .vecDoublePopItems )")

        let s = Interpreter()
        s.stacks[.vecString]!.prepend(contentsOf:
            [VecStringItem(["b"]), VecStringItem(["a", "z"])] as [any Item])
        // x = ["b"] top, y = ["a","z"]. LT: y < x → ["a","z"] < ["b"] → "a"<"b" → true.
        doThis(.vecStringLT, to: s)
        #expect((topItem(s, .bool) as! BoolItem).value)
    }
}
