//
//  CruxCompleteness.swift
//  PushInterpreterTests
//
//  How much of what a run leaves on its stacks can explain itself. Roadmap §P,
//  step 2 (2026-11-07): the baseline that provenance compression (step 3) is to
//  improve.
//

@testable import PushInterpreter

/// A tally of every item a run leaves on a result stack, by how complete its crux
/// is, and of whether that crux replays. Value stacks and `.error` are tallied
/// apart, because a random program's `.error` is mostly starved instructions,
/// whose "missing args" refusals are observed stand-ins by design.
///
/// **Completeness classes**, read off the crux's leaves:
/// - `derived`: no stand-ins that lose anything; every leaf is an instruction,
///   an input or constant token, a literal from the program, or a `.minted`
///   stand-in (a constant the instruction supplies itself).
/// - `observed`: contains `.observed` stand-ins (state reads, transient-state
///   errors, diagnostics) but no elided ones.
/// - `elided`: contains at least one `.elided` stand-in: part of the history was
///   over budget and dropped.
/// - `programLiteral`: an item with no history that appears literally in the
///   program text, or is a bound input or constant value itself.
/// - `boundContents`: an item with no history found *inside* a bound input or
///   constant value (a block bound to `.input3`, unwrapped). It reproduces, but
///   its crux has lost the link to the binding: a known loophole, not yet closed.
/// - `unmarked`: an item with no history found nowhere in the program or the
///   bindings. That is an unmarked substitution, the loophole stand-ins exist
///   to close, so this should stay at zero.
///
/// **Replay**, from `inspectCrux`: `holds`, `broken`, or `unchecked` when the
/// replay ran out of steps before finishing (a budget limit, not a verdict).
@MainActor
struct CruxCompleteness {
    enum Completeness: String, CaseIterable {
        case derived, observed, elided, programLiteral, boundContents, unmarked
    }

    enum Group: String, CaseIterable {
        case values = "value stacks"
        case errors = ".error"
    }

    private(set) var counts: [Group: [Completeness: Int]] = [:]
    private(set) var holds = 0
    private(set) var unchecked = 0
    private(set) var broken: [String] = []
    /// Which instructions the stand-ins name, and why, counted once per item.
    private(set) var standInSources: [Group: [String: Int]] = [:]
    /// A few unmarked and bound-contents items, to show what slipped through.
    private(set) var examples: [Completeness: [String]] = [:]

    func count(_ kind: Completeness, in group: Group? = nil) -> Int {
        let groups = group.map { [$0] } ?? Group.allCases
        return groups.reduce(0) { $0 + (counts[$1]?[kind] ?? 0) }
    }

    func items(in group: Group) -> Int { counts[group]?.values.reduce(0, +) ?? 0 }

    /// The stacks whose items are results. `.exec` holds the pending program, not
    /// results, so it is left out.
    static let resultStacks: [PushStack] = PushStack.allStacks.filter { $0 != .exec }

    /// Every item anywhere inside `items`, nested blocks included, by its printed
    /// form.
    static func printedLeaves(of items: [any Item]) -> Set<String> {
        var found: Set<String> = []
        var pending = items
        while let item = pending.popLast() {
            found.insert(item.pretty())
            if let block = item.exactly(CodeItem.self) { pending.append(contentsOf: block.value) }
        }
        return found
    }

    /// Classify and replay every item `interpreter` left on a result stack.
    mutating func record(
        _ interpreter: Interpreter,
        program: [any Item],
        inputs: [PushInstruction: any Item],
        constants: [PushInstruction: any Item],
        settings: InterpreterSettings
    ) {
        let programText = Self.printedLeaves(of: program)
        let boundValues = Array(inputs.values) + Array(constants.values)
        let bound = Set(boundValues.map { $0.pretty() })
        let insideBound = Self.printedLeaves(of: boundValues)
        for stack in Self.resultStacks {
            let group: Group = stack == .error ? .errors : .values
            for item in interpreter.stacks[stack]! {
                guard PushStack.defaultStack(for: item) != nil else { continue }
                if item.call.isEmpty {
                    let printed = item.pretty()
                    let kind: Completeness =
                        programText.contains(printed) || bound.contains(printed) ? .programLiteral
                        : insideBound.contains(printed) ? .boundContents
                        : .unmarked
                    counts[group, default: [:]][kind, default: 0] += 1
                    if kind != .programLiteral, examples[kind, default: []].count < 5 {
                        examples[kind, default: []].append(".\(stack) \(printed)")
                    }
                    continue
                }
                let standIns = item.crux().compactMap { $0.exactly(StandInItem.self) }
                let losing = standIns.filter { $0.reason != .minted }
                let kind: Completeness =
                    losing.contains { $0.reason == .elided } ? .elided
                    : losing.isEmpty ? .derived : .observed
                counts[group, default: [:]][kind, default: 0] += 1
                for source in Set(standIns.map { "\($0.source.map(\.rawValue) ?? "interpreter") \($0.reason)" }) {
                    standInSources[group, default: [:]][source, default: 0] += 1
                }

                switch inspectCrux(of: item, inputs: inputs, constants: constants,
                                   settings: settings, onHalt: .reportInconclusive) {
                case .holds:
                    holds += 1
                case .inconclusive:
                    unchecked += 1
                case .broken(_, let why):
                    broken.append(".\(stack) \(item.pretty()): \(why)")
                }
            }
        }
    }

    /// A short report: per group, the classes as shares of its items and the
    /// commonest stand-in sources; then the replay verdicts.
    func report(_ title: String) -> String {
        func percent(_ count: Int, of total: Int) -> String {
            let share = total == 0 ? 0 : 100.0 * Double(count) / Double(total)
            return "\(count) (\(share.formatted(.number.precision(.fractionLength(1))))%)"
        }
        var lines = ["crux completeness, \(title)"]
        for group in Group.allCases {
            let total = items(in: group)
            lines.append("  \(group.rawValue): \(total) items")
            let classes = Completeness.allCases.map { "\($0.rawValue) \(percent(count($0, in: group), of: total))" }
            lines.append("    " + classes.joined(separator: ", "))
            let top = (standInSources[group] ?? [:])
                .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(6)
            if !top.isEmpty {
                let sources = top.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
                lines.append("    stand-in sources (items): " + sources)
            }
        }
        lines.append("  replay: \(holds) hold, \(broken.count) broken, \(unchecked) unchecked (out of steps)")
        for kind in [Completeness.boundContents, .unmarked] where !(examples[kind] ?? []).isEmpty {
            lines.append("  \(kind.rawValue) examples: " + examples[kind]!.joined(separator: "; "))
        }
        return lines.joined(separator: "\n")
    }
}
