//
//  InstructionTag+Flow.swift
//  Plunge
//
//  The flow tags: net items on the stacks, whatever their types (2026-11-17).
//

public nonisolated extension InstructionTag {
    /// Leaves fewer items than it takes: `.intAdd` takes two and gives one.
    static let consumer = InstructionTag("consumer")
    /// Leaves as many items as it takes: `.stringReverse`.
    static let neutral = InstructionTag("neutral")
    /// Leaves more items than it takes: a literal, an input, a query that reads and leaves.
    static let producer = InstructionTag("producer")
}
