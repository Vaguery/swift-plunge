//
//  VectorItems.swift
//  Plunge
//
//  The four vector item types.
//  Split out of Items.swift, which keeps the `Item` protocol and the provenance law.
//

import Foundation


/// A vector of bools: an item of the `.vecBool` stack.
public nonisolated struct VecBoolItem: Item, Equatable, Pretty {
    public var value: [Bool]
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

    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: [Bool], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [Bool], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.count
    }

    public static func == (lhs: VecBoolItem, rhs: VecBoolItem) -> Bool {
        lhs.value == rhs.value
    }

    public func pretty() -> String {
        "\(value)"
    }
}

/// A vector of doubles: an item of the `.vecDouble` stack.
public nonisolated struct VecDoubleItem: Item, Equatable, Pretty {
    public var value: [Double]
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

    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: [Double], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [Double], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.count
    }

    /// Equal as vector operations compare doubles: every NaN is the same NaN
    /// (`DoubleKey`), so a vector holding one still equals itself.
    public static func == (lhs: VecDoubleItem, rhs: VecDoubleItem) -> Bool {
        lhs.value.elementsEqual(rhs.value) { DoubleKey(value: $0) == DoubleKey(value: $1) }
    }

    public func pretty() -> String {
        "\(value)"
    }
}

/// A vector of ints: an item of the `.vecInt` stack.
public nonisolated struct VecIntItem: Item, Equatable, Pretty {
    public var value: [Int]
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

    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: [Int], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [Int], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.count
    }

    public static func == (lhs: VecIntItem, rhs: VecIntItem) -> Bool {
        lhs.value == rhs.value
    }

    public func pretty() -> String {
        "\(value)"
    }
}

/// A vector of strings: an item of the `.vecString` stack.
public nonisolated struct VecStringItem: Item, Equatable, Pretty {
    public var value: [String]
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


    /// Total characters across all contained strings — the "total characters"
    /// measure that a plain element count would miss. O(element count) once.
    public let weight: Int

    /// Where each element came from, when recording; see `Pieces`.
    var members: Pieces? { callStorage.members }

    /// Creates an item holding `value`. Leave `call` empty: the interpreter fills
    /// in histories as it runs.
    public init(_ value: [String], call: [any Item] = []) {
        self.init(value, call: call, members: nil)
    }

    init(_ value: [String], call: [any Item], members: Pieces?) {
        self.value = value
        self.callStorage = CallStorage(call, members: members.flatMap { $0.count == value.count ? $0 : nil })
        self.weight = value.reduce(0) { $0 + $1.utf8.count }
    }

    public static func == (lhs: VecStringItem, rhs: VecStringItem) -> Bool {
        lhs.value == rhs.value
    }

    public func pretty() -> String {
        "\(value)"
    }
}
