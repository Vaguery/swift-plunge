//
//  Crux Forms Showcase.swift
//  PlungeTests
//
//  Prints worked examples of every form of a crux, for the documentation
//  (2026-11-15): the program, its crux, distilled, abstract, tunable and
//  skeleton cruxes; fitting an abstract crux's constants to data; a fragment
//  with parameters against one without; skeletons shared by different programs.
//
//  Off unless `PUSH_CRUX_FORMS` is set. Run:
//
//      PUSH_CRUX_FORMS=1 swift test --filter CruxFormsShowcase
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct CruxFormsShowcase {

    nonisolated static let enabled = ProcessInfo.processInfo.environment["PUSH_CRUX_FORMS"] != nil

    typealias Example = CruxFormsExampleTests

    static func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }

    static func top(_ program: [any Item], inputs: [PushInstruction: any Item],
                    constants: [PushInstruction: any Item] = [:]) -> any Item {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: inputs, constants: constants, program: program)
        inty.run()
        return inty.stacks[.double]!.first!
    }

    static func value(_ program: [any Item], x: Double, y: Double) -> Double? {
        let redo = Interpreter()
        redo.load(inputs: [.input(0): DoubleItem(x), .input(1): DoubleItem(y)], program: program)
        redo.run()
        return redo.stacks[.double]!.first.flatMap { $0.exactly(DoubleItem.self)?.value }
    }

    static func describe(_ roles: [AbstractCrux.Role]) -> String {
        roles.enumerated().map { index, role in
            let what: String = switch role {
            case .input(let slot): ".\(slot.rawValue)"
            case .constant(let slot): "slot .\(slot.rawValue)"
            case .derived(let value): "derived \(value.pretty())"
            case .literal(let value): "literal \(value.pretty())"
            case .open(let stack): "open \(stack.rawValue)"
            case .control(let neutral): "control (neutral \(neutral.pretty()))"
            case .anyInput(let stack): "any \(stack.rawValue) input"
            case .anyConstant(let stack): "any \(stack.rawValue) constant"
            }
            return "$\(index) = \(what)"
        }.joined(separator: "; ")
    }

    @Test(.enabled(if: CruxFormsShowcase.enabled))
    func `print the worked examples`() {
        var lines: [String] = []
        // 1. The forms of one program.
        let item = Example.result()
        let distilled = item.distilledCrux()
        let abstract = distilled.abstracted()!
        let tunable = distilled.tunable()!
        let skeleton = distilled.skeleton()!
        lines += [
            "== forms",
            "program:   \(CodeItem(Example.program).pretty())",
            "crux:      \(CodeItem(item.crux()).pretty())",
            "distilled: \(CodeItem(distilled.program).pretty())",
            "abstract:  \(abstract.key)  [\(Self.describe(abstract.roles))]",
            "tunable:   \(tunable.key)  [\(Self.describe(tunable.roles))]",
            "skeleton:  \(skeleton.key)  [\(Self.describe(skeleton.roles))]",
            "steps: program \(Self.steps(Example.program)), crux \(Self.steps(item.crux())), "
                + "distilled \(Self.steps(distilled.program))"
        ]

        lines += Self.fitLines(abstract)

        // 3. A fragment with parameters in place, and one without.
        let inputs: [PushInstruction: any Item] = [.input(0): DoubleItem(4)]
        let withParameters = Self.top(Self.ins(.input(0)) + [DoubleItem(2)] + Self.ins(.doubleMultiply)
                                 + [DoubleItem(1)] + Self.ins(.doubleAdd), inputs: inputs).distilledCrux()
        let bare = Self.top(Self.ins(.input(0), .doubleSin), inputs: inputs).distilledCrux()
        let bareWithout = Self.top(Self.ins(.input(0)), inputs: inputs).distilledCrux()
        lines += ["== parameters in place or not",
                  "A crux:     \(CodeItem(withParameters.program).pretty())",
                  "A abstract: \(withParameters.abstracted()!.key)",
                  "A tunable:  \(withParameters.tunable()!.key)",
                  "B crux:     \(CodeItem(bareWithout.program).pretty())",
                  "B abstract: \(bareWithout.abstracted()!.key)",
                  "B tunable:  \(bareWithout.tunable()!.key)",
                  "C crux:     \(CodeItem(bare.program).pretty())",
                  "C tunable:  \(bare.tunable()!.key)"]

        // 4. Different programs, one skeleton.
        let both: [PushInstruction: any Item] = [.input(0): DoubleItem(4), .input(1): DoubleItem(10)]
        let constants: [PushInstruction: any Item] = [.constant(10): DoubleItem(0.5), .constant(13): DoubleItem(9)]
        let programs: [[any Item]] = [
            Self.ins(.input(0), .constant(10), .doubleMultiply),
            Self.ins(.input(1), .constant(13), .doubleMultiply),
            Self.ins(.input(0), .constant(13), .doubleSubtract, .constant(10), .doubleSubtract, .constant(13), .doubleAdd) // differs
                + [],
            [DoubleItem(2)] + Self.ins(.input(1), .doubleMultiply),
            Self.ins(.constant(10), .constant(13), .doubleAdd, .input(0), .doubleMultiply)
        ]
        lines.append("== skeletons")
        for program in programs {
            let found = Self.top(program, inputs: both, constants: constants).distilledCrux()
            lines.append("program \(CodeItem(program).pretty())  abstract \(found.abstracted()!.key)  "
                         + "skeleton \(found.skeleton()!.key)")
        }
        print(lines.joined(separator: "\n"))
    }

    /// Fits the running example's abstract crux, x·k0 + k1·y, to data made by 3x + 2y. The holes are linear, so
    /// least squares is exact.
    static func fitLines(_ abstract: AbstractCrux) -> [String] {
        let points: [(x: Double, y: Double)] = [(1, 2), (2, -1), (4, 3), (-3, 5), (0.5, 0.5)]
        let target = { (p: (x: Double, y: Double)) in 3 * p.x + 2 * p.y }
        var (sxx, sxy, syy, sxt, syt) = (0.0, 0.0, 0.0, 0.0, 0.0)
        for p in points {
            sxx += p.x * p.x; sxy += p.x * p.y; syy += p.y * p.y
            sxt += p.x * target(p); syt += p.y * target(p)
        }
        let det = sxx * syy - sxy * sxy
        let k0 = (sxt * syy - syt * sxy) / det, k1 = (syt * sxx - sxt * sxy) / det
        let fitted = abstract.program(filling: [DoubleItem(k0), DoubleItem(k1)])
        var lines = ["== fit to 3x + 2y",
                  "k0 = \(k0), k1 = \(k1)",
                  "fitted:    \(CodeItem(fitted).pretty())"]
        for p in points {
            let original = abstract.program(filling: abstract.originalFillers!)
            lines.append("  x \(p.x), y \(p.y): target \(target(p)), "
                         + "fitted \(Self.value(fitted, x: p.x, y: p.y) ?? .nan), "
                         + "original \(Self.value(original, x: p.x, y: p.y) ?? .nan)")
        }

        return lines
    }

    static func steps(_ program: [any Item]) -> Int {
        let redo = Interpreter()
        redo.load(inputs: Example.inputs, constants: Example.constants, program: program)
        redo.run()
        return redo.counter
    }

    // MARK: - A dozen examples across the language, as JSON for the documentation

    static let allInputs: [PushInstruction: any Item] = [
        .input(0): IntItem(5), .input(1): StringItem("hello world"), .input(2): BoolItem(true), .input(3): CharItem("m"),
        .input(4): DoubleItem(2.5), .input(5): VecIntItem([1, 2, 3]), .input(6): VecDoubleItem([0.5, 1.5, 4]),
        .input(7): VecBoolItem([true, false, true]), .input(8): VecStringItem(["apple", "pear", "fig"])
    ]
    static let allConstants: [PushInstruction: any Item] = [
        .constant(0): IntItem(7), .constant(1): IntItem(-2), .constant(10): DoubleItem(0.5), .constant(11): DoubleItem(3),
        .constant(20): StringItem("abc"), .constant(40): VecIntItem([10, 20, 30]),
        .constant(60): VecStringItem(["fig", "cba", "plum"])
    ]

    struct Showcased: Encodable {
        let name: String, stack: String, note: String
        let program: String, value: String, crux: String, distilled: String
        let derived: [String]
        let abstract: String?, abstractRoles: String?
        let tunable: String?, tunableRoles: String?
        let skeleton: String?, skeletonRoles: String?
        let refills: [String: Bool]
        let steps: [String: Int]
        let loops: String?
    }

    typealias Environment = (inputs: [PushInstruction: any Item], constants: [PushInstruction: any Item])

    static func replayValue(_ program: [any Item], on stack: PushStack,
                            _ environment: Environment = (allInputs, allConstants)) -> (value: String?, steps: Int) {
        let redo = Interpreter()
        redo.load(inputs: environment.inputs, constants: environment.constants, program: program)
        redo.run(stepLimit: 100_000)
        return (redo.stacks[stack]!.first?.pretty(), redo.counter)
    }

    static func showcase(_ name: String, _ program: [any Item], on stack: PushStack, note: String,
                         _ environment: Environment = (allInputs, allConstants)) -> Showcased {
        let inty = Interpreter.recordingProvenance()
        inty.load(inputs: environment.inputs, constants: environment.constants, program: program)
        inty.run(stepLimit: 100_000)
        let item = inty.stacks[stack]!.first!
        let distilled = item.distilledCrux()
        let abstract = distilled.abstracted(), tunable = distilled.tunable(), skeleton = distilled.skeleton()
        var refills: [String: Bool] = [:]
        for (form, crux) in [("abstract", abstract), ("tunable", tunable), ("skeleton", skeleton)] {
            guard let crux, let fillers = crux.originalFillers else { continue }
            refills[form] = replayValue(crux.program(filling: fillers), on: stack, environment).value == item.pretty()
        }
        refills["distilled"] = replayValue(distilled.program, on: stack, environment).value == item.pretty()
        let minimized = item.minimizingLoops(on: [environment], stack: stack)
        let loops = minimized.flatMap { found -> String? in
            guard found.loops > 0 else { return nil }
            let changes = found.changes.map { "\($0.from) → \($0.to) passes" }.joined(separator: ", ")
            return "\(CodeItem(found.program).pretty())" + (changes.isEmpty ? " (no pass can go)" : " (\(changes))")
        }
        return Showcased(
            name: name, stack: stack.rawValue, note: note,
            program: CodeItem(program).pretty(), value: item.pretty(), crux: CodeItem(item.crux()).pretty(),
            distilled: CodeItem(distilled.program).pretty(),
            derived: distilled.derived.map {
                "\($0.value.pretty()) from \(CodeItem($0.origin).pretty())"
                    + ($0.slotsRead.isEmpty ? ""
                       : ", reading " + $0.slotsRead.map { ".\($0.rawValue)" }.joined(separator: " "))
            },
            abstract: abstract?.key, abstractRoles: abstract.map { describe($0.roles) },
            tunable: tunable?.key, tunableRoles: tunable.map { describe($0.roles) },
            skeleton: skeleton?.key, skeletonRoles: skeleton.map { describe($0.roles) },
            refills: refills,
            steps: ["program": inty.counter, "crux": replayValue(item.crux(), on: stack, environment).steps,
                    "distilled": replayValue(distilled.program, on: stack, environment).steps],
            loops: loops)
    }

    @Test(.enabled(if: CruxFormsShowcase.enabled))
    func `write the examples as JSON`() throws {
        func ins(_ names: PushInstruction...) -> [any Item] { names.map { InstructionItem($0) } }
        let examples = [
            Self.showcase("double arithmetic", Example.program, on: .double,
                          note: "the running example, with unrelated bool and int work mixed in",
                          (Example.inputs, Example.constants)),
            Self.showcase("int arithmetic", ins(.input(0), .constant(0), .intMultiply) + [IntItem(3), IntItem(4)]
                     + ins(.intAdd, .intAdd), on: .int, note: "a slot read times an input, plus literal work"),
            Self.showcase("bool", ins(.input(2)) + [IntItem(3), IntItem(4)] + ins(.intLT, .boolAnd), on: .bool,
                     note: "a comparison of two literals feeds a logical operation on an input"),
            Self.showcase("char", ins(.input(3), .intFromChar, .constant(0), .intAdd, .charFromInt), on: .char,
                     note: "a code-point shift by a constant slot"),
            Self.showcase("string", ins(.constant(20), .stringReverse, .constant(20), .constant(1), .stringNth, .stringRemove, .input(1),
                                   .stringConcat), on: .string,
                     note: "a constant string reversed, a character picked by a constant index removed from it, "
                         + "then the input joined on"),
            Self.showcase("vector of strings", ins(.constant(60), .constant(20), .stringReverse, .vecStringRemove, .input(8),
                                              .vecStringConcat), on: .vecString,
                     note: "a constant vector filtered by a reversed constant string, then the input appended"),
            Self.showcase("vector of ints", ins(.input(5), .constant(40), .vecIntAdd) + [IntItem(2)] + ins(.vecIntMultiplyInt),
                     on: .vecInt, note: "an input added element-wise to a constant vector, then every element doubled"),
            Self.showcase("vector of doubles", ins(.input(6), .vecDoubleMean, .constant(10), .constant(11), .doubleAdd,
                                              .doubleMultiply), on: .double,
                     note: "the mean of an input vector, scaled by work on two constant slots"),
            Self.showcase("vector of bools", ins(.input(7), .vecBoolNot) + [IntItem(3), IntItem(4)]
                     + ins(.intLT, .vecBoolAndBool), on: .vecBool,
                     note: "an input negated element-wise, then masked by a constant comparison"),
            Self.showcase("a loop", [IntItem(0), CodeItem(ins(.input(0), .intAdd) + [IntItem(12)] + ins(.intMin)),
                                     IntItem(50)]
                     + ins(.execDoTimes), on: .int,
                     note: "a counted loop that adds the input fifty times but never passes 12"),
            Self.showcase("the loop, minimized first", [IntItem(0), CodeItem(ins(.input(0), .intAdd) + [IntItem(12)]
                          + ins(.intMin)), IntItem(3)] + ins(.execDoTimes), on: .int,
                          note: "the same loop at the three passes loop minimization found"),
            Self.showcase("code built, then run", [CodeItem([IntItem(2)]), CodeItem([IntItem(3)] + ins(.intMultiply))]
                     + ins(.codeConcat, .codeDo, .input(0), .intAdd), on: .int,
                     note: "two code blocks joined and run: the crux keeps what ran, not how the code was built"),
            Self.showcase("a function mapped", [CodeItem([IntItem(3)] + ins(.intMultiply))]
                     + ins(.codePushAllFunctions, .input(5), .vecIntMap), on: .vecInt,
                     note: "a function derived from a code block and mapped over the input vector"),
            Self.showcase("a stack depth", ins(.input(0)) + [IntItem(10)] + ins(.intStackDepth, .intAdd, .intMultiply),
                     on: .int, note: "the depth of the int stack, read mid-program, is the run's state"),
            Self.showcase("a print", ins(.input(0)) + [IntItem(2), IntItem(3)] + ins(.intAdd, .intMultiply, .intPrint),
                     on: .print, note: "a printed result rests on .print")
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let dir = ProcessInfo.processInfo.environment["PUSH_ATTRIBUTION_DIR"].map { URL(fileURLWithPath: $0) }
            ?? URL.temporaryDirectory
        try encoder.encode(examples).write(to: dir.appending(path: "crux-forms.json"))
        print("wrote \(examples.count) examples to \(dir.path)")
    }
}
