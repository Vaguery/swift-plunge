//
//  Char Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    /// The character whose Unicode scalar value is `code`, or nil if `code` is not
    /// a valid scalar (negative, past 0x10FFFF, or a surrogate).
    ///
    /// Character codes are scalar values in both directions (Roadmap #42), so
    /// `.charFromInt` and `.intFromChar` are inverses: `65 .charFromInt` is `A`.
    /// They used to map any number to `|n mod 95| + 32`, which made 65 an `a`.
    static func character(scalar code: Int) -> Character? {
        guard let bits = UInt32(exactly: code), let scalar = Unicode.Scalar(bits) else { return nil }
        return Character(scalar)
    }

    // Typed operations (Roadmap #44): arguments in written order, so `y x .charLT`
    // is `{ y, x in y < x }`. A thrown `Refusal` becomes an error.

    /// Truncates toward zero, then reads the result as a Unicode scalar value.
    static let charFromDouble_behavior =
        Behavior.operation(.charFromDouble, takes: DoubleItem.self, gives: CharItem.self) { x throws(Refusal) in
            // Int(x) traps on non-finite or out-of-Int-range doubles,
            // so guard the conversion first.
            guard x.isFinite, x >= Double(Int.min), x < Double(Int.max) else {
                throw Refusal("Overflow in .charFromDouble: \(x) → Int")
            }
            guard let c = character(scalar: Int(x)) else {
                throw Refusal("Not a Unicode scalar in .charFromDouble: \(x)", kind: .conversion)
            }
            return c
        }
        .described("Truncates a double toward zero and converts it to the char with that Unicode scalar value; " +
                   "refuses a non-finite or invalid value.")

    /// The character with this Unicode scalar value; an error if there is none.
    static let charFromInt_Behavior =
        Behavior.operation(.charFromInt, takes: IntItem.self, gives: CharItem.self) { x throws(Refusal) in
            guard let c = character(scalar: x) else {
                throw Refusal("Not a Unicode scalar in .charFromInt: \(x)", kind: .conversion)
            }
            return c
        }
        .described("Converts an int to the char with that Unicode scalar value; refuses a negative value, a " +
                   "surrogate, or one past 0x10FFFF.")

    // Comparisons and classifications are non-destructive queries: the operands
    // survive, and the result's crux clears them away (`Behavior.reading`).
    static let charGT_Behavior =
        Behavior.operation(.charGT, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y > x }
        .described("Compares in Unicode order, leaving both chars: `a b .charGT` gives a > b.")

    static let charGTE_Behavior =
        Behavior.operation(.charGTE, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y >= x }
        .described("Compares in Unicode order, leaving both chars: `a b .charGTE` gives a ≥ b.")

    static let charIsDigit_Behavior =
        Behavior.operation(.charIsDigit, reads: CharItem.self, gives: BoolItem.self) { x in x.isWholeNumber }
        .described("Tests whether the char stands for a whole number, in any script, leaving the char.")

    static let charIsLetter_Behavior =
        Behavior.operation(.charIsLetter, reads: CharItem.self, gives: BoolItem.self) { x in x.isLetter }
        .described("Tests whether the char is a letter, in any script, leaving the char.")

    static let charIsWhitespace_Behavior =
        Behavior.operation(.charIsWhitespace, reads: CharItem.self, gives: BoolItem.self) { x in x.isWhitespace }
        .described("Tests whether the char is whitespace (space, tab, newline and the like), leaving the char.")

    static let charLT_Behavior =
        Behavior.operation(.charLT, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y < x }
        .described("Compares in Unicode order, leaving both chars: `a b .charLT` gives a < b.")

    static let charLTE_Behavior =
        Behavior.operation(.charLTE, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y <= x }
        .described("Compares in Unicode order, leaving both chars: `a b .charLTE` gives a ≤ b.")

    static let charBehaviors:[PushInstruction : Behavior] =
    [
        .charFromDouble : charFromDouble_behavior,
        .charFromInt : charFromInt_Behavior,
        .charIsDigit : charIsDigit_Behavior,
        .charIsLetter : charIsLetter_Behavior,
        .charIsWhitespace : charIsWhitespace_Behavior,
    ]
}
