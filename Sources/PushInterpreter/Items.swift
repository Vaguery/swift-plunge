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

// MARK: - The provenance law
//
// An item's `call` records how to rebuild it, and `crux()` reads that record
// back out as runnable Push source. The record is NOT a trace of what ran. Its
// one obligation is:
//
//     running an item's crux on a fresh interpreter reproduces that item's
//     value, on that item's stack.
//
// Combinatory rearrangement cannot affect that obligation, so it must not be
// recorded — recording it is what made `call` grow without bound. For each
// result a Behavior returns:
//
//  1. Rearrangement WITHIN one stack is free: the result keeps its argument's
//     `call` untouched. Covers dup/swap/rot/pop/flush/yank/yankDup/deepDup/
//     shove, the exec combinators (execK, execS, execIf), and every body copy
//     or re-pushed continuation token an iteration emits.
//
//  2. Relocation ACROSS stacks is not free: `.intQuote` moves a value from
//     `.int` to `.code`, and a crux omitting it would leave an int where a code
//     item belongs. These record `call = [args…, InstructionItem(name)]`.
//     Transit does not count: an arg pushed to `.exec` that `pushDefault`
//     returns to `.int` has moved nowhere, so rule 1 applies.
//
//  3. A genuinely new value records `call = [args…, InstructionItem(name)]` —
//     args in the order that re-runs postfix, instruction last.
//
//  4. A freshly minted instruction token records nothing. Its crux is itself.
//
//  5. When a Behavior puts SEVERAL results on ONE stack, each result records the
//     discard that surfaces it, right there in its own `call`:
//
//         call: [s, .stringPushAllChars, IntItem(2), .charPopItems]
//
//     The count is taken from the END of that stack's results, NOT the order
//     they were produced in: `distribute` prepends Routers one at a time, so the
//     last one pushed ends up on top. Of N results on a stack, the one at
//     position i needs `N - 1 - i` pops — the first produced is the deepest. The
//     top one needs none and records nothing extra. Count N and i among
//     same-stack results only: an instruction emitting one `.char` and three
//     `.exec` items has N = 1 on `.char`.
//
// `crux()` needs no special case for any of this — it walks `call` and lets each
// element speak. Recording the pops as ordinary items rather than as a separate
// `index` field is deliberate: the Behavior knows exactly what it pushed and
// where, so it states the selection outright instead of leaving `crux()` to
// re-derive a stack from the item's type.
//
// Growth that survives this law is honest (a value really was accumulated), and
// is bounded by the `callWeight` budget in `Interpreter.push`.

public nonisolated protocol Item: Pretty, Sendable {
    associatedtype Value
    var call: [any Item] {get set}
    var isContingent: Bool {get set}
    var value: Value {get set}

    /// Declared here (not only in an extension) so it dispatches dynamically
    /// through `any Item` — same reason as `weight` below. `IteratorItem`
    /// overrides it, and a protocol-extension-only method would statically
    /// dispatch to the default and silently ignore that override.
    func crux() -> [any Item]

    /// A recursive memory-proxy: the total primitive content this item holds,
    /// summed through nesting (a vector's elements, a string's characters, a
    /// code block's leaves). Scalars weigh 1. Container types store it, computed
    /// once at construction. Declared here (not only in an extension) so it
    /// dispatches correctly through `any Item`.
    var weight: Int {get}

    /// The provenance counterpart of `weight`: roughly the number of items
    /// `crux()` would emit for this item, and so a proxy for both the memory the
    /// history occupies and the size of the reconstruction. Bounded by
    /// `maxCallWeight` at the push boundary (`Interpreter.push`).
    ///
    /// Unlike `weight` this cannot be a construction-time `let`: `value` is never
    /// mutated after construction, but `call` *is* reassigned during execution.
    /// So each struct stores it and refreshes it from `call`'s `didSet`. It is
    /// maintained rather than computed on demand because the case that matters —
    /// a long accumulation chain — would otherwise cost a full walk per push, and
    /// re-walking a chain that grows by one each step is the quadratic behaviour
    /// this whole exercise exists to remove.
    var callWeight: Int {get}

    func isEqual(to other: any Item) -> Bool
}

nonisolated extension Item {
    // Default for scalar items (Bool, Int, Double, Char, Instruction, Error):
    // one unit each. Container types override with a stored, memoized weight.
    public var weight: Int { 1 }


    /// The `callWeight` for a freshly assigned `call`. Each child already stores
    /// its own, so this is O(call.count) — not O(chain) — which is what keeps
    /// maintaining it cheap.
    ///
    /// Saturating rather than trapping: provenance is a DAG, so a shared node
    /// counted once per path can in principle exceed `Int.max` even though the
    /// stored graph is small. Saturating keeps the over-budget check firing;
    /// wrapping would make it silently pass.
    static func weighCall(_ call: [any Item]) -> Int {
        var total = 1
        for child in call {
            let (sum, overflowed) = total.addingReportingOverflow(child.callWeight)
            total = overflowed ? Int.max : sum
        }
        return total
    }
}

