//
//  ItemArchive.swift
//  PushInterpreter
//
//  Opt-in history encoding (Roadmap #22, ruling P8; 2026-11-08). `AnyItem`
//  encodes an item's value only; this encodes items with their histories.
//

/// Items **with their histories**, for storing them or sending them across a
/// process boundary. The opt-in counterpart of `AnyItem`, which encodes values
/// only and so decodes to items whose crux is themselves.
///
/// **A node table, children before parents.** A history is a DAG: a
/// non-destructive read keeps its arguments, so one value is built from the two
/// before it and its tree grows like fib(N). Each node is written once and
/// referred to by its position in the table, which is what makes the encoding
/// about as long as the crux rather than as the tree. A node is shared when it is
/// the same history in memory (`CruxSharing.key`, the identity `crux()` shares
/// by), so a decoded archive shares exactly what the original did, and encoding
/// it again gives the same table.
///
/// Everything an item's history consists of is carried:
///  - its `call`;
///  - the histories of the items it holds (a block's contents, an iterator's
///    origin, destination and body, a stand-in's value), each its own node;
///  - its members (`Pieces`), the origins of a vector's or string's elements;
///  - its weight, when the push boundary measured it as its crux
///    (`HoldsCall.remeasured`), so a decoded item weighs what the original did.
///
/// Decoding needs no interpreter and no input bindings: it rebuilds the items,
/// not a program to run. Their `crux()` is then the original's.
///
/// The table is flat, so neither encoding nor decoding recurses, however deep a
/// history is.
public nonisolated struct ItemArchive: Codable, Sendable {
    /// The archived items, with their histories.
    public let items: [any Item]

    public init(_ items: [any Item]) {
        self.items = items
    }

    public init(from decoder: any Decoder) throws {
        items = try ArchiveTable(from: decoder).items()
    }

    public func encode(to encoder: any Encoder) throws {
        var writer = ArchiveWriter()
        let roots = items.map { writer.archive($0) }
        try ArchiveTable(nodes: writer.nodes, roots: roots).encode(to: encoder)
    }
}

/// The encoded form: every node, children first, and the positions of the items
/// that were archived.
nonisolated struct ArchiveTable: Codable, Sendable {
    var nodes: [ArchiveNode]
    var roots: [Int]

    /// The archived items, rebuilt node by node. A node may refer only to nodes
    /// before it, which is what the writer produces and what makes one pass enough.
    func items() throws -> [any Item] {
        var built: [any Item] = []
        built.reserveCapacity(nodes.count)
        for node in nodes {
            let available = built.count
            built.append(try node.item { position in
                guard position >= 0, position < available else {
                    throw ArchiveError.badReference(position, inNode: available)
                }
                return built[position]
            })
        }
        return try roots.map { position in
            guard position >= 0, position < built.count else {
                throw ArchiveError.badReference(position, inNode: nil)
            }
            return built[position]
        }
    }
}

/// A malformed archive.
public nonisolated enum ArchiveError: Error, Sendable, Equatable {
    /// A node (or, for `nil`, a root) refers to a position that is not before it.
    case badReference(Int, inNode: Int?)
    /// A node's shape and fields disagree, e.g. a history on a stand-in.
    case malformed(String)
}

