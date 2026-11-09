//
//  Text Behavior Tests.swift
//  PushInterpreterTests
//
//  Case, substring search, prefixes and suffixes, and trimming.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct TextBehaviorTests {

    static func run(_ program: [any Item]) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        inty.load(program: program)
        inty.run(stepLimit: 1_000)
        return inty
    }

    @Test func `char case maps one character to one`() {
        let inty = Self.run([CharItem("a"), InstructionItem(.charUpper), CharItem("Q"), InstructionItem(.charLower)])
        #expect(stackString(inty, .char) == "[ 'q' 'A' ]")
        let eszett = Self.run([CharItem("ß"), InstructionItem(.charUpper)])
        #expect(stackString(eszett, .char) == "[ ]")
        #expect(eszett.stacks[.error]!.count == 1, "ß uppercases to two characters")
    }

    @Test func `char case questions read and leave`() {
        let inty = Self.run([CharItem("a"), InstructionItem(.charIsUpper), InstructionItem(.charIsLower)])
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(stackString(inty, .char) == "[ 'a' ]")
    }

    @Test func `string case maps the whole string`() {
        let inty = Self.run([StringItem("Straße"), InstructionItem(.stringUpper)])
        #expect(stackString(inty, .string) == "[ \"STRASSE\" ]")
        let lower = Self.run([StringItem("MiXeD"), InstructionItem(.stringLower)])
        #expect(stackString(lower, .string) == "[ \"mixed\" ]")
    }

    @Test func `indexOf finds a substring, counted in characters`() {
        let inty = Self.run([StringItem("hello"), StringItem("ll"), InstructionItem(.stringIndexOf)])
        #expect(stackString(inty, .int) == "[ 2 ]")
        #expect(inty.stacks[.string]!.count == 2, "a query leaves both")

        let missing = Self.run([StringItem("hello"), StringItem("z"), InstructionItem(.stringIndexOf)])
        #expect(stackString(missing, .int) == "[ ]")
        #expect(missing.stacks[.error]!.count == 1)
    }

    @Test func `starts and ends with`() {
        let inty = Self.run([StringItem("prefix"), StringItem("pre"), InstructionItem(.stringStartsWith),
                             InstructionItem(.stringEndsWith)])
        #expect(stackString(inty, .bool) == "[ false true ]")
    }

    @Test func `trim removes whitespace at both ends only`() {
        let inty = Self.run([StringItem("  a b \n"), InstructionItem(.stringTrim)])
        #expect(stackString(inty, .string) == "[ \"a b\" ]")
        let blank = Self.run([StringItem("   "), InstructionItem(.stringTrim)])
        #expect(stackString(blank, .string) == "[ \"\" ]")
    }
}
