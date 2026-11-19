//
//  AbstractCrux.swift
//  Plunge
//
//  A distilled crux, its repeats rolled into loops, with its constants made
//  into typed holes (the abstract crux), or its constants and inputs both (the
//  skeleton crux): the crux's structure, open to other assignments and to
//  composition. Added 2026-11-15; the skeleton split out, and rolling added,
//  the same day.
//

/// **A crux's structure, with typed holes where its constants were.**
///
/// Built from a ``DistilledCrux``. The work that read only constants is already
/// one value (a derived constant). There are three levels:
///
/// - **The abstract crux** (``DistilledCrux/abstracted(_:literals:limit:)``):
///   every constant is a hole (each constant slot, derived constant and
///   literal), and **the inputs stay where they are**, as instructions. It is
///   still a model of the data it came from, with its constants free:
///   `.input0 .constant3 .intAdd` abstracts to `.input0 $0 .intAdd`. Constant slots
///   of one type are interchangeable: reading `.constant5` instead gives the same
///   abstract crux.
/// - **The tunable crux** (``DistilledCrux/tunable(_:sites:literals:limit:)``):
///   the abstract crux with a parametric transform on each input, whose
///   parameters are further holes. The inputs still stay in place, so it is the
///   form for search and curve fitting. See ``TunableCrux``.
/// - **The skeleton crux** (``DistilledCrux/skeleton(_:literals:limit:)``):
///   every input is a hole too, so nothing is left but typed holes and the
///   work between them: `.input0 .constant3 .intAdd` and `.input2 .constant0 .intAdd`
///   are both `$0 $1 .intAdd`. It is the form for building new structures
///   combinatorially and for telling shapes apart, not for fitting.
///
/// **Structure, not replay.** Beyond the distilled crux, these forms describe and
/// modify the crux's structure; they don't have to replay its value. So they are
/// built on its **rolled** form: a run of identical passes, written out once per
/// pass in the history, is rolled back into a counted loop,
/// `seed ( body ) count .execDoTimes .codePop`, keeping its count. A constant in
/// the body is then one hole shared by every pass, and the loop's seed and count
/// are holes of their own. `0 ( .input0 .intAdd 12 .intMin ) 50 .execDoTimes`
/// abstracts to `$0 ( .input0 .intAdd $1 .intMin ) $2 .execDoTimes .codePop`:
/// three holes, not one per pass. Repeats are rolled wherever they are, written
/// as a loop or not.
///
/// **Holes are marked in place.** ``template`` is the structure with a marker at
/// each hole, and a marker may sit inside a loop's body. ``program(filling:)``
/// puts fillers in place of the markers; ``key`` prints the structure with `$0`,
/// `$1`, …; ``function`` makes a ``FunctionItem`` the language can apply and
/// compose, building a loop body that has holes from quoted pieces.
///
/// **Two readings** (``Reading``): one hole per distinct constant slot (and, in a
/// skeleton, input) keeps "the same one, used twice"; one hole per use keeps only
/// the shape.
///
/// **Where holes go.** On the crux's data: leaves in argument positions, where
/// each pushes exactly one item, including those in a rolled loop's body.
/// Bookkeeping literals (the counts of clean-up pops) stay in the structure.
/// Observed stand-ins stay too: they are the run's state, frozen.
public nonisolated struct AbstractCrux: Sendable {
    /// What a hole stood for.
    public enum Role: Sendable {
        /// An input slot: in a skeleton crux only.
        case input(PushInstruction)
        /// A constant slot.
        case constant(PushInstruction)
        /// A value a distilled crux put in place of constant work.
        case derived(any Item)
        /// A literal from the program, or a rolled loop's count.
        case literal(any Item)
        /// A subtree of this type, cut out (``opening(_:)``).
        case open(PushStack)
        /// A parameter of a tunable crux, and the value that leaves the crux as it
        /// was (``TunableCrux``).
        case control(neutral: any Item)
        /// A hole for some input of this type, added by construction
        /// (``extended(by:with:leafFirst:)``): which input is for the filler to
        /// say.
        case anyInput(PushStack)
        /// A hole for some constant of this type, added by construction.
        case anyConstant(PushStack)
    }

    /// How many holes a constant slot (or, in a skeleton, an input) gets.
    public enum Reading: Sendable {
        /// One per distinct slot, at every place it is used.
        case perDistinct
        /// One per use.
        case perUse
    }

    /// The structure, with a marker at each hole: a `StandInItem` of reason
    /// `hole` whose value is the hole's number. Markers may sit inside code
    /// blocks (a rolled loop's body).
    public let template: [any Item]
    /// The stack each hole takes its filler from, by hole number.
    public let holeStacks: [PushStack]
    /// What each hole stood for, by hole number.
    public let roles: [Role]
    /// The stack the result rests on.
    public let output: PushStack
    /// The subtrees of the structure, each a contiguous span of ``template``, for
    /// ``opening(_:)``.
    public let subtrees: [Subtree]

    /// A subtree of the structure: the span `start..<end` of ``template`` nets one
    /// item on `stack`.
    public struct Subtree: Sendable, Hashable {
        public let start: Int, end: Int
        public let stack: PushStack
    }

    /// How many holes there are.
    public var holeCount: Int { roles.count }

    /// The structure's printed form, `«fn (int, int) -> int: .input0 $0 .intAdd $1 .intMultiply»`:
    /// the key under which cruxes that differ only in their constants (and, for
    /// skeletons, their inputs) are the same.
    public var key: String {
        let signature = holeStacks.map(\.tag).joined(separator: ", ")
        return "«fn (\(signature)) -> \(output.tag): \(Self.printed(template))»"
    }

    /// The fillers that put back what each hole stood for: the input and constant
    /// tokens, the derived values and literals, and the neutral settings of
    /// controls. `nil` if a hole is open.
    public var originalFillers: [any Item]? {
        var fillers: [any Item] = []
        for role in roles {
            switch role {
            case .input(let slot), .constant(let slot): fillers.append(InstructionItem(slot))
            case .derived(let value), .literal(let value), .control(neutral: let value): fillers.append(value)
            case .open, .anyInput, .anyConstant: return nil
            }
        }
        return fillers
    }

    /// The program with `fillers` in the holes, one per hole, including those in
    /// a loop's body.
    public func program(filling fillers: [any Item]) -> [any Item] {
        precondition(fillers.count == holeCount, "one filler per hole")
        return Self.filled(template, fillers)
    }

    /// The same structure with `subtree` cut out and a hole of its type in its
    /// place. The holes inside the subtree go with it, and the rest are
    /// renumbered in order of first appearance.
    public func opening(_ subtree: Subtree) -> AbstractCrux? {
        guard subtrees.contains(subtree) else { return nil }
        let width = subtree.end - subtree.start
        let opened = holeCount
        var template = Array(self.template[..<subtree.start]) + [Self.marker(opened)]
            + Array(self.template[subtree.end...])
        var stacks = holeStacks + [subtree.stack]
        var roles = self.roles + [.open(subtree.stack)]
        // Renumber the holes still used, in order of first appearance.
        var order: [Int] = []
        Self.visitMarkers(template) { if !order.contains($0) { order.append($0) } }
        let renumber = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        template = Self.mapMarkers(template) { Self.marker(renumber[$0]!) }
        stacks = order.map { stacks[$0] }
        roles = order.map { roles[$0] }
        let spans = subtrees.compactMap { span -> Subtree? in
            if span.end <= subtree.start { return span }
            if span.start >= subtree.end {
                return Subtree(start: span.start - width + 1, end: span.end - width + 1, stack: span.stack)
            }
            if span.start <= subtree.start && span.end >= subtree.end && span != subtree {
                return Subtree(start: span.start, end: span.end - width + 1, stack: span.stack)
            }
            return nil
        }
        return AbstractCrux(template: template, holeStacks: stacks, roles: roles, output: output, subtrees: spans)
    }
}