/// One item, with its children named by position. Exactly one of `scalar`,
/// `code`, `iterator` and `standIn` is present.
nonisolated struct ArchiveNode: Codable, Sendable {
    /// An item that holds no other items, encoded as `AnyItem` does.
    var scalar: AnyItem?
    /// A block: its contents.
    var code: [Int]?
    var iterator: ArchivedIterator?
    var standIn: ArchivedStandIn?
    var ref: ArchivedRef?
    /// The history, when there is one.
    var call: [Int]?
    /// The weight the push boundary measured, when it is not the tree's.
    var weight: UInt32?
    /// The origins of a vector's or string's elements.
    var members: [ArchivedRun]?

    /// The item this node describes, its children looked up by `resolve`.
    func item(_ resolve: (Int) throws -> any Item) throws -> any Item {
        let bare = try shape(resolve)
        guard let call, !call.isEmpty else { return bare }
        guard let holder = bare as? any HoldsCall else {
            throw ArchiveError.malformed("\(type(of: bare)) cannot carry a history")
        }
        let pieces = try members.map { runs in Pieces(runs: try runs.map { try $0.run(resolve) }) }
        var storage = CallStorage(try call.map(resolve), members: pieces)
        if let weight { storage = storage.remeasured(weight: Int(weight)) }
        return holder.storing(storage)
    }

    private func shape(_ resolve: (Int) throws -> any Item) throws -> any Item {
        if let scalar { return scalar.item }
        if let code { return CodeItem(try code.map(resolve)) }
        if let iterator { return try iterator.item(resolve) }
        if let standIn {
            return StandInItem(standingInFor: try resolve(standIn.value),
                               source: standIn.source, reason: standIn.reason)
        }
        if let ref { return RefItem(key: ref.key, bound: try resolve(ref.bound)) }
        throw ArchiveError.malformed("a node with no item")
    }
}

/// An `IteratorItem`, its held items named by position.
nonisolated struct ArchivedIterator: Codable, Sendable {
    var cursor: Int
    var kind: IteratorKind
    var origin: Int
    var destination: Int?
    var body: Int?
    var emits: Bool
    var laps: Int
    var burial: Int

    func item(_ resolve: (Int) throws -> any Item) throws -> IteratorItem {
        var block: CodeItem?
        if let body {
            guard let code = try resolve(body).exactly(CodeItem.self) else {
                throw ArchiveError.malformed("an iterator's body must be a code block")
            }
            block = code
        }
        return IteratorItem(kind: kind, origin: try resolve(origin), destination: try destination.map(resolve),
                            body: block, emits: emits, cursor: cursor, laps: laps, burial: burial)
    }
}

/// A `RefItem`, its bound item named by position.
nonisolated struct ArchivedRef: Codable, Sendable {
    var key: Int
    var bound: Int
}

/// A `StandInItem`, its value named by position.
nonisolated struct ArchivedStandIn: Codable, Sendable {
    var value: Int
    var source: PushInstruction?
    var reason: StandInItem.Reason
}

/// One run of `Pieces`: an item that went in, or `[source, from, count, step]`.
nonisolated struct ArchivedRun: Codable, Sendable {
    var item: Int?
    var span: [Int]?

    func run(_ resolve: (Int) throws -> any Item) throws -> Pieces.Run {
        if let item { return .item(try resolve(item)) }
        guard let span, span.count == 4, span[2] >= 0 else { throw ArchiveError.malformed("a member run") }
        return .span(source: try resolve(span[0]), from: span[1], count: span[2], step: span[3])
    }
}

