//
//  IndexRolling.swift
//  Plunge
//
//  Rolling a crux's repeated passes into a counted loop when they differ by an
//  index (#65's first gap; 2026-11-20, for PlungeGP's reconciled cruxes).
//

/// **Passes that differ by an index, rolled into a counted loop.** A loop over
/// a vector's elements, or a conditional inside a counted loop joined across
/// cases, leaves a crux with one segment for each pass, the segments the same
/// but for an index: a literal (`1 .vecStringNth`, then `2 .vecStringNth`) or
/// the loop's own counter (`«minted .execDoCount: 0» 2 .intAdd`). Folding
/// (`CruxCompression.compressed`) rolls only passes that are identical.
///
/// ``rolledByIndex(_:)`` finds runs of segments that are the same apart from
/// their ints, where each int that changes from pass to pass changes by the
/// same step, 1 or −1, and writes the run as one pass in a counted loop:
///
/// - With no int changing: `( body ) K .execDoTimes .codePop`.
/// - Counting up: `K ( body ) .execDoCount .codePop`, the ints offset from the
///   index, which counts from 0 (a count of 0 makes no pass, where a range
///   whose bounds meet makes one).
/// - Counting down: `a b ( body ) .execDoRange .codePop`, from `a` toward `b`.
///
/// The loop pushes its index onto `.int` before each pass. When the pass read
/// the index once, first, the body is the pass without it, so the loop's push
/// stands in for it. Otherwise the body binds the index to ``loopKey`` and looks
/// it up wherever the pass read it (adding the offset, for an int that ran a
/// fixed distance from the index), and pops the binding at the end.
///
/// The rewrite keeps every value: each int it replaces is computed as the same
/// number. A pass that works with iterators (or makes one, as `.codePeekNth`
/// does) is not rolled, since the loop's own iterator is on `.iterator` while it
/// runs. A crux whose own work looks up
/// ``loopKey`` would see the binding; replay the rolled crux to be sure. A run is
/// rolled only when that makes the crux shorter, and runs are looked for inside
/// code blocks and loop bodies too.
nonisolated extension CruxCompression {

    /// The key a rolled body binds its index to.
    public static let loopKey = -9_973

    /// The longest crux ``rolledByIndex(_:)`` looks at; a longer one is returned
    /// as it is.
    public static let rollingLimit = 2_000

    /// `crux` with each run of passes that differ only by an index rolled into a
    /// counted loop. See the discussion above.
    public static func rolledByIndex(_ crux: [any Item]) -> [any Item] {
        guard crux.count <= rollingLimit else { return crux }
        return IndexRoller.render(IndexRoller.roll(IndexRoller.units(crux)))
    }
}

