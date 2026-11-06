//
//  SizeLimits.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

nonisolated extension PushStack {
    /// Whether items pushed to this stack are subject to size limits.
    ///
    /// `.error` is exempt so overflow reports can always land, and the planned
    /// `.memory` stack is unlimited by design — add its case here when it exists.
    var enforcesSizeLimits: Bool {
        switch self {
        case .error: false
        default: true
        }
    }
}


nonisolated extension Interpreter {

    /// The element count of a vector item, or `nil` for non-vector items.
    ///
    /// Exact-type tests first (see `PushStack.accepts`), so the common case — a
    /// scalar — costs pointer compares rather than four failed casts.
    func vectorLength(of item: any Item) -> Int? {
        let type = Swift.type(of: item)
        if type == VecIntItem.self, let vector = item as? VecIntItem { return vector.value.count }
        if type == VecDoubleItem.self, let vector = item as? VecDoubleItem { return vector.value.count }
        if type == VecBoolItem.self, let vector = item as? VecBoolItem { return vector.value.count }
        if type == VecStringItem.self, let vector = item as? VecStringItem { return vector.value.count }
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
    func overflow(of item: any Item) -> String? {
        if let length = vectorLength(of: item), length > config.maxVectorLength {
            return "vector length \(length) exceeds maxVectorLength \(config.maxVectorLength)"
        }
        let type = Swift.type(of: item)
        // `utf8.count` is O(1) and never less than the character count, so a string
        // under the cap in bytes is under it in characters, and only a long one pays
        // for the O(n) character count.
        if type == StringItem.self, let string = (item as? StringItem)?.value {
            if string.utf8.count > config.maxStringLength, string.count > config.maxStringLength {
                return "string length \(string.count) exceeds maxStringLength \(config.maxStringLength)"
            }
        }
        if type == CodeItem.self, let code = item as? CodeItem {
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
