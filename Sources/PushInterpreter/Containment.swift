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
