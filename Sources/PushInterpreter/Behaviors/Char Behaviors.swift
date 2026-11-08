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

    /// The character with this Unicode scalar value; an error if there is none.
    static let charFromInt_Behavior =
        Behavior.operation(.charFromInt, takes: IntItem.self, gives: CharItem.self) { x throws(Refusal) in
            guard let c = character(scalar: x) else {
                throw Refusal("Not a Unicode scalar in .charFromInt: \(x)", kind: .conversion)
            }
            return c
        }

    // Comparisons and classifications are non-destructive queries: the operands
    // survive, and the result's crux clears them away (`Behavior.reading`).
    static let charGT_Behavior =
        Behavior.operation(.charGT, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y > x }

    static let charGTE_Behavior =
        Behavior.operation(.charGTE, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y >= x }

    static let charIsDigit_Behavior =
        Behavior.operation(.charIsDigit, reads: CharItem.self, gives: BoolItem.self) { x in x.isWholeNumber }

    static let charIsLetter_Behavior =
        Behavior.operation(.charIsLetter, reads: CharItem.self, gives: BoolItem.self) { x in x.isLetter }

    static let charIsWhitespace_Behavior =
        Behavior.operation(.charIsWhitespace, reads: CharItem.self, gives: BoolItem.self) { x in x.isWhitespace }

    static let charLT_Behavior =
        Behavior.operation(.charLT, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y < x }

    static let charLTE_Behavior =
        Behavior.operation(.charLTE, reads: CharItem.self, CharItem.self, gives: BoolItem.self) { y, x in y <= x }

    static let charBehaviors:[PushInstruction : Behavior] =
    [
        .charFromDouble : charFromDouble_behavior,
        .charFromInt : charFromInt_Behavior,
        .charIsDigit : charIsDigit_Behavior,
        .charIsLetter : charIsLetter_Behavior,
        .charIsWhitespace : charIsWhitespace_Behavior,
    ]
}