// MARK: - Markers

nonisolated extension AbstractCrux {
    /// The marker for hole `number`.
    static func marker(_ number: Int) -> any Item {
        StandInItem(standingInFor: IntItem(number), source: nil, reason: .hole)
    }

    /// The hole number `item` marks, if it is a marker.
    static func holeNumber(_ item: any Item) -> Int? {
        guard let standIn = item.exactly(StandInItem.self), standIn.reason == .hole else { return nil }
        return standIn.value.exactly(IntItem.self)?.value
    }

    /// Calls `visit` with each marker's number, in order, through code blocks.
    static func visitMarkers(_ items: [any Item], _ visit: (Int) -> Void) {
        for item in items {
            if let number = holeNumber(item) {
                visit(number)
            } else if let block = item.exactly(CodeItem.self) {
                visitMarkers(block.value, visit)
            }
        }
    }

    /// `items` with each marker replaced by `replace(number)`, through code blocks.
    static func mapMarkers(_ items: [any Item], _ replace: (Int) -> any Item) -> [any Item] {
        items.map { item in
            if let number = holeNumber(item) { return replace(number) }
            if let block = item.exactly(CodeItem.self), block.value.contains(where: { containsMarker($0) }) {
                return CodeItem(mapMarkers(block.value, replace))
            }
            return item
        }
    }

    static func containsMarker(_ item: any Item) -> Bool {
        if holeNumber(item) != nil { return true }
        guard let block = item.exactly(CodeItem.self) else { return false }
        return block.value.contains(where: containsMarker)
    }

    static func filled(_ items: [any Item], _ fillers: [any Item]) -> [any Item] {
        mapMarkers(items) { fillers[$0] }
    }

    /// `items` printed as a program's body, `$n` for each marker.
    static func printed(_ items: [any Item]) -> String {
        items.map { item -> String in
            if let number = holeNumber(item) { return "$\(number)" }
            if let block = item.exactly(CodeItem.self), block.value.contains(where: { containsMarker($0) }) {
                return "( \(printed(block.value)) )"
            }
            return item.pretty()
        }.joined(separator: " ")
    }
}

