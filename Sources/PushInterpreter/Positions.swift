//
//  Positions.swift
//  PushInterpreter
//
//  Where any int lands inside a collection. The one place the rule lives, so
//  the vector, string and code families cannot drift apart again.
//

/// Turns any int a program supplies into a real position, by **clamping**:
/// below the range is the first position,
/// above it the last. Never modulo — wrapping made `100 .vecIntNth` a different
/// element for every input length, where a clamp means "the last" on all of them.
///
/// Two kinds of position, with different ranges:
///
/// - an **item** names an existing element: N of them, `0…N−1`. A collection with
///   no elements has no item positions, so callers check for that first and
///   answer with an `ErrorKind.emptyCollection` error.
/// - a **gap** names a place between elements, where something is inserted or a
///   cut is made: N+1 of them, `0…N`. Even an empty collection has one gap, so a
///   gap position always exists.
nonisolated enum Position {

    /// One of `count` item positions, `0…count−1`. `count` must be positive.
    static func item(_ index: Int, count: Int) -> Int {
        precondition(count > 0, "an empty collection has no item positions")
        return min(max(0, index), count - 1)
    }

    /// One of the `count + 1` gap positions, `0…count`.
    static func gap(_ index: Int, count: Int) -> Int {
        min(max(0, index), count)
    }
}
