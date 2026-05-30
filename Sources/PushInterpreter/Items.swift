//
//  Items.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


protocol Pushable {
    associatedtype Item
    var value: Item { get }
    func prettyHistory() -> String
}


struct Item<T> : Pushable {
    let value: T
    let call: [any Pushable]
    let isContingent: Bool
    let index: Int

    init(_ v:T,
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