/// Builds the node table, children first, writing each shared node once.
nonisolated struct ArchiveWriter {
    private(set) var nodes: [ArchiveNode] = []
    /// Nodes with a history, by the identity `crux()` shares by. Checked for
    /// equal values as well, so a reused call array can never merge two items.
    private var withHistory: [CruxSharing.Key: [(item: any Item, position: Int)]] = [:]
    /// The commonest literals, shared by value: a literal has no history, so
    /// equal ones are interchangeable.
    private var instructions: [PushInstruction: Int] = [:]
    private var ints: [Int: Int] = [:]

    private enum Task {
        case visit(any Item)
        case build(any Item, children: Int)
    }

    /// The position of `root`'s node, writing it and every node it needs. Not
    /// recursive: a history may be as deep as `maxCallDepth`.
    mutating func archive(_ root: any Item) -> Int {
        var tasks: [Task] = [.visit(root)]
        var positions: [Int] = []
        while let task = tasks.popLast() {
            switch task {
            case .visit(let item):
                if let known = written(item) {
                    positions.append(known)
                    continue
                }
                let children = Self.children(of: item)
                tasks.append(.build(item, children: children.count))
                tasks.append(contentsOf: children.reversed().map(Task.visit))
            case .build(let item, let count):
                let children = Array(positions.suffix(count))
                positions.removeLast(count)
                positions.append(write(item, children: children))
            }
        }
        return positions[0]
    }

    /// Everything a node refers to, in the order `write` reads them back: its
    /// history, the items it holds, then its members' items.
    static func children(of item: any Item) -> [any Item] {
        let call = item.call
        guard !call.isEmpty else { return held(by: item) }
        let members = (item as? any HoldsCall)?.callStorage.members?.runs ?? []
        return call + held(by: item) + members.map(\.item)
    }

    /// The items an item holds as part of its value.
    static func held(by item: any Item) -> [any Item] {
        if let code = item.exactly(CodeItem.self) { return code.value }
        if let iterator = item.exactly(IteratorItem.self) {
            return [iterator.origin] + [iterator.destination, iterator.body].compactMap { $0 }
        }
        if let standIn = item.exactly(StandInItem.self) { return [standIn.value] }
        if let pair = item.exactly(RefItem.self) { return [pair.bound] }
        return []
    }

    private func written(_ item: any Item) -> Int? {
        if let key = CruxSharing.key(item) {
            return withHistory[key]?.first { $0.item.isEqual(to: item) }?.position
        }
        if let instruction = item.exactly(InstructionItem.self) { return instructions[instruction.value] }
        if let int = item.exactly(IntItem.self) { return ints[int.value] }
        return nil
    }

    private mutating func write(_ item: any Item, children: [Int]) -> Int {
        let call = item.call
        let heldCount = Self.held(by: item).count
        let held = Array(children[call.count..<(call.count + heldCount)])
        var node = Self.shape(of: item, held: held)
        if !call.isEmpty {
            node.call = Array(children[..<call.count])
            if item.callWeight != Int(CallMeasure.of(call).weight) { node.weight = UInt32(clamping: item.callWeight) }
            if let runs = (item as? any HoldsCall)?.callStorage.members?.runs {
                node.members = Self.archived(runs, at: children[(call.count + heldCount)...])
            }
        }
        let position = nodes.count
        nodes.append(node)
        remember(item, at: position)
        return position
    }

    private static func shape(of item: any Item, held: [Int]) -> ArchiveNode {
        var node = ArchiveNode()
        if item.exactly(CodeItem.self) != nil {
            node.code = held
        } else if let iterator = item.exactly(IteratorItem.self) {
            var rest = held.dropFirst()
            node.iterator = ArchivedIterator(
                cursor: iterator.value, kind: iterator.kind, origin: held[0],
                destination: iterator.destination == nil ? nil : rest.popFirst(),
                body: iterator.body == nil ? nil : rest.popFirst(),
                emits: iterator.emits, laps: iterator.laps, burial: iterator.burial)
        } else if let standIn = item.exactly(StandInItem.self) {
            node.standIn = ArchivedStandIn(value: held[0], source: standIn.source, reason: standIn.reason)
        } else if let pair = item.exactly(RefItem.self) {
            node.ref = ArchivedRef(key: pair.key, bound: held[0])
        } else {
            node.scalar = AnyItem(item)
        }
        return node
    }

    private static func archived(_ runs: [Pieces.Run], at positions: ArraySlice<Int>) -> [ArchivedRun] {
        zip(runs, positions).map { run, position in
            switch run {
            case .item: ArchivedRun(item: position)
            case .span(_, let from, let count, let step): ArchivedRun(span: [position, from, count, step])
            }
        }
    }

    private mutating func remember(_ item: any Item, at position: Int) {
        if let key = CruxSharing.key(item) {
            withHistory[key, default: []].append((item, position))
        } else if let instruction = item.exactly(InstructionItem.self) {
            instructions[instruction.value] = position
        } else if let int = item.exactly(IntItem.self) {
            ints[int.value] = position
        }
    }
}

nonisolated extension Pieces.Run {
    /// The item a run names: the item that went in, or the source of a span.
    var item: any Item {
        switch self {
        case .item(let item): item
        case .span(let source, _, _, _): source
        }
    }
}

nonisolated extension HoldsCall {
    /// This item with `storage` as its history.
    func storing(_ storage: CallStorage) -> any Item {
        var copy = self
        copy.callStorage = storage
        return copy
    }
}
