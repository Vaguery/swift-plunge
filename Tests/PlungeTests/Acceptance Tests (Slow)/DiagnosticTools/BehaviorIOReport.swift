//
//  BehaviorIOReport.swift
//  PlungeTests
//
//  Classifies and writes up what `BehaviorIOSurvey` observed.
//

@testable import Plunge

/// How an instruction's outputs vary, from its non-starved trials.
enum OutputClass: String, CaseIterable {
    /// Writes into stacks directly (`BehaviorWithSideEffects`), beyond its Routers.
    case directWrites = "writes stacks directly"
    /// Returned no Routers in any trial: it only consumes.
    case nothing = "returns nothing"
    /// One result signature every time.
    case fixed = "fixed"
    /// One set of stack:type pairs, in varying numbers.
    case variableCount = "fixed types, variable count"
    /// The types vary, but only on `.exec` or `.code`, which hold any item.
    case programTypes = "types vary on .exec/.code only"
    /// The types vary elsewhere: read off a value (an iterator's kind, a binding).
    case valueTypes = "types vary with argument values"
}

struct BehaviorIOReport {
    let records: [PushInstruction: BehaviorIOSurvey.Record]

    static func shape(_ signature: String) -> Set<String> {
        Set(signature.split(separator: " ").map(String.init))
    }

    func classify(_ record: BehaviorIOSurvey.Record) -> OutputClass {
        if !record.directWrites.isEmpty { return .directWrites }
        let signatures = Array(record.resultSignatures.keys)
        if signatures.isEmpty { return .nothing }
        if signatures.count == 1 { return .fixed }
        let shapes = Set(signatures.map(Self.shape))
        if shapes.count == 1 { return .variableCount }
        let off = Set(shapes.map { $0.filter { !$0.hasPrefix(".exec:") && !$0.hasPrefix(".code:") } })
        return off.count == 1 ? .programTypes : .valueTypes
    }

    static func inputs(_ behavior: Behavior) -> String {
        behavior.requirements.map { requirement in
            switch requirement {
            case .takes(let stack): "take .\(stack)"
            case .reads(let stack): "read .\(stack)"
            case .needs(let stack, let count): "need .\(stack)×\(count)"
            case .takesMany(let stack, _): "take n .\(stack)"
            case .takesFirst(let stack, _): "take the first fitting .\(stack)"
            }
        }.joined(separator: ", ")
    }

