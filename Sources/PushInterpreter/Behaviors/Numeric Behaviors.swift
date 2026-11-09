//
//  Numeric Behaviors.swift
//  PushInterpreter
//
//  The arithmetic the language lacked (*Behavior coverage audit*,
//  P5): absolute value, negation, sign and power for ints and doubles; square
//  root, exponential, logarithm and the three roundings for doubles.
//
//  As everywhere: a Behavior returns its intended output or an
//  error. Anything that would overflow an int, or come out NaN or infinite for
//  a double, is refused. Written order is reading order: `b e .intPow` is b to
//  the e.
//

import Foundation

nonisolated extension Interpreter {

    // MARK: - Ints

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


    // MARK: - Doubles

    /// `value`, unless it is NaN or infinite, which is refused as `doubleAdd`
    /// refuses an overflow.
    static func finite(_ value: Double, _ instruction: PushInstruction, _ arguments: String) throws(Refusal) -> Double {
        guard value.isFinite else { throw Refusal("No finite result in .\(instruction): \(arguments)") }
        return value
    }

    static let doubleAbs_Behavior =
        Behavior.operation(.doubleAbs, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            try finite(abs(x), .doubleAbs, "\(x)")
        }
        .described("Takes the absolute value; refuses a non-finite input.")

    static let doubleNegate_Behavior =
        Behavior.operation(.doubleNegate, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            try finite(-x, .doubleNegate, "\(x)")
        }
        .described("Negates; refuses a non-finite input.")

    /// −1.0, 0.0 or 1.0; a NaN has no sign and is refused.
    static let doubleSign_Behavior =
        Behavior.operation(.doubleSign, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard !x.isNaN else { throw Refusal("No sign in .doubleSign: \(x)") }
            return x > 0 ? 1 : (x < 0 ? -1 : 0)
        }
        .described("Gives the sign of a double: −1.0, 0.0 or 1.0; refuses NaN.")

    /// `b e .doublePow` is b to the e. A negative base with a fractional
    /// exponent, or an overflow, is refused.
    static let doublePow_Behavior =
        Behavior.operation(.doublePow, takes: DoubleItem.self, DoubleItem.self,
                           gives: DoubleItem.self) { base, exponent throws(Refusal) in
            try finite(Foundation.pow(base, exponent), .doublePow, "\(base) ^ \(exponent)")
        }
        .described(
            "Raises to a power: `b e .doublePow` gives b to the e;"
            + " refuses a non-finite result (as for b < 0, e fractional)."
        )

    static let doubleSqrt_Behavior =
        Behavior.operation(.doubleSqrt, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard x >= 0 else { throw Refusal("No real root in .doubleSqrt: \(x)") }
            return try finite(x.squareRoot(), .doubleSqrt, "\(x)")
        }
        .described("Takes the square root; refuses a negative or non-finite input.")

    static let doubleExp_Behavior =
        Behavior.operation(.doubleExp, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            try finite(Foundation.exp(x), .doubleExp, "\(x)")
        }
        .described("Raises e to the given power; refuses a result that is not finite.")

    /// The natural logarithm; refused for zero and below.
    static let doubleLog_Behavior =
        Behavior.operation(.doubleLog, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard x > 0 else { throw Refusal("No logarithm in .doubleLog: \(x)") }
            return try finite(Foundation.log(x), .doubleLog, "\(x)")
        }
        .described("Takes the natural logarithm; refuses zero, negatives and non-finite inputs.")

    static let doubleFloor_Behavior =
        Behavior.operation(.doubleFloor, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            try finite(x.rounded(.down), .doubleFloor, "\(x)")
        }
        .described("Rounds down to a whole number; refuses a non-finite input.")

    static let doubleCeil_Behavior =
        Behavior.operation(.doubleCeil, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            try finite(x.rounded(.up), .doubleCeil, "\(x)")
        }
        .described("Rounds up to a whole number; refuses a non-finite input.")

    /// To the nearest whole number, halves away from zero (2.5 → 3, −2.5 → −3).
    static let doubleRound_Behavior =
        Behavior.operation(.doubleRound, takes: DoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            try finite(x.rounded(.toNearestOrAwayFromZero), .doubleRound, "\(x)")
        }
        .described(
            "Rounds to the nearest whole number, halves away from zero (2.5 gives 3); refuses a non-finite input."
        )


    // MARK: - The family

    static let numericBehaviors: [PushInstruction: Behavior] = [
        .intAbs: intAbs_Behavior,
        .intNegate: intNegate_Behavior,
        .intSign: intSign_Behavior,
        .intPow: intPow_Behavior,
        .doubleAbs: doubleAbs_Behavior,
        .doubleNegate: doubleNegate_Behavior,
        .doubleSign: doubleSign_Behavior,
        .doublePow: doublePow_Behavior,
        .doubleSqrt: doubleSqrt_Behavior,
        .doubleExp: doubleExp_Behavior,
        .doubleLog: doubleLog_Behavior,
        .doubleFloor: doubleFloor_Behavior,
        .doubleCeil: doubleCeil_Behavior,
        .doubleRound: doubleRound_Behavior
    ]
}
