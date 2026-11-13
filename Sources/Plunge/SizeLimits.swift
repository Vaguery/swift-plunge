//
//  SizeLimits.swift
//  Plunge
//
//  Created by Bill Tozier on 7/13/26.
//

nonisolated extension PushStack {
    /// Whether items pushed to this stack are subject to size limits.
    ///
    /// The channels (`.error` and `.print`) are exempt: an overflow report must
    /// always land, and a print must never be refused. Their total still counts
    /// toward `maxLiveWeight`, so the memory guard bounds them.
    var enforcesSizeLimits: Bool {
        !isChannel
    }
}


nonisolated extension Interpreter {

    /// The element count of a vector item, or `nil` for non-vector items.
    func vectorLength(of item: any Item) -> Int? { Self.vectorLength(item) }

    /// Generic over the item's concrete type, so the existential is opened once at
    /// the call and each type test is a metadata pointer compare. A matching type is
    /// then read with `unsafeBitCast`, which is exact because `T` *is* that type.
    /// Before, each test was followed by an `as?` cast out of the existential, a
    /// runtime `swift_dynamicCast` on every push (Phase 4 profile).
    private static func vectorLength<T: Item>(_ item: T) -> Int? {
        if T.self == VecIntItem.self { return unsafeBitCast(item, to: VecIntItem.self).value.count }
        if T.self == VecDoubleItem.self { return unsafeBitCast(item, to: VecDoubleItem.self).value.count }
        if T.self == VecBoolItem.self { return unsafeBitCast(item, to: VecBoolItem.self).value.count }
        if T.self == VecStringItem.self { return unsafeBitCast(item, to: VecStringItem.self).value.count }
        return nil
    }

    /// Reports why an item is too large to push, or `nil` if it is within limits.
    ///
    /// Only the kinds of item that can grow without bound during execution are
    /// checked — vectors (repeat/concat inside loops), strings (concat/repeat),
    /// and code (`exec`/`code` combinators and recursion). A single oversized
    /// value is refused at the push boundary; the instruction's other results
    /// are unaffected. Stack depth and numeric magnitude are intentionally not
    /// limited here.
    func overflow(of item: any Item) -> String? { overflow(ofOpened: item) }

    /// `overflow(of:)` with the existential opened; see `vectorLength(_:)`.
    private func overflow<T: Item>(ofOpened item: T) -> String? {
        if let length = Self.vectorLength(item), length > config.maxVectorLength {
            return "vector length \(length) exceeds maxVectorLength \(config.maxVectorLength)"
        }
        // `utf8.count` is O(1) and never less than the character count, so a string
        // under the cap in bytes is under it in characters, and only a long one pays
        // for the O(n) character count.
        if T.self == StringItem.self {
            let string = unsafeBitCast(item, to: StringItem.self).value
            if string.utf8.count > config.maxStringLength, string.count > config.maxStringLength {
                return "string length \(string.count) exceeds maxStringLength \(config.maxStringLength)"
            }
        }
        if T.self == CodeItem.self {
            let code = unsafeBitCast(item, to: CodeItem.self)
            if code.flatSize > config.maxCodePoints {
                return "code size \(code.flatSize) exceeds maxCodePoints \(config.maxCodePoints)"
            }
        }
        // Stack safety rather than size: walking or releasing nested structure
        // costs a stack frame per level, and wrapping adds a level without adding
        // points or weight, so no cap above sees it. Counted through iterators as
        // well as blocks: an iterator holds blocks and is quoted into them, and
        // that alternation nested thousands deep killed a worker thread rendering
        // it (the second dual-mode stress run, in the runaway guard).
        if item.nestingDepth > config.maxCodeDepth {
            return "nesting depth \(item.nestingDepth) exceeds maxCodeDepth \(config.maxCodeDepth)"
        }
        // The recursive backstop: catches nested content the per-dimension caps
        // above miss (a vector of long strings, code whose leaves are large).
        if item.weight > config.maxItemWeight {
            return "item weight \(item.weight) exceeds maxItemWeight \(config.maxItemWeight)"
        }
        return nil
    }
}
