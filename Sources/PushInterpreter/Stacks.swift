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
    
    
    static func emptyStacks() -> StackSet {
        StackSet()
    }

}

nonisolated extension PushStack: CustomStringConvertible {
    /// The case name. Without this, interpolating a stack (`"missing args: .\(stack)"`)
    /// falls back to runtime reflection, which profiling caught allocating in the
    /// step loop. Raw values are the case names, so the text is unchanged.
    public var description: String { rawValue }
}

nonisolated extension PushStack {

    /// This stack's position in `allCases` — its slot in a `StackSet`.
    ///
    /// **Free, and derived rather than maintained.** A payload-free enum is stored
    /// as its case's declaration index, which is exactly the order `allCases`
    /// lists; reading that byte back is the whole computation. Adding a stack
    /// needs no table edit. `Stack Ordinal Tests` pins the assumption, and
    /// `unsafeBitCast` itself traps if the enum ever outgrows one byte.
    ///
    /// Why not a dictionary keyed by the stack: `PushStack` is String-backed, and
    /// its hash goes through the raw *string*. Profiling found that hashing on
    /// every stack access was about a fifth of all interpreter time.
    @inline(__always)
    var ordinal: Int { Int(unsafeBitCast(self, to: UInt8.self)) }

    /// Every stack's pop/swap/popItems instruction, looked up once at launch
    /// rather than by building a name and searching 608 raw values per call.
    /// `.error` has none of the three, so its entries are nil.
    private static let popItemsByOrdinal = allCases.map { PushInstruction(rawValue: "\($0.rawValue)PopItems") }
    private static let swapByOrdinal = allCases.map { PushInstruction(rawValue: "\($0.rawValue)Swap") }
    private static let popByOrdinal = allCases.map { PushInstruction(rawValue: "\($0.rawValue)Pop") }

    /// The instruction a crux needs from this stack. Asking `.error` — the one stack
    /// without pop/swap instructions — is a bug in the asking behavior, as it was
    /// when this was looked up by name.
    private func required(_ table: [PushInstruction?], _ suffix: String) -> PushInstruction {
        guard let instruction = table[ordinal] else {
            preconditionFailure(".\(self) has no \(suffix) instruction")
        }
        return instruction
    }
}

/// The interpreter's stacks: one `Deque` per `PushStack`, held in an array in
/// `allCases` order and addressed by `PushStack.ordinal`.
///
/// It reads like the dictionary it replaced — `stacks[.int]!.prepend(x)`,
/// `stacks[.code]?.count` — because the subscript is optional-returning and
/// mutates **in place** (it yields the stored slot, so no copy-on-write copy of a
/// stack is ever made by reaching into it). Every slot is always present; the
/// optional exists only so existing call sites keep their shape.
nonisolated struct StackSet: Sendable {
    private var slots: [Deque<any Item>?]

    init() {
        slots = Array(repeating: Deque(), count: PushStack.allCases.count)
    }

    subscript(stack: PushStack) -> Deque<any Item>? {
        @inline(__always) get { slots[stack.ordinal] }
        @inline(__always) _modify { yield &slots[stack.ordinal] }
        @inline(__always) set { slots[stack.ordinal] = newValue ?? Deque() }
    }

    /// Every stack, in `allCases` order.
    var keys: [PushStack] { PushStack.allCases }
    /// Every stack's contents, in `allCases` order.
    var values: [Deque<any Item>] { slots.map { $0 ?? Deque() } }
    var count: Int { slots.count }
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
    ///
    /// Compares exact types rather than casting (`is`): every Item is a struct, so
    /// the two mean the same thing, and a metatype comparison is a pointer compare
    /// where `is` on an existential is a runtime cast — which profiling found on
    /// every push.
    func accepts(_ item: any Item) -> Bool {
        if self == .exec { return true }
        return PushStack.defaultStack(for: item) == self
    }

    /// The stack an item comes to rest on, or `nil` for items that never rest
    /// on one — which is now only `InstructionItem`, since it executes rather
    /// than lands.
    ///
    /// Shared by `Interpreter.pushDefault`, which routes a literal popped off
    /// `.exec`, and by `crux()`, which needs an item's stack to name that
    /// stack's `PopItems` instruction. The two must agree, so they read one map.
    ///
    /// Exact-type comparison, not `is`, for the reason given at `accepts`. The
    /// common types are tested first.
    static func defaultStack(for item: any Item) -> PushStack? {
        let type = Swift.type(of: item)
        if type == IntItem.self { return .int }
        if type == DoubleItem.self { return .double }
        if type == BoolItem.self { return .bool }
        if type == CodeItem.self { return .code }
        if type == ErrorItem.self { return .error }
        if type == StringItem.self { return .string }
        if type == CharItem.self { return .char }
        if type == IteratorItem.self { return .iterator }
        if type == VecIntItem.self { return .vecInt }
        if type == VecDoubleItem.self { return .vecDouble }
        if type == VecBoolItem.self { return .vecBool }
        if type == VecStringItem.self { return .vecString }
        return nil
    }

    /// This stack's `PopItems` instruction — the token `crux()` emits to discard
    /// results stacked above the one it is reconstructing. Every stack has one
    /// (`combinators(for:)` builds the family for all of them), so the lookup
    /// cannot fail.
    var popItemsInstruction: PushInstruction { required(Self.popItemsByOrdinal, "PopItems") }

    /// This stack's `Swap` instruction. Every stack has one; used by a query's
    /// cleanup crux to lift its result past an argument buried on the same stack.
    var swapInstruction: PushInstruction { required(Self.swapByOrdinal, "Swap") }

    /// This stack's `Pop` instruction. Every stack has one.
    var popInstruction: PushInstruction { required(Self.popByOrdinal, "Pop") }
}

