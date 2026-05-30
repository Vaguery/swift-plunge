//
//  Items.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


nonisolated protocol Pushable {
    associatedtype Sometype
    var value: Sometype { get }
    func pretty() -> String
    func prettyHistory() -> String
}


struct Item<T:Equatable> : Pushable {
    let value: T
    let call: [Item]
    let isContingent: Bool
    let index: Int

    init(_ v:T,
         _ call:[Item] = [],
         isContingent: Bool = false,
         index:Int = 0) {
        self.value = v
        self.call  = call
        self.isContingent = isContingent
        self.index = index
    }
        
    func pretty() -> String {
        return "\(value)"
    }
    
    func prettyHistory() -> String {
        if self.call.isEmpty {
            return self.pretty()+":()"
        } else {
            var result = self.pretty() + ":( "
            for h in self.call {
                result += (h.prettyHistory() + " ")
            }
            result += " )"
            return result
        }
    }
}

extension Item : Equatable where T:Equatable {
    static func == (lhs: Item<T>, rhs: Item<T>) -> Bool {
        return (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.index == rhs.index)
    }
}

struct Error : Pushable {
    let value: String
    let call: [any Pushable]

    init(_ v:String,
         _ call:[any Pushable] = []) {
        self.value = v
        self.call  = call
    }
    
    func pretty() -> String {
        return "Error: \"\(value)\""
    }
    
    func prettyHistory() -> String {
        if self.call.isEmpty {
            return self.pretty()+":()"
        } else {
            var result = self.pretty() + ":( "
            for h in self.call {
                result += (h.prettyHistory() + " ")
            }
            result += " )"
            return result
        }
    }
}

extension Error : Equatable {
    static func == (lhs: Error, rhs: Error) -> Bool {
        return (lhs.value == rhs.value)
    }
}


struct Code : Pushable {
    let value: [any Pushable]
    let call: [any Pushable]
    let isContingent: Bool
    let index: Int

    init(_ v:[any Pushable],
         _ call:[any Pushable] = [],
         isContingent: Bool = false,
         index:Int = 0) {
        self.value = v
        self.call  = call
        self.isContingent = isContingent
        self.index = index
    }
    
    func pretty() -> String {
        return "\(value)"
    }
    
    func prettyHistory() -> String {
        if self.call.isEmpty {
            return self.pretty()+":()"
        } else {
            var result = self.pretty() + ":( "
            for h in self.call {
                result += (h.prettyHistory() + " ")
            }
            result += " )"
            return result
        }
    }
}