    private var sorted: [(PushInstruction, BehaviorIOSurvey.Record)] {
        records.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    private func top(_ counts: [String: Int], _ limit: Int) -> String {
        counts.sorted { $0.value > $1.value }.prefix(limit)
            .map { "\($0.key.isEmpty ? "(none)" : $0.key) ×\($0.value)" }.joined(separator: "; ")
    }

    func table() -> String {
        var lines = ["instruction\tinputs\tclass\tstarved\tresult signatures\tbody errors\terror kinds\t"
                     + "gate refusals\tdirect writes"]
        for (name, record) in sorted {
            let behavior = Interpreter.language[name]!
            lines.append([name.rawValue, Self.inputs(behavior), classify(record).rawValue,
                          "\(record.starved)/\(record.trials)", top(record.resultSignatures, 4),
                          "\(record.errorAlone) alone, \(record.errorWithResults) with results",
                          top(record.errorKinds, 3), top(record.refusals, 3), top(record.directWrites, 3)]
                .joined(separator: "\t"))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func summary() -> String {
        var out = "# Behavior I/O survey\n\n\(records.count) instructions × \(BehaviorIOSurvey.trials) trials.\n\n"
        out += classes() + errors() + gate() + exec()
        return out
    }

    private func names(_ list: [PushInstruction], _ limit: Int = 40) -> String {
        let shown = list.prefix(limit).map { "`\($0.rawValue)`" }.joined(separator: ", ")
        return list.count > limit ? shown + ", … (\(list.count) in all)" : shown
    }

    private func classes() -> String {
        var out = "## Output classes (non-starved trials)\n\n"
        for kind in OutputClass.allCases {
            let members = sorted.filter { classify($0.1) == kind }.map(\.0)
            out += "- **\(kind.rawValue)**: \(members.count)\n"
            if kind != .fixed { out += "  - \(names(members, 60))\n" }
        }
        let never = sorted.filter { $0.1.starved == $0.1.trials }.map(\.0)
        out += "\nNever ran (starved every trial): \(never.count). \(names(never))\n\n"
        for kind in [OutputClass.variableCount, .programTypes, .valueTypes] {
            out += "### Examples: \(kind.rawValue)\n\n"
            for (name, record) in sorted.filter({ classify($0.1) == kind }).prefix(12) {
                out += "- `\(name.rawValue)`: \(top(record.resultSignatures, 4))\n"
            }
            out += "\n"
        }
        return out
    }

    private func errors() -> String {
        let erring = sorted.filter { $0.1.errorAlone + $0.1.errorWithResults > 0 }
        var kinds: [String: Int] = [:]
        for (_, record) in erring { for (kind, count) in record.errorKinds { kinds[kind, default: 0] += count } }
        let alone = erring.filter { $0.1.errorWithResults == 0 }.map(\.0)
        let mixed = erring.filter { $0.1.errorWithResults > 0 }.map(\.0)
        let declared = Set(Interpreter.instructions(declaring: .fallible))
        let undeclared = erring.map(\.0).filter { !declared.contains($0) }
        let silent = declared.filter { name in erring.allSatisfy { $0.0 != name } }.sorted { $0.rawValue < $1.rawValue }
        var out = "## Errors from the body\n\n"
        out += "\(erring.count) instructions returned an error from their body in some trial. "
        out += "Kinds: \(top(kinds, 8)).\n\n"
        out += "- Error **instead of** results, always: \(alone.count). \(names(alone))\n"
        out += "- Error **alongside** results, in some trial: \(mixed.count). \(names(mixed))\n"
        out += "- Erred but not tagged `.fallible`: \(undeclared.count). \(names(undeclared))\n"
        out += "- Tagged `.fallible` but never erred here: \(silent.count). \(names(silent))\n\n"
        out += "Samples:\n\n"
        for (name, record) in erring.prefix(25) {
            out += "- `\(name.rawValue)`: \(record.errorSamples.sorted().joined(separator: " | "))\n"
        }
        return out + "\n"
    }

    private func gate() -> String {
        let refused = sorted.filter { !$0.1.refusals.isEmpty }
        var categories: [String: Int] = [:]
        for (_, record) in refused { for (key, count) in record.refusals { categories[key, default: 0] += count } }
        let landed = records.values.map(\.landed).reduce(0, +)
        let total = landed + categories.values.reduce(0, +)
        var out = "## The push gate\n\n"
        out += "\(total) Routers pushed; \(total - landed) refused, by: \(top(categories, 10)).\n\n"
        out += "Instructions with a refused result: \(refused.count). \(names(refused.map(\.0), 80))\n\n"
        return out
    }

    private func exec() -> String {
        var types: [String: Int] = [:]
        var producers: [PushInstruction] = []
        var passing = 0
        for (name, record) in sorted {
            let execs = record.resultSignatures.keys.flatMap { $0.split(separator: " ") }
                .filter { $0.hasPrefix(".exec:") || $0.hasPrefix(".code:") }
            if !execs.isEmpty { producers.append(name) }
            for entry in execs { types[String(entry), default: 0] += 1 }
            if !execs.isEmpty && record.passThrough > 0 { passing += 1 }
        }
        var out = "## Results on .exec and .code\n\n"
        out += "\(producers.count) instructions put something on `.exec` or `.code`; \(passing) of them, in some "
        out += "trial, put back an item that was one of their own arguments. Stack:type pairs seen (by "
        out += "instruction): \(top(types, 20)).\n"
        return out
    }
}
