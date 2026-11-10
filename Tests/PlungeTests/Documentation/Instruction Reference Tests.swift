//
//  Instruction Reference Tests.swift
//  PlungeTests
//
//  The instruction reference in the DocC catalog is generated from the language
//  itself: each instruction's summary (declared beside its definition with
//  `described(_:)`), its arguments and its outputs. These tests keep the two
//  in step.
//
//  To regenerate the pages after changing the language:
//
//      PUSH_WRITE_REFERENCE=1 swift test --filter InstructionReferenceTests
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct InstructionReferenceTests {

    // MARK: - The checks

    @Test func `every instruction has a summary`() {
        let missing = Interpreter.language.filter { $0.value.summary.isEmpty }.keys.map(\.rawValue).sorted()
        #expect(missing.isEmpty, "\(missing.count) instructions have no summary: \(missing)")
    }

    @Test func `the committed reference pages match the language`() throws {
        let pages = Self.pages()
        let folder = Self.referenceFolder
        if ProcessInfo.processInfo.environment["PUSH_WRITE_REFERENCE"] == "1" {
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for (name, text) in pages {
                try text.write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
            }
            return
        }
        for (name, text) in pages {
            let committed = try? String(contentsOf: folder.appending(path: name), encoding: .utf8)
            #expect(committed == text, "\(name) is stale: run PUSH_WRITE_REFERENCE=1 swift test --filter InstructionReferenceTests")
        }
        let onDisk = (try? FileManager.default.contentsOfDirectory(atPath: folder.path())) ?? []
        let extra = Set(onDisk.filter { $0.hasSuffix(".md") }).subtracting(pages.keys)
        #expect(extra.isEmpty, "pages no longer generated: \(extra.sorted())")
    }


    // MARK: - Where the pages go

    static let referenceFolder = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources/Plunge/Plunge.docc/Instruction Reference")


    // MARK: - Pages

    /// One page per subject, in reading order.
    struct Subject {
        let page: String
        let title: String
        let intro: String
    }

    static let subjects: [Subject] = [
        Subject(page: "BoolInstructions", title: "Bool instructions",
                intro: "The `.bool` stack holds `true` and `false`. Comparisons on other stacks put their answers here, and the conditional instructions on `.code` and `.exec` take their condition from it."),
        Subject(page: "IntInstructions", title: "Int instructions",
                intro: "The `.int` stack holds 64-bit signed integers. Arithmetic never wraps: a result that would overflow is refused, and the refusal goes to `.error`. Ints also serve the rest of the language as counts, indices, depths and binding keys."),
        Subject(page: "DoubleInstructions", title: "Double instructions",
                intro: "The `.double` stack holds 64-bit floating-point numbers. No instruction leaves a NaN or an infinity on the stack: a result that would be one is refused instead."),
        Subject(page: "CharInstructions", title: "Char instructions",
                intro: "The `.char` stack holds single characters (Swift `Character`s, so one may be several Unicode scalars). Strings are taken apart into chars and built back up from them."),
        Subject(page: "StringInstructions", title: "String instructions",
                intro: "The `.string` stack holds text. Indices count characters, not bytes, and an index outside a string is clamped into it rather than refused."),
        Subject(page: "CodeInstructions", title: "Code instructions",
                intro: "The `.code` stack holds blocks: lists of any items, nested to any depth. A block met on `.exec` comes to rest here as data; `codeDo` and the other control instructions are what run one. Blocks are also the language's general-purpose container."),
        Subject(page: "ExecInstructions", title: "Exec instructions",
                intro: "The `.exec` stack is the program still to run: the interpreter pops its top item each step and executes it. These instructions loop, branch and rearrange what is pending. Their bodies come from `.code`."),
        Subject(page: "IteratorInstructions", title: "Iterator instructions",
                intro: "The `.iterator` stack holds first-class loops: a source (a range, a collection or a block), a cursor, and optionally a body to run each pass. Iterators are how the language counts, walks collections and collects results."),
        Subject(page: "BindingInstructions", title: "Binding instructions",
                intro: "The `.binding` stack holds keyed bindings: an int key and any item. The topmost binding with a key is that variable's current value, and older ones below it are shadowed, so each variable is a stack of its own. The inputs are bound to keys 0, 1, 2, … at load, and fresh keys follow them. The binders, `intRef`, `stringRef` and the rest, are on their source stacks' pages."),
        Subject(page: "VecBoolInstructions", title: "Vector of bool instructions",
                intro: "The `.vecBool` stack holds vectors of bools. It shares its instruction families with the other vector types."),
        Subject(page: "VecIntInstructions", title: "Vector of int instructions",
                intro: "The `.vecInt` stack holds vectors of ints. It shares its instruction families with the other vector types, and adds the numeric reductions."),
        Subject(page: "VecDoubleInstructions", title: "Vector of double instructions",
                intro: "The `.vecDouble` stack holds vectors of doubles. It shares its instruction families with the other vector types, and adds the numeric reductions."),
        Subject(page: "VecStringInstructions", title: "Vector of string instructions",
                intro: "The `.vecString` stack holds vectors of strings: words, lines and lists of names. It shares its instruction families with the other vector types."),
        Subject(page: "EnvironmentInstructions", title: "Inputs, output and the interpreter",
                intro: "These instructions read the program's environment (its inputs and the interpreter's state) or write to its printout. The constants of each type are on that type's page.")
    ]

    /// The page an instruction belongs on: its stack's, by name, with the few
    /// that are named for what they do rather than for a stack placed by hand.
    static func page(of name: PushInstruction) -> String {
        let raw = name.rawValue
        if raw == "vecFromIterator" { return "IteratorInstructions" }
        if raw == "vecFromCode" { return "CodeInstructions" }
        let stacks = PushStack.allCases.map(\.rawValue).sorted { $0.count > $1.count }
        for stack in stacks where raw.hasPrefix(stack) {
            let rest = raw.dropFirst(stack.count)
            guard rest.first.map({ !$0.isLowercase }) ?? true else { continue }
            if stack == "error" { return "EnvironmentInstructions" }
            return "\(stack.prefix(1).uppercased())\(stack.dropFirst())Instructions"
        }
        return "EnvironmentInstructions"
    }

    /// The generated family every stack has (dup, pop, swap, …): described once,
    /// on its own page, rather than on every stack's.
    static func isGeneratedFamily(_ name: PushInstruction) -> Bool {
        Interpreter.instructions(role: .stackFamily).contains(name)
    }

    static let sections: [(BehaviorClass, String)] = [
        (.operation, "Operations"),
        (.contextRead, "Reading the environment"),
        (.control, "Control"),
        (.structural, "Rearranging the stack"),
        (.channel, "Output")
    ]

    static func pages() -> [String: String] {
        var pages: [String: String] = [:]
        let names = Interpreter.language.keys.sorted { $0.rawValue < $1.rawValue }
        var byPage: [String: [PushInstruction]] = [:]
        for name in names where !isGeneratedFamily(name) { byPage[page(of: name), default: []].append(name) }

        for subject in subjects {
            let members = byPage[subject.page] ?? []
            var text = "# \(subject.title)\n\n\(subject.intro)\n\n"
            text += "<!-- Generated by Instruction Reference Tests from the language itself: do not edit. -->\n"
            for (behaviorClass, heading) in sections {
                let rows = members.filter { Interpreter.language[$0]!.behaviorClass == behaviorClass }
                guard !rows.isEmpty else { continue }
                text += "\n## \(heading)\n\n" + table(rows)
            }
            if let stack = stack(of: subject) {
                let family = names.filter { isGeneratedFamily($0) && page(of: $0) == subject.page }
                if !family.isEmpty {
                    text += "\n## The stack's own instructions\n\n"
                    text += "Every stack has the same family for copying, deleting, reordering and measuring "
                    text += "its items; see <doc:StackInstructions>. On `.\(stack)` they are "
                    text += family.map { "`\($0.rawValue)`" }.joined(separator: ", ") + ".\n"
                }
            }
            pages["\(subject.page).md"] = text
        }
        pages["StackInstructions.md"] = stackFamilyPage()
        return pages
    }

    static func stack(of subject: Subject) -> String? {
        PushStack.allCases.map(\.rawValue).first { "\($0.prefix(1).uppercased())\($0.dropFirst())Instructions" == subject.page }
    }

    /// The generated family, shown once, on `.int`: the members on every other
    /// stack differ only in the stack's name.
    static func stackFamilyPage() -> String {
        let family = Interpreter.language.keys.filter { isGeneratedFamily($0) && $0.rawValue.hasPrefix("int") }
            .sorted { $0.rawValue < $1.rawValue }
        let stacks = Interpreter.generatedFamilyStacks.map { "`.\($0.rawValue)`" }.joined(separator: ", ")
        var text = "# Stack instructions\n\n"
        text += "Every stack but `.error` has the same family of instructions for copying, deleting, "
        text += "reordering and measuring its items: \(stacks). They are listed here once, for `.int`; "
        text += "on another stack, replace `int` with that stack's name (`codeDup`, `vecStringYank`, …).\n\n"
        text += "An index or a count comes from `.int`, and is clamped into the stack rather than refused. "
        text += "When the stack is `.int` itself, the index is popped first and the rest of the stack is "
        text += "counted after it.\n\n"
        text += "<!-- Generated by Instruction Reference Tests from the language itself: do not edit. -->\n\n"
        return text + table(family)
    }


    // MARK: - Rows

    static func table(_ names: [PushInstruction]) -> String {
        var text = "| Instruction | What it does | Takes | Gives |\n|---|---|---|---|\n"
        for name in names {
            let behavior = Interpreter.language[name]!
            let summary = behavior.summary.replacing("|", with: "\\|")
            text += "| `\(name.rawValue)` | \(summary) | \(takes(behavior)) | \(gives(behavior)) |\n"
        }
        return text
    }

    /// The arguments, in the order the instruction claims them (the top first).
    static func takes(_ behavior: Behavior) -> String {
        let parts = behavior.requirements.map { requirement -> String in
            switch requirement {
            case .takes(let stack): "`\(stack.rawValue)`"
            case .reads(let stack): "`\(stack.rawValue)` (read)"
            case .needs(let stack, let count): count == 1 ? "a `\(stack.rawValue)` item" : "\(count) `\(stack.rawValue)` items"
            case .takesMany(let stack, _): "n × `\(stack.rawValue)`"
            }
        }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    /// The outputs, and whether it can refuse its arguments.
    static func gives(_ behavior: Behavior) -> String {
        func list(_ stacks: [PushStack]) -> String {
            stacks.isEmpty ? "—" : stacks.map { "`\($0.rawValue)`" }.joined(separator: ", ")
        }
        var text: String = switch behavior.produces {
        case .results(let stacks): list(stacks)
        case .alternatives(let options): options.map(list).joined(separator: " or ")
        case .deferred(let stack): "`\(stack.rawValue)`"
        case .input: "the input's type"
        case .delivery(let stack): "`\(stack.rawValue)`, one per step"
        case .positions(let stack): "`\(stack.rawValue)`, rearranged"
        case .continuation: "the rest of the program"
        case .printout: "the printout"
        }
        if behavior.tags.contains(.fallible) { text += "; may refuse" }
        return text
    }
}
