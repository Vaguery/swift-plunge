//
//  Stacks.swift
//  Plunge
//
//  Created by Bill Tozier on 5/30/26.
//

import Foundation
import DequeModule


public nonisolated enum PushStack: String, CaseIterable, Comparable & Hashable, Codable, Sendable {
    case bool, int, double, code, exec, char, string
    case vecBool, vecInt, vecDouble, vecString
    case iterator
    case binding
    case function
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

nonisolated extension PushStack {
    /// What one item of this stack is called in prose: "an int", "a block", "a
    /// vector of strings". For the instruction summaries of generated families.
    var noun: String {
        switch self {
        case .bool: "bool"
        case .int: "int"
        case .double: "double"
        case .char: "char"
        case .string: "string"
        case .code: "block"
        case .exec: "pending item"
        case .iterator: "iterator"
        case .binding: "binding"
        case .function: "function"
        case .error: "error"
        case .vecBool: "vector of bools"
        case .vecInt: "vector of ints"
        case .vecDouble: "vector of doubles"
        case .vecString: "vector of strings"
        }
    }

    /// `noun` with its article: "an int", "a block".
    var aNoun: String {
        ("aeiou".contains(noun.first!) ? "an " : "a ") + noun
    }

    /// `noun` for several items: "ints", "blocks", "vectors of strings".
    var plural: String {
        switch self {
        case .vecBool, .vecInt, .vecDouble, .vecString: "vectors" + noun.dropFirst("vector".count)
        default: noun + "s"
        }
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

    /// The stack at `ordinal`, the inverse of `ordinal`. `ordinal` must be below
    /// `allCases.count` (checked in debug builds only: this runs on every step).
    @inline(__always)
    init(ordinal: Int) {
        assert(ordinal >= 0 && ordinal < PushStack.allCases.count)
        self = unsafeBitCast(UInt8(ordinal), to: PushStack.self)
    }

    /// Every stack's pop/swap/popItems instruction, looked up once at launch
    /// rather than by building a name and searching every instruction's raw value per call.
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

/// Builds an `[any Item]` by initializing its storage in place.
///
/// `map` and `append` store each element through the standard library's
/// `_appendElementAssumeUniqueAndCapacity`, which the optimizer specializes from
/// taking an `any Item` to a generic over the opened type (the `Tf4…e` symbols).
/// For an item held in a heap box (a block, an iterator) that means making the box
/// unique, which copies the item when an argument shares it, then copying the
/// value out and boxing it afresh in the array: two allocations and a full copy
/// per argument, on every step (Phase 4 profile). `initialize(to:)` is inlined,
/// so the existential is copied as it is, which for a box is one retain.
nonisolated enum ItemArray {
    @inline(__always)
    static func make(count: Int, _ element: (Int) -> any Item) -> [any Item] {
        [any Item](unsafeUninitializedCapacity: count) { buffer, initialized in
            for index in 0..<count { (buffer.baseAddress! + index).initialize(to: element(index)) }
            initialized = count
        }
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

    /// Per-kind counts of the errors on `.error`, for the `errorCount*`
    /// instructions. See `errorCount(of:)`.
    private var errorTally = ErrorTally()

    /// Every stack starts with **storage of its own**. An empty `Deque()` shares
    /// one global empty buffer with every other empty deque in the process, and
    /// the per-step reads of a stack's count retain and release it: with most of
    /// a run's stacks empty, interpreters on different threads contended on that
    /// one reference count. Unoptimized, twelve interpreters in parallel ran 54
    /// times slower each than one alone; with their own buffers, 1.4 times.
    /// `Interpreter.clear` keeps a cleared stack's buffer for the same reason.
    init() {
        slots = (0..<PushStack.allCases.count).map { _ in Self.ownEmptyStack() }
    }

    /// An empty stack with a buffer of its own (see `init`).
    static func ownEmptyStack() -> Deque<any Item> { Deque(minimumCapacity: 1) }

    subscript(stack: PushStack) -> Deque<any Item>? {
        @inline(__always) get { slots[stack.ordinal] }
        @inline(__always) _modify { yield &slots[stack.ordinal] }
        @inline(__always) set {
            slots[stack.ordinal] = newValue ?? Self.ownEmptyStack()
            if stack == .error { errorTally = ErrorTally() }
        }
    }

    /// The item at `index` on `stack` (0 is the top), or nil past the bottom.
    ///
    /// A plain read. `stacks[stack]![index]` goes through the subscript's mutating
    /// accessor, and a mutable access to an item held in a heap box (a block, an
    /// iterator) copies the whole item if anything else shares the box, as an
    /// argument array does. The Phase 4 profile found that copy in every
    /// `Behavior.act`.
    func item(at index: Int, on stack: PushStack) -> (any Item)? {
        guard let deque = slots[stack.ordinal], index >= 0, index < deque.count else { return nil }
        return deque[index]
    }

    /// The summed `weight` of a stack's top `count` items (wrapping, as `liveWeight`
    /// is kept), for the weight accounting of a removal.
    ///
    /// A read, on purpose. Summing through `stacks[stack]![i].weight` in the
    /// interpreter went through the subscript's mutating accessor, and a mutable
    /// access to an item held in a heap box (a block, an iterator) makes the box
    /// unique first: with a Behavior's argument array still holding the same box,
    /// that copied the whole item just to read one integer of it (Phase 4 profile).
    func weight(ofTop count: Int, on stack: PushStack) -> Int {
        guard let deque = slots[stack.ordinal] else { return 0 }
        var total = 0
        for index in 0..<Swift.min(count, deque.count) {
            total = total.addingReportingOverflow(deque[index].weight).0
        }
        return total
    }

    /// The first stack in `PushStack.allStacks` order that is subject to size limits
    /// and holds more than `depth` items: the runaway guard's per-step gate.
    ///
    /// It runs on every step, and nearly always finds nothing, so that case touches
    /// nothing but the slots' counts:
    /// - **`mutating`, though it only reads.** Called on the interpreter's stored
    ///   `stacks`, a non-mutating method gets a copy of the struct, which retains
    ///   the slot array; a mutating one works in place. (The closure this replaced
    ///   also copied every stack's `Deque` out of its slot.)
    /// - **Ordinal order first.** The sorted order (a static array, retained to
    ///   walk) matters only for choosing among deep stacks, so it is read only
    ///   when one exists.
    mutating func firstLimitedStack(deeperThan depth: Int) -> PushStack? {
        var anyDeep = false
        for ordinal in slots.indices where (slots[ordinal]?.count ?? 0) > depth
            && PushStack(ordinal: ordinal).enforcesSizeLimits {
            anyDeep = true
            break
        }
        guard anyDeep else { return nil }
        for ordinal in Self.limitedOrdinalsInOrder where (slots[ordinal]?.count ?? 0) > depth {
            return PushStack(ordinal: ordinal)
        }
        return nil
    }

    private static let limitedOrdinalsInOrder = PushStack.allStacks.filter(\.enforcesSizeLimits).map(\.ordinal)

    /// How many errors of `kind` are on `.error`, in amortized O(1).
    ///
    /// Counting by scanning cost O(depth) per call, and `.error` is exempt from
    /// every size limit, so it keeps growing through a long run: two stress-run
    /// programs spent minutes in `errorCount*` this way. Keeping a tally on every
    /// push would charge every error (and starved instructions raise one
    /// constantly) for a query that is rare. So the tally is **lazy**: it covers
    /// the bottom `counted` errors, and each query counts only the ones pushed
    /// since the last.
    ///
    /// That rests on how `.error` changes: only `Interpreter.place` and
    /// `requiresProvenance` write it, both prepending at the top, and no
    /// instruction can pop or rearrange it. So the bottom `counted` errors are
    /// the ones already tallied. If `.error` is shorter than `counted`, it was
    /// emptied or replaced, and the tally starts over. Replacing the whole set
    /// (`reset`, `load`) or assigning the `.error` slot starts it over as well.
    /// *Error Tally Tests* hold it to a full recount.
    mutating func errorCount(of kind: ErrorKind) -> Int {
        let errors = slots[PushStack.error.ordinal] ?? Deque()
        if errors.count < errorTally.counted { errorTally = ErrorTally() }
        for i in 0..<(errors.count - errorTally.counted) {
            if let error = errors[i] as? ErrorItem { errorTally.counts[error.kind, default: 0] += 1 }
        }
        errorTally.counted = errors.count
        return errorTally.counts[kind] ?? 0
    }

    /// The tally behind `errorCount(of:)`: how many errors, counted from the
    /// bottom of `.error`, are in `counts`.
    private struct ErrorTally: Sendable {
        var counted = 0
        var counts: [ErrorKind: Int] = [:]
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
        if type == BindingItem.self { return .binding }
        if type == FunctionItem.self { return .function }
        if type == VecIntItem.self { return .vecInt }
        if type == VecDoubleItem.self { return .vecDouble }
        if type == VecBoolItem.self { return .vecBool }
        if type == VecStringItem.self { return .vecString }
        return nil
    }

    /// This stack's `PopItems` instruction — the token `crux()` emits to discard
    /// results stacked above the one it is reconstructing. Every stack has one
    /// (`stackFamily(for:)` builds the family for all of them), so the lookup
    /// cannot fail.
    var popItemsInstruction: PushInstruction { required(Self.popItemsByOrdinal, "PopItems") }

    /// This stack's `Swap` instruction. Every stack has one; used by a query's
    /// cleanup crux to lift its result past an argument buried on the same stack.
    var swapInstruction: PushInstruction { required(Self.swapByOrdinal, "Swap") }

    /// This stack's `Pop` instruction. Every stack has one.
    var popInstruction: PushInstruction { required(Self.popByOrdinal, "Pop") }
}
