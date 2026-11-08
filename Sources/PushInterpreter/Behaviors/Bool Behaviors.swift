//
//  Bool Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule

nonisolated extension Interpreter {

    // Typed operations (Roadmap #44): arguments in written order, so in
    // `p q .boolPandNotQ` the closure is `{ p, q in p && !q }`. Here `y` is the
    // deeper (first-written) argument, `x` the top.

    static let boolAnd_Behavior =
        Behavior.operation(.boolAnd, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x && y }

    static let boolFromDouble_Behavior =
        Behavior.operation(.boolFromDouble, takes: DoubleItem.self, gives: BoolItem.self) { x in x != 0.0 }

    static let boolFromInt_Behavior =
        Behavior.operation(.boolFromInt, takes: IntItem.self, gives: BoolItem.self) { x in x != 0 }

    static let boolIfPThenQ_Behavior =
        Behavior.operation(.boolIfPThenQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x || !y }

    static let boolIfQThenP_Behavior =
        Behavior.operation(.boolIfQThenP, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !x || y }

    static let boolNand_Behavior =
        Behavior.operation(.boolNand, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !(x && y) }

    static let boolNor_Behavior =
        Behavior.operation(.boolNor, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !(x || y) }

    static let boolNot_Behavior =
        Behavior.operation(.boolNot, takes: BoolItem.self, gives: BoolItem.self) { x in !x }

    static let boolNotP_Behavior =
        Behavior.operation(.boolNotP, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !y }

    static let boolNotPandQ_Behavior =
        Behavior.operation(.boolNotPandQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !y && x }

    static let boolNotQ_Behavior =
        Behavior.operation(.boolNotQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in !x }

    static let boolOr_Behavior =
        Behavior.operation(.boolOr, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x || y }

    static let boolP_Behavior =
        Behavior.operation(.boolP, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in y }

    static let boolPandNotQ_Behavior =
        Behavior.operation(.boolPandNotQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in y && !x }

    static let boolQ_Behavior =
        Behavior.operation(.boolQ, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x }

    static let boolXnor_Behavior =
        Behavior.operation(.boolXnor, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x == y }

    static let boolXor_Behavior =
        Behavior.operation(.boolXor, takes: BoolItem.self, BoolItem.self, gives: BoolItem.self) { y, x in x != y }

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
