//
//  FunctionItem.swift
//  Plunge
//
//  A function on the `.function` stack: a body with typed holes.
//

/// **A function: a body with typed holes.** Two routes make one:
/// - **Starvation.** An instruction that comes up short for arguments leaves its
///   missing-arguments error and is also pushed onto `.function` as a *bare*
///   function: the instruction alone, nothing it found bound or copied. Its holes
///   are its arguments, read from its declared requirements only when something
///   asks (`holes`), so a starvation costs one push and nothing more.
/// - **`codePushAllFunctions`.** A block is run in a sandbox with a placeholder
///   for every missing argument, and every item it pushes whose history uses a
///   placeholder becomes a function: that history, each placeholder a hole.
///
/// **A hole is a stack and its positions, not an item.** The body holds no hole
/// markers: a hole names which stack its filler comes from and where in the body
/// the filler goes, so nothing can push a hole or route one onto a stack. One
/// hole can sit at several positions (`x x .intMultiply` squares its one
/// argument). Filling every hole gives a runnable program (`filled(with:)`).
///
/// **A function is data.** Met on `.exec`, it comes to rest on `.function`, as a
/// block comes to rest on `.code`; nothing runs it but an instruction that
/// applies it (map, filter and reduce). It is its own literal: a starvation
/// depends on the moment's stacks, and a derivation makes all of a block's
/// functions at once, so neither can be replayed for one function alone.
public nonisolated struct FunctionItem: Item, Equatable, Pretty {

    /// One hole: its filler comes from `stack` and goes before the body item at
    /// each of `positions` (the body's count for the end). Fillers sharing a
    /// position go in hole order.
    public struct Hole: Hashable, Sendable, Codable {
        public let stack: PushStack
        public let positions: [Int]
        public init(stack: PushStack, positions: [Int]) {
            self.stack = stack
            self.positions = positions
        }
    }

    /// The body, without its holes.
    public var value: [any Item]
    /// A derived function's holes, in order; empty for a bare one, whose holes
    /// come from its instruction (`holes`).
    let derivedHoles: [Hole]
    /// A derived function's output stack: where the item it was read from went.
    let derivedOutput: PushStack?
    /// Whether this is a starved instruction, its holes its arguments.
    public let isBare: Bool

    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    /// The body's content and one for each hole.
    public let weight: Int
    /// A function is a container: one level above its body.
    public let nestingDepth: Int

    /// A starved item as a bare function.
    public init(bare item: any Item, call: [any Item] = []) {
        self.init(body: [item], holes: [], output: nil, isBare: true, call: call)
    }

    /// A derived function: `body` with `holes`, its value landing on `output`.
    public init(body: [any Item], holes: [Hole], output: PushStack, call: [any Item] = []) {
        self.init(body: body, holes: holes, output: output, isBare: false, call: call)
    }

    private init(body: [any Item], holes: [Hole], output: PushStack?, isBare: Bool, call: [any Item]) {
        self.value = body
        self.derivedHoles = holes
        self.derivedOutput = output
        self.isBare = isBare
        self.callStorage = CallStorage(call)
        var weight = holes.count, deepest = 0
        for item in body {
            weight = weight.addingReportingOverflow(item.weight).0
            deepest = Swift.max(deepest, item.nestingDepth)
        }
        self.weight = Swift.max(weight, 1)
        self.nestingDepth = 1 + deepest
    }

    /// The holes, in the order they are filled.
    public var holes: [Hole] {
        guard isBare else { return derivedHoles }
        return bareInstruction.flatMap { Self.bareShapes[$0]?.holes } ?? []
    }

    /// The stack the function's value lands on, or nil when its instruction
    /// does not say (a value-dependent result, a continuation, a printout).
    public var output: PushStack? {
        guard isBare else { return derivedOutput }
        return bareInstruction.flatMap { Self.bareShapes[$0]?.output }
    }

    /// How many holes take items from `stack`.
    public func holeCount(on stack: PushStack) -> Int {
        holes.count { $0.stack == stack }
    }

    /// The body with `fillers` in its holes, one per hole in order: a program.
    public func filled(with fillers: [any Item]) -> [any Item] {
        precondition(fillers.count == holes.count, "one filler per hole")
        return Self.merged(value, layout) { fillers[$0] }
    }

    /// Every hole occurrence as (position, hole), in the order they are filled:
    /// by position, then by hole.
    var layout: [(position: Int, hole: Int)] {
        holes.enumerated().flatMap { index, hole in hole.positions.map { (position: $0, hole: index) } }
            .sorted { ($0.position, $0.hole) < ($1.position, $1.hole) }
    }

    /// `body` with `filler(hole)` before each body item at its positions.
    static func merged<T>(_ body: [T], _ layout: [(position: Int, hole: Int)], _ filler: (Int) -> T) -> [T] {
        var result: [T] = []
        result.reserveCapacity(body.count + layout.count)
        var next = 0
        for index in 0...body.count {
            while next < layout.count, layout[next].position == index {
                result.append(filler(layout[next].hole))
                next += 1
            }
            if index < body.count { result.append(body[index]) }
        }
        return result
    }

    public static func == (lhs: FunctionItem, rhs: FunctionItem) -> Bool {
        lhs.isBare == rhs.isBare && lhs.derivedHoles == rhs.derivedHoles
            && lhs.derivedOutput == rhs.derivedOutput && lhs.value == rhs.value
    }

    /// `ƒ( ⟨int⟩ 3 .intAdd )`, each hole written as its stack. Rendered by
    /// `NestedRendering`, since the body can hold blocks that hold functions.
    public func pretty() -> String {
        NestedRendering.render(self)
    }

    private var bareInstruction: PushInstruction? {
        value.first?.exactly(InstructionItem.self)?.value
    }
}

