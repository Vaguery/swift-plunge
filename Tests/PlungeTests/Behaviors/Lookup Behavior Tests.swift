//
//  Lookup Behavior Tests.swift
//  PushInterpreterTests
//
//  Pattern lookup on the stacks: the probe is
//  read; a copy of the first match below it goes on top and its position onto
//  `.int`; a miss is a refusal; `…From` continues a walk.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct LookupBehaviorTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    @Test func `nearest copies the closest item and leaves the probe`() {
        // .double reads, top first: 10.0 (the probe), 9.5, 3.0, 11.0.
        let inty = Self.run([DoubleItem(11), DoubleItem(3), DoubleItem(9.5), DoubleItem(10),
                             Self.op(.doubleLookupNearest)])
        #expect(stackString(inty, .double) == "[ 9.5 10.0 9.5 3.0 11.0 ]")
        #expect(stackString(inty, .int) == "[ 2 ]", "found at depth 1, so 2: where it sits under the copy")
    }

    @Test func `the position reaches the match with yank`() {
        let inty = Self.run([StringItem("pear"), StringItem("apple pie"), StringItem("apple"),
                             Self.op(.stringLookupPrefix), Self.op(.stringYank)])
        #expect(stackString(inty, .string) == "[ \"apple pie\" \"apple pie\" \"apple\" \"pear\" ]")
    }

    @Test func `walking every match: use the copy, then continue from the position`() {
        // Strings containing "a", below the probe "a": "cat" then "bat"; "dog" never.
        let inty = Self.run([StringItem("bat"), StringItem("dog"), StringItem("cat"), StringItem("a"),
                             Self.op(.stringLookupContaining), Self.op(.stringPop),
                             Self.op(.stringLookupContainingFrom)])
        #expect(stackString(inty, .string) == "[ \"bat\" \"a\" \"cat\" \"dog\" \"bat\" ]")
        #expect(stackString(inty, .int) == "[ 4 ]")
    }

    @Test func `a miss is a refusal that consumes nothing`() {
        let inty = Self.run([VecIntItem([9]), VecIntItem([1, 2]), IntItem(1), Self.op(.vecIntLookupPrefixFrom)])
        #expect(stackString(inty, .vecInt) == "[ [1, 2] [9] ]")
        #expect(stackString(inty, .int) == "[ 1 ]", "the start is handed back")
        #expect(inty.stacks[.error]!.first!.pretty().contains("missing args: .vecInt"))

        let alone = Self.run([IntItem(5), Self.op(.intLookupNearest)])
        #expect(stackString(alone, .int) == "[ 5 ]", "nothing below the probe")
    }

    @Test func `on the int stack the position lands on top, so a yank reaches the match`() {
        let inty = Self.run([IntItem(40), IntItem(7), IntItem(12), Self.op(.intLookupNearest)])
        #expect(stackString(inty, .int) == "[ 2 7 12 7 40 ]", "the position above the copy")

        let yanked = Self.run([IntItem(40), IntItem(7), IntItem(12), Self.op(.intLookupNearest),
                               Self.op(.intYank)])
        #expect(stackString(yanked, .int) == "[ 7 7 12 40 ]", "the yank takes the position and fetches the match")
    }

    @Test func `a dictionary as association blocks on code`() {
        let entryA = CodeItem([StringItem("a"), IntItem(1)])
        let entryB = CodeItem([StringItem("b"), IntItem(2)])
        let inty = Self.run([entryA, entryB, StringItem("a"), Self.op(.stringQuote), Self.op(.codeLookupPrefix),
                             IntItem(1), Self.op(.codeEmitNthRoot)])
        #expect(inty.stacks[.int]!.first!.pretty() == "1", "the value stored under \"a\"")
    }

    @Test func `shape matches the same tree with atoms as parameters`() {
        let probe = CodeItem([IntItem(1), InstructionItem(.intAdd)])
        let wrongOp = CodeItem([IntItem(5), InstructionItem(.intSubtract)])
        let sameShape = CodeItem([IntItem(5), InstructionItem(.intAdd)])
        let inty = Self.run([sameShape, wrongOp, probe, Self.op(.codeLookupShape)])
        #expect(inty.stacks[.code]!.first!.pretty() == "( 5 .intAdd )")
    }

    @Test func `the copy keeps its own history`() {
        let inty = Self.run([IntItem(2), IntItem(3), Self.op(.intAdd), IntItem(4), Self.op(.intLookupEqual)])
        // No 4 below the probe: a refusal.
        #expect(inty.stacks[.error]!.count == 1)

        let found = Self.run([IntItem(2), IntItem(3), Self.op(.intAdd), IntItem(6), Self.op(.intLookupNearest)])
        let copy = found.stacks[.int]![1]   // under its position
        #expect(copy.pretty() == "5")
        #expect(CodeItem(copy.crux()).pretty() == "( 2 3 .intAdd )")
    }
}
