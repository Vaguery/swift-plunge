//
//  Containment.swift
//  PushInterpreter
//
//  What an item taken out of a container records. Added 2026-11-07 for
//  provenance completeness.
//

/// **The containment law.** An item taken out of a container is the item that went
/// in, so it keeps its own history (law 1b). If it has none, because it was born
/// inside the container rather than put there, its history is its **address**: the
/// container, the position, and the instruction that takes it out from there.
///
/// Items are born inside containers more often than it might seem: the contents of
/// a block bound to `.input3`, a block a structural edit rebuilt along its path
/// (`.codeWrapRange` makes a new inner block), the leaf a `.codeNthRoot` box
/// holds. Taken out bare, such an item looks like a literal of the program, and a
/// crux built on it has lost its link to the container: an input-blind crux for a
/// result that did depend on the input. The address keeps the link, and it is
/// ordinary runnable Push.
///
/// **A container with no history of its own** is a literal of the program, so its
/// contents are literals of the program too, and are taken out bare, as before.
/// (Vector and string elements are not items of the program text at all, which is
/// why their extraction instructions always record an address.)
///
/// The rule is representation-neutral: any container that can say "the thing at
/// position k" can give its contents an address, and any representation with
/// containers needs it.
nonisolated enum Containment {

    /// `element`, taken out of the block `container` at `index` by `instruction`
    /// (`.codeEmitNthRoot` for a root position, `.codeEmitNth` for a
    /// pre-order point): unchanged if it has a history of its own, if it does not
    /// rest on a stack (an instruction runs, a stand-in marks itself), or if the
    /// container is a literal; otherwise addressed.
    ///
    /// The address is the crux the instruction itself would record, so a replay
    /// reproduces the item exactly, history included. The emit instructions read
    /// their arguments without consuming them, so the address ends with the same
    /// clean-up any non-destructive query records (`Behavior.reading`).
    ///
    /// `index` is the item that names the position: the program's own `.int` for
    /// an emit instruction, a literal position for `.codeDo` and the iterators.
    @inline(__always)
    static func takenOut(
        _ element: any Item,
        of container: CodeItem,
        at index: @autoclosure () -> IntItem,
        by instruction: PushInstruction,
        _ recording: ProvenanceRecording
    ) -> any Item {
        guard recording.isOn, element.call.isEmpty, !container.call.isEmpty,
              let stack = PushStack.defaultStack(for: element) else { return element }
        var addressed = element
        addressed.call = Behavior.reading(
            [.code: 1, .int: 1],
            producing: stack,
            from: [container, index(), InstructionItem(instruction)])
        return addressed
    }

    /// A block's root contents as `.codeDo` spreads them: each addressed as
    /// `.codeEmitNthRoot` would take it out (see `takenOut`). The block itself
    /// unchanged when recording is off or it is a literal, so the search pays
    /// nothing.
    static func contents(of block: CodeItem, _ recording: ProvenanceRecording) -> [any Item] {
        guard recording.isOn, !block.call.isEmpty else { return block.value }
        return block.value.enumerated().map { index, element in
            takenOut(element, of: block, at: IntItem(index), by: .codeEmitNthRoot, recording)
        }
    }
}

// MARK: - Members: the elements of vectors and strings

