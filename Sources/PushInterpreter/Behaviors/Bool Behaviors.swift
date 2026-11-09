//
//  Bool Behaviors.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 5/31/26.
//

import DequeModule

nonisolated extension Interpreter {

    // Typed operations: arguments in written order, so in
    // `p q .boolPandNotQ` the closure is `{ p, q in p && !q }`. Here `y` is the
    // deeper (first-written) argument, `x` the top.

    static let boolAnd_Behavior =
        Behavior.operation(.boolAnd, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x && y }
        .described("Gives true when both bools are true.")

    static let boolFromDouble_Behavior =
        Behavior.operation(.boolFromDouble, takes: DoubleItem.self, gives: BoolItem.self) { x in x != 0.0 }
        .described("Converts a double: false for 0.0, true for anything else, NaN included.")

    static let boolFromInt_Behavior =
        Behavior.operation(.boolFromInt, takes: IntItem.self, gives: BoolItem.self) { x in x != 0 }
        .described("Converts an int: false for 0, true for anything else.")

    static let boolIfPThenQ_Behavior =
        Behavior.operation(.boolIfPThenQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x || !y }
        .described("Implies: `p q .boolIfPThenQ` gives p → q, false only when p is true and q false.")

    static let boolIfQThenP_Behavior =
        Behavior.operation(.boolIfQThenP, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !x || y }
        .described("Implies backwards: `p q .boolIfQThenP` gives q → p, false only when q is true and p false.")

    static let boolNand_Behavior =
        Behavior.operation(.boolNand, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !(x && y) }
        .described("Gives false only when both bools are true.")

    static let boolNor_Behavior =
        Behavior.operation(.boolNor, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !(x || y) }
        .described("Gives true only when both bools are false.")

    static let boolNot_Behavior =
        Behavior.operation(.boolNot, takes: BoolItem.self, gives: BoolItem.self) { x in !x }
        .described("Negates a bool.")

    static let boolNotP_Behavior =
        Behavior.operation(.boolNotP, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !y }
        .described("Negates the deeper of two bools: `p q .boolNotP` gives ¬p, discarding q.")

    static let boolNotPandQ_Behavior =
        Behavior.operation(.boolNotPandQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !y && x }
        .described("Combines: `p q .boolNotPandQ` gives ¬p ∧ q.")

    static let boolNotQ_Behavior =
        Behavior.operation(.boolNotQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !x }
        .described("Negates the top of two bools: `p q .boolNotQ` gives ¬q, discarding p.")

    static let boolOr_Behavior =
        Behavior.operation(.boolOr, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x || y }
        .described("Gives true when either bool is true.")

    static let boolP_Behavior =
        Behavior.operation(.boolP, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in y }
        .described("Keeps the deeper of two bools: `p q .boolP` gives p, discarding q.")

    static let boolPandNotQ_Behavior =
        Behavior.operation(.boolPandNotQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in y && !x }
        .described("Combines: `p q .boolPandNotQ` gives p ∧ ¬q.")

    static let boolQ_Behavior =
        Behavior.operation(.boolQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x }
        .described("Keeps the top of two bools: `p q .boolQ` gives q, discarding p.")

    static let boolXnor_Behavior =
        Behavior.operation(.boolXnor, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x == y }
        .described("Gives true when the two bools are equal.")

    static let boolXor_Behavior =
        Behavior.operation(.boolXor, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x != y }
        .described("Gives true when the two bools differ.")

    static let boolBehaviors: [PushInstruction: Behavior] =
        [
            .boolAnd: boolAnd_Behavior,
            .boolFromDouble: boolFromDouble_Behavior,
            .boolFromInt: boolFromInt_Behavior,
            .boolIfPThenQ: boolIfPThenQ_Behavior,
            .boolIfQThenP: boolIfQThenP_Behavior,
            .boolNand: boolNand_Behavior,
            .boolNor: boolNor_Behavior,
            .boolNot: boolNot_Behavior,
            .boolNotP: boolNotP_Behavior,
            .boolNotPandQ: boolNotPandQ_Behavior,
            .boolNotQ: boolNotQ_Behavior,
            .boolOr: boolOr_Behavior,
            .boolP: boolP_Behavior,
            .boolPandNotQ: boolPandNotQ_Behavior,
            .boolQ: boolQ_Behavior,
            .boolXnor: boolXnor_Behavior,
            .boolXor: boolXor_Behavior,
        ]

}
