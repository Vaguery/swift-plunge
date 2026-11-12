//
//  Arithmetic.swift
//  Plunge
//
//  The arithmetic of ints and doubles, once: the scalar instructions
//  (`intAdd`, `doubleDivide`, …) and their element-wise vector siblings
//  (`vecIntAdd`, `vecDoubleDivide`, …) call the same functions, so the two can
//  never disagree about a result or a refusal. `label` names the instruction in
//  a refusal's message.
//

nonisolated enum IntArithmetic {
    static func add(_ y: Int, _ x: Int, _ label: PushInstruction) throws(Refusal) -> Int {
        let (result, overflowed) = y.addingReportingOverflow(x)
        guard !overflowed else { throw Refusal("Overflow in .\(label): \(y) + \(x)") }
        return result
    }

    static func subtract(_ y: Int, _ x: Int, _ label: PushInstruction) throws(Refusal) -> Int {
        let (result, overflowed) = y.subtractingReportingOverflow(x)
        guard !overflowed else { throw Refusal("Overflow in .\(label): \(y) - \(x)") }
        return result
    }

    static func multiply(_ y: Int, _ x: Int, _ label: PushInstruction) throws(Refusal) -> Int {
        let (result, overflowed) = y.multipliedReportingOverflow(by: x)
        guard !overflowed else { throw Refusal("Overflow in .\(label): \(y) * \(x)") }
        return result
    }

    /// The zero divisor is checked first: dividing by zero also reports overflow.
    static func quot(_ y: Int, _ x: Int, _ label: PushInstruction) throws(Refusal) -> Int {
        guard x != 0 else { throw Refusal("Divide by zero .\(label): \(y) / \(x)") }
        let (result, overflowed) = y.dividedReportingOverflow(by: x)
        guard !overflowed else { throw Refusal("Overflow in .\(label): \(y) / \(x)") }
        return result
    }

    static func mod(_ y: Int, _ x: Int, _ label: PushInstruction) throws(Refusal) -> Int {
        guard x != 0 else { throw Refusal("Divide by zero .\(label): \(y) % \(x)") }
        let (result, overflowed) = y.remainderReportingOverflow(dividingBy: x)
        guard !overflowed else { throw Refusal("Overflow in .\(label): \(y) % \(x)") }
        return result
    }
}

/// An infinite or NaN result is refused as overflow.
nonisolated enum DoubleArithmetic {
    static func finite(_ result: Double, _ label: PushInstruction, _ text: @autoclosure () -> String)
        throws(Refusal) -> Double {
        guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .\(label): \(text())") }
        return result
    }

    static func add(_ y: Double, _ x: Double, _ label: PushInstruction) throws(Refusal) -> Double {
        try finite(y + x, label, "\(y) + \(x)")
    }

    static func subtract(_ y: Double, _ x: Double, _ label: PushInstruction) throws(Refusal) -> Double {
        try finite(y - x, label, "\(y) - \(x)")
    }

    static func multiply(_ y: Double, _ x: Double, _ label: PushInstruction) throws(Refusal) -> Double {
        try finite(y * x, label, "\(y) * \(x)")
    }

    static func divide(_ y: Double, _ x: Double, _ label: PushInstruction) throws(Refusal) -> Double {
        try finite(y / x, label, "\(y) / \(x)")
    }

    static func mod(_ y: Double, _ x: Double, _ label: PushInstruction) throws(Refusal) -> Double {
        try finite(y.truncatingRemainder(dividingBy: x), label, "\(y) % \(x)")
    }
}