/// Where each element of a vector or string came from, kept only when recording,
/// in the container's `CallStorage`.
///
/// A block's contents are items, so they keep their histories without help. A
/// vector's or string's elements are raw values, so the container records, for
/// each element, its **origin**: either the item that went in (`.vecIntConj` of a
/// computed 5), or position `j` of the container the element was born in (a
/// constant, a literal, a computed vector). The extraction instructions then hand
/// back the item that went in, exactly as `.codeEmitNthRoot` hands back a block's
/// content, or the element's address in its **source**: `.vecInt3 2 .vecIntNth`,
/// not the address in whatever concatenation it ended up in.
///
/// **A piece table.** Most elements come from a few sources, in runs (a
/// concatenation of two constants is two runs), so the origins are stored as runs:
/// a single item, or a span of a source's positions stepping forward or backward.
/// A container with no members is a **source**: its elements were born there, and
/// are addressed from it. Building a container out of another one's elements
/// carries their origins over (`origins`), so an origin always names the source,
/// never an intermediate rearrangement.
///
/// Members are a fixed point: a replay of an element's address finds the source
/// rebuilt with no member at that position (a source's positions are its own), so
/// it records the same address again.
nonisolated struct Pieces: Sendable {

    /// A run of consecutive elements with one origin.
    nonisolated enum Run: Sendable {
        /// One element: the item that went in.
        case item(any Item)
        /// `count` elements: positions `from`, `from + step`, … of `source`.
        case span(source: any Item, from: Int, count: Int, step: Int)

        var count: Int {
            switch self {
            case .item: 1
            case .span(_, _, let count, _): count
            }
        }
    }

    let runs: [Run]
    /// Where each run ends (exclusive), for a binary search.
    private let ends: [Int]

    /// How many elements the runs cover.
    var count: Int { ends.last ?? 0 }

    /// The runs for `origins`, merging consecutive positions of one run of one
    /// input into a span.
    init(_ origins: [Origin]) {
        var runs: [Run] = []
        var ends: [Int] = []
        var last: (key: Origin.Key, index: Int)?
        for origin in origins {
            switch origin {
            case .item(let item):
                runs.append(.item(item))
                last = nil
            case .element(let source, let index, let key):
                if let previous = last, previous.key == key,
                   case .span(let source, let from, let count, let step) = runs[runs.count - 1],
                   count == 1 ? abs(index - previous.index) == 1 : index == previous.index + step {
                    runs[runs.count - 1] = .span(source: source, from: from, count: count + 1,
                                                 step: count == 1 ? index - previous.index : step)
                    ends[ends.count - 1] += 1
                    last = (key, index)
                    continue
                }
                runs.append(.span(source: source, from: index, count: 1, step: 1))
                last = (key, index)
            }
            ends.append((ends.last ?? 0) + 1)
        }
        self.runs = runs
        self.ends = ends
    }

    /// These runs, as they were: how `ItemArchive` rebuilds a decoded item's
    /// members.
    init(runs: [Run]) {
        var total = 0
        self.runs = runs
        self.ends = runs.map { run in
            total += run.count
            return total
        }
    }

    /// The origin of element `index`, or nil if out of range. O(log runs).
    func origin(at index: Int) -> Origin? {
        guard index >= 0, index < count else { return nil }
        var low = 0, high = ends.count - 1
        while low < high {
            let mid = (low + high) / 2
            if ends[mid] > index { high = mid } else { low = mid + 1 }
        }
        let offset = index - (low == 0 ? 0 : ends[low - 1])
        switch runs[low] {
        case .item(let item): return .item(item)
        case .span(let source, let from, _, let step):
            return .element(source: source, position: from + offset * step, key: Origin.Key(tag: 0, run: low))
        }
    }

    /// Every element's origin, in order, for building another container out of
    /// this one. `tag` tells this container's runs apart from another input's.
    func origins(tag: Int) -> [Origin] {
        var out: [Origin] = []
        out.reserveCapacity(count)
        for (run, piece) in runs.enumerated() {
            switch piece {
            case .item(let item): out.append(.item(item))
            case .span(let source, let from, let count, let step):
                let key = Origin.Key(tag: tag, run: run)
                for offset in 0..<count {
                    out.append(.element(source: source, position: from + offset * step, key: key))
                }
            }
        }
        return out
    }
}

/// Where one element of a vector or string came from; see `Pieces`.
nonisolated enum Origin: Sendable {
    /// Which run of which input an element came from, so `Pieces` merges only
    /// positions that really are one run of one source.
    struct Key: Equatable, Sendable {
        let tag: Int
        let run: Int
    }

    /// The item that went in.
    case item(any Item)
    /// `position` in the `source` container it was born in.
    case element(source: any Item, position: Int, key: Key)
}

/// A container whose elements have origins: the four vectors and `StringItem`.
nonisolated protocol HoldsMembers: Item {
    var members: Pieces? { get }
}

