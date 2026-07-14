//
//  SizeLimits Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/13/26.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct SizeLimitsTests {

    let inty = Interpreter()

    // MARK: CodeItem.flatSize

    @Test func `flatSize counts a flat block`() {
        #expect(CodeItem([IntItem(1), IntItem(2), InstructionItem(.intAdd)]).flatSize == 3)
    }

    @Test func `flatSize recurses into nested code`() {
        let code = CodeItem([IntItem(1), CodeItem([IntItem(2), IntItem(3)])])
        #expect(code.flatSize == 3)
    }

    @Test func `flatSize of empty and empty-nested code is zero`() {
        #expect(CodeItem([]).flatSize == 0)
        #expect(CodeItem([CodeItem([]), CodeItem([CodeItem([])])]).flatSize == 0)
    }

    @Test func `flatSize of deep single-leaf nesting is one`() {
        #expect(CodeItem([CodeItem([CodeItem([IntItem(9)])])]).flatSize == 1)
    }

    // MARK: Item.weight

    @Test func `scalars weigh one`() {
        #expect(IntItem(999).weight == 1)
        #expect(BoolItem(true).weight == 1)
        #expect(DoubleItem(3.14).weight == 1)
        #expect(CharItem("x").weight == 1)
        #expect(InstructionItem(.intAdd).weight == 1)
    }

    @Test func `string weight is its byte count`() {
        #expect(StringItem("hello").weight == 5)
        #expect(StringItem("").weight == 0)
    }

    @Test func `vector weight is element count, but total chars for vecString`() {
        #expect(VecIntItem([1, 2, 3, 4]).weight == 4)
        #expect(VecBoolItem([true, false]).weight == 2)
        // total characters across the strings, not the count of strings
        #expect(VecStringItem(["ab", "cde", ""]).weight == 5)
    }

    @Test func `code weight sums its contents recursively`() {
        let code = CodeItem([
            IntItem(1),                       // 1
            VecStringItem(["abcd"]),          // 4
            CodeItem([StringItem("xyz")]),    // 3
        ])
        #expect(code.weight == 8)
    }

    // MARK: push-boundary enforcement

    @Test func `an oversized vector is refused and reported to error`() {
        inty.config.maxVectorLength = 3
        inty.push(VecIntItem([1, 2, 3, 4]), to: .vecInt)

        #expect(inty.stacks[.vecInt]!.isEmpty)
        #expect(inty.stacks[.error]!.count == 1)
        #expect(stackString(inty, .error).contains("maxVectorLength"))
    }

    @Test func `a vector within the limit pushes normally`() {
        inty.config.maxVectorLength = 3
        inty.push(VecIntItem([1, 2, 3]), to: .vecInt)

        #expect(inty.stacks[.vecInt]!.count == 1)
        #expect(inty.stacks[.error]!.isEmpty)
    }

    @Test func `an oversized string is refused and reported to error`() {
        inty.config.maxStringLength = 4
        inty.push(StringItem("toolong"), to: .string)

        #expect(inty.stacks[.string]!.isEmpty)
        #expect(inty.stacks[.error]!.count == 1)
        #expect(stackString(inty, .error).contains("maxStringLength"))
    }

    @Test func `an oversized code item is refused and reported to error`() {
        inty.config.maxCodePoints = 2
        inty.push(CodeItem([IntItem(1), IntItem(2), IntItem(3)]), to: .code)

        #expect(inty.stacks[.code]!.isEmpty)
        #expect(inty.stacks[.error]!.count == 1)
        #expect(stackString(inty, .error).contains("maxCodePoints"))
    }

    // The key guarantee: only the overflowing item disappears, not the rest.
    @Test func `only the overflowing item is dropped, others push`() {
        inty.config.maxVectorLength = 3
        inty.push(VecIntItem([9, 9]), to: .vecInt)          // fine
        inty.push(VecIntItem([1, 2, 3, 4, 5]), to: .vecInt) // oversized
        inty.push(IntItem(42), to: .int)                    // unrelated, fine

        #expect(inty.stacks[.vecInt]!.count == 1)
        #expect((inty.stacks[.vecInt]!.first as? VecIntItem)?.value == [9, 9])
        #expect((inty.stacks[.int]!.first as? IntItem)?.value == 42)
        #expect(inty.stacks[.error]!.count == 1)
    }

    // MARK: recursive weight cap (the nested-content backstop)

    // The hole from the worst-case analysis: a vector of long strings passes the
    // element-count cap but is caught by the recursive weight cap.
    @Test func `a vector of long strings passes the count cap but fails on weight`() {
        inty.config.maxVectorLength = 10   // count is fine: only 3 strings
        inty.config.maxItemWeight = 12
        let bomb = VecStringItem(["aaaaa", "bbbbb", "ccccc"]) // count 3, weight 15

        #expect(inty.overflow(of: bomb) != nil) // flagged despite small count
        inty.push(bomb, to: .vecString)
        #expect(inty.stacks[.vecString]!.isEmpty)
        #expect(stackString(inty, .error).contains("maxItemWeight"))
    }

    @Test func `code whose leaves are large is caught by weight, not flatSize`() {
        inty.config.maxCodePoints = 10     // only 2 leaves: flatSize fine
        inty.config.maxItemWeight = 8
        let code = CodeItem([VecIntItem([1, 2, 3, 4, 5]), VecIntItem([6, 7, 8, 9, 10])]) // weight 10

        inty.push(code, to: .code)
        #expect(inty.stacks[.code]!.isEmpty)
        #expect(stackString(inty, .error).contains("maxItemWeight"))
    }

    // MARK: stack-depth cap

    @Test func `a push onto a full stack is refused`() {
        inty.config.maxStackDepth = 3
        for n in 0..<3 { inty.push(IntItem(n), to: .int) }
        #expect(inty.stacks[.int]!.count == 3)

        inty.push(IntItem(99), to: .int) // over depth
        #expect(inty.stacks[.int]!.count == 3)
        #expect(stackString(inty, .error).contains("maxStackDepth"))
    }

    // MARK: invariant violations (a mis-typed push, formerly a fatalError)

    @Test func `a mis-typed push is refused with an invariant marker, not a trap`() {
        inty.push(StringItem("x"), to: .int) // .int accepts only IntItem

        #expect(inty.stacks[.int]!.isEmpty)
        #expect(stackString(inty, .error).contains(Interpreter.invariantMarker))
        // the invariant is preserved: nothing wrong-typed reached .int
        #expect(inty.stacks[.error]!.count == 1)
    }

    // MARK: exemptions

    @Test func `error stack is exempt from size limits`() {
        #expect(PushStack.error.enforcesSizeLimits == false)
        // all other stacks enforce
        for stack in PushStack.allCases where stack != .error {
            #expect(stack.enforcesSizeLimits)
        }
    }

    // End to end through the real step/distribute/Router path: a behavior that
    // grows a vector past the cap has its result refused, its inputs still
    // consumed, and an error reported.
    @Test func `an instruction that grows a vector past the cap overflows to error`() {
        inty.config.maxVectorLength = 3
        inty.load(
            stacks: [.vecInt: [VecIntItem([1, 2]), VecIntItem([3, 4])]],
            program: [InstructionItem(.vecIntConcat)]
        )
        inty.run(stepLimit: 10)

        // the length-4 concatenation is refused; the two operands were consumed
        #expect(inty.stacks[.vecInt]!.isEmpty)
        #expect(inty.stacks[.error]!.count == 1)
        #expect(stackString(inty, .error).contains("maxVectorLength"))
    }
}
