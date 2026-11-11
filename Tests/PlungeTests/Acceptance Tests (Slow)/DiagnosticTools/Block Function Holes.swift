//
//  Block Function Holes.swift
//  PlungeTests
//
//  The holes a test-side `functionFromCode` makes: whenever an instruction is
//  about to run without enough arguments, a fresh placeholder is slipped under
//  what is there for each one missing, so it runs. A placeholder is an ordinary
//  value whose history is one minted stand-in naming a marker token, so it
//  shows up in every crux that uses it, wherever that crux goes. This is what a
//  "robust sandbox" mode in the interpreter would do from the inside.
//

@testable import Plunge

extension FunctionOutcome {

    /// The stacks that can hold holes and functions' results: everything but
    /// the program and the errors.
    static let holeStacks: [PushStack] = PushStack.allCases.filter { $0 != .exec && $0 != .error }

    /// One hole: the marker naming it, its stack, and the placeholder it holds
    /// in each of three rounds (the first is the one the block ran with).
    struct Hole {
        let marker: PushInstruction
        let stack: PushStack
        let values: [any Item]
    }

    /// The holes one conversion has made, in the order it made them.
    @MainActor struct HoleRegistry {
        private(set) var holes: [PushInstruction: Hole] = [:]
        private var markers: [PushInstruction]
        private var counts: [PushStack: Int] = [:]
        let constants: [PushInstruction: any Item]

        /// Markers are instruction tokens the block never names, so a minted
        /// stand-in naming one cannot have come from the block itself.
        init(avoiding used: Set<PushInstruction>, constants: [PushInstruction: any Item]) {
            markers = PushInstruction.allCases.filter { !used.contains($0) }.sorted { $0.rawValue > $1.rawValue }
            self.constants = constants
        }

        /// A fresh hole on `stack`, as the item to put there.
        mutating func make(_ stack: PushStack) -> (any Item)? {
            guard let marker = markers.popLast() else { return nil }
            let ordinal = counts[stack, default: 0]
            counts[stack] = ordinal + 1
            let values = (0..<3).map { FunctionOutcome.placeholder(stack, ordinal, round: $0, constants: constants) }
            holes[marker] = Hole(marker: marker, stack: stack, values: values)
            var item = values[0]
            item.call = [StandInItem(standingInFor: values[0], source: marker, reason: .minted)]
            return item
        }

        /// The hole `leaf` is, if it is one.
        func hole(_ leaf: any Item) -> Hole? {
            guard let standIn = leaf as? StandInItem, standIn.reason == .minted, let source = standIn.source else {
                return nil
            }
            return holes[source]
        }

        var made: Int { holes.count }
    }

    /// The placeholder for the `ordinal`th hole of `stack`'s type in `round`:
    /// one of the run's own constants of that type where it has them (a
    /// different slot each round), else a fixed stand-in value.
    static func placeholder(_ stack: PushStack, _ ordinal: Int, round: Int,
                            constants: [PushInstruction: any Item]) -> any Item {
        if let slot = PushInstruction(rawValue: "\(stack)\((ordinal + 3 * round) % 10)"),
           var value = constants[slot] {
            value.call = []
            return value
        }
        let fixed = placeholders(stack, round: round)
        return fixed.isEmpty ? IntItem(0) : fixed[ordinal % fixed.count]
    }

    /// Fixed placeholders, for runs without constants and the types that have
    /// none, chosen so comparisons between them come out differently in some
    /// round.
    static func placeholders(_ stack: PushStack, round: Int) -> [any Item] {
        let sets: [[any Item]]
        switch stack {
        case .int: sets = [[3, 5, 2, 7], [8, 4, 6, 1], [-2, 0, 9, -5]].map { $0.map { IntItem($0) } }
        case .double:
            sets = [[1.5, 2.25, 0.75, 3.5], [2.5, 1.25, 4.75, 0.5], [-1.5, 0, 9.5, -0.25]]
                .map { $0.map { DoubleItem($0) } }
        case .bool: sets = [[true, false, true, false], [false, true, false, true], [true, true, false, false]]
                .map { $0.map { BoolItem($0) } }
        case .char: sets = ["aexm", "bfyn", "zaqb"].map { $0.map { CharItem($0) } }
        case .string: sets = [["abc", "hello", "xy", "qrst"], ["dog", "w", "ab cd", "zzz"], ["", "a b c", "hello", "x"]]
                .map { $0.map { StringItem($0) } }
        case .vecInt: sets = [[[1, 2, 3], [4, 5]], [[2, 4], [1, 1, 1]], [[], [5, -1, 0]]]
                .map { $0.map { VecIntItem($0) } }
        case .vecDouble: sets = [[[1.5, 2.5], [0.25]], [[2], [1.5, 1.5]], [[], [-1, 0.5]]]
                .map { $0.map { VecDoubleItem($0) } }
        case .vecBool: sets = [[[true, false], [false]], [[false], [true, true]], [[], [true]]]
                .map { $0.map { VecBoolItem($0) } }
        case .vecString: sets = [[["a", "bc"], ["d"]], [["k"], ["lm", "n"]], [[], ["t u"]]]
                .map { $0.map { VecStringItem($0) } }
        default: return structuredPlaceholders(stack, round: round)
        }
        return sets[round]
    }

