//
//  Double Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule
import Foundation

nonisolated extension Interpreter {

    // Typed operations (Roadmap #44): arguments in written order, so `y x .doubleSubtract`
    // is `{ y, x in y - x }`. A thrown `Refusal` becomes an error; an infinite or
    // NaN result is refused as overflow.

    static let doubleAdd_Behavior =
        Behavior.operation(.doubleAdd, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y + x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleAdd: \(y) + \(x)") }
            return result
        }
        .described("Adds two doubles; refuses a result that is not finite.")

    /// Whole-number quotient: `y` less its remainder, divided by `x`.
    static let doubleQuot_Behavior =
        Behavior.operation(.doubleQuot, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = (y - y.truncatingRemainder(dividingBy: x)) / x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleQuot: \(y) // \(x)") }
            return result
        }
        .described(
            "Divides, truncating toward zero: `a b .doubleQuot` gives a ÷ b as a whole number;"
            + " refuses when b is 0 or on overflow."
        )

    static let doubleDivide_Behavior =
        Behavior.operation(.doubleDivide, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y / x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleDivide: \(y) / \(x)") }
            return result
        }
        .described("Divides: `a b .doubleDivide` gives a ÷ b; refuses when b is 0 or the result is not finite.")

    static let doubleMod_Behavior =
        Behavior.operation(.doubleMod, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y.truncatingRemainder(dividingBy: x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleMod: \(y) % \(x)") }
            return result
        }
        .described("Takes the remainder: `a b .doubleMod` gives a mod b, with the sign of a; refuses when b is 0.")

    static let doubleMin_Behavior =
        Behavior.operation(.doubleMin, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x in min(x, y) }
        .described("Keeps the smaller of two doubles.")

    static let doubleMax_Behavior =
        Behavior.operation(.doubleMax, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x in max(x, y) }
        .described("Keeps the larger of two doubles.")

    // The non-destructive siblings (ruling I7): read both, leave them, push the
    // larger (smaller).
    static let doublePeekMax_Behavior =
        Behavior.operation(.doublePeekMax, reads: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x in max(x, y) }
        .described("Pushes the larger of the top two doubles, leaving both.")

    static let doublePeekMin_Behavior =
        Behavior.operation(.doublePeekMin, reads: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x in min(x, y) }
        .described("Pushes the smaller of the top two doubles, leaving both.")

    static let doubleSubtract_Behavior =
        Behavior.operation(.doubleSubtract, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y - x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleSubtract: \(y) - \(x)") }
            return result
        }
        .described("Subtracts: `a b .doubleSubtract` gives a − b; refuses a result that is not finite.")

    static let doubleMultiply_Behavior =
        Behavior.operation(.doubleMultiply, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y * x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleMultiply: \(y) * \(x)") }
            return result
        }
        .described("Multiplies two doubles; refuses a result that is not finite.")

    static let doubleFromInt_Behavior =
        Behavior.operation(.doubleFromInt, takes: IntItem.self, gives: DoubleItem.self) { x in Double(x) }
        .described("Converts an int to the nearest double.")

    // Comparisons are non-destructive queries: both operands survive, and the
    // result's crux clears them away (`Behavior.reading`).
    //
    // IEEE semantics: every comparison with a NaN operand is false. (`>=` and `<=`
    // used to compare `DoubleItem`s, whose `Comparable` defaults made them `!(y < x)`
    // and `!(x < y)`, so a NaN made both true. Fixed 2026-11-08.)
    static let doubleGT_Behavior =
        Behavior.operation(.doubleGT, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y > x }
        .described("Compares, leaving both doubles: `a b .doubleGT` gives a > b.")

    static let doubleGTE_Behavior =
        Behavior.operation(.doubleGTE, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y >= x }
        .described("Compares, leaving both doubles: `a b .doubleGTE` gives a ≥ b.")

    static let doubleLTE_Behavior =
        Behavior.operation(.doubleLTE, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y <= x }
        .described("Compares, leaving both doubles: `a b .doubleLTE` gives a ≤ b.")

    static let doubleLT_Behavior =
        Behavior.operation(.doubleLT, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y < x }
        .described("Compares, leaving both doubles: `a b .doubleLT` gives a < b.")

    static let doubleCos_Behavior =
        Behavior.operation(.doubleCos, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = cos(x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleCos: cos(\(x))") }
            return result
        }
        .described("Takes the cosine of an angle in radians; refuses a non-finite input.")

    static let doubleSin_Behavior =
        Behavior.operation(.doubleSin, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = sin(x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleSin: sin(\(x))") }
            return result
        }
        .described("Takes the sine of an angle in radians; refuses a non-finite input.")

    static let doubleTan_Behavior =
        Behavior.operation(.doubleTan, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = tan(x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleTan: tan(\(x))") }
            return result
        }
        .described("Takes the tangent of an angle in radians; refuses a non-finite input.")

    static let doubleInc_Behavior =
        Behavior.operation(.doubleInc, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = x + 1.0
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleInc: \(x) + 1.0") }
            return result
        }
        .described("Adds 1.0; refuses a non-finite input.")

    static let doubleDec_Behavior =
        Behavior.operation(.doubleDec, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = x - 1.0
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleDec: \(x) - 1.0") }
            return result
        }
        .described("Subtracts 1.0; refuses a non-finite input.")

    static let doubleFromBool_Behavior =
        Behavior.operation(.doubleFromBool, takes: BoolItem.self, gives: DoubleItem.self) { x in x ? 1.0 : 0.0 }
        .described("Converts a bool: 1.0 for true, 0.0 for false.")

    /// The character's ASCII code; any non-ASCII character is 0.
    /// The character's Unicode scalar value, as `.intFromChar` gives it and the
    /// inverse of `.charFromDouble`. (Until 2026-11-09 this gave the ASCII code,
    /// and 0.0 for anything else.) A character made of several scalars has no
    /// single value, so it is refused.
    static let doubleFromChar_Behavior =
        Behavior.operation(.doubleFromChar, takes: CharItem.self, gives: DoubleItem.self) { c throws(Refusal) in
            let scalars = c.unicodeScalars
            guard scalars.count == 1, let scalar = scalars.first else {
                throw Refusal("Several Unicode scalars in .doubleFromChar: \(c)", kind: .conversion)
            }
            return Double(scalar.value)
        }
        .described("Converts a char to its Unicode scalar value; refuses a char made of several scalars.")

    /// The string read as a number; an error if it is not one, or if it reads as
    /// a non-finite value.
    static let doubleFromString_Behavior =
        Behavior.operation(.doubleFromString, takes: StringItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard let num = Double(x) else {
                throw Refusal("Not a number in .doubleFromString: \"\(x)\"", kind: .conversion)
            }
            // "inf"/"infinity"/"nan"/"1e400" parse to non-finite values;
            // reject them here so they cannot poison later numeric behaviors
            guard !(num.isInfinite || num.isNaN) else { throw Refusal("Overflow in .doubleFromString: \"\(x)\"") }
            return num
        }
        .described("Parses a string as a double; refuses one that is not a number or that reads as infinite or NaN.")

    static let doubleBehaviors:[PushInstruction : Behavior] =
        
        [
            .doubleAdd : doubleAdd_Behavior,
            .doubleCos : doubleCos_Behavior,
            .doubleDec : doubleDec_Behavior,
            .doubleDivide : doubleDivide_Behavior,
            .doubleFromBool : doubleFromBool_Behavior,
            .doubleFromChar : doubleFromChar_Behavior,
            .doubleFromInt : doubleFromInt_Behavior,
            .doubleFromString : doubleFromString_Behavior,
            .doubleInc : doubleInc_Behavior,
            .doubleMax : doubleMax_Behavior,
            .doubleMin : doubleMin_Behavior,
            .doublePeekMax : doublePeekMax_Behavior,
            .doublePeekMin : doublePeekMin_Behavior,
            .doubleMod : doubleMod_Behavior,
            .doubleMultiply : doubleMultiply_Behavior,
            .doubleQuot : doubleQuot_Behavior,
            .doubleSin : doubleSin_Behavior,
            .doubleSubtract : doubleSubtract_Behavior,
            .doubleTan : doubleTan_Behavior,
        ]
        
}

