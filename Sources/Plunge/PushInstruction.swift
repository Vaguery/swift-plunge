//
//  PushInstruction.swift
//  Plunge
//
//  Every instruction: a named one, or a member of the input or constant family
//  (2026-11-19, swift-plunge #55).
//

/// Every instruction in the language: a named instruction such as `.intAdd`, or a
/// member of one of two numbered families, the inputs and the constants.
///
/// ```swift
/// let add: PushInstruction = .intAdd        // a named instruction
/// let x: PushInstruction = .input(0)        // pushes training case input 0
/// let c: PushInstruction = .constant(12)    // pushes the individual's constant 12
/// ```
///
/// **Names.** An instruction's ``rawValue`` is its name, the one the
/// <doc:InstructionReference> lists it under: `"intAdd"`, `"input0"`,
/// `"constant12"`. Encoding, decoding and printing all use it, so `.input(0)`
/// prints as `.input0`.
///
/// **The families have no last member.** `.input(k)` and `.constant(k)` exist
/// for every `k` of 0 or more, so a problem can have as many inputs, and an
/// individual as many constants, as it needs. The language lists the first few
/// of each (``listedInputCount`` and ``listedConstantCount``) wherever it lists
/// its instructions, and those are the ones random code draws from; the rest
/// behave the same way and are made when first used.
///
/// **Constants have no type.** A constant's slot holds an item of any type, and
/// the item goes to its own stack when the instruction runs, as an input does.
/// So to change a constant you change the value an individual binds to it; its
/// instruction says only which slot to read. See <doc:InputsAndConstants>.
///
/// In a program an instruction is wrapped in an ``InstructionItem``; inside
/// `program { … }` it can be written bare. To ask what an instruction does, use
/// ``Runner/summary(of:)`` and ``Runner/signature(of:)``.
public nonisolated enum PushInstruction: Sendable, Hashable {
    /// A named instruction, such as `.intAdd`. Every name also has a shorthand,
    /// so `.named(.intAdd)` and `.intAdd` are the same instruction.
    case named(InstructionName)
    /// Pushes the value its training case binds to input `slot`.
    case input(Int)
    /// Pushes the value its individual binds to constant `slot`.
    case constant(Int)
}


// MARK: - Families

public nonisolated extension PushInstruction {

    /// How many inputs the language lists: `.input(0)` through `.input(9)`. More
    /// can be used; these are the ones its lists of instructions include.
    static let listedInputCount = 10

    /// How many constants the language lists: `.constant(0)` through
    /// `.constant(79)`. More can be used; these are the ones its lists of
    /// instructions include, and the ones random code assigns.
    static let listedConstantCount = 80

    /// The name, for a named instruction; nil for an input or a constant.
    var name: InstructionName? {
        if case .named(let name) = self { name } else { nil }
    }

    /// The slot number, for an input or a constant; nil for a named instruction.
    var slot: Int? {
        switch self {
        case .named: nil
        case .input(let slot), .constant(let slot): slot
        }
    }

    /// Whether this is an input: `.input(k)` for some `k`.
    var isInput: Bool {
        if case .input = self { true } else { false }
    }

    /// Whether this is a constant: `.constant(k)` for some `k`.
    var isConstant: Bool {
        if case .constant = self { true } else { false }
    }
}

nonisolated extension PushInstruction {

    /// The listed member that stands for this instruction's family in the tables
    /// built once from the language (signatures, tags, roles): `.input(0)` for any
    /// input, `.constant(0)` for any constant, and a named instruction itself.
    /// Every member of a family has the same signature and tags.
    var representative: PushInstruction {
        switch self {
        case .named: self
        case .input: .input(0)
        case .constant: .constant(0)
        }
    }
}


// MARK: - Names

extension PushInstruction: RawRepresentable {

    /// The instruction named `rawValue`: a named instruction (`"intAdd"`), an input
    /// (`"input12"`) or a constant (`"constant3"`). Nil for anything else,
    /// including a slot number written with a sign or a leading zero (`"input07"`),
    /// so that every instruction has exactly one name.
    public nonisolated init?(rawValue: String) {
        if let name = InstructionName(rawValue: rawValue) {
            self = .named(name)
        } else if let slot = Self.slotNumber(in: rawValue, after: "input") {
            self = .input(slot)
        } else if let slot = Self.slotNumber(in: rawValue, after: "constant") {
            self = .constant(slot)
        } else {
            return nil
        }
    }

    /// The instruction's name: `"intAdd"`, `"input12"`, `"constant3"`.
    public nonisolated var rawValue: String {
        switch self {
        case .named(let name): name.rawValue
        case .input(let slot): "input\(slot)"
        case .constant(let slot): "constant\(slot)"
        }
    }

    /// The number after `prefix` in `text`, if `text` is `prefix` and then the
    /// digits of a number of 0 or more, written without a leading zero.
    private nonisolated static func slotNumber(in text: String, after prefix: String) -> Int? {
        guard text.hasPrefix(prefix) else { return nil }
        let digits = text.dropFirst(prefix.count)
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isWholeNumber }),
              digits == "0" || digits.first != "0" else { return nil }
        return Int(digits)
    }
}

extension PushInstruction: CustomStringConvertible {
    /// The instruction's name.
    public nonisolated var description: String { rawValue }
}

extension PushInstruction: Codable {
    // Encoded as its name, a single string, as it was when every instruction was
    // a case of one string-backed enum.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let instruction = PushInstruction(rawValue: name) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "no instruction is named \(name)")
        }
        self = instruction
    }

    public nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension PushInstruction: CaseIterable {
    /// Every named instruction, then the listed inputs and the listed constants.
    /// The families go on past these (see ``listedInputCount``).
    public nonisolated static let allCases: [PushInstruction] =
        InstructionName.allCases.map(PushInstruction.named)
        + (0..<listedInputCount).map(PushInstruction.input)
        + (0..<listedConstantCount).map(PushInstruction.constant)
}

extension PushInstruction {
    // Hashed by small integers, not by the name's string: instructions key the
    // tables a run consults on every step.
    public nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .named(let name):
            hasher.combine(0)
            hasher.combine(name.ordinal)
        case .input(let slot):
            hasher.combine(1)
            hasher.combine(slot)
        case .constant(let slot):
            hasher.combine(2)
            hasher.combine(slot)
        }
    }
}