// MARK: - As a function the language can use

nonisolated extension AbstractCrux {
    /// The structure as a ``FunctionItem``, so it can sit on `.function` and work
    /// with `.functionApply`, `.functionCompose` and the maps. A code block that
    /// has holes in it (a rolled loop's body) is built from quoted pieces:
    /// `( .input0 .intAdd ) $1 .intQuote .codeConcat ( .intMin ) .codeConcat`.
    /// `nil` when that isn't possible: a hole two code blocks deep, a hole whose
    /// type has no quoting instruction, or holes the language would fill in
    /// another order.
    public var function: FunctionItem? {
        var body: [any Item] = []
        var positions = [[Int]](repeating: [], count: holeCount)
        var lastAt: [Int: Int] = [:]
        var parts: [QuotePart] = []
        for item in template {
            if let number = Self.holeNumber(item) {
                parts.append(.hole(number))
            } else if let block = item.exactly(CodeItem.self),
                      block.value.contains(where: { Self.containsMarker($0) }) {
                guard let quoted = Self.quoted(block.value, holeStacks: holeStacks) else { return nil }
                parts += quoted
            } else {
                parts.append(.item(item))
            }
        }
        for part in parts {
            switch part {
            case .item(let item):
                body.append(item)
            case .hole(let number):
                // Holes at one position are filled in hole order.
                let position = body.count
                guard number >= (lastAt[position] ?? -1) else { return nil }
                lastAt[position] = number
                positions[number].append(position)
            }
        }
        let holes = zip(holeStacks, positions).map { FunctionItem.Hole(stack: $0, positions: $1) }
        return FunctionItem(body: body, holes: holes, output: output)
    }

    /// A piece of a function's body: an item, or a hole.
    private enum QuotePart { case item(any Item), hole(Int) }

    /// Code that leaves `( contents )` on `.code`, with each marker's filler
    /// quoted in: runs of plain items as literal code blocks, each hole as its
    /// filler and the quoting instruction of its type, joined by `.codeConcat`.
    private static func quoted(_ contents: [any Item], holeStacks: [PushStack]) -> [QuotePart]? {
        var parts: [QuotePart] = []
        var pieces = 0
        var run: [any Item] = []
        func joined() {
            pieces += 1
            if pieces > 1 { parts.append(.item(InstructionItem(.codeConcat))) }
        }
        func flush() {
            guard !run.isEmpty else { return }
            parts.append(.item(CodeItem(run)))
            run = []
            joined()
        }
        for item in contents {
            if let number = holeNumber(item) {
                flush()
                guard let quoting = PushInstruction(rawValue: "\(holeStacks[number].rawValue)Quote"),
                      Interpreter.language[quoting] != nil else { return nil }
                parts += [.hole(number), .item(InstructionItem(quoting))]
                joined()
            } else if containsMarker(item) {
                return nil
            } else {
                run.append(item)
            }
        }
        flush()
        if pieces == 0 { parts.append(.item(CodeItem([]))) }
        return parts
    }
}
