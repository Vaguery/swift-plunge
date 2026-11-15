//
//  AbstractCrux Builder.swift
//  Plunge
//
//  Building the abstract, tunable and skeleton cruxes from a distilled crux:
//  roll its repeats into loops, then write its structure out with a marker at
//  each hole. Split out of AbstractCrux.swift 2026-11-15, when rolling was
//  added.
//

nonisolated extension DistilledCrux {
    /// The abstract crux: typed holes for its constant slots, derived constants
    /// and, if `literals`, its literals and loop counts, with its inputs left in
    /// place, built on its rolled form. `nil` when the structure is over `limit`
    /// items.
    public func abstracted(_ reading: AbstractCrux.Reading = .perDistinct, literals: Bool = true,
                           limit: Int = 2_000) -> AbstractCrux? {
        var builder = AbstractCrux.Builder(reading: reading, literals: literals, inputHoles: false, sites: [],
                                           limit: limit)
        return builder.build(item)
    }

    /// The skeleton crux: the abstract crux with every input a typed hole too, so
    /// that only the work between the holes is left. `nil` when the structure is
    /// over `limit` items.
    public func skeleton(_ reading: AbstractCrux.Reading = .perDistinct, literals: Bool = true,
                         limit: Int = 2_000) -> AbstractCrux? {
        var builder = AbstractCrux.Builder(reading: reading, literals: literals, inputHoles: true, sites: [],
                                           limit: limit)
        return builder.build(item)
    }
}

