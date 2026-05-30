//
//  Stacks.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation


enum PushStack : String, CaseIterable, Comparable & Hashable {
    case bool, int, float, code, exec, char, string
    case vecBool, vecInt, vecFloat, vecString
    case error
    
    
    static func < (lhs: PushStack, rhs: PushStack) -> Bool {
        if lhs == .exec {
            return true
        } else if rhs == .exec {
            return false
        } else {
            return "\(lhs)" < "\(rhs)"
        }
    }

    
    static let allStacks = PushStack.allCases.sorted(by: {$0 < $1})
}

