//
//  MemberItem.swift
//  PushInterpreter
//
//  Container types a typed operation can build or take elements from.
//

/// **A container whose elements can record where they came from** (`members`,
/// per-element provenance): the vectors and strings. What
/// `Behavior.assembling` and `Behavior.splitting` build.
nonisolated protocol MemberItem: ValueItem, HoldsMembers {
    init(_ value: Value, call: [any Item], members: Pieces?)
}

/// **A container an element can be taken out of**, keeping that element's history
/// when it has one. What `Behavior.extracting` takes from.
nonisolated protocol TracingItem: MemberItem {
    associatedtype ElementItem: ValueItem
    /// How many elements there are.
    var elementCount: Int { get }
    /// The value of element `index`.
    func element(at index: Int) -> ElementItem.Value
    /// Element `index` as its origin says to take it out: the item that went in,
    /// or its address in its source; nil when it has no origin of its own.
    func tracedElement(at index: Int, _ recording: ProvenanceRecording) -> (any Item)?
}

nonisolated extension StringItem: MemberItem, TracingItem {
    typealias ElementItem = CharItem
    var elementCount: Int { value.count }
    func element(at index: Int) -> Character { value[value.index(value.startIndex, offsetBy: index)] }
    func tracedElement(at index: Int, _ recording: ProvenanceRecording) -> (any Item)? {
        traced(at: index, element(at: index), recording)
    }
}
