//
//  Stacks.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation
import DequeModule


nonisolated enum PushStack : String, CaseIterable, Comparable & Hashable {
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


nonisolated extension PushStack {

    /// `.exec` is (for now) the only heterogeneous stack: it interleaves
    /// instructions, code, and literals awaiting execution, so it holds
    /// `any Item`. Every other stack is homogeneous — including `.error`, which
    /// holds only `ErrorItem` — which is the invariant that makes the
    /// `a[i] as! XItem` casts scattered through the Behaviors safe.
    var isHeterogeneous: Bool {
        self == .exec
    }

    /// Whether `item` is a valid element for this stack. `.exec` accepts
    /// anything; every other stack accepts only its matching Item type.
    func accepts(_ item: any Item) -> Bool {
        switch self {
        case .bool:      return item is BoolItem
        case .int:       return item is IntItem
        case .double:    return item is DoubleItem
        case .char:      return item is CharItem
        case .string:    return item is StringItem
        case .code:      return item is CodeItem
        case .vecBool:   return item is VecBoolItem
        case .vecInt:    return item is VecIntItem
        case .vecDouble: return item is VecDoubleItem
        case .vecString: return item is VecStringItem
        case .error:     return item is ErrorItem
        case .exec:      return true
        }
    }
}

