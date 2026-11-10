//
//  InstructionTagging.swift
//  PushInterpreter
//
//  The table from tags to instructions, and the place to add your own.
//

/// **Which instructions carry which tags**: a value you can extend and combine.
///
/// ``standard`` is the library's seed: the tags each Behavior declares, and the
/// derived tags computed from its declarations (see ``InstructionTag``). Layer
/// your own over it:
///
/// ```swift
/// let mine = InstructionTagging.standard
///     .adding("psb:vectorAverage", to: [.vecIntSum, .vecDoubleSum])
/// let configuration = RunnerConfiguration(
///     disabledBehaviors: mine.instructions(taggedAnyOf: ["psb:vectorAverage"]))
/// ```
///
/// Tags describe; they are not meant to cut the language down. The usual search
/// runs with every instruction enabled, and an excluding tag is the rare,
/// deliberate exception. To let a search lean on tags without losing the
/// unusual instructions, use them as weights with a floor, or swap an instruction
/// for one of its ``neighbors(of:)``.
public nonisolated struct InstructionTagging: Sendable, Hashable, Codable {

    /// Each tag's instructions.
    public private(set) var members: [InstructionTag: Set<PushInstruction>]

    /// A tagging holding exactly `members`.
    public init(_ members: [InstructionTag: Set<PushInstruction>] = [:]) {
        self.members = members.filter { !$0.value.isEmpty }
    }

    /// The library's tags: declared at the Behaviors, and derived from their
    /// declarations. Every instruction in the language carries at least one.
    public static let standard: InstructionTagging = {
        var members = Interpreter.automaticTags
        for (tag, instructions) in Interpreter.declaredTags { members[tag, default: []].formUnion(instructions) }
        return InstructionTagging(members)
    }()

    /// Every tag with at least one instruction: the library's in display order,
    /// then any others alphabetically.
    public var tags: [InstructionTag] {
        let known = InstructionTag.known.filter { members[$0] != nil }
        let others = members.keys.filter { InstructionTag.entries[$0] == nil }.sorted { $0.rawValue < $1.rawValue }
        return known + others
    }

    /// The instructions carrying `tag`.
    public func instructions(tagged tag: InstructionTag) -> Set<PushInstruction> {
        members[tag] ?? []
    }

    /// The instructions carrying any of `tags`: for example, the set to disable.
    public func instructions(taggedAnyOf tags: some Sequence<InstructionTag>) -> Set<PushInstruction> {
        tags.reduce(into: []) { $0.formUnion(members[$1] ?? []) }
    }

    /// Every tag `instruction` carries.
    public func tags(of instruction: PushInstruction) -> Set<InstructionTag> {
        Set(members.filter { $0.value.contains(instruction) }.keys)
    }

    /// This tagging with `tag` also on `instructions`.
    public func adding(_ tag: InstructionTag, to instructions: some Sequence<PushInstruction>) -> InstructionTagging {
        var copy = self
        copy.add(tag, to: instructions)
        return copy
    }

    /// Puts `tag` on `instructions` as well.
    public mutating func add(_ tag: InstructionTag, to instructions: some Sequence<PushInstruction>) {
        members[tag, default: []].formUnion(instructions)
        if members[tag]?.isEmpty == true { members[tag] = nil }
    }

    /// This tagging and `other` together: each tag on every instruction either
    /// gives it.
    public func merging(_ other: InstructionTagging) -> InstructionTagging {
        var copy = self
        for (tag, instructions) in other.members { copy.add(tag, to: instructions) }
        return copy
    }

    /// How alike two instructions are by their tags: the tags they share over the
    /// tags either carries (0 to 1).
    public func similarity(_ first: PushInstruction, _ second: PushInstruction) -> Double {
        let (one, other) = (tags(of: first), tags(of: second))
        let either = one.union(other).count
        return either == 0 ? 0 : Double(one.intersection(other).count) / Double(either)
    }

    /// The instructions sharing a tag with `instruction`, most alike first (ties
    /// by name): candidates for a mutation that swaps one instruction for a
    /// relative.
    public func neighbors(of instruction: PushInstruction) -> [PushInstruction] {
        let own = tags(of: instruction)
        let candidates = instructions(taggedAnyOf: own).subtracting([instruction])
        return candidates
            .map { ($0, similarity(instruction, $0)) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.rawValue < $1.0.rawValue }
            .map(\.0)
    }
}
