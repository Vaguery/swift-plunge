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
    func vectorLength(of item: any Item) -> Int? {
        switch item {
        case let v as VecIntItem: v.value.count
        case let v as VecDoubleItem: v.value.count
        case let v as VecBoolItem: v.value.count
        case let v as VecStringItem: v.value.count
        default: nil
        }
    }

    /// Reports why an item is too large to push, or `nil` if it is within limits.
    ///
    /// Only two kinds of item can grow without bound during execution — vectors
    /// (via repeat/concat inside loops) and code (via `exec`/`code` combinators
    /// and recursion) — so only those are checked. A single oversized value is
    /// refused at the push boundary; the instruction's other results are
    /// unaffected. Stack depth and numeric magnitude are intentionally not
    /// limited here.
    func overflow(of item: any Item) -> String? {
        if let length = vectorLength(of: item), length > config.maxVectorLength {
            return "vector length \(length) exceeds maxVectorLength \(config.maxVectorLength)"
        }
        if let code = item as? CodeItem, code.flatSize > config.maxCodePoints {
            return "code size \(code.flatSize) exceeds maxCodePoints \(config.maxCodePoints)"
        }
        return nil
    }
}
