//
//  Output Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule

nonisolated extension Interpreter {

    static let printNewline_Behavior =
        BehaviorWithSideEffects(
            .printNewline,
            takes: [],
            as: .channel,
            modifier: { (interpreter, _) in
                interpreter.printText("\n")
                return []
            }
        )

    static let boolPrint_Behavior =
        BehaviorWithSideEffects(
            .boolPrint,
            takes: [.bool],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! BoolItem
                interpreter.printItem(x)
                return []
            }
        )

    static let iteratorPrint_Behavior =
        BehaviorWithSideEffects(
            .iteratorPrint,
            takes: [.iterator],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! IteratorItem
                interpreter.printItem(x)
                return []
            }
        )

    static let execPrint_Behavior =
        BehaviorWithSideEffects(
            .execPrint,
            takes: [.exec],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0]
                interpreter.printItem(x)
                return []
            }
        )

    static let doublePrint_Behavior =
        BehaviorWithSideEffects(
            .doublePrint,
            takes: [.double],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! DoubleItem
                interpreter.printItem(x)
                return []
            }
        )

    static let charPrint_Behavior =
        BehaviorWithSideEffects(
            .charPrint,
            takes: [.char],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! CharItem
                interpreter.printItem(x)
                return []
            }
        )

    static let intPrint_Behavior =
        BehaviorWithSideEffects(
            .intPrint,
            takes: [.int],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! IntItem
                interpreter.printItem(x)
                return []
            }
        )

    static let stringPrint_Behavior =
        BehaviorWithSideEffects(
            .stringPrint,
            takes: [.string],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! StringItem
                interpreter.printItem(x)
                return []
            }
        )

    static let vecBoolPrint_Behavior =
        BehaviorWithSideEffects(
            .vecBoolPrint,
            takes: [.vecBool],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecBoolItem
                interpreter.printItem(x)
                return []
            }
        )

    static let vecDoublePrint_Behavior =
        BehaviorWithSideEffects(
            .vecDoublePrint,
            takes: [.vecDouble],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecDoubleItem
                interpreter.printItem(x)
                return []
            }
        )

    static let vecIntPrint_Behavior =
        BehaviorWithSideEffects(
            .vecIntPrint,
            takes: [.vecInt],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecIntItem
                interpreter.printItem(x)
                return []
            }
        )

    static let vecStringPrint_Behavior =
        BehaviorWithSideEffects(
            .vecStringPrint,
            takes: [.vecString],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecStringItem
                interpreter.printItem(x)
                return []
            }
        )

    static let codePrint_Behavior =
        BehaviorWithSideEffects(
            .codePrint,
            takes: [.code],
            as: .channel,
            modifier: { (interpreter, args) in
                let (x) = args[0] as! CodeItem
                interpreter.printItem(x)
                return []
            }
        )


    static var outputBehaviors:[PushInstruction : Behavior] {
        let result:[PushInstruction : Behavior] =
        [
            .boolPrint : boolPrint_Behavior,
            .charPrint : charPrint_Behavior,
            .codePrint : codePrint_Behavior,
            .doublePrint : doublePrint_Behavior,
            .execPrint : execPrint_Behavior,
            .intPrint : intPrint_Behavior,
            .iteratorPrint : iteratorPrint_Behavior,
            .printNewline : printNewline_Behavior,
            .stringPrint : stringPrint_Behavior,
            .vecBoolPrint : vecBoolPrint_Behavior,
            .vecDoublePrint : vecDoublePrint_Behavior,
            .vecIntPrint : vecIntPrint_Behavior,
            .vecStringPrint : vecStringPrint_Behavior,

        ]
        return result
    }
}