/// The search and rewrite behind ``CruxCompression/rolledByIndex(_:)``.
private nonisolated enum IndexRoller {

    /// A crux element as rolling sees it: an int (a literal, or a loop's minted
    /// counter plus a literal) whose value may change from pass to pass, a code
    /// block, or anything else.
    indirect enum Unit {
        case number(Int, original: [any Item])
        case block([Unit])
        case token(any Item)

        /// What must match from pass to pass: everything but an int's value.
        var signature: String {
            switch self {
            case .number: "#"
            case .block(let inner): "(" + inner.map(\.signature).joined(separator: " ") + ")"
            case .token(let item): "\(type(of: item)) \(item.prettyProgram())"
            }
        }

        /// The ints in it, in order, at any depth.
        var numbers: [Int] {
            switch self {
            case .number(let value, _): [value]
            case .block(let inner): inner.flatMap(\.numbers)
            case .token: []
            }
        }

        var tokens: Int {
            switch self {
            case .number(_, let original): original.count
            case .block(let inner): inner.reduce(0) { $0 + $1.tokens }
            case .token: 1
            }
        }
    }

    static func units(_ crux: [any Item]) -> [Unit] {
        var units: [Unit] = []
        var index = 0
        while index < crux.count {
            let item = crux[index]
            if let block = item.exactly(CodeItem.self) {
                units.append(.block(Self.units(block.value)))
            } else if let number = item.exactly(IntItem.self) {
                units.append(.number(number.value, original: [item]))
            } else if let standIn = item.exactly(StandInItem.self), standIn.reason == .minted,
                      let start = standIn.value.exactly(IntItem.self)?.value {
                // A loop's counter: its minted start, and the literal added to it.
                if index + 2 < crux.count, let step = crux[index + 1].exactly(IntItem.self)?.value,
                   crux[index + 2].exactly(InstructionItem.self)?.value == .intAdd {
                    units.append(.number(start &+ step, original: Array(crux[index...(index + 2)])))
                    index += 3
                    continue
                }
                units.append(.number(start, original: [item]))
            } else {
                units.append(.token(item))
            }
            index += 1
        }
        return units
    }

    static func render(_ units: [Unit]) -> [any Item] {
        units.flatMap { unit -> [any Item] in
            switch unit {
            case .number(_, let original): original
            case .block(let inner): [CodeItem(render(inner))]
            case .token(let item): [item]
            }
        }
    }

    /// A run of passes: `count` segments of `period` units from `start`, its
    /// ints changing by `step` (0 when none changes).
    struct Run {
        let start: Int
        let period: Int
        let count: Int
        let step: Int
        let saved: Int
        let rolled: [Unit]
    }

    /// `units` with the run that saves most rolled, and the same done to what is
    /// before and after it, and inside every code block.
    static func roll(_ units: [Unit]) -> [Unit] {
        guard let best = bestRun(units) else {
            return units.map { unit in
                if case .block(let inner) = unit { return .block(roll(inner)) }
                return unit
            }
        }
        let before = Array(units[..<best.start])
        let after = Array(units[(best.start + best.period * best.count)...])
        return roll(before) + best.rolled + roll(after)
    }

    /// The longest pass looked for, in units.
    static let maximumPeriod = 400

    static func bestRun(_ units: [Unit]) -> Run? {
        let count = units.count
        guard count >= 2 else { return nil }
        let signatures = units.map(\.signature)
        let numbers = units.map(\.numbers)
        let tokens = units.map(\.tokens)
        var best: Run?
        var matchedBy: [Int: [Int]] = [:]
        for period in 1...min(count / 2, maximumPeriod) {
            // matched[i]: how many units from i on equal the ones a period later.
            var matched = Array(repeating: 0, count: count + 1)
            for index in stride(from: count - period - 1, through: 0, by: -1) {
                matched[index] = signatures[index] == signatures[index + period] ? matched[index + 1] + 1 : 0
            }
            matchedBy[period] = matched
            let divisors = (1..<period).filter { period % $0 == 0 }
            for start in 0...(count - 2 * period) where matched[start] >= period {
                // Not the middle of a longer run with the same period.
                if start >= period, matched[start - period] >= period { continue }
                // Not a pass that repeats a shorter one: rolled by the shorter
                // period it saves more, and trying every multiple of it made the
                // search cubic in a repetitive crux.
                if divisors.contains(where: { (matchedBy[$0]?[start] ?? 0) >= period - $0 }) { continue }
                let passes = matched[start] / period + 1
                guard let run = progression(start: start, period: period, passes: passes, numbers: numbers)
                else { continue }
                // As written: passes may write the same int differently (a loop's
                // first counter is its minted start alone).
                let written = tokens[start..<(start + period * run.passes)].reduce(0, +)
                let body = Array(units[start..<(start + period)])
                // Measured without rolling inside the body, which only the
                // chosen run needs.
                guard let rolled = rolledRun(body, run, nested: false) else { continue }
                let saved = written - rolled.reduce(0) { $0 + $1.tokens }
                if saved > (best?.saved ?? 0) {
                    best = Run(start: start, period: period, count: run.passes, step: run.step, saved: saved,
                               rolled: rolledRun(body, run, nested: true) ?? rolled)
                }
            }
        }
        return best
    }

    /// How a run's ints change: the pass count (at least 2), the step, the first
    /// pass's ints and which of them change.
    struct Progression {
        let passes: Int
        let step: Int
        let first: [Int]
        let varying: [Bool]
    }

    /// How many of `passes` segments from `start` have ints that change, if at
    /// all, by one step.
    static func progression(start: Int, period: Int, passes: Int, numbers: [[Int]]) -> Progression? {
        func pass(_ index: Int) -> [Int] {
            numbers[(start + index * period)..<(start + (index + 1) * period)].flatMap { $0 }
        }
        let first = pass(0)
        let second = pass(1)
        let steps = zip(second, first).map { $0 &- $1 }
        let varying = steps.map { $0 != 0 }
        let step = steps.first { $0 != 0 } ?? 0
        guard [0, 1, -1].contains(step), steps.allSatisfy({ $0 == 0 || $0 == step }) else { return nil }
        var count = 2
        while count < passes, zip(pass(count), first).enumerated()
                .allSatisfy({ $0.element.0 == $0.element.1 &+ (varying[$0.offset] ? step &* count : 0) }) {
            count += 1
        }
        return Progression(passes: count, step: step, first: first, varying: varying)
    }

    /// One pass, rolled: the body built from the first pass, in its loop; nil
    /// when the pass leaves a code block that looks up the index to run in a
    /// later pass, after the index has moved on.
    static func rolledRun(_ pass: [Unit], _ run: Progression, nested: Bool) -> [Unit]? {
        // A rolled loop keeps its own iterator on `.iterator` through its passes,
        // where a pass that works with iterators would find it.
        guard !touchesIterators(pass) else { return nil }
        let (passes, step, first, varying) = (run.passes, run.step, run.first, run.varying)
        func roll(_ units: [Unit]) -> [Unit] { nested ? Self.roll(units) : units }
        let body: [Unit]
        let base = zip(first, varying).first { $0.1 }?.0 ?? 0
        if step == 0 {
            body = roll(pass)
            return [.block(body), .number(passes, original: [IntItem(passes)]),
                    .token(InstructionItem(.execDoTimes)), .token(InstructionItem(.codePop))]
        }
        // Counting up always counts from 0, the ints offset from the index: a
        // range whose bounds meet still makes one pass, where a count of 0 makes
        // none, so a count read from the data stays right however small.
        let counting = step == 1
        let origin = counting ? 0 : base
        let readFirst: Bool
        if case .number = pass[0] { readFirst = varying[0] && varying.count { $0 } == 1 } else { readFirst = false }
        if readFirst {
            // Read once, first: the loop's own push is the read, moved to where
            // the pass's int began.
            let shift: [Unit] = base == origin ? []
                : [.number(base - origin, original: [IntItem(base - origin)]), .token(InstructionItem(.intAdd))]
            body = shift + roll(Array(pass.dropFirst()))
        } else {
            guard runsWithin(pass, varying: varying) else { return nil }
            var position = 0
            let fetched = fetching(pass, first: first, varying: varying, base: origin, position: &position)
            body = [.number(CruxCompression.loopKey, original: [IntItem(CruxCompression.loopKey)]),
                    .token(InstructionItem(.intRefAs))] + roll(fetched)
                + [.number(CruxCompression.loopKey, original: [IntItem(CruxCompression.loopKey)]),
                   .token(InstructionItem(.bindingPopKey)), .token(InstructionItem(.intPop))]
        }
        let bounds = counting ? [passes] : [base, base &+ step &* passes]
        let loop: [Unit] = bounds.map { Unit.number($0, original: [IntItem($0)]) }
        return loop + [.block(body)]
            + [.token(InstructionItem(counting ? .execDoCount : .execDoRange)),
               .token(InstructionItem(.codePop))]
    }

    /// Whether any of `units`, at any depth, is an instruction that may put an
    /// item on `.iterator`, take one from it, or move items within it.
    static func touchesIterators(_ units: [Unit]) -> Bool {
        units.contains { unit in
            switch unit {
            case .token(let item): (item as? InstructionItem).map { iteratorTouching.contains($0.value) } ?? false
            case .block(let inner): touchesIterators(inner)
            case .number: false
            }
        }
    }

    /// The instructions that may put an item on `.iterator`, take or read one
    /// there, or move items within it: from their behaviors' results and
    /// requirements. (`.codePeekNth` makes an iterator, for one.)
    static let iteratorTouching: Set<PushInstruction> = Set(Interpreter.language.compactMap { entry in
        let behavior = entry.value
        let makes = behavior.produces.valueStacks.contains(.iterator) || behavior.produces == .positions(.iterator)
        let uses = behavior.requirements.contains { String(describing: $0).contains("iterator") }
        return makes || uses || entry.key.rawValue.hasPrefix("iterator") ? entry.key : nil
    })

    /// Whether every code block in `pass` holding an int that changes is followed,
    /// in the pass, by an instruction that could run it: a block left for the
    /// next pass would look up the next pass's index.
    static func runsWithin(_ pass: [Unit], varying: [Bool]) -> Bool {
        var position = 0
        var pending = false
        for unit in pass {
            let numbers = unit.numbers.count
            defer { position += numbers }
            switch unit {
            case .block:
                if varying[position..<(position + numbers)].contains(true) { pending = true }
            case .token(let item) where item is InstructionItem:
                pending = false
            default:
                break
            }
        }
        return !pending
    }

    /// `units` with each int that changes from pass to pass replaced by a lookup
    /// of the index, plus its offset from it.
    static func fetching(_ units: [Unit], first: [Int], varying: [Bool], base: Int,
                         position: inout Int) -> [Unit] {
        units.flatMap { unit -> [Unit] in
            switch unit {
            case .number:
                defer { position += 1 }
                guard varying[position] else { return [unit] }
                var lookup: [any Item] = [IntItem(CruxCompression.loopKey), InstructionItem(.bindingDeref),
                                          InstructionItem(.intSwap), InstructionItem(.intPop)]
                let offset = first[position] &- base
                if offset != 0 { lookup += [IntItem(offset), InstructionItem(.intAdd)] }
                return lookup.map { .token($0) }
            case .block(let inner):
                return [.block(fetching(inner, first: first, varying: varying, base: base, position: &position))]
            case .token:
                return [unit]
            }
        }
    }
}
