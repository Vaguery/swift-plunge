//
//  AbstractCrux+Construction.swift
//  Plunge
//
//  Building new structures from known ones: five composable steps on abstract
//  and skeleton cruxes (2026-11-16).
//

/// **Constructing structures.** Each step builds a new ``AbstractCrux`` from
/// known ones as a well-typed expression, not by editing program text:
///
/// | Step | Builds | From `$0` |
/// |---|---|---|
/// | ``wrapped(by:)`` | op(S) | `$0 .doubleAbs` |
/// | ``extended(by:with:leafFirst:)`` | op(S, a new hole) | `$0 $1 .doubleMultiply` |
/// | ``reused(by:)`` | op(S, S), the value shared | `$0 .doubleDup .doubleMultiply` |
/// | ``combined(with:by:)`` | op(S, T) | `$0 $1 .doubleDup .doubleMultiply .doubleSubtract` |
/// | ``grafted(_:into:)`` | a hole of S replaced by T | `$0 $1 $2 .doubleAdd .doubleMultiply` |
///
/// They compose because every template nets one value on its output stack:
/// templates concatenate, and a hole's marker can be replaced by another
/// template. Holes are renumbered by first appearance, as ``opening(_:)``
/// renumbers them. An operator is checked against its signature
/// (``InstructionSignature``): it must take exactly its arguments from the
/// stacks given and put one result on a stack. A step returns `nil` when the
/// types don't fit.
///
/// A constructed structure keeps only its whole span as a subtree, so
/// ``opening(_:)`` can open it only whole.
nonisolated extension AbstractCrux {
    /// A new hole for ``extended(by:with:leafFirst:)``: some input, or some
    /// constant, of a type.
    public enum NewLeaf: Sendable, Hashable {
        case input(PushStack)
        case constant(PushStack)

        var stack: PushStack {
            switch self {
            case .input(let stack), .constant(let stack): stack
            }
        }

        var role: Role {
            switch self {
            case .input(let stack): .anyInput(stack)
            case .constant(let stack): .anyConstant(stack)
            }
        }
    }

    /// op(S): `op` applied to this structure's value.
    public func wrapped(by op: PushInstruction) -> AbstractCrux? {
        guard let result = Self.result(of: op, taking: [output: 1]) else { return nil }
        return Self.built(template + [InstructionItem(op)], holeStacks: holeStacks, roles: roles, output: result)
    }

    /// op(S, a new hole): `op` applied to this structure's value and a new hole
    /// for some input or constant. The hole comes after S, or, with `leafFirst`,
    /// before it (for an operator whose argument order matters).
    public func extended(by op: PushInstruction, with leaf: NewLeaf, leafFirst: Bool = false) -> AbstractCrux? {
        var taking: [PushStack: Int] = [output: 1]
        taking[leaf.stack, default: 0] += 1
        guard let result = Self.result(of: op, taking: taking) else { return nil }
        let hole = [Self.marker(holeCount)]
        let body = leafFirst ? hole + template : template + hole
        return Self.built(body + [InstructionItem(op)], holeStacks: holeStacks + [leaf.stack],
                          roles: roles + [leaf.role], output: result)
    }

    /// op(S, S): `op` applied to this structure's value twice, made once and
    /// shared by a `dup`.
    public func reused(by op: PushInstruction) -> AbstractCrux? {
        guard let result = Self.result(of: op, taking: [output: 2]),
              let dup = PushInstruction(rawValue: output.rawValue + "Dup") else { return nil }
        return Self.built(template + [InstructionItem(dup), InstructionItem(op)], holeStacks: holeStacks,
                          roles: roles, output: result)
    }

    /// op(S, T): `op` applied to this structure's value and `other`'s, in that
    /// order. Their holes stay distinct.
    public func combined(with other: AbstractCrux, by op: PushInstruction) -> AbstractCrux? {
        var taking: [PushStack: Int] = [output: 1]
        taking[other.output, default: 0] += 1
        guard let result = Self.result(of: op, taking: taking) else { return nil }
        let shifted = Self.mapMarkers(other.template) { Self.marker($0 + holeCount) }
        return Self.built(template + shifted + [InstructionItem(op)], holeStacks: holeStacks + other.holeStacks,
                          roles: roles + other.roles, output: result)
    }

    /// This structure with hole `hole` replaced by `other` (at every place the
    /// hole appears), `other`'s holes kept distinct. `nil` if `other`'s value
    /// isn't the hole's type, or there is no such hole.
    public func grafted(_ other: AbstractCrux, into hole: Int) -> AbstractCrux? {
        guard holeStacks.indices.contains(hole), holeStacks[hole] == other.output else { return nil }
        let shifted = Self.mapMarkers(other.template) { Self.marker($0 + holeCount) }
        let body = Self.splicing(template, hole: hole, with: shifted)
        return Self.built(body, holeStacks: holeStacks + other.holeStacks, roles: roles + other.roles,
                          output: output)
    }

    // MARK: - Building

    /// The stack `op` puts its one result on, if it takes exactly `taking` and
    /// nothing else.
    static func result(of op: PushInstruction, taking: [PushStack: Int]) -> PushStack? {
        guard let signature = Interpreter.signatures[op], signature.consumes == taking,
              signature.reads.isEmpty, signature.needs.isEmpty, signature.variadic.isEmpty,
              signature.observes.isEmpty, case .results(let results) = signature.produces, results.count == 1
        else { return nil }
        return results[0]
    }

    /// `items` with each marker for `hole` replaced by `replacement`, through
    /// code blocks.
    static func splicing(_ items: [any Item], hole: Int, with replacement: [any Item]) -> [any Item] {
        items.flatMap { item -> [any Item] in
            if holeNumber(item) == hole { return replacement }
            if let block = item.exactly(CodeItem.self), block.value.contains(where: { containsMarker($0) }) {
                return [CodeItem(splicing(block.value, hole: hole, with: replacement))]
            }
            return [item]
        }
    }

    /// A structure from a template whose markers number into `holeStacks` and
    /// `roles`: holes no longer used are dropped and the rest renumbered by first
    /// appearance.
    static func built(_ template: [any Item], holeStacks: [PushStack], roles: [Role],
                      output: PushStack) -> AbstractCrux {
        var order: [Int] = []
        visitMarkers(template) { if !order.contains($0) { order.append($0) } }
        let renumber = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        let renumbered = mapMarkers(template) { marker(renumber[$0] ?? $0) }
        return AbstractCrux(template: renumbered, holeStacks: order.map { holeStacks[$0] },
                            roles: order.map { roles[$0] }, output: output,
                            subtrees: [Subtree(start: 0, end: renumbered.count, stack: output)])
    }
}
