//
//  CruxCompleteness.swift
//  PushInterpreterTests
//
//  How much of what a run leaves on its stacks can explain itself. Roadmap §P,
//  step 2 (2026-11-07): the baseline the later steps are measured against.
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
///   its crux has lost the link to the binding. Closed by the containment law
///   (`Containment`, §P step 4): such an item now records its address, so this
///   should stay at zero.
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
    /// Value-stack items whose crux takes something out of a container by its
    /// address (`v k .vecIntNth`, `s .stringFirst`, `b k .codeEmitNthRoot`): an
    /// element that was born in its container rather than put there (`Containment`).
    private(set) var addressed = 0
    /// Value-stack items whose crux reuses a shared node (`.xDup`, `.xYankDup`,
    /// `.xYank`: `CruxSharing`) or runs a folded loop (`CruxCompression.folded`).
    private(set) var compressed = (shared: 0, folded: 0)
    /// The total crux length of the value-stack items with a history, for a mean.
    private(set) var cruxLeaves = 0
    /// Vectors and strings left with members, the elements they cover, and the
    /// runs those take (`Pieces`): how well the piece table groups by source.
    private(set) var pieceTables = (containers: 0, elements: 0, runs: 0, items: 0)

    static func isAddress(_ leaf: any Item) -> Bool {
        leaf.exactly(InstructionItem.self).map { addressInstructions.contains($0.value) } ?? false
    }

    /// The instructions that take an element out of a container by position.
    static let addressInstructions: Set<PushInstruction> = {
        var names: Set<PushInstruction> = [.stringNth, .stringFirst, .stringLast, .stringNthWord,
                                           .codeEmitNthRoot, .codeEmitNthPoint]
        for prefix in ["vecBool", "vecDouble", "vecInt", "vecString"] {
            for suffix in ["Nth", "First", "Last"] {
                if let name = PushInstruction(rawValue: prefix + suffix) { names.insert(name) }
            }
        }
        return names
    }()

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
                let crux = item.crux()
                if group == .values { measure(crux); measure(item) }
                let standIns = crux.compactMap { $0.exactly(StandInItem.self) }
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

    /// Counts a value-stack item's crux toward the mean length and the addressed.
    private mutating func measure(_ item: any Item) {
        guard let pieces = (item as? any HoldsMembers)?.members else { return }
        pieceTables.containers += 1
        pieceTables.elements += pieces.count
        pieceTables.runs += pieces.runs.count
        pieceTables.items += pieces.runs.count { if case .item = $0 { true } else { false } }
    }

    private mutating func measure(_ crux: [any Item]) {
        cruxLeaves += crux.count
        if crux.contains(where: Self.isAddress) { addressed += 1 }
        if crux.contains(where: Self.isSharing) { compressed.shared += 1 }
        if crux.indices.contains(where: { Self.isFold(crux, at: $0) }) { compressed.folded += 1 }
    }

    /// The instructions only a shared crux writes: a program's own dups and yanks
    /// record nothing (provenance law 1), so a crux holds them only by sharing.
    static let sharingInstructions: Set<PushInstruction> = Set(PushStack.allCases.flatMap { stack in
        stack.sharingInstructions.map { [$0.dup, $0.yank, $0.yankDup] } ?? []
    })

    static func isSharing(_ leaf: any Item) -> Bool {
        leaf.exactly(InstructionItem.self).map { sharingInstructions.contains($0.value) } ?? false
    }

    /// Whether a folded loop, `( body ) K .execDoTimes .codePop`, ends at `index`.
    static func isFold(_ crux: [any Item], at index: Int) -> Bool {
        index >= 3
            && crux[index].exactly(InstructionItem.self)?.value == .codePop
            && crux[index - 1].exactly(InstructionItem.self)?.value == .execDoTimes
            && crux[index - 2].exactly(IntItem.self) != nil
            && crux[index - 3].exactly(CodeItem.self) != nil
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
            if group == .values {
                let derivedItems = max(1, total - count(.programLiteral, in: group))
                let mean = (Double(cruxLeaves) / Double(derivedItems)).formatted(.number.precision(.fractionLength(1)))
                lines.append("    taken out by address: \(percent(addressed, of: total)); mean crux length \(mean)")
                lines.append("    compressed: \(percent(compressed.shared, of: total)) reuse a shared node, "
                             + "\(percent(compressed.folded, of: total)) run a folded loop")
                let tables = pieceTables
                lines.append("    members: \(tables.containers) vectors and strings, "
                             + "\(tables.elements) elements in \(tables.runs) runs "
                             + "(\(tables.items) of them single items that went in)")
            }
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
