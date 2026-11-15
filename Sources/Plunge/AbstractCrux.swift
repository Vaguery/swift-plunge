//
//  AbstractCrux.swift
//  Plunge
//
//  A distilled crux with its inputs, constants and literals made into typed
//  holes: a function, open for composition and for other assignments.
//  Added 2026-11-15.
//

/// **A crux with typed holes where its inputs and constants were.** It is a
/// ``FunctionItem``, so it can sit on `.function` and work with `.functionApply`,
/// `.functionCompose` and the maps unchanged, and a role for each hole says what
/// was there.
///
/// Built from a ``DistilledCrux``: the work that read only constants is already
/// one value (a derived constant), so the holes are the crux's real points of
/// contact with its data. Inputs and constant slots of one type are
/// interchangeable in the shape: `.input0 .input1 .intAdd` and
/// `.input2 .input0 .intAdd` abstract to the same function, `$0 $1 .intAdd`.
///
/// **Two readings** (``Reading``): one hole per distinct input or constant keeps
/// "the same input, used twice"; one hole per use keeps only the shape.
///
/// **Where holes go.** Only on the crux's data: leaves in argument positions,
/// where each pushes exactly one item. Bookkeeping literals (the counts of
/// clean-up pops, the copies a shared node makes) stay in the body, and so does
/// the inside of a code block, such as a folded loop's body. Observed stand-ins
/// stay too: they are the run's state, frozen.
public nonisolated struct AbstractCrux: Sendable {
    /// What a hole stood for.
    public enum Role: Sendable {
        /// An input slot.
        case input(PushInstruction)
        /// A constant slot.
        case constant(PushInstruction)
        /// A value a distilled crux put in place of constant work.
        case derived(any Item)
        /// A literal from the program.
        case literal(any Item)
        /// A subtree of this type, cut out (``opening(_:)``).
        case open(PushStack)
        /// A parameter of a tunable crux, and the value that leaves the crux as it
        /// was (``TunableCrux``).
        case control(neutral: any Item)
    }

    /// How many holes an input or constant gets.
    public enum Reading: Sendable {
        /// One per distinct input or constant slot, at every place it is used.
        case perDistinct
        /// One per use.
        case perUse
    }

    /// The crux as a function: its body, and a hole for each input, constant and
    /// value.
    public let function: FunctionItem
    /// What each hole stood for, in the order of `function.holes`.
    public let roles: [Role]
    /// The subtrees of the body, each a contiguous span, for ``opening(_:)``.
    public let subtrees: [Subtree]

    /// A subtree of the body: the span `start..<end` nets one item on `stack`.
    public struct Subtree: Sendable, Hashable {
        public let start: Int, end: Int
        public let stack: PushStack
    }

    /// The key under which abstract cruxes that differ only in which inputs and
    /// constants they read are the same: the function's printed form.
    public var key: String { function.pretty() }

    /// The fillers that put back what each hole stood for: the input and constant
    /// tokens, the derived values and literals, and the neutral settings of
    /// controls. `nil` if a hole is open.
    public var originalFillers: [any Item]? {
        var fillers: [any Item] = []
        for role in roles {
            switch role {
            case .input(let slot), .constant(let slot): fillers.append(InstructionItem(slot))
            case .derived(let value), .literal(let value), .control(neutral: let value): fillers.append(value)
            case .open: return nil
            }
        }
        return fillers
    }

    /// The program with `fillers` in the holes, one per hole.
    public func program(filling fillers: [any Item]) -> [any Item] {
        function.filled(with: fillers)
    }

    /// The same crux with `subtree` cut out and a hole of its type in its place.
    /// The holes inside the subtree go with it.
    public func opening(_ subtree: Subtree) -> AbstractCrux? {
        guard subtrees.contains(subtree) else { return nil }
        let width = subtree.end - subtree.start
        var body = function.value
        body.removeSubrange(subtree.start..<subtree.end)
        var holes: [FunctionItem.Hole] = []
        var roles: [Role] = []
        var opened = false
        func addOpen() {
            holes.append(FunctionItem.Hole(stack: subtree.stack, positions: [subtree.start]))
            roles.append(.open(subtree.stack))
            opened = true
        }
        for (hole, role) in zip(function.holes, self.roles) {
            let kept = hole.positions.compactMap { position -> Int? in
                if position < subtree.start { return position }
                if position >= subtree.end { return position - width }
                return nil
            }
            if !opened, let first = hole.positions.first, first >= subtree.start { addOpen() }
            if !kept.isEmpty {
                holes.append(FunctionItem.Hole(stack: hole.stack, positions: kept))
                roles.append(role)
            }
        }
        if !opened { addOpen() }
        let spans = subtrees.compactMap { span -> Subtree? in
            if span.end <= subtree.start { return span }
            if span.start >= subtree.end {
                return Subtree(start: span.start - width, end: span.end - width, stack: span.stack)
            }
            if span.start <= subtree.start && span.end >= subtree.end && span != subtree {
                return Subtree(start: span.start, end: span.end - width, stack: span.stack)
            }
            return nil
        }
        let function = FunctionItem(body: body, holes: holes, output: self.function.output ?? subtree.stack)
        return AbstractCrux(function: function, roles: roles, subtrees: spans)
    }
}

nonisolated extension DistilledCrux {
    /// This crux with typed holes for its inputs, constants, derived values and,
    /// if `literals`, its literals. `nil` when the history is over `limit` leaves
    /// written out as a tree.
    public func abstracted(_ reading: AbstractCrux.Reading = .perDistinct, literals: Bool = true,
                           limit: Int = 2_000) -> AbstractCrux? {
        var builder = AbstractCrux.Builder(reading: reading, literals: literals, sites: [], limit: limit)
        return builder.build(item)
    }
}