nonisolated extension FunctionItem: HoldsCall {
    /// A function hands over its body as well as its history, as a block does.
    @_documentation(visibility: internal)
    public mutating func detachForRelease(into work: inout [any Item]) {
        callStorage.detach(into: &work)
        work.append(contentsOf: value)
        value = []
    }
}

nonisolated extension FunctionItem {

    /// A bare function's shape: its instruction's arguments as holes, and its
    /// output stack.
    struct BareShape: Sendable {
        let holes: [Hole]
        let output: PushStack?
    }

    /// Every instruction's bare shape, read once from the language.
    static let bareShapes: [PushInstruction: BareShape] =
        Interpreter.language.mapValues { BareShape(holes: holes(of: $0), output: output(of: $0)) }

    /// The arguments a Behavior declares, as holes before the instruction: each
    /// stack's in its requirements' order of first appearance, as many as it
    /// takes and reads (or needs, if more), deepest first. A count its arguments
    /// decide (`takesMany`) has no fixed holes.
    static func holes(of behavior: Behavior) -> [Hole] {
        var order: [PushStack] = []
        var counted: [PushStack: Int] = [:], needed: [PushStack: Int] = [:]
        for requirement in behavior.requirements {
            switch requirement {
            case .takes(let stack), .reads(let stack), .takesFirst(let stack, _):
                if counted[stack] == nil && needed[stack] == nil { order.append(stack) }
                counted[stack, default: 0] += 1
            case .needs(let stack, let count):
                if counted[stack] == nil && needed[stack] == nil { order.append(stack) }
                needed[stack] = Swift.max(needed[stack] ?? 0, count)
            case .takesMany:
                continue
            }
        }
        return order.flatMap { stack in
            let count = Swift.max(counted[stack] ?? 0, needed[stack] ?? 0)
            return Array(repeating: Hole(stack: stack, positions: [0]), count: count)
        }
    }

    /// Where a Behavior's value lands: the last of its fixed results, or the
    /// stack it rearranges or delivers to; nil when that is not fixed.
    static func output(of behavior: Behavior) -> PushStack? {
        switch behavior.produces {
        case .results(let stacks): stacks.last
        case .positions(let stack), .deferred(let stack), .delivery(let stack), .several(let stack): stack
        case .alternatives, .continuation, .input, .printout: nil
        }
    }
}
