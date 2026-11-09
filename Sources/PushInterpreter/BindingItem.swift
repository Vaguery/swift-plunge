//
//  BindingItem.swift
//  PushInterpreter
//
//  A keyed binding on the `.binding` stack (*Behavior coverage audit*
//  §9–§11, rulings 7–13; Roadmap #39).
//

/// **A binding: an int key and the item bound to it.** The `.binding` stack holds
/// these, and a variable is every pair with one key: the topmost is its current
/// value, the ones below it are older values it shadows, so each variable is a
/// stack of its own.
///
/// - **Keys are ints.** At every load the interpreter binds key *i* to input
///   slot *i*, for every bound input, and hands out fresh keys from the number
///   of input slots up (`Interpreter.nextRefKey`).
/// - **The value is any item but an iterator or a pair** (loop state is private,
///   and a pair of pairs has no binder). A copy of an item, bound, keeps the
///   item's own history (law 1), so dereferencing it gives back the item with
///   its provenance intact.
/// - **The key is `value`**, as an iterator's cursor is: the part a pair is
///   addressed by.
///
/// A literal pair in a program lands on `.binding`, as a block lands on `.code`.
/// One made by a binder records how to make it again (`BindingItem.rebuilt`).
public nonisolated struct BindingItem: Item, Pretty {
    /// The key.
    public var value: Int
    /// The item bound to the key.
    public let bound: any Item

    /// This item's provenance, behind one optional reference; see `CallStorage`.
    var callStorage = CallStorage.literal
    public var call: [any Item] {
        get { callStorage.call }
        set { callStorage = CallStorage(newValue) }
    }
    public var callMeasure: CallMeasure { callStorage.measure }
    public var callWeight: Int { Int(callStorage.measure.weight) }
    public var callDepth: Int { Int(callStorage.measure.depth) }

    public init(key: Int, bound: any Item, call: [any Item] = []) {
        self.value = key
        self.bound = bound
        self.callStorage = CallStorage(call)
    }

    /// The key.
    public var key: Int { value }

    /// The key and what it holds.
    public var weight: Int {
        let (sum, overflowed) = bound.weight.addingReportingOverflow(1)
        return overflowed ? Int.max : sum
    }

    /// A pair is a container: one level above what it holds.
    public var nestingDepth: Int { bound.nestingDepth + 1 }

    public func isEqual(to other: any Item) -> Bool {
        guard let other = other as? BindingItem else { return false }
        return value == other.value && bound.isEqual(to: other.bound)
    }

    /// `⟨3 ↦ 'a'⟩`. Rendered by `NestedRendering`, since the value can be a
    /// block holding pairs.
    public func pretty() -> String {
        NestedRendering.render(self)
    }
}

nonisolated extension BindingItem: HoldsCall {}


nonisolated extension BindingItem {

    /// The binder for each stack whose items can be bound.
    static let binders: [PushStack: PushInstruction] = [
        .bool: .boolRef, .int: .intRef, .double: .doubleRef, .char: .charRef, .string: .stringRef,
        .code: .codeRef, .vecBool: .vecBoolRef, .vecInt: .vecIntRef, .vecDouble: .vecDoubleRef,
        .vecString: .vecStringRef
    ]

    /// **How a pair binding `bound` to `key` is made again**, for its `call`:
    /// bind `bound` with its type's binder, clear away what the binder leaves
    /// (the fresh key on `.int`, and `bound` itself, which it read), then re-key
    /// the new pair to `key`:
    ///
    ///     5 .intRef .intPop .intPop .intRef_actuallyWas_12 .bindingRekey
    ///
    /// `key` carries its own history (a stand-in for a fresh key, or the
    /// argument a `bindingRekey` was given). Nil for an item with no binder.
    static func rebuilt(binding bound: any Item, to key: any Item) -> [any Item]? {
        guard let stack = PushStack.defaultStack(for: bound), let binder = binders[stack] else { return nil }
        return [bound, InstructionItem(binder), InstructionItem(.intPop), InstructionItem(stack.popInstruction),
                key, InstructionItem(.bindingRekey)]
    }
}
