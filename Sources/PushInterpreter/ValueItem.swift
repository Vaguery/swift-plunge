//
//  ValueItem.swift
//  PushInterpreter
//
//  An item type a typed operation can take or give (Roadmap #44).
//

/// **An item type with a home stack and a plain value.** Enough for a typed
/// operation (`Behavior.operation(_:takes:gives:…)`) to know which stack an
/// argument comes from, which stack a result goes to, and how to build the result
/// from a value and its `call`.
///
/// A new type joins the typed operations by conforming here: one declaration of
/// its stack and its initializer.
nonisolated protocol ValueItem: Item {
    static var pushStack: PushStack { get }
    init(_ value: Value, call: [any Item])
}

nonisolated extension CharItem: ValueItem {
    static var pushStack: PushStack { .char }
}
