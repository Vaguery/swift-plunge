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

    static let intSubtract_Behavior =
        Behavior.operation(.intSubtract, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            let (result, overflowed) = y.subtractingReportingOverflow(x)
            guard !overflowed else { throw Refusal("Overflow in .intSubtract: \(y) - \(x)") }
            return result
        }

    static let intMultiply_Behavior =
        Behavior.operation(.intMultiply, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            let (result, overflowed) = y.multipliedReportingOverflow(by: x)
            guard !overflowed else { throw Refusal("Overflow in .intMultiply: \(y) * \(x)") }
            return result
        }

    static let intMax_Behavior =
        Behavior.operation(.intMax, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in max(y, x) }

    static let intMin_Behavior =
        Behavior.operation(.intMin, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x in min(y, x) }

    // The zero divisor is checked first: dividing by zero also reports overflow.
    static let intQuot_Behavior =
        Behavior.operation(.intQuot, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            guard x != 0 else { throw Refusal("Divide by zero .intQuot: \(y) / \(x)") }
            let (result, overflowed) = y.dividedReportingOverflow(by: x)
            guard !overflowed else { throw Refusal("Overflow in .intQuot: \(y) / \(x)") }
            return result
        }

    static let intMod_Behavior =
        Behavior.operation(.intMod, takes: IntItem.self, IntItem.self, gives: IntItem.self) { y, x throws(Refusal) in
            guard x != 0 else { throw Refusal("Divide by zero .intMod: \(y) % \(x)") }
            let (result, overflowed) = y.remainderReportingOverflow(dividingBy: x)
            guard !overflowed else { throw Refusal("Overflow in .intMod: \(y) % \(x)") }
            return result
        }

    // Comparisons are non-destructive queries: both operands survive, and the
    // result's crux clears them away (`Behavior.reading`).
    static let intGT_Behavior =
        Behavior.operation(.intGT, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y > x }

    static let intGTE_Behavior =
        Behavior.operation(.intGTE, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y >= x }

    static let intLTE_Behavior =
        Behavior.operation(.intLTE, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y <= x }

    static let intLT_Behavior =
        Behavior.operation(.intLT, reads: IntItem.self, IntItem.self, gives: BoolItem.self) { y, x in y < x }

    static let intInc_Behavior =
        Behavior.operation(.intInc, takes: IntItem.self, gives: IntItem.self) { x throws(Refusal) in
            let (result, overflowed) = x.addingReportingOverflow(1)
            guard !overflowed else { throw Refusal("Overflow in .intInc: \(x) + 1»") }
            return result
        }

    static let intDec_Behavior =
        Behavior.operation(.intDec, takes: IntItem.self, gives: IntItem.self) { x throws(Refusal) in
            let (result, overflowed) = x.subtractingReportingOverflow(1)
            guard !overflowed else { throw Refusal("Overflow in .intDec: \(x) - 1»") }
            return result
        }

    static let intFromBool_Behavior =
        Behavior.operation(.intFromBool, takes: BoolItem.self, gives: IntItem.self) { x in x ? 1 : 0 }

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

    /// The string read as an integer; an error if it is not one.
    static let intFromString_Behavior =
        Behavior.operation(.intFromString, takes: StringItem.self, gives: IntItem.self) { s throws(Refusal) in
            guard let v = Int(s) else { throw Refusal("Not an integer in .intFromString: \"\(s)\"", kind: .conversion) }
            return v
        }

    /// `Int(_:)` traps on a non-finite or out-of-range double, so those refuse.
    static let intFromDouble_Behavior =
        Behavior.operation(.intFromDouble, takes: DoubleItem.self, gives: IntItem.self) { x throws(Refusal) in
            guard x.isFinite, x >= Double(Int.min), x < Double(Int.max) else {
                throw Refusal("Overflow in .intFromDouble: \(x) → Int")
            }
            return Int(x)
        }

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
            .intMod : intMod_Behavior,
            .intMultiply : intMultiply_Behavior,
            .intQuot : intQuot_Behavior,
            .intSubtract : intSubtract_Behavior,
        ]

}