nonisolated extension Item where Self: Equatable {
    public func isEqual(to other: any Item) -> Bool {
        guard let otherWithSameType = other as? Self else { return false }
        return self == otherWithSameType
    }
}


nonisolated extension Item {
    /// Runnable Push source that reproduces this item's value on this item's
    /// stack. See "The provenance law" above — this reads back what the law
    /// tells Behaviors to record.
    public func crux() -> [any Item] {
        // An empty `call` means "I am a literal", and a literal is already a
        // runnable program producing itself. This is also why eliding an
        // over-budget `call` (Interpreter.push) is always safe: it costs the
        // explanation, never the correctness of the reconstruction.
        if self.call.isEmpty { return [self] }
        return self.call.flatMap { $0.crux() }
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Bool, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
    }
    
    public static func == (lhs: BoolItem, rhs: BoolItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}

public nonisolated struct CharItem: Item, Equatable, Comparable, Pretty {
    public var value: Character
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Character, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
    }
    
    public static func == (lhs: CharItem, rhs: CharItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool

    /// The number of items in this code's fully flattened `.value`: every
    /// non-code item counts as one, and a nested `CodeItem` contributes its own
    /// `flatSize` (its contents), recursively — so `[1, [2, 3]]` is 3 and an
    /// empty or empty-nested block contributes nothing. Computed once here
    /// because `value` is never mutated after construction.
    public let flatSize: Int

    /// Recursive content weight: the sum of the weights of everything this block
    /// holds, at every level. Reuses each child's already-stored weight.
    public let weight: Int

    public init(_ value: [any Item], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.flatSize = value.reduce(0) { $0 + (($1 as? CodeItem)?.flatSize ?? 1) }
        self.weight = value.reduce(0) { $0 + $1.weight }
    }

    public static func == (lhs: CodeItem, rhs: CodeItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Double, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
    }
    
    public static func == (lhs: DoubleItem, rhs: DoubleItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: PushInstruction, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
    }
    
    public static func == (lhs: InstructionItem, rhs: InstructionItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: Int, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
    }
    
    public static func == (lhs: IntItem, rhs: IntItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: String, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.utf8.count
    }
    
    public static func == (lhs: StringItem, rhs: StringItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
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
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: [Bool], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.count
    }
    
    public static func == (lhs: VecBoolItem, rhs: VecBoolItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct VecDoubleItem: Item, Equatable, Pretty {
    public var value: [Double]
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: [Double], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.count
    }
    
    public static func == (lhs: VecDoubleItem, rhs: VecDoubleItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}


public nonisolated struct VecIntItem: Item, Equatable, Pretty {
    public var value: [Int]
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    public let weight: Int

    public init(_ value: [Int], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.count
    }
    
    public static func == (lhs: VecIntItem, rhs: VecIntItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct VecStringItem: Item, Equatable, Pretty {
    public var value: [String]
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool

    /// Total characters across all contained strings — the "total characters"
    /// measure that a plain element count would miss. O(element count) once.
    public let weight: Int

    public init(_ value: [String], call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
        self.weight = value.reduce(0) { $0 + $1.utf8.count }
    }
    
    public static func == (lhs: VecStringItem, rhs: VecStringItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
    }
    
    public func pretty() -> String {
        "\(value)"
    }
}



public nonisolated struct ErrorItem: Item, Equatable {
    public var value: String
    public var call: [any Item] {
        didSet { self.callWeight = Self.weighCall(call) }
    }

    /// See `Item.callWeight`. Maintained on assignment; `didSet` does not fire
    /// during `init`, so the initializer sets it directly.
    public private(set) var callWeight: Int = 1

    public var isContingent: Bool
    
    public init(_ value: String, call: [any Item] = [], isContingent: Bool =  false) {
        self.value = value
        self.call = call
        self.callWeight = Self.weighCall(call)
        self.isContingent = isContingent
    }
    
    public static func == (lhs: ErrorItem, rhs: ErrorItem) -> Bool {
        (lhs.value == rhs.value) &&
        (lhs.call == rhs.call) &&
        (lhs.isContingent == rhs.isContingent)
    }
    
    public func pretty() -> String {
        "« ‼️ \(value) »"
    }
}
