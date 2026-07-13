//
//  Builders.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//
//  Ergonomic construction helpers so callers can express programs, inputs, and
//  constants from ordinary Swift values instead of wrapping every literal in an
//  Item type by hand.

/// Wraps a raw Swift value in its matching `Item`, or returns it unchanged if it
/// already is one. Returns `nil` for unsupported types.
///
/// Supported: `Int`, `Double`, `Bool`, `String`, `Character`, `[Int]`,
/// `[Double]`, `[Bool]`, `[String]`, `PushInstruction`, and any existing
/// `Item`.
public nonisolated func pushItem(_ value: Any) -> (any Item)? {
    switch value {
    case let item as any Item:      item
    case let bool as Bool:          BoolItem(bool)
    case let int as Int:            IntItem(int)
    case let double as Double:      DoubleItem(double)
    case let string as String:      StringItem(string)
    case let char as Character:     CharItem(char)
    case let vector as [Int]:       VecIntItem(vector)
    case let vector as [Double]:    VecDoubleItem(vector)
    case let vector as [Bool]:      VecBoolItem(vector)
    case let vector as [String]:    VecStringItem(vector)
    case let instruction as PushInstruction: InstructionItem(instruction)
    default:                        nil
    }
}


/// Builds an instruction-keyed item map — for a `TrainingCase`'s inputs or an
/// `Individual`'s constants — from raw values, wrapping each with `pushItem`.
/// A value that cannot be converted is skipped.
///
/// ```swift
/// let inputs = bindings([.input0: 5, .input1: [1, 2, 3]])
/// let constants = bindings([.int0: 10, .string0: "seed"])
/// ```
public nonisolated func bindings(
    _ pairs: KeyValuePairs<PushInstruction, Any>
) -> [PushInstruction: any Item] {
    var result: [PushInstruction: any Item] = [:]
    for (instruction, value) in pairs {
        if let item = pushItem(value) { result[instruction] = item }
    }
    return result
}


/// A result builder for programs, so a `[any Item]` can be written as a block of
/// bare literals and instructions rather than wrapped `Item` values.
///
/// ```swift
/// let p = program {
///     PushInstruction.input0
///     10
///     PushInstruction.intAdd
/// }
/// ```
@resultBuilder
public nonisolated enum PushProgram {
    public static func buildBlock(_ parts: [any Item]...) -> [any Item] {
        parts.flatMap { $0 }
    }
    public static func buildExpression(_ item: any Item) -> [any Item] { [item] }
    public static func buildExpression(_ instruction: PushInstruction) -> [any Item] {
        [InstructionItem(instruction)]
    }
    public static func buildExpression(_ int: Int) -> [any Item] { [IntItem(int)] }
    public static func buildExpression(_ double: Double) -> [any Item] { [DoubleItem(double)] }
    public static func buildExpression(_ string: String) -> [any Item] { [StringItem(string)] }
    public static func buildExpression(_ bool: Bool) -> [any Item] { [BoolItem(bool)] }
    public static func buildArray(_ parts: [[any Item]]) -> [any Item] { parts.flatMap { $0 } }
    public static func buildOptional(_ part: [any Item]?) -> [any Item] { part ?? [] }
    public static func buildEither(first part: [any Item]) -> [any Item] { part }
    public static func buildEither(second part: [any Item]) -> [any Item] { part }
}

/// Builds a program from a `PushProgram` block. See `PushProgram`.
public nonisolated func program(@PushProgram _ build: () -> [any Item]) -> [any Item] {
    build()
}

/// Builds a program from a flat list of raw values, each converted with
/// `pushItem`. For nested code, use `CodeItem` directly or a `GenomeEncoding`.
public nonisolated func program(_ tokens: [Any]) -> [any Item] {
    tokens.compactMap { pushItem($0) }
}
