//
//  Containment.swift
//  PushInterpreter
//
//  What an item taken out of a container records. Added 2026-11-07 for
//  provenance completeness (Roadmap §P, step 4): see "Containment" in
//  `Notes on Push/Provenance and the crux.md`.
//

/// **The containment law.** An item taken out of a container is the item that went
/// in, so it keeps its own history (law 1b). If it has none, because it was born
/// inside the container rather than put there, its history is its **address**: the
/// container, the position, and the instruction that takes it out from there.
///
/// Items are born inside containers more often than it might seem: the contents of
/// a block bound to `.input3`, a block a structural edit rebuilt along its path
/// (`.codeWrapPoints` makes a new inner block), the leaf a `.codeNthRoot` box
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
    /// (`.codeEmitNthRoot` for a root position, `.codeEmitNthPoint` for a
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

/// The items that went into a vector or string, one slot per element: the item,
/// if it went in with a history of its own, else `nil`. Kept only when recording,
/// in the container's `CallStorage` (Roadmap #21, ruling P5: "a parallel
/// per-element provenance array").
///
/// A block's contents are items, so they keep their histories without help. A
/// vector's or string's elements are raw values, so the container keeps the items
/// for them. The extraction instructions then hand back the item that went in,
/// exactly as `.codeEmitNthRoot` hands back a block's content, and fall back to the
/// address (`v k .vecIntNth`) for an element with no member. Either way the crux is
/// a fixed point. What the member adds is *addressability*: an element's crux is
/// its own history, not the whole vector's history plus a selection.
typealias Members = [(any Item)?]

/// A container whose elements can have members: the four vectors and `StringItem`.
nonisolated protocol HoldsMembers: Item {
    var members: Members? { get }
}

nonisolated extension VecBoolItem: HoldsMembers {}
nonisolated extension VecDoubleItem: HoldsMembers {}
nonisolated extension VecIntItem: HoldsMembers {}
nonisolated extension VecStringItem: HoldsMembers {}
nonisolated extension StringItem: HoldsMembers {}

nonisolated extension HoldsMembers {
    /// The item that went in at `index`, if it went in with a history.
    @inline(__always)
    func member(at index: Int) -> (any Item)? {
        guard let members, members.indices.contains(index) else { return nil }
        return members[index]
    }
}

nonisolated extension VectorItem {
    /// One slot per element, for building another vector out of this one: the
    /// members if there are any, else empty slots. Called only when recording.
    var slots: Members { members ?? Members(repeating: nil, count: value.count) }
}

nonisolated extension StringItem {
    /// One slot per character, as `VectorItem.slots`. O(n): called only when
    /// recording.
    var slots: Members { members ?? Members(repeating: nil, count: value.count) }

    /// The slots of `piece`, a substring of this string's `value` (a word, say).
    /// Called only when recording.
    func slots(of piece: Substring) -> Members {
        guard let members else { return [] }
        let start = value.distance(from: value.startIndex, to: piece.startIndex)
        let end = start + piece.count
        guard start >= 0, end <= members.count else { return [] }
        return Array(members[start..<end])
    }
}

nonisolated extension Containment {
    /// The slot for an item going into a vector or string: the item itself if it
    /// has a history to keep, else `nil` (it will be addressed from the container).
    @inline(__always)
    static func slot(_ item: any Item) -> (any Item)? {
        item.call.isEmpty ? nil : item
    }

    /// `members` if they line up with `characters`, slot for slot and value for
    /// value; `nil` otherwise. Joining strings can move a character boundary (a
    /// combining mark after a letter), and a list that does not line up must not
    /// hand back the wrong character's history.
    static func aligned(_ members: Members, with characters: [Character]) -> Members? {
        guard members.count == characters.count else { return nil }
        for (member, character) in zip(members, characters) {
            if let member, member.exactly(CharItem.self)?.value != character { return nil }
        }
        return members
    }
}

nonisolated extension ProvenanceRecording {
    /// Members for a new vector or string, built only when recording, and `nil`
    /// when no element has one (the common case, which then costs nothing more).
    @inline(__always)
    func members(_ build: @autoclosure () -> Members) -> Members? {
        guard isOn else { return nil }
        let built = build()
        return built.contains { $0 != nil } ? built : nil
    }
}
