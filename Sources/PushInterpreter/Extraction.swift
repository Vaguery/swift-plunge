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
