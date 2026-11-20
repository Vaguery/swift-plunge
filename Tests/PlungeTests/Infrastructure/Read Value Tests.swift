//
//  Read Value Tests.swift
//  PlungeTests
//
//  An input or constant token in a history notes the value it read, and a crux
//  shows it: `«.input0 int: 4»` (2026-11-20). The note never changes a run.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct ReadValueTests {

    static func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }

    /// The top of `stack` after running `program` with provenance on.
    static func top(_ program: [any Item], inputs: [PushInstruction: any Item],
                    constants: [PushInstruction: any Item] = [:], on stack: PushStack = .int) -> any Item {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, constants: constants, program: program)
        inty.run(stepLimit: 1_000)
        return inty.stacks[stack]!.first!
    }

    /// `.input0 .constant0 .intAdd`.
    static let sum = ins(.input(0), .constant(0), .intAdd)

    @Test func `a crux shows what each input and constant read`() {
        let item = Self.top(Self.sum, inputs: [.input(0): IntItem(4)], constants: [.constant(0): IntItem(10)])
        #expect(CodeItem(item.crux()).pretty() == "( «.input0 int: 4» «.constant0 int: 10» .intAdd )")
    }

    @Test func `a value is written in its short form, with its type`() {
        #expect(InstructionItem(.input(2), read: StringItem("hi")).pretty() == "«.input2 str: \"hi\"»")
        #expect(InstructionItem(.constant(1), read: DoubleItem(2.5)).pretty() == "«.constant1 dbl: 2.5»")
        #expect(InstructionItem(.constant(3), read: VecIntItem([])).pretty() == "«.constant3 vecInt: []»")
        #expect(InstructionItem(.input(0)).pretty() == ".input0", "a token in a program read nothing")
    }

    @Test func `a key leaves inputs bare and keeps constants; a program form leaves both bare`() {
        let one = Self.top(Self.sum, inputs: [.input(0): IntItem(4)], constants: [.constant(0): IntItem(10)])
        let other = Self.top(Self.sum, inputs: [.input(0): IntItem(9)], constants: [.constant(0): IntItem(10)])
        #expect(CodeItem(one.crux()).pretty() != CodeItem(other.crux()).pretty())
        #expect(CodeItem(one.crux()).prettyKey() == "( .input0 «.constant0 int: 10» .intAdd )")
        #expect(CodeItem(one.crux()).prettyKey() == CodeItem(other.crux()).prettyKey(), "one key on every case")
        #expect(CodeItem(one.crux()).prettyProgram() == "( .input0 .constant0 .intAdd )")
        let otherConstant = Self.top(Self.sum, inputs: [.input(0): IntItem(4)],
                                     constants: [.constant(0): IntItem(11)])
        #expect(CodeItem(one.crux()).prettyKey() != CodeItem(otherConstant.crux()).prettyKey(),
                "another constant is another computation")
    }

    @Test func `the read value is only a note: a crux replayed on another case reads that case`() {
        let crux = Self.top(Self.sum, inputs: [.input(0): IntItem(4)], constants: [.constant(0): IntItem(10)]).crux()
        let replayed = Self.top(crux, inputs: [.input(0): IntItem(30)], constants: [.constant(0): IntItem(1)])
        #expect((replayed as? IntItem)?.value == 31)
        #expect(InstructionItem(.input(0), read: IntItem(4)) == InstructionItem(.input(0)), "equality ignores it")
    }

    @Test func `the note fits in the item's history reference, so the item stays small`() {
        #expect(MemoryLayout<InstructionItem>.size <= 24)
        let noted = InstructionItem(.input(0), read: IntItem(4))
        #expect(noted.call.isEmpty && noted.callWeight == 1, "still a literal")
    }

    @Test func `read values survive encoding and the item archive`() throws {
        let item = Self.top(Self.sum, inputs: [.input(0): IntItem(4)], constants: [.constant(0): IntItem(10)])
        let printed = CodeItem(item.crux()).pretty()
        // A token on its own, as `AnyItem` encodes it.
        let token = InstructionItem(.input(0), read: StringItem("hi"))
        let decoded = try JSONDecoder().decode(AnyItem.self, from: JSONEncoder().encode(AnyItem(token))).item
        #expect(decoded.pretty() == token.pretty())
        // A whole history, as the archive keeps it.
        let archived = try JSONDecoder().decode(ItemArchive.self, from: JSONEncoder().encode(ItemArchive([item])))
        #expect(CodeItem(archived.items[0].crux()).pretty() == printed)
    }

    @Test func `two reads of one slot on different cases are archived apart`() throws {
        let four = Self.top(Self.sum, inputs: [.input(0): IntItem(4)], constants: [.constant(0): IntItem(10)])
        let nine = Self.top(Self.sum, inputs: [.input(0): IntItem(9)], constants: [.constant(0): IntItem(10)])
        let archived = try JSONDecoder().decode(ItemArchive.self, from: JSONEncoder().encode(ItemArchive([four, nine])))
        #expect(archived.items.map { CodeItem($0.crux()).pretty() }
                == [CodeItem(four.crux()).pretty(), CodeItem(nine.crux()).pretty()])
    }

    @Test func `a crux still converts back to a genome`() {
        let crux = Self.top(Self.sum, inputs: [.input(0): IntItem(4)], constants: [.constant(0): IntItem(10)]).crux()
        let genome = Genome(program: crux, constants: [.constant(0): IntItem(10)])
        #expect(CodeItem(genome.translate()).prettyProgram() == CodeItem(crux).prettyProgram())
    }
}
