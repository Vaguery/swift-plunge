//
//  Items.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


// building up the protocol infrastructure

nonisolated protocol Pretty {
    func pretty() -> String
}

nonisolated protocol Item: Pretty, Sendable {
    associatedtype Value
    var call: [any Item] {get set}
    var isContingent: Bool {get set}
    var index: Int {get set}
    var value: Value {get set}
    
    func isEqual(to other: any Item) -> Bool
}

nonisolated extension Item where Self: Equatable {
    func isEqual(to other: any Item) -> Bool {
        guard let otherWithSameType = other as? Self else { return false }
        return self == otherWithSameType
    }
}


nonisolated extension Item {
    func crux() -> [any Item] {
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
nonisolated func == (lhs: [any Item], rhs: [any Item]) -> Bool {
    // Arrays must have the same count to be equal
    guard lhs.count == rhs.count else { return false }
    
    // Compare elements line-by-line using zip
    return zip(lhs, rhs).allSatisfy { leftElement, rightElement in
        leftElement.isEqual(to: rightElement)
    }
}











// creating structs for each PushType

nonisolated struct BoolItem: Item, Equatable, Pretty {
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

nonisolated struct CharItem: Item, Equatable, Comparable, Pretty {
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


nonisolated struct CodeItem: Item, Equatable, Pretty {
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
        result += ")"
        return result
    }

    
}


nonisolated struct DoubleItem: Item, Equatable, Comparable, Pretty {
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


nonisolated struct InstructionItem: Item, Equatable, Comparable, Pretty {
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



nonisolated struct IntItem: Item, Equatable, Comparable, Pretty {
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



nonisolated struct StringItem: Item, Equatable, Comparable, Pretty {
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


nonisolated struct VecBoolItem: Item, Equatable, Pretty {
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



nonisolated struct VecDoubleItem: Item, Equatable, Pretty {
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


nonisolated struct VecIntItem: Item, Equatable, Pretty {
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



nonisolated struct VecStringItem: Item, Equatable, Pretty {
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



nonisolated struct ErrorItem: Item, Equatable {
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
        "« ‼️ \(value) »"
    }
}
