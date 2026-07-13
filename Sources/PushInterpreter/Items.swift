//
//  Items.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


// building up the protocol infrastructure

public nonisolated protocol Pretty {
    func pretty() -> String
}

public nonisolated protocol Item: Pretty, Sendable {
    associatedtype Value
    var call: [any Item] {get set}
    var isContingent: Bool {get set}
    var index: Int {get set}
    var value: Value {get set}

    /// A recursive memory-proxy: the total primitive content this item holds,
    /// summed through nesting (a vector's elements, a string's characters, a
    /// code block's leaves). Scalars weigh 1. Container types store it, computed
    /// once at construction. Declared here (not only in an extension) so it
    /// dispatches correctly through `any Item`.
    var weight: Int {get}

    func isEqual(to other: any Item) -> Bool
}

nonisolated extension Item {
    // Default for scalar items (Bool, Int, Double, Char, Instruction, Error):
    // one unit each. Container types override with a stored, memoized weight.
    public var weight: Int { 1 }
}

nonisolated extension Item where Self: Equatable {
    public func isEqual(to other: any Item) -> Bool {
        guard let otherWithSameType = other as? Self else { return false }
        return self == otherWithSameType
    }
}


nonisolated extension Item {
    public func crux() -> [any Item] {
        var result = [any Item]()

        if self.call.isEmpty {
            result.append(self)
        } else if self.index > 0 && self.call[0] is CodeItem {
            let idx = self.index
            let motherBlock = self.call[0] as! CodeItem
            result.append(motherBlock.value[idx])
        } else {
            for item in self.call {
                result.append(contentsOf: item.crux())
            }
        }
        return result
    }
}






//  global == definition to help compare items that aren't the same exact type
//
public nonisolated func == (lhs: [any Item], rhs: [any Item]) -> Bool {
    // Arrays must have the same count to be equal
    guard lhs.count == rhs.count else { return false }
    
    // Compare elements line-by-line using zip
    return zip(lhs, rhs).allSatisfy { leftElement, rightElement in
        leftElement.isEqual(to: rightElement)
    }
}











// creating structs for each PushType

public nonisolated struct BoolItem: Item, Equatable, Pretty {
    public var value: Bool
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    
    public init(_ value: Bool, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    public static func == (lhs: BoolItem, rhs: BoolItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}

public nonisolated struct CharItem: Item, Equatable, Comparable, Pretty {
    public var value: Character
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    
    public init(_ value: Character, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    public static func == (lhs: CharItem, rhs: CharItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public static func < (lhs: CharItem, rhs: CharItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "'\(value)'"
    }

}


public nonisolated struct CodeItem: Item, Equatable, Pretty {
    public var value: [any Item]
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int

    /// The number of items in this code's fully flattened `.value`: every
    /// non-code item counts as one, and a nested `CodeItem` contributes its own
    /// `flatSize` (its contents), recursively — so `[1, [2, 3]]` is 3 and an
    /// empty or empty-nested block contributes nothing. Computed once here
    /// because `value` is never mutated after construction.
    public let flatSize: Int

    /// Recursive content weight: the sum of the weights of everything this block
    /// holds, at every level. Reuses each child's already-stored weight.
    public let weight: Int

    public init(_ value: [any Item], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
        self.flatSize = value.reduce(0) { $0 + (($1 as? CodeItem)?.flatSize ?? 1) }
        self.weight = value.reduce(0) { $0 + $1.weight }
    }

    public static func == (lhs: CodeItem, rhs: CodeItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public func pretty() -> String {
        var result = "( "
        for i in value {
            result += "\(i.pretty()) "
        }
        result += ")"
        return result
    }

    
}


public nonisolated struct DoubleItem: Item, Equatable, Comparable, Pretty {
    public var value: Double
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    
    public init(_ value: Double, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    public static func == (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public static func < (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}


public nonisolated struct InstructionItem: Item, Equatable, Comparable, Pretty {
    public var value: PushInstruction
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    
    public init(_ value: PushInstruction, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    public static func == (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public static func < (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        lhs.value.rawValue < rhs.value.rawValue
    }
    
    public func pretty() -> String {
        ".\(value)"
    }

}



public nonisolated struct IntItem: Item, Equatable, Comparable, Pretty {
    public var value: Int
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    
    public init(_ value: Int, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    public static func == (lhs: IntItem, rhs: IntItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public static func < (lhs: IntItem, rhs: IntItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct StringItem: Item, Equatable, Comparable, Pretty {
    public var value: String
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    public let weight: Int

    public init(_ value: String, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
        self.weight = value.utf8.count
    }
    
    public static func == (lhs: StringItem, rhs: StringItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public static func < (lhs: StringItem, rhs: StringItem) -> Bool {
        lhs.value < rhs.value
    }
    
    public func pretty() -> String {
        "\"\(value)\""
    }
}


public nonisolated struct VecBoolItem: Item, Equatable, Pretty {
    public var value: [Bool]
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    public let weight: Int

    public init(_ value: [Bool], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
        self.weight = value.count
    }
    
    public static func == (lhs: VecBoolItem, rhs: VecBoolItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct VecDoubleItem: Item, Equatable, Pretty {
    public var value: [Double]
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    public let weight: Int

    public init(_ value: [Double], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
        self.weight = value.count
    }
    
    public static func == (lhs: VecDoubleItem, rhs: VecDoubleItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}


public nonisolated struct VecIntItem: Item, Equatable, Pretty {
    public var value: [Int]
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    public let weight: Int

    public init(_ value: [Int], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
        self.weight = value.count
    }
    
    public static func == (lhs: VecIntItem, rhs: VecIntItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct VecStringItem: Item, Equatable, Pretty {
    public var value: [String]
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int

    /// Total characters across all contained strings — the "total characters"
    /// measure that a plain element count would miss. O(element count) once.
    public let weight: Int

    public init(_ value: [String], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
        self.weight = value.reduce(0) { $0 + $1.utf8.count }
    }
    
    public static func == (lhs: VecStringItem, rhs: VecStringItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct ErrorItem: Item, Equatable {
    public var value: String
    public var call: [any Item]
    public var isContingent: Bool
    public var index: Int
    
    public init(_ value: String, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    public static func == (lhs: ErrorItem, rhs: ErrorItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    public func pretty() -> String {
        "« ‼️ \(value) »"
    }
}
