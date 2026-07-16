//
//  Stacks.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import Foundation
import DequeModule


public nonisolated enum PushStack : String, CaseIterable, Comparable & Hashable, Codable, Sendable {
    case bool, int, double, code, exec, char, string
    case vecBool, vecInt, vecDouble, vecString
    case iterator
    case error


    public static func < (lhs: PushStack, rhs: PushStack) -> Bool {
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
        case .iterator:  return item is IteratorItem
        case .error:     return item is ErrorItem
        case .exec:      return true
        }
    }

    /// The stack an item comes to rest on, or `nil` for items that never rest
    /// on one — which is now only `InstructionItem`, since it executes rather
    /// than lands.
    ///
    /// Shared by `Interpreter.pushDefault`, which routes a literal popped off
    /// `.exec`, and by `crux()`, which needs an item's stack to name that
    /// stack's `PopItems` instruction. The two must agree, so they read one map.
    static func defaultStack(for item: any Item) -> PushStack? {
        switch item {
        case is BoolItem:      .bool
        case is CharItem:      .char
        case is CodeItem:      .code
        case is DoubleItem:    .double
        case is IntItem:       .int
        case is StringItem:    .string
        case is VecBoolItem:   .vecBool
        case is VecDoubleItem: .vecDouble
        case is VecIntItem:    .vecInt
        case is VecStringItem: .vecString
        case is IteratorItem:  .iterator
        case is ErrorItem:     .error
        default:               nil
        }
    }

    /// This stack's `PopItems` instruction — the token `crux()` emits to discard
    /// results stacked above the one it is reconstructing. Every stack has one
    /// (`combinators(for:)` builds the family for all of them), so the lookup
    /// cannot fail.
    var popItemsInstruction: PushInstruction {
        PushInstruction(rawValue: "\(self.rawValue)PopItems")!
    }
}

