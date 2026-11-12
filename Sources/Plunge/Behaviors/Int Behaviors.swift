//
//  Int Behaviors.swift
//  Plunge
//
//  Created by Bill Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    // Typed operations: arguments in written order, so `y x .intSubtract`
    // is `{ y, x in y - x }`. A thrown `Refusal` becomes an error.

    static let intAdd_Behavior =
        Behavior.operation(.intAdd, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            try IntArithmetic.add(y, x, .intAdd)
        }
        .described("Adds two ints; refuses on overflow.")

    static let intSubtract_Behavior =
        Behavior.operation(.intSubtract, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            try IntArithmetic.subtract(y, x, .intSubtract)
        }
        .described("Subtracts: `a b .intSubtract` gives a − b; refuses on overflow.")

    static let intMultiply_Behavior =
        Behavior.operation(.intMultiply, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            try IntArithmetic.multiply(y, x, .intMultiply)
        }
        .described("Multiplies two ints; refuses on overflow.")

    static let intMax_Behavior =
        Behavior.operation(.intMax, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in max(y, x) }
        .described("Keeps the larger of two ints.")

    static let intMin_Behavior =
        Behavior.operation(.intMin, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in min(y, x) }
        .described("Keeps the smaller of two ints.")

    // The non-destructive siblings: read the two
    // ints, leave them, and push the larger (smaller). `Peek` is the language's
    // label for a read that does not consume, as on the iterator getters.
    static let intPeekMax_Behavior =
        Behavior.operation(.intPeekMax, reads: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in max(y, x) }
        .described("Pushes the larger of the top two ints, leaving both.")

    static let intPeekMin_Behavior =
        Behavior.operation(.intPeekMin, reads: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in min(y, x) }
        .described("Pushes the smaller of the top two ints, leaving both.")

    static let intQuot_Behavior =
        Behavior.operation(.intQuot, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            try IntArithmetic.quot(y, x, .intQuot)
        }
        .described("Divides, truncating toward zero: `a b .intQuot` gives a ÷ b; refuses when b is 0 or on overflow.")

    static let intMod_Behavior =
        Behavior.operation(.intMod, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            try IntArithmetic.mod(y, x, .intMod)
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

    // MARK: - Sign, magnitude and power
    //
    // Anything that would overflow is refused. Written order is reading order:
    // `b e .intPow` is b to the e.

    static let intAbs_Behavior =
        Behavior.operation(.intAbs, takes: IntItem.self, gives: IntItem.self) { x throws(Refusal) in
            guard x != .min else { throw Refusal("Overflow in .intAbs: \(x)") }
            return abs(x)
        }
        .described("Takes the absolute value; refuses the most negative int, whose absolute value overflows.")

    static let intNegate_Behavior =
        Behavior.operation(.intNegate, takes: IntItem.self, gives: IntItem.self) { x throws(Refusal) in
            guard x != .min else { throw Refusal("Overflow in .intNegate: \(x)") }
            return -x
        }
        .described("Negates; refuses the most negative int, whose negation overflows.")

    /// −1, 0 or 1.
    static let intSign_Behavior =
        Behavior.operation(.intSign, takes: IntItem.self, gives: IntItem.self) { x in x.signum() }
        .described("Gives the sign of an int: −1, 0 or 1.")

    /// `b e .intPow` is b to the e, by repeated squaring. A negative exponent
    /// has an int answer only for a base of 1 or −1; otherwise it is refused, as
    /// is a result that overflows.
    static let intPow_Behavior =
        Behavior.operation(.intPow, takes: IntItem.self, IntItem.self,
                           gives: IntItem.self) { base, exponent throws(Refusal) in
            guard exponent >= 0 else {
                switch base {
                case 1: return 1
                case -1: return exponent.isMultiple(of: 2) ? 1 : -1
                default: throw Refusal("No int result in .intPow: \(base) ^ \(exponent)")
                }
            }
            var result = 1, square = base, remaining = exponent
            while remaining > 0 {
                if remaining & 1 == 1 {
                    let (product, overflowed) = result.multipliedReportingOverflow(by: square)
                    guard !overflowed else { throw Refusal("Overflow in .intPow: \(base) ^ \(exponent)") }
                    result = product
                }
                remaining >>= 1
                if remaining > 0 {
                    let (product, overflowed) = square.multipliedReportingOverflow(by: square)
                    guard !overflowed else { throw Refusal("Overflow in .intPow: \(base) ^ \(exponent)") }
                    square = product
                }
            }
            return result
        }
        .described(
            "Raises to a power: `b e .intPow` gives b to the e; refuses on overflow, or a negative e unless b is ±1."
        )


    static let intBehaviors: [PushInstruction: Behavior] =
        [
            .intAdd: intAdd_Behavior,
            .intDec: intDec_Behavior,
            .intFromBool: intFromBool_Behavior,
            .intFromChar: intFromChar_Behavior,
            .intFromDouble: intFromDouble_Behavior,
            .intFromString: intFromString_Behavior,
            .intInc: intInc_Behavior,
            .intMax: intMax_Behavior,
            .intMin: intMin_Behavior,
            .intPeekMax: intPeekMax_Behavior,
            .intPeekMin: intPeekMin_Behavior,
            .intMod: intMod_Behavior,
            .intMultiply: intMultiply_Behavior,
            .intQuot: intQuot_Behavior,
            .intSubtract: intSubtract_Behavior,
            .intAbs: intAbs_Behavior,
            .intNegate: intNegate_Behavior,
            .intSign: intSign_Behavior,
            .intPow: intPow_Behavior
        ]

}