nonisolated extension AbstractCrux {
    /// One step of writing a structure out.
    enum BuildStep {
        /// A node; `argument` when it sits in an argument position, where it
        /// pushes exactly one item.
        case node(any Item, argument: Bool)
        /// An item written as it is.
        case token(any Item)
        /// The end of a subtree begun at `start`, which nets one item on `stack`.
        case close(start: Int, stack: PushStack)
        /// The start and end of a rolled loop's body.
        case openBody, closeBody
    }

    /// Writes a history's structure out, leaf by leaf, putting holes on its data.
    struct Builder {
        let reading: Reading
        let literals: Bool
        /// Whether inputs become holes (a skeleton) or stay as instructions.
        let inputHoles: Bool
        let sites: Set<TuningSite>
        let limit: Int

        /// The structure being written; a rolled loop's body is written into a
        /// buffer of its own, on top.
        private var buffers: [[any Item]] = [[]]
        private var written = 0
        private var holeStacks: [PushStack] = []
        private var roles: [Role] = []
        /// The hole each shared thing has: an input or constant slot, or one of
        /// the controls decorating an input.
        private var distinct: [String: Int] = [:]
        /// The highest hole placed at each top-level position (counted in items,
        /// not markers). The language fills holes at one position in hole order,
        /// so a hole goes there again only after them; otherwise that use gets a
        /// hole of its own.
        private var lastHoleAt: [Int: Int] = [:]
        private var subtrees: [Subtree] = []
        /// For each rolled loop: the levels of one pass, top first.
        private var passes: [CruxSharing.Key: [any Item]] = [:]

        init(reading: Reading, literals: Bool, inputHoles: Bool, sites: Set<TuningSite>, limit: Int) {
            self.reading = reading
            self.literals = literals
            self.inputHoles = inputHoles
            self.sites = sites
            self.limit = limit
        }

        mutating func build(_ root: any Item) -> AbstractCrux? {
            guard let output = PushStack.defaultStack(for: root) else { return nil }
            let rolled = roll(root)
            guard emit(rolled) else { return nil }
            if sites.contains(.output) { decorate(output, sharing: nil) }
            return AbstractCrux(template: buffers[0], holeStacks: holeStacks, roles: roles, output: output,
                                subtrees: subtrees)
        }

        /// `root` with every run of identical passes rolled into a counted loop,
        /// noting each loop's pass. Two passes are enough when the body has at
        /// least three items.
        private mutating func roll(_ root: any Item) -> any Item {
            var found: [CruxSharing.Key: [any Item]] = [:]
            let rolled = HistoryRewrite.rewrite(root) { node in
                guard let (fold, pass) = HistoryRewrite.foldedPass(node, twoPassBody: 3),
                      let key = CruxSharing.key(fold) else { return nil }
                found[key] = pass
                return fold
            }
            passes = found
            return rolled
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

        // MARK: Writing

        private var atTop: Bool { buffers.count == 1 }

        private mutating func append(_ item: any Item) {
            buffers[buffers.count - 1].append(item)
            written += 1
        }

        /// Places a marker for `role`: the hole `shared` names if there is one and
        /// it may go here, otherwise a new one.
        private mutating func place(_ role: Role, stack: PushStack, shared: String?) {
            let position = buffers[0].count { AbstractCrux.holeNumber($0) == nil }
            if reading == .perDistinct, let shared, let number = distinct[shared],
               !atTop || number >= (lastHoleAt[position] ?? -1) {
                if atTop { lastHoleAt[position] = number }
                append(AbstractCrux.marker(number))
                return
            }
            let number = roles.count
            if let shared, distinct[shared] == nil { distinct[shared] = number }
            holeStacks.append(stack)
            roles.append(role)
            if atTop { lastHoleAt[position] = number }
            append(AbstractCrux.marker(number))
        }

        private mutating func addHole(_ role: Role, stack: PushStack) {
            switch role {
            case .input(let slot):
                if inputHoles {
                    place(role, stack: stack, shared: slot.rawValue)
                } else {
                    append(InstructionItem(slot))
                }
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
                    append(InstructionItem(instruction))
                case .control(let neutral):
                    let controlStack = PushStack.defaultStack(for: neutral) ?? stack
                    place(.control(neutral: neutral), stack: controlStack, shared: sharing.map { "\($0)#\(index)" })
                }
            }
        }

        /// Writes `root` out; false once the structure passes `limit` items.
        /// Iterative: an explicit stack of work, since a history can nest deeply.
        private mutating func emit(_ root: any Item) -> Bool {
            var work: [BuildStep] = [.node(root, argument: true)]
            while let next = work.popLast() {
                if written > limit { return false }
                switch next {
                case .token(let item):
                    append(item)
                case .openBody:
                    buffers.append([])
                case .closeBody:
                    let body = buffers.removeLast()
                    buffers[buffers.count - 1].append(CodeItem(body))
                case .close(let start, let stack):
                    if atTop { subtrees.append(Subtree(start: start, end: buffers[0].count, stack: stack)) }
                case .node(let node, let argument):
                    work += expand(node, argument: argument)
                }
            }
            return true
        }

        /// The steps that write `node`: a hole for data, the node itself for a
        /// literal, a rolled loop's parts, or the node's call.
        private mutating func expand(_ node: any Item, argument: Bool) -> [BuildStep] {
            let stack = argument ? PushStack.defaultStack(for: node) : nil
            if argument, let stack, let role = role(of: node) {
                addHole(role, stack: stack)
                return []
            }
            let call = node.call
            if call.isEmpty {
                append(node)
                return []
            }
            // Pushed first, so it runs after the node's own steps.
            var steps: [BuildStep] = []
            if let stack, argument, atTop { steps.append(.close(start: buffers[0].count, stack: stack)) }
            if let key = CruxSharing.key(node), let pass = passes[key] {
                return steps + Self.loopSteps(call, pass: pass).reversed()
            }
            let arguments = CruxSharing.argumentCount(call)
            for (index, child) in call.enumerated().reversed() {
                steps.append(.node(child, argument: index < arguments))
            }
            return steps
        }

        /// A rolled loop, `seed ( body ) count .execDoTimes .codePop`, as steps:
        /// the seed and the count as arguments, and the body written from one
        /// pass's levels, bottom first, so the data in it gets holes too.
        static func loopSteps(_ call: [any Item], pass: [any Item]) -> [BuildStep] {
            var steps: [BuildStep] = [.node(call[0], argument: true), .openBody]
            for level in pass.reversed() {
                let levelCall = level.call
                let arguments = CruxSharing.argumentCount(levelCall)
                for (index, element) in levelCall.enumerated() where index > 0 {
                    steps.append(index < arguments ? .node(element, argument: true) : .token(element))
                }
            }
            steps += [.closeBody, .node(call[2], argument: true), .token(call[3]), .token(call[4])]
            return steps
        }
    }
}
