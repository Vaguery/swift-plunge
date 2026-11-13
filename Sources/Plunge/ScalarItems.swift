//
//  ScalarItems.swift
//  Plunge
//
//  The item types that hold a single value: bools, chars, doubles, instructions,
//  ints and strings.
//  Split out of Items.swift, which keeps the `Item` protocol and the provenance law.
//

import Foundation


/// A bool: an item of the `.bool` stack.
public nonisolated struct BoolItem: Item, Equatable, Pretty {
    public var value: Bool
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: Bool, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }

    public static func == (lhs: BoolItem, rhs: BoolItem) -> Bool {
        lhs.value == rhs.value
    }

    public func pretty() -> String {
        "\(value)"
    }
}

/// A single character: an item of the `.char` stack.
public nonisolated struct CharItem: Item, Equatable, Comparable, Pretty {
    public var value: Character
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: Character, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }

    public static func == (lhs: CharItem, rhs: CharItem) -> Bool {
        lhs.value == rhs.value
    }

    public static func < (lhs: CharItem, rhs: CharItem) -> Bool {
        lhs.value < rhs.value
    }

    /// The character in single quotes, with `'`, `\\` and non-printing characters
    /// escaped: `'x'`, `'\''`, `'\n'`.
    public func pretty() -> String {
        "'\(String(value).escaped(for: "'"))'"
    }

}

/// A 64-bit floating-point number: an item of the `.double` stack.
public nonisolated struct DoubleItem: Item, Equatable, Comparable, Pretty {
    public var value: Double
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: Double, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }

    public static func == (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        lhs.value == rhs.value
    }

    public static func < (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        lhs.value < rhs.value
    }

    public func pretty() -> String {
        "\(value)"
    }
}

/// An instruction as an item in a program. Met on `.exec` it runs; inside a
/// code block it is data like anything else.
public nonisolated struct InstructionItem: Item, Equatable, Comparable, Pretty {
    public var value: PushInstruction
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: PushInstruction, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }

    public static func == (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        lhs.value == rhs.value
    }

    public static func < (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        lhs.value.rawValue < rhs.value.rawValue
    }

    public func pretty() -> String {
        ".\(value)"
    }

}

/// A 64-bit integer: an item of the `.int` stack.
public nonisolated struct IntItem: Item, Equatable, Comparable, Pretty {
    public var value: Int
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }


    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: Int, call: [any Item] = []) {
        self.value = value
        self.callStorage = CallStorage(call)
    }

    public static func == (lhs: IntItem, rhs: IntItem) -> Bool {
        lhs.value == rhs.value
    }

    public static func < (lhs: IntItem, rhs: IntItem) -> Bool {
        lhs.value < rhs.value
    }

    public func pretty() -> String {
        "\(value)"
    }
}

/// A string: an item of the `.string` stack.
public nonisolated struct StringItem: Item, Equatable, Comparable, Pretty {
    public var value: String
    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    /// The size and depth of this item's history.
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    /// The string's UTF-8 length, which a native `String` stores, so this is O(1).
    /// Not cached: a stored copy would put a `StringItem` over the three words an
    /// `any Item` holds inline (see `CallStorage`).
    public var weight: Int { value.utf8.count }

    /// Where each character came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    /// `members`, if given, must line up with the characters. Character boundaries
    /// can move when strings are joined (a combining mark after a letter), so a
    /// list that does not line up exactly is dropped, and the characters are
    /// addressed from the string instead.
    public init(_ value: String, call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: String, call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { Containment.aligned($0, with: Array(value)) })
    }

    public static func == (lhs: StringItem, rhs: StringItem) -> Bool {
        lhs.value == rhs.value
    }

    public static func < (lhs: StringItem, rhs: StringItem) -> Bool {
        lhs.value < rhs.value
    }

    /// The string in double quotes, with `"`, `\\` and non-printing characters
    /// (`\n`, `\t`, `\r` and the rest) escaped as Swift writes them, so the text
    /// between the quotes can never be mistaken for the end of the string.
    public func pretty() -> String {
        "\"\(value.escaped(for: "\""))\""
    }
}


nonisolated extension String {
    /// This text as it prints between `quote` marks: the quote mark itself and
    /// `\\` escaped, and every character that might not show on a page written
    /// as an escape (`\n`, `\t`, `\r`, `\0`, `\u{…}`). The other kind of quote
    /// mark is left alone, so a string may hold `'` and a char may be `"`. One
    /// routine for strings, chars and the strings inside a vector, so the three
    /// agree.
    ///
    /// **Nothing invisible is left raw**, so the printed text can be read back
    /// exactly: besides the ASCII controls, that means every space but the plain
    /// one (no-break space, ideographic space), the line and paragraph separators,
    /// and the format characters (zero-width space and joiner, direction marks,
    /// the byte-order mark), along with unassigned, private-use and surrogate
    /// code points.
    func escaped(for quote: Character) -> String {
        var text = ""
        for scalar in unicodeScalars {
            if scalar == "\"" || scalar == "'" {
                text += Character(scalar) == quote ? "\\\(scalar)" : String(scalar)
            } else if scalar.isASCII {
                text += scalar.escaped(asASCII: false)
            } else if scalar.mightNotShow {
                let hex = String(scalar.value, radix: 16, uppercase: true)
                text += "\\u{" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex + "}"
            } else {
                text.unicodeScalars.append(scalar)
            }
        }
        return text
    }
}

nonisolated extension Unicode.Scalar {
    /// Whether this non-ASCII character can be invisible, or change the layout,
    /// when printed: a space, a line or paragraph separator, a control or format
    /// character, or a code point with no assigned glyph.
    var mightNotShow: Bool {
        switch properties.generalCategory {
        case .spaceSeparator, .lineSeparator, .paragraphSeparator, .control, .format,
             .unassigned, .privateUse, .surrogate: true
        default: false
        }
    }
}
