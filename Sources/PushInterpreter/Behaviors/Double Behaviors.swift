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

    /// Whole-number quotient: `y` less its remainder, divided by `x`.
    static let doubleQuot_Behavior =
        Behavior.operation(.doubleQuot, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = (y - y.truncatingRemainder(dividingBy: x)) / x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleQuot: \(y) // \(x)") }
            return result
        }

    static let doubleDivide_Behavior =
        Behavior.operation(.doubleDivide, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y / x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleDivide: \(y) / \(x)") }
            return result
        }

    static let doubleMod_Behavior =
        Behavior.operation(.doubleMod, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y.truncatingRemainder(dividingBy: x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleMod: \(y) % \(x)") }
            return result
        }

    static let doubleMin_Behavior =
        Behavior.operation(.doubleMin, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x in min(x, y) }

    static let doubleMax_Behavior =
        Behavior.operation(.doubleMax, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x in max(x, y) }

    static let doubleSubtract_Behavior =
        Behavior.operation(.doubleSubtract, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y - x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleSubtract: \(y) - \(x)") }
            return result
        }

    static let doubleMultiply_Behavior =
        Behavior.operation(.doubleMultiply, takes: DoubleItem.self, DoubleItem.self, gives: DoubleItem.self) { y, x throws(Refusal) in
            let result = y * x
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleMultiply: \(y) * \(x)") }
            return result
        }

    static let doubleFromInt_Behavior =
        Behavior.operation(.doubleFromInt, takes: IntItem.self, gives: DoubleItem.self) { x in Double(x) }

    // Comparisons are non-destructive queries: both operands survive, and the
    // result's crux clears them away (`Behavior.reading`).
    //
    // IEEE semantics: every comparison with a NaN operand is false. (`>=` and `<=`
    // used to compare `DoubleItem`s, whose `Comparable` defaults made them `!(y < x)`
    // and `!(x < y)`, so a NaN made both true. Fixed 2026-11-08.)
    static let doubleGT_Behavior =
        Behavior.operation(.doubleGT, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y > x }

    static let doubleGTE_Behavior =
        Behavior.operation(.doubleGTE, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y >= x }

    static let doubleLTE_Behavior =
        Behavior.operation(.doubleLTE, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y <= x }

    static let doubleLT_Behavior =
        Behavior.operation(.doubleLT, reads: DoubleItem.self, DoubleItem.self, gives: BoolItem.self) { y, x in y < x }

    static let doubleCos_Behavior =
        Behavior.operation(.doubleCos, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = cos(x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleCos: cos(\(x))") }
            return result
        }

    static let doubleSin_Behavior =
        Behavior.operation(.doubleSin, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = sin(x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleSin: sin(\(x))") }
            return result
        }

    static let doubleTan_Behavior =
        Behavior.operation(.doubleTan, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = tan(x)
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleTan: tan(\(x))") }
            return result
        }

    static let doubleInc_Behavior =
        Behavior.operation(.doubleInc, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = x + 1.0
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleInc: \(x) + 1.0") }
            return result
        }

    static let doubleDec_Behavior =
        Behavior.operation(.doubleDec, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let result = x - 1.0
            guard !(result.isInfinite || result.isNaN) else { throw Refusal("Overflow in .doubleDec: \(x) - 1.0") }
            return result
        }

    static let doubleFromBool_Behavior =
        Behavior.operation(.doubleFromBool, takes: BoolItem.self, gives: DoubleItem.self) { x in x ? 1.0 : 0.0 }

    /// The character's ASCII code; any non-ASCII character is 0.
    static let doubleFromChar_Behavior =
        Behavior.operation(.doubleFromChar, takes: CharItem.self, gives: DoubleItem.self) { x in
            x.isASCII ? Double(x.asciiValue!) : 0.0
        }

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
            .doubleMod : doubleMod_Behavior,
            .doubleMultiply : doubleMultiply_Behavior,
            .doubleQuot : doubleQuot_Behavior,
            .doubleSin : doubleSin_Behavior,
            .doubleSubtract : doubleSubtract_Behavior,
            .doubleTan : doubleTan_Behavior,
        ]
        
}

