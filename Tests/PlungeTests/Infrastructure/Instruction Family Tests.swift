//
//  Instruction Family Tests.swift
//  PlungeTests
//
//  How instructions are named since 2026-11-19 (#55). Most instructions have a
//  name (`.intAdd`). Two are numbered families with no last member: the inputs,
//  `.input(k)`, and the constants, `.constant(k)`. Constants have no type: a
//  slot holds a value of any type. Each test below states one rule.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct InstructionFamilyTests {

    // MARK: - Writing and reading instructions

    @Test func `a named instruction has a shorthand, the same instruction`() {
        let written: PushInstruction = .intAdd
        #expect(written == .named(.intAdd))
        #expect(written.name == .intAdd)
        #expect(written.slot == nil)
    }

    @Test func `inputs and constants are numbered, and know their number`() {
        let input: PushInstruction = .input(12)
        let constant: PushInstruction = .constant(3)
        #expect(input.isInput && !input.isConstant && input.slot == 12 && input.name == nil)
        #expect(constant.isConstant && !constant.isInput && constant.slot == 3)
        #expect(PushInstruction.input(3) != PushInstruction.constant(3), "same number, different families")
    }

    @Test func `every instruction has one name, used to print, encode and look it up`() {
        let names: [(PushInstruction, String)] = [(.intAdd, "intAdd"), (.input(0), "input0"),
                                                  (.input(12), "input12"), (.constant(3), "constant3"),
                                                  (.constant(250), "constant250")]
        for (instruction, name) in names {
            #expect(instruction.rawValue == name)
            #expect("\(instruction)" == name)
            #expect(PushInstruction(rawValue: name) == instruction)
        }
        // In a program, an instruction prints with a dot, as before.
        #expect(InstructionItem(.input(0)).pretty() == ".input0")
        #expect(InstructionItem(.constant(12)).pretty() == ".constant12")
    }

    @Test func `names that aren't instructions are refused`() {
        // No number, a sign, a leading zero, or something that isn't a name.
        for name in ["input", "constant", "input-1", "input+1", "input07", "constant00", "inputX", "intAddd", ""] {
            #expect(PushInstruction(rawValue: name) == nil, "\(name)")
        }
        // The typed constant names are gone.
        #expect(PushInstruction(rawValue: "int3") == nil)
    }

    @Test func `instructions encode as their names, so older files still read`() throws {
        let instructions: [PushInstruction] = [.intAdd, .input(12), .constant(3)]
        let json = try JSONEncoder().encode(instructions)
        #expect(String(decoding: json, as: UTF8.self) == #"["intAdd","input12","constant3"]"#)
        #expect(try JSONDecoder().decode([PushInstruction].self, from: json) == instructions)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([PushInstruction].self, from: Data(#"["int3"]"#.utf8))
        }
    }

    @Test func `instructions work as dictionary keys and in sets`() {
        let set: Set<PushInstruction> = [.input(1), .input(1), .constant(1), .intAdd, .named(.intAdd)]
        #expect(set.count == 3)
        let table: [PushInstruction: String] = [.input(1): "x", .constant(1): "c"]
        #expect(table[.input(1)] == "x" && table[.constant(1)] == "c")
    }

    // MARK: - The families have no last member

    @Test func `the language lists ten inputs and eighty constants`() {
        let runner = Runner()
        #expect(runner.instructions(role: .input) == (0..<10).map(PushInstruction.input))
        #expect(Set(runner.instructions(role: .constant)) == Set((0..<80).map(PushInstruction.constant)))
        #expect(PushInstruction.allCases.count == InstructionName.allCases.count + 10 + 80)
    }

    @Test func `an input past the listed ones runs like any other`() {
        let inty = Interpreter()
        inty.load(inputs: [.input(25): IntItem(4)], program: [InstructionItem(.input(25))])
        inty.run()
        #expect((inty.stacks[.int]!.first as? IntItem)?.value == 4)
    }

    @Test func `a constant past the listed ones runs like any other`() {
        let inty = Interpreter()
        inty.load(constants: [.constant(500): StringItem("far")], program: [InstructionItem(.constant(500))])
        inty.run()
        #expect((inty.stacks[.string]!.first as? StringItem)?.value == "far")
    }

    @Test func `an unbound member refuses, naming itself`() {
        let inty = Interpreter()
        inty.load(program: [InstructionItem(.input(25)), InstructionItem(.constant(500))])
        inty.run()
        let errors = inty.stacks[.error]!.compactMap { $0 as? ErrorItem }
        #expect(errors.map(\.kind).sorted { "\($0)" < "\($1)" } == [.missingConstant, .missingInput])
        #expect(errors.contains { $0.source == .input(25) })
        #expect(errors.contains { $0.source == .constant(500) })
    }

    @Test func `a member past the listed ones answers the language's questions like the first`() {
        let runner = Runner()
        #expect(runner.signature(of: .input(57)) == runner.signature(of: .input(0)))
        #expect(runner.signature(of: .constant(500)) == runner.signature(of: .constant(0)))
        #expect(runner.tags(of: .input(57)) == runner.tags(of: .input(0)))
        #expect(runner.summary(of: .constant(500)) != nil)
        #expect(runner.signature(of: .input(-1)) == nil, "no negative slots")
    }

    @Test func `any member can be disabled, listed or not`() {
        let table = BehaviorTable(Interpreter.language, disabling: [.input(3), .input(40), .constant(90)])
        #expect(table[.input(3)] == nil)
        #expect(table[.input(40)] == nil)
        #expect(table[.constant(90)] == nil)
        #expect(table[.input(4)] != nil && table[.input(41)] != nil && table[.constant(91)] != nil)
        #expect(table[.input(-1)] == nil, "a negative slot is no instruction")
    }

    // MARK: - Constants have no type

    @Test func `a constant slot takes a value of any type, which goes to its own stack`() {
        let values: [(any Item, PushStack)] = [(IntItem(1), .int), (BoolItem(true), .bool),
                                               (StringItem("s"), .string), (VecIntItem([1, 2]), .vecInt),
                                               (CodeItem([IntItem(5)]), .code)]
        for (value, stack) in values {
            let inty = Interpreter()
            inty.load(constants: [.constant(0): value], program: [InstructionItem(.constant(0))])
            inty.run()
            #expect(inty.stacks[stack]!.count == 1, "\(value.pretty()) should rest on .\(stack)")
        }
    }

    @Test func `only constants can be bound as constants`() {
        let inty = Interpreter()
        let rejected = inty.loadConstants([.constant(2): IntItem(1), .intAdd: IntItem(1),
                                           .input(0): IntItem(1), .constant(-1): IntItem(1)])
        #expect(Set(rejected) == [.intAdd, .input(0), .constant(-1)])
        #expect(inty.constants.keys.map(\.self) == [.constant(2)])
    }

    @Test func `random code spreads the listed constants over types by a convention`() {
        // Ten slots per type, in the order the typed constants had.
        #expect(PushInstruction.conventionalConstant(.int, 3) == .constant(3))
        #expect(PushInstruction.conventionalConstant(.double, 3) == .constant(13))
        #expect(PushInstruction.conventionalConstant(.vecBool, 9) == .constant(79))
        #expect(PushInstruction.conventionalConstant(.bool, 0) == nil, "Booleans had no typed constants")
        #expect(PushInstruction.conventionalConstant(.int, 10) == nil, "ten per type")
        #expect(PushInstruction.conventionalStack(ofConstantSlot: 13) == .double)
        #expect(PushInstruction.conventionalStack(ofConstantSlot: 80) == nil, "past the listed constants")

        let inty = Interpreter()
        RandomCode.setRandomConstants(in: inty)
        for slot in 0..<80 {
            let value = inty.constants[.constant(slot)]
            #expect(value.flatMap(PushStack.defaultStack(for:)) == PushInstruction.conventionalStack(ofConstantSlot: slot))
        }
    }

    // MARK: - Inputs on `.binding`, and fresh keys

    @Test func `fresh binding keys start past the inputs, at 10 for ten inputs or fewer`() {
        #expect(Interpreter.firstFreshKey(after: [.input(0): IntItem(1)]) == 10)
        #expect(Interpreter.firstFreshKey(after: [:]) == 10)
        #expect(Interpreter.firstFreshKey(after: [.input(14): IntItem(1)]) == 15)
    }

    @Test func `an input past the listed ones is bound on .binding under its number`() {
        let inty = Interpreter()
        inty.load(inputs: [.input(0): IntItem(1), .input(14): IntItem(2)], program: [])
        let keys = inty.stacks[.binding]!.compactMap { ($0 as? BindingItem)?.key }
        #expect(keys == [14, 0], "the highest slot's pair on top")
        #expect(inty.nextRefKey == 15)
    }

    // MARK: - Crux shapes

    @Test func `crux shapes number the constants in order of first appearance`() {
        let crux: [any Item] = [InstructionItem(.constant(40)), InstructionItem(.constant(7)),
                                InstructionItem(.constant(40)), InstructionItem(.intAdd)]
        #expect(CodeItem(Interpreter.cruxShape(crux)).pretty() == "( .constant0 .constant1 .constant0 .intAdd )")
    }

    // MARK: - The generated shorthands

    /// Every name needs its shorthand in `PushInstruction+Names.swift`. The file is
    /// generated: set PUSH_WRITE_NAMES=1 to rewrite it after adding an instruction.
    @Test func `every instruction name has its shorthand`() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Sources/Plunge/PushInstruction+Names.swift")
        let expected = Self.namesFile()
        if ProcessInfo.processInfo.environment["PUSH_WRITE_NAMES"] == "1" {
            try expected.write(to: url, atomically: true, encoding: .utf8)
        }
        let committed = try String(contentsOf: url, encoding: .utf8)
        #expect(committed == expected, "PushInstruction+Names.swift is out of date: run PUSH_WRITE_NAMES=1")
    }

    static func namesFile() -> String {
        let header = """
            //
            //  PushInstruction+Names.swift
            //  Plunge
            //
            //  GENERATED: a shorthand for every named instruction, so `.intAdd` can be
            //  written wherever a `PushInstruction` is expected. `Instruction Family Tests`
            //  fails if a name is missing; to regenerate, run
            //  PUSH_WRITE_NAMES=1 swift test --filter InstructionFamilyTests
            //

            // swiftlint:disable file_length
            public nonisolated extension PushInstruction {

            """
        let lines = InstructionName.allCases.map {
            "    static var \($0.rawValue): PushInstruction { .named(.\($0.rawValue)) }\n"
        }
        return header + lines.joined() + "}\n"
    }
}
