//
//  Items.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


// building up the protocol infrastructure

protocol Pretty {
    func pretty() -> String
}

protocol Item: Pretty {
    var call: [any Item] {get set}
    var isContingent: Bool {get set}
    var index: Int {get set}
    
    func isEqual(to other: Item) -> Bool
}

extension Item where Self: Equatable {
    func isEqual(to other: Item) -> Bool {
        guard let otherWithSameType = other as? Self else { return false }
        return self == otherWithSameType
    }
}



func == (lhs: [any Item], rhs: [any Item]) -> Bool {
    // Arrays must have the same count to be equal
    guard lhs.count == rhs.count else { return false }
    
    // Compare elements line-by-line using zip
    return zip(lhs, rhs).allSatisfy { leftElement, rightElement in
        leftElement.isEqual(to: rightElement)
    }
}

//
//
//
//
// creating structs for each PushType

struct BoolItem: Item, Equatable, Pretty {
    var value: Bool
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: Bool, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: BoolItem, rhs: BoolItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    func pretty() -> String {
        "\(value)"
    }
}

struct CharItem: Item, Equatable, Comparable, Pretty {
    var value: Character
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: Character, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: CharItem, rhs: CharItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    static func < (lhs: CharItem, rhs: CharItem) -> Bool {
        lhs.value < rhs.value
    }
    
    func pretty() -> String {
        "'\(value)'"
    }

}


struct CodeItem: Item, Equatable, Pretty {
    var value: [any Item]
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: [any Item], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }

    static func == (lhs: CodeItem, rhs: CodeItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    func pretty() -> String {
        var result = "( "
        for i in value {
            result += "\(i.pretty()) "
        }
        result += " )"
        return result
    }

    
}


struct DoubleItem: Item, Equatable, Comparable, Pretty {
    var value: Double
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: Double, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    static func < (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        lhs.value < rhs.value
    }
    
    func pretty() -> String {
        "\(value)"
    }
}


struct InstructionItem: Item, Equatable, Comparable, Pretty {
    var value: PushInstruction
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: PushInstruction, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    static func < (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        lhs.value.rawValue < rhs.value.rawValue
    }
    
    func pretty() -> String {
        ".\(value)"
    }

}



struct IntItem: Item, Equatable, Comparable, Pretty {
    var value: Int
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: Int, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: IntItem, rhs: IntItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    static func < (lhs: IntItem, rhs: IntItem) -> Bool {
        lhs.value < rhs.value
    }
    
    func pretty() -> String {
        "\(value)"
    }
}



struct StringItem: Item, Equatable, Comparable, Pretty {
    var value: String
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: String, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: StringItem, rhs: StringItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    static func < (lhs: StringItem, rhs: StringItem) -> Bool {
        lhs.value < rhs.value
    }
    
    func pretty() -> String {
        "\"\(value)\""
    }
}


struct VecBoolItem: Item, Equatable, Pretty {
    var value: [Bool]
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: [Bool], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: VecBoolItem, rhs: VecBoolItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    func pretty() -> String {
        "\(value)"
    }
}



struct VecDoubleItem: Item, Equatable, Pretty {
    var value: [Double]
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: [Double], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: VecDoubleItem, rhs: VecDoubleItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    func pretty() -> String {
        "\(value)"
    }
}


struct VecIntItem: Item, Equatable, Pretty {
    var value: [Int]
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: [Int], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: VecIntItem, rhs: VecIntItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    func pretty() -> String {
        "\(value)"
    }
}



struct VecStringItem: Item, Equatable, Pretty {
    var value: [String]
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: [String], call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: VecStringItem, rhs: VecStringItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    func pretty() -> String {
        "\(value)"
    }
}



struct ErrorItem: Item, Equatable {
    var value: String
    var call: [any Item]
    var isContingent: Bool
    var index: Int
    
    init(_ value: String, call: [any Item] = [], isContingent: Bool =  false, index: Int = 0) {
        self.value = value
        self.call = call
        self.isContingent = isContingent
        self.index = index
    }
    
    static func == (lhs: ErrorItem, rhs: ErrorItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent) &&
        (lhs.index == rhs.index)
    }
    
    func pretty() -> String {
        "«\(value)»"
    }
}