    /// Placeholders for blocks, iterators and bindings.
    static func structuredPlaceholders(_ stack: PushStack, round: Int) -> [any Item] {
        switch stack {
        case .code: return [[CodeItem([IntItem(1)])], [CodeItem([StringItem("q"), IntItem(2)])], [CodeItem([])]][round]
        case .iterator: return [iteratorPlaceholders[round]]
        case .binding: return [BindingItem(key: 3 + round, bound: IntItem([3, 8, -2][round]))]
        default: return []
        }
    }

    /// An unplayed bare iterator over a short string's chars (`s ( ) 0 0 true
    /// .iteratorFromString`), one per round.
    static let iteratorPlaceholders: [any Item] = ["abc", "xy", "hello"].map { text in
        let sub = Interpreter()
        sub.load(program: [StringItem(text), CodeItem([]), IntItem(0), IntItem(0), BoolItem(true),
                           InstructionItem(.iteratorFromString)])
        sub.run()
        guard var made = sub.stacks[.iterator]?.first else {
            preconditionFailure("no iterator placeholder for \"\(text)\": \(sub.stacks[.error]!.map { $0.pretty() })")
        }
        made.call = []
        return made
    }

    /// Before `token` runs: for each stack it takes, reads or (as a structural
    /// rule) needs a fixed number of items from, a fresh hole for every one missing, slipped under what
    /// is there so the arguments present keep their places. Returns how many.
    static func supplyHoles(for token: PushInstruction, in sub: Interpreter,
                            registry: inout HoleRegistry) -> Int {
        guard let signature = runner.signature(of: token) else { return 0 }
        var wanted = signature.consumes
        for (stack, count) in signature.reads { wanted[stack, default: 0] += count }
        for (stack, count) in signature.needs { wanted[stack] = max(wanted[stack] ?? 0, count) }
        var made = 0
        for (stack, count) in wanted.sorted(by: { $0.key.rawValue < $1.key.rawValue })
        where holeStacks.contains(stack) {
            let present = Array(sub.stacks[stack]!)
            guard present.count < count else { continue }
            let holes = (present.count..<count).compactMap { _ in registry.make(stack) }
            sub.clear(stack)
            for item in holes.reversed() + present.reversed() { sub.push(item, to: stack) }
            made += holes.count
        }
        return made
    }

    /// Whether `item` is an instruction that only moves, copies or deletes
    /// items: what it leaves on top is not newly made.
    static func rearranges(_ item: any Item) -> Bool {
        guard let token = (item as? InstructionItem)?.value,
              let signature = runner.signature(of: token) else { return false }
        if case .positions = signature.produces { return true }
        return false
    }

    /// A cheap stand-in for an item's identity: its value and the length of
    /// its history.
    static func fingerprint(_ item: any Item) -> String { render(item) + "#\(item.call.count)" }

    /// The items in `items` (top first) that were not in `before`, bottom up:
    /// the order a step pushed them.
    static func fresh(_ before: [String], _ items: [any Item]) -> [any Item] {
        var remaining: [String: Int] = [:]
        for print in before { remaining[print, default: 0] += 1 }
        var result: [any Item] = []
        for item in items.reversed() {
            let print = fingerprint(item)
            if let left = remaining[print], left > 0 { remaining[print] = left - 1 } else { result.append(item) }
        }
        return result
    }

    /// Every instruction token in `items`, at any depth.
    static func tokens(in items: [any Item]) -> Set<PushInstruction> {
        var found: Set<PushInstruction> = []
        var pending = items
        while let item = pending.popLast() {
            if let token = (item as? InstructionItem)?.value {
                found.insert(token)
            } else if let inner = item as? CodeItem {
                pending += inner.value
            }
        }
        return found
    }
}
