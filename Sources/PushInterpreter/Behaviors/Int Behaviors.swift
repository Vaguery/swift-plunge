//
//  Int Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    // Typed operations (Roadmap #44): arguments in written order, so `y x .intSubtract`
    // is `{ y, x in y - x }`. A thrown `Refusal` becomes an error.

    static let intAdd_Behavior =
        Behavior.operation(.intAdd, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            let (result, overflowed) = y.addingReportingOverflow(x)
            guard !overflowed else { throw Refusal("Overflow in .intAdd: \(y) + \(x)") }
            return result
        }
        .described("Adds two ints; refuses on overflow.")

    static let intSubtract_Behavior =
        Behavior.operation(.intSubtract, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            let (result, overflowed) = y.subtractingReportingOverflow(x)
            guard !overflowed else { throw Refusal("Overflow in .intSubtract: \(y) - \(x)") }
            return result
        }
        .described("Subtracts: `a b .intSubtract` gives a − b; refuses on overflow.")

    static let intMultiply_Behavior =
        Behavior.operation(.intMultiply, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            let (result, overflowed) = y.multipliedReportingOverflow(by: x)
            guard !overflowed else { throw Refusal("Overflow in .intMultiply: \(y) * \(x)") }
            return result
        }
        .described("Multiplies two ints; refuses on overflow.")

    static let intMax_Behavior =
        Behavior.operation(.intMax, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in max(y, x) }
        .described("Keeps the larger of two ints.")

    static let intMin_Behavior =
        Behavior.operation(.intMin, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in min(y, x) }
        .described("Keeps the smaller of two ints.")

    // The non-destructive siblings (ruling I7, named 2026-11-09): read the two
    // ints, leave them, and push the larger (smaller). `Peek` is the language's
    // label for a read that does not consume, as on the iterator getters.
    static let intPeekMax_Behavior =
        Behavior.operation(.intPeekMax, reads: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in max(y, x) }
        .described("Pushes the larger of the top two ints, leaving both.")

    static let intPeekMin_Behavior =
        Behavior.operation(.intPeekMin, reads: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in min(y, x) }
        .described("Pushes the smaller of the top two ints, leaving both.")

    // The zero divisor is checked first: dividing by zero also reports overflow.
    static let intQuot_Behavior =
        Behavior.operation(.intQuot, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            guard x != 0 else { throw Refusal("Divide by zero .intQuot: \(y) / \(x)") }
            let (result, overflowed) = y.dividedReportingOverflow(by: x)
            guard !overflowed else { throw Refusal("Overflow in .intQuot: \(y) / \(x)") }
            return result
        }
        .described("Divides, truncating toward zero: `a b .intQuot` gives a ÷ b; refuses when b is 0 or on overflow.")

    static let intMod_Behavior =
        Behavior.operation(.intMod, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            guard x != 0 else { throw Refusal("Divide by zero .intMod: \(y) % \(x)") }
            let (result, overflowed) = y.remainderReportingOverflow(dividingBy: x)
            guard !overflowed else { throw Refusal("Overflow in .intMod: \(y) % \(x)") }
            return result
        }
        .described("Takes the remainder: `a b .intMod` gives a mod b, with the sign of a; refuses when b is 0.")

    // Comparisons are non-destructive queries: both operands survive, and the
    // result's crux clears them away (`Behavior.reading`).
    static let intGT_Behavior =
        Behavior.operation(.intGT, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y > x }
        .described("Compares, leaving both ints: `a b .intGT` gives a > b.")

    static let intGTE_Behavior =
        Behavior.operation(.intGTE, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y >= x }
        .described("Compares, leaving both ints: `a b .intGTE` gives a ≥ b.")

    static let intLTE_Behavior =
        Behavior.operation(.intLTE, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y <= x }
        .described("Compares, leaving both ints: `a b .intLTE` gives a ≤ b.")

    static let intLT_Behavior =
        Behavior.operation(.intLT, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y < x }
        .described("Compares, leaving both ints: `a b .intLT` gives a < b.")

    static let intInc_Behavior =
        Behavior.operation(.intInc, takes: IntItem.self, gives: IntItem.self) { x throws(Refusal) in
            let (result, overflowed) = x.addingReportingOverflow(1)
            guard !overflowed else { throw Refusal("Overflow in .intInc: \(x) + 1»") }
            return result
        }
        .described("Adds 1; refuses on overflow.")

    static let intDec_Behavior =
        Behavior.operation(.intDec, takes: IntItem.self, gives: IntItem.self) { x throws(Refusal) in
            let (result, overflowed) = x.subtractingReportingOverflow(1)
            guard !overflowed else { throw Refusal("Overflow in .intDec: \(x) - 1»") }
            return result
        }
        .described("Subtracts 1; refuses on overflow.")

    static let intFromBool_Behavior =
        Behavior.operation(.intFromBool, takes: BoolItem.self, gives: IntItem.self) { x in x ? 1 : 0 }
        .described("Converts a bool: 1 for true, 0 for false.")

    /// The character's Unicode scalar value, the inverse of `.charFromInt`. A
    /// character made of several scalars (a flag, a letter with a combining
    /// accent) has no single code, so it is an error.
    static let intFromChar_Behavior =
        Behavior.operation(.intFromChar, takes: CharItem.self, gives: IntItem.self) { c throws(Refusal) in
            let scalars = c.unicodeScalars
            guard scalars.count == 1, let scalar = scalars.first else {
                throw Refusal("Several Unicode scalars in .intFromChar: \(c)", kind: .conversion)
            }
            return Int(scalar.value)
        }
        .described("Converts a char to its Unicode scalar value; refuses a char made of several scalars.")

    /// The string read as an integer; an error if it is not one.
    static let intFromString_Behavior =
        Behavior.operation(.intFromString, takes: StringItem.self, gives: IntItem.self) { s throws(Refusal) in
            guard let v = Int(s) else { throw Refusal("Not an integer in .intFromString: \"\(s)\"", kind: .conversion) }
            return v
        }
        .described("Parses a string as an integer; refuses one that is not.")

    /// `Int(_:)` traps on a non-finite or out-of-range double, so those refuse.
    static let intFromDouble_Behavior =
        Behavior.operation(.intFromDouble, takes: DoubleItem.self, gives: IntItem.self) { x throws(Refusal) in
            guard x.isFinite, x >= Double(Int.min), x < Double(Int.max) else {
                throw Refusal("Overflow in .intFromDouble: \(x) → Int")
            }
            return Int(x)
        }
        .described("Converts a double, truncating toward zero; refuses one that is not finite or out of range.")

    static let intBehaviors:[PushInstruction : Behavior] =
        [
            .intAdd : intAdd_Behavior,
            .intDec : intDec_Behavior,
            .intFromBool : intFromBool_Behavior,
            .intFromChar : intFromChar_Behavior,
            .intFromDouble : intFromDouble_Behavior,
            .intFromString : intFromString_Behavior,
            .intInc : intInc_Behavior,
            .intMax : intMax_Behavior,
            .intMin : intMin_Behavior,
            .intPeekMax : intPeekMax_Behavior,
            .intPeekMin : intPeekMin_Behavior,
            .intMod : intMod_Behavior,
            .intMultiply : intMultiply_Behavior,
            .intQuot : intQuot_Behavior,
            .intSubtract : intSubtract_Behavior,
        ]

}
