//
//  Extraction.swift
//  PushInterpreter
//
//  Which element an `extracting` body takes out of which container.
//

/// **An element to take out of a container**, as an `extracting` body names it.
/// The constructor hands back the element itself when it kept a history
/// (`Containment`), and otherwise builds it with the instruction's own `call`.
nonisolated struct Extraction<Container: TracingItem> {
    let container: Container
    let index: Int

    init(_ container: Container, at index: Int) {
        self.container = container
        self.index = index
    }
}


/// **What a find found** (`Behavior.finding`): the element's index and value,
/// and the container it came from when that container traces its elements'
/// origins (nil for a block, whose items carry no origins).
nonisolated struct Found<Value> {
    let index: Int
    let value: Value
    let container: (any TracingItem)?

    init(_ value: Value, at index: Int, in container: (any TracingItem)? = nil) {
        self.index = index
        self.value = value
        self.container = container
    }
}