nonisolated extension VecBoolItem: HoldsMembers {}
nonisolated extension VecDoubleItem: HoldsMembers {}
nonisolated extension VecIntItem: HoldsMembers {}
nonisolated extension VecStringItem: HoldsMembers {}
nonisolated extension StringItem: HoldsMembers {}

nonisolated extension HoldsMembers {
    /// Every element's origin, for building a new container out of this one: its
    /// members if it has any, else its own positions (it is a source). `tag` tells
    /// two inputs apart. Called only when recording.
    func origins(_ tag: Int = 0, count: Int) -> [Origin] {
        if let members { return members.origins(tag: tag) }
        let key = Origin.Key(tag: tag, run: -1)
        return (0..<count).map { .element(source: self, position: $0, key: key) }
    }
}

nonisolated extension VectorItem {
    /// Every element's origin; see `HoldsMembers.origins(_:count:)`.
    func origins(_ tag: Int = 0) -> [Origin] { origins(tag, count: value.count) }

    /// Element `index` as its origin says to take it out: the item that went in,
    /// or its address in its source. `nil` for a source, whose elements the
    /// caller addresses from itself as it always has.
    func traced(at index: Int, _ recording: ProvenanceRecording) -> (any Item)? {
        guard let origin = members?.origin(at: index) else { return nil }
        switch origin {
        case .item(let item):
            return item
        case .element(let source, let position, _):
            return Scalar(value[index], call: recording(
                [source, IntItem(position), InstructionItem(Self.nthInstruction)]))
        }
    }
}

nonisolated extension StringItem {
    /// Every character's origin; see `HoldsMembers.origins(_:count:)`. O(n).
    func origins(_ tag: Int = 0) -> [Origin] { origins(tag, count: value.count) }

    /// The origins of `piece`, a substring of this string's `value` (a word, say).
    func origins(of piece: Substring, _ tag: Int = 0) -> [Origin] {
        let start = value.distance(from: value.startIndex, to: piece.startIndex)
        let all = origins(tag)
        let end = start + piece.count
        guard start >= 0, end <= all.count else { return [] }
        return Array(all[start..<end])
    }

    /// Character `index` (which is `character`) as its origin says to take it out;
    /// see `VectorItem.traced(at:_:)`.
    func traced(at index: Int, _ character: Character, _ recording: ProvenanceRecording) -> (any Item)? {
        guard let origin = members?.origin(at: index) else { return nil }
        switch origin {
        case .item(let item):
            return item
        case .element(let source, let position, _):
            return CharItem(character, call: recording([source, IntItem(position), InstructionItem(.stringNth)]))
        }
    }
}

nonisolated extension Containment {
    /// `pieces` if they line up with `characters`, element for element and value
    /// for value; `nil` otherwise. Joining strings can merge characters (a
    /// combining mark after a letter), and origins that do not line up must not
    /// hand back the wrong character's history.
    static func aligned(_ pieces: Pieces, with characters: [Character]) -> Pieces? {
        guard pieces.count == characters.count else { return nil }
        var position = 0
        for run in pieces.runs {
            switch run {
            case .item(let item):
                guard item.exactly(CharItem.self)?.value == characters[position] else { return nil }
            case .span(let source, let from, let count, let step):
                guard let text = source.exactly(StringItem.self) else { return nil }
                let sourceCharacters = Array(text.value)
                for offset in 0..<count {
                    let index = from + offset * step
                    guard sourceCharacters.indices.contains(index),
                          sourceCharacters[index] == characters[position + offset] else { return nil }
                }
            }
            position += run.count
        }
        return pieces
    }
}

nonisolated extension ProvenanceRecording {
    /// The pieces for a new vector or string, built only when recording; `nil` for
    /// an empty one.
    @inline(__always)
    func pieces(_ build: @autoclosure () -> [Origin]) -> Pieces? {
        guard isOn else { return nil }
        let origins = build()
        return origins.isEmpty ? nil : Pieces(origins)
    }
}
