//
//  Stacks.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation
import DequeModule


enum PushStack : String, CaseIterable, Comparable & Hashable {
    case bool, int, double, code, exec, char, string
    case vecBool, vecInt, vecDouble, vecString
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
    
    
    static func emptyStacks() -> [PushStack: Deque<any Item>] {
        PushStack.allStacks.reduce(into: [:]) {
            $0[$1] = Deque()
        }
    }

}