nonisolated extension AbstractCrux {
    /// One step of writing a history out: a node to write, or the end of a
    /// subtree begun at `start`.
    enum BuildStep { case node(any Item, argument: Bool), close(start: Int, stack: PushStack) }

    /// Writes a history out as a tree, leaf by leaf, putting holes on its data.
    struct Builder {
        let reading: Reading
        let literals: Bool
        let sites: Set<TuningSite>
        let limit: Int

        private var body: [any Item] = []
        private var holePositions: [[Int]] = []
        private var holeStacks: [PushStack] = []
        private var roles: [Role] = []
        /// The hole each shared thing has: an input or constant slot, or one of
        /// the controls decorating an input.
        private var distinct: [String: Int] = [:]
        /// The highest hole already placed at each position. Holes at one
        /// position are filled in hole order, so a hole can be placed there
        /// again only after them; otherwise that use gets a hole of its own.
        private var lastHoleAt: [Int: Int] = [:]
        private var subtrees: [Subtree] = []

        init(reading: Reading, literals: Bool, sites: Set<TuningSite>, limit: Int) {
            self.reading = reading
            self.literals = literals
            self.sites = sites
            self.limit = limit
        }

        mutating func build(_ root: any Item) -> AbstractCrux? {
            guard let output = PushStack.defaultStack(for: root) else { return nil }
            guard emit(root, asArgument: true) else { return nil }
            if sites.contains(.output) { decorate(output, sharing: nil) }
            let holes = zip(holeStacks, holePositions).map { FunctionItem.Hole(stack: $0, positions: $1) }
            let function = FunctionItem(body: body, holes: holes, output: output)
            return AbstractCrux(function: function, roles: roles, subtrees: subtrees)
        }

        /// The role of `node` if it is a leaf of data that gets a hole.
        func role(of node: any Item) -> Role? {
            let call = node.call
            if call.count == 1, let token = call[0].exactly(InstructionItem.self)?.value {
                let dependence = CruxDependence.token(token)
                if dependence.contains(.input) { return .input(token) }
                if dependence.contains(.constant) { return .constant(token) }
                return nil
            }
            if call.count == 1, let standIn = call[0].exactly(StandInItem.self), standIn.reason == .distilled {
                return .derived(standIn.value)
            }
            guard call.isEmpty, literals else { return nil }
            if node is CodeItem || node is InstructionItem || node is StandInItem || node is FunctionItem {
                return nil
            }
            return .literal(node)
        }

        /// Places a hole for `role` at the end of the body: the hole `shared` names
        /// if there is one and it may go here, otherwise a new one.
        private mutating func place(_ role: Role, stack: PushStack, shared: String?) {
            let position = body.count
            if reading == .perDistinct, let shared, let index = distinct[shared],
               index >= (lastHoleAt[position] ?? -1) {
                holePositions[index].append(position)
                lastHoleAt[position] = index
                return
            }
            let index = roles.count
            if let shared, distinct[shared] == nil { distinct[shared] = index }
            holePositions.append([position])
            holeStacks.append(stack)
            roles.append(role)
            lastHoleAt[position] = index
        }

        private mutating func addHole(_ role: Role, stack: PushStack) {
            switch role {
            case .input(let slot):
                place(role, stack: stack, shared: slot.rawValue)
                if sites.contains(.inputs) { decorate(stack, sharing: slot.rawValue) }
            case .constant(let slot):
                place(role, stack: stack, shared: slot.rawValue)
            default:
                place(role, stack: stack, shared: nil)
            }
        }

        /// Appends the tunable template for a value on `stack`: its instructions,
        /// and a control hole for each parameter, shared by every use of the
        /// input `sharing` names when holes are per distinct input.
        private mutating func decorate(_ stack: PushStack, sharing: String?) {
            guard let template = TunableCrux.template(for: stack) else { return }
            for (index, part) in template.enumerated() {
                switch part {
                case .instruction(let instruction):
                    body.append(InstructionItem(instruction))
                case .control(let neutral):
                    let controlStack = PushStack.defaultStack(for: neutral) ?? stack
                    place(.control(neutral: neutral), stack: controlStack, shared: sharing.map { "\($0)#\(index)" })
                }
            }
        }

        /// Writes `node` out; false once the body passes `limit`. Iterative: an
        /// explicit stack of work, since a history can nest deeply.
        private mutating func emit(_ root: any Item, asArgument: Bool) -> Bool {
            var work: [BuildStep] = [.node(root, argument: asArgument)]
            while let next = work.popLast() {
                switch next {
                case .close(let start, let stack):
                    subtrees.append(Subtree(start: start, end: body.count, stack: stack))
                case .node(let node, let argument):
                    let stack = argument ? PushStack.defaultStack(for: node) : nil
                    if argument, let stack, let role = role(of: node) {
                        addHole(role, stack: stack)
                        continue
                    }
                    let call = node.call
                    if call.isEmpty {
                        body.append(node)
                        if body.count > limit { return false }
                        continue
                    }
                    if let stack, argument { work.append(.close(start: body.count, stack: stack)) }
                    let arguments = CruxSharing.argumentCount(call)
                    for (index, child) in call.enumerated().reversed() {
                        work.append(.node(child, argument: index < arguments))
                    }
                }
            }
            return true
        }
    }
}
