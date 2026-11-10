//
//  Conversion Behavior Tests.swift
//  PushInterpreterTests
//
//  Vectors and code, chars into strings, and a string and its pieces.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct ConversionBehaviorTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    /// The top of `stack` re-run from its crux alone: that value and nothing else.
    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        let top = inty.stacks[stack]!.first!
        let fresh = Interpreter()
        fresh.load(program: top.crux())
        fresh.run(stepLimit: 1_000)
        return fresh.stacks[stack]!.count == 1 && fresh.stacks[stack]!.first!.pretty() == top.pretty()
            && PushStack.allCases.filter { $0 != stack && $0 != .exec }.allSatisfy { fresh.stacks[$0]!.isEmpty }
    }

    @Test func `a vector quotes into code and reads back`() {
        let quoted = Self.run([VecIntItem([1, 2, 3]), InstructionItem(.vecIntQuote)])
        #expect(stackString(quoted, .code) == "[ ( [1, 2, 3] ) ]")
        let back = Self.run([VecIntItem([1, 2, 3]), InstructionItem(.vecIntQuote), InstructionItem(.vecFromCode)])
        #expect(stackString(back, .vecInt) == "[ [1, 2, 3] ]")
    }

    @Test func `vecFromCode reads its type off the contents, uniform or refuse`() {
        let ints = Self.run([CodeItem([IntItem(4), IntItem(5)]), InstructionItem(.vecFromCode)])
        #expect(stackString(ints, .vecInt) == "[ [4, 5] ]")
        #expect(Self.replays(ints, .vecInt))

        let words = Self.run([CodeItem([StringItem("a"), StringItem("b")]), InstructionItem(.vecFromCode)])
        #expect(stackString(words, .vecString) == "[ [\"a\", \"b\"] ]")

        let mixed = Self.run([CodeItem([IntItem(4), StringItem("b")]), InstructionItem(.vecFromCode)])
        #expect(mixed.stacks[.error]!.count == 1)
        let empty = Self.run([CodeItem([]), InstructionItem(.vecFromCode)])
        #expect(empty.stacks[.error]!.count == 1)
    }

    @Test func `chars collect back into a string`() {
        let inty = Self.run([StringItem("abc"), InstructionItem(.stringPushAll),
                             IntItem(3), InstructionItem(.stringReadItems)])
        #expect(stackString(inty, .string) == "[ \"abc\" ]", "the inverse of stringPushAll")
        #expect(inty.stacks[.char]!.count == 3, "read, not taken")
        #expect(Self.replays(inty, .string))

        let all = Self.run([CharItem("x"), CharItem("y"), InstructionItem(.stringReadStack)])
        #expect(stackString(all, .string) == "[ \"xy\" ]")
        #expect(Self.replays(all, .string))
    }

    @Test func `a second way to reverse a string, through its letters`() {
        // Reading chars back is the identity (it inverts `stringPushAll`),
        // so the second route goes through a vector of letters instead.
        let inty = Self.run([StringItem("abc"), StringItem(""), InstructionItem(.stringSplitOn),
                             InstructionItem(.vecStringReverse), StringItem(""), InstructionItem(.vecStringJoin)])
        #expect(stackString(inty, .string) == "[ \"cba\" ]")
    }

    @Test func `split on a separator, then join with it, is the identity`() {
        let split = Self.run([StringItem("a,,b"), StringItem(","), InstructionItem(.stringSplitOn)])
        #expect(stackString(split, .vecString) == "[ [\"a\", \"\", \"b\"] ]")

        let roundTrip = Self.run([StringItem("a,,b"), StringItem(","), InstructionItem(.stringSplitOn),
                                  StringItem(","), InstructionItem(.vecStringJoin)])
        #expect(stackString(roundTrip, .string) == "[ \"a,,b\" ]")

        let letters = Self.run([StringItem("abc"), StringItem(""), InstructionItem(.stringSplitOn)])
        #expect(stackString(letters, .vecString) == "[ [\"a\", \"b\", \"c\"] ]")
    }

    @Test func `join with a separator, as Spin Words needs`() {
        let inty = Self.run([VecStringItem(["spin", "words"]), StringItem(" "), InstructionItem(.vecStringJoin)])
        #expect(stackString(inty, .string) == "[ \"spin words\" ]")
    }
}
