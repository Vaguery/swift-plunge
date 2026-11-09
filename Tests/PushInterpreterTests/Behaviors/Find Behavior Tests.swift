//
//  Find Behavior Tests.swift
//  PushInterpreterTests
//
//  Lookup within a collection (Behavior coverage audit §8, step 4b): a query
//  that reads a container and a probe, and gives the first matching element
//  with its index; and `IndexOf` from a start.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct FindBehaviorTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// `item` re-run from its crux on a fresh interpreter: that value on
    /// `stack`, and nothing anywhere else.
    static func replays(_ item: any Item, on stack: PushStack) -> Bool {
        let fresh = Interpreter()
        fresh.load(program: item.crux())
        fresh.run(stepLimit: 10_000)
        return fresh.stacks[stack]!.count == 1 && fresh.stacks[stack]!.first!.pretty() == item.pretty()
            && PushStack.allCases.filter { $0 != stack && $0 != .exec }.allSatisfy { fresh.stacks[$0]!.isEmpty }
    }

    @Test func `nearest in a vector gives the element and its index, and reads both arguments`() {
        let inty = Self.run([VecIntItem([3, 9, 14]), IntItem(10), Self.op(.vecIntFindNearest)])
        #expect(stackString(inty, .int) == "[ 9 1 10 ]", "the element on top of its index, the probe kept")
        #expect(stackString(inty, .vecInt) == "[ [3, 9, 14] ]")
        let ints = inty.stacks[.int]!
        #expect(Self.replays(ints[0], on: .int) && Self.replays(ints[1], on: .int))
    }

    @Test func `nearest ties go to the first, and From skips ahead`() {
        let tie = Self.run([VecDoubleItem([1, 3, 5]), DoubleItem(4), Self.op(.vecDoubleFindNearest)])
        #expect(stackString(tie, .double) == "[ 3.0 4.0 ]")
        #expect(stackString(tie, .int) == "[ 1 ]")

        let from = Self.run([VecDoubleItem([1, 3, 5]), DoubleItem(4), IntItem(2), Self.op(.vecDoubleFindNearestFrom)])
        #expect(stackString(from, .double) == "[ 5.0 4.0 ]")
        #expect(stackString(from, .int) == "[ 2 2 ]", "index 2, above the start it read")
        #expect(Self.replays(from.stacks[.double]!.first!, on: .double))
        #expect(Self.replays(from.stacks[.int]!.first!, on: .int))
    }

    @Test func `nearest character in a string`() {
        let inty = Self.run([StringItem("adz"), CharItem("y"), Self.op(.stringFindNearest)])
        #expect(stackString(inty, .char) == "[ 'z' 'y' ]")
        #expect(stackString(inty, .int) == "[ 2 ]")
        #expect(Self.replays(inty.stacks[.char]!.first!, on: .char))
    }

    @Test func `the first word with a prefix, or containing a substring`() {
        let words = VecStringItem(["cat", "apple", "pineapple", "apricot"])
        let prefix = Self.run([words, StringItem("ap"), Self.op(.vecStringFindPrefix)])
        #expect(stackString(prefix, .string) == "[ \"apple\" \"ap\" ]")
        #expect(stackString(prefix, .int) == "[ 1 ]")
        #expect(Self.replays(prefix.stacks[.string]!.first!, on: .string))
        #expect(Self.replays(prefix.stacks[.int]!.first!, on: .int))

        let next = Self.run([words, StringItem("ap"), IntItem(2), Self.op(.vecStringFindPrefixFrom)])
        #expect(stackString(next, .string) == "[ \"apricot\" \"ap\" ]")

        let containing = Self.run([words, StringItem("pp"), IntItem(2), Self.op(.vecStringFindContainingFrom)])
        #expect(stackString(containing, .string) == "[ \"pineapple\" \"pp\" ]")
    }

    @Test func `an association list inside one block`() {
        let table = CodeItem([CodeItem([StringItem("a"), IntItem(1)]), IntItem(7),
                              CodeItem([StringItem("b"), IntItem(2)])])
        let inty = Self.run([table, StringItem("b"), Self.op(.stringQuote), Self.op(.codeFindPrefix)])
        #expect(inty.stacks[.code]!.first!.pretty() == "( \"b\" 2 )")
        #expect(stackString(inty, .int) == "[ 2 ]", "the bare 7 is passed over: only blocks have a prefix")
        #expect(inty.stacks[.code]!.count == 3, "the table and the probe are kept")
        #expect(Self.replays(inty.stacks[.code]!.first!, on: .code))
        #expect(Self.replays(inty.stacks[.int]!.first!, on: .int))
    }

    @Test func `a miss is a refusal that leaves everything`() {
        let empty = Self.run([VecIntItem([]), IntItem(4), Self.op(.vecIntFindNearest)])
        #expect(stackString(empty, .int) == "[ 4 ]")
        #expect(empty.stacks[.error]!.first!.pretty().contains("Not found"))

        let past = Self.run([VecStringItem(["ab"]), StringItem("a"), IntItem(1), Self.op(.vecStringFindPrefixFrom)])
        #expect(stackString(past, .string) == "[ \"a\" ]")
        #expect(stackString(past, .int) == "[ 1 ]")
        #expect(past.stacks[.error]!.count == 1)
    }

    @Test func `IndexOf from a start walks every occurrence`() {
        let vec = Self.run([VecIntItem([5, 0, 5, 5]), IntItem(5), IntItem(1), Self.op(.vecIntIndexOfFrom)])
        #expect(stackString(vec, .int) == "[ 2 1 5 ]")
        #expect(Self.replays(vec.stacks[.int]!.first!, on: .int))

        let char = Self.run([CharItem("a"), StringItem("banana"), IntItem(2), Self.op(.stringIndexOfCharFrom)])
        #expect(stackString(char, .int) == "[ 3 2 ]")

        let text = Self.run([StringItem("abcabc"), StringItem("bc"), IntItem(2), Self.op(.stringIndexOfFrom)])
        #expect(stackString(text, .int) == "[ 4 2 ]", "counted from the front, not from the start")

        let none = Self.run([StringItem("abcabc"), StringItem("bc"), IntItem(5), Self.op(.stringIndexOfFrom)])
        #expect(stackString(none, .int) == "[ 5 ]")
        #expect(none.stacks[.error]!.count == 1)

        let atEnd = Self.run([StringItem("ab"), StringItem(""), IntItem(2), Self.op(.stringIndexOfFrom)])
        #expect(stackString(atEnd, .int) == "[ 2 2 ]", "an empty needle is found at the start")
    }
}
