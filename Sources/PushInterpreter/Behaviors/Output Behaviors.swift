//
//  Output Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule

nonisolated extension Interpreter {

    static let printNewline_Behavior =
        BehaviorWithSideEffects(
            .printNewline,
            takes: [],
            modifier: { (interpreter, _) in
                interpreter.printout.append("\n")
                return []
            }
        )

    static let boolPrint_Behavior =
        BehaviorWithSideEffects(
            .boolPrint,
            takes: [.bool],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! BoolItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let execPrint_Behavior =
        BehaviorWithSideEffects(
            .execPrint,
            takes: [.exec],
            modifier: { (interpreter, args) in
                let (x) = args[0]
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let doublePrint_Behavior =
        BehaviorWithSideEffects(
            .doublePrint,
            takes: [.double],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! DoubleItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let charPrint_Behavior =
        BehaviorWithSideEffects(
            .charPrint,
            takes: [.char],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! CharItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let intPrint_Behavior =
        BehaviorWithSideEffects(
            .intPrint,
            takes: [.int],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! IntItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let stringPrint_Behavior =
        BehaviorWithSideEffects(
            .stringPrint,
            takes: [.string],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! StringItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let vecBoolPrint_Behavior =
        BehaviorWithSideEffects(
            .vecBoolPrint,
            takes: [.vecBool],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecBoolItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let vecDoublePrint_Behavior =
        BehaviorWithSideEffects(
            .vecDoublePrint,
            takes: [.vecDouble],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecDoubleItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let vecIntPrint_Behavior =
        BehaviorWithSideEffects(
            .vecIntPrint,
            takes: [.vecInt],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecIntItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let vecStringPrint_Behavior =
        BehaviorWithSideEffects(
            .vecStringPrint,
            takes: [.vecString],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! VecStringItem
                interpreter.printout.append("\(x.pretty())\n")
                return []
            }
        )

    static let codePrint_Behavior =
        BehaviorWithSideEffects(
            .codePrint,
            takes: [.code],
            modifier: { (interpreter, args) in
                let (x) = args[0] as! CodeItem
                interpreter.printout.append("\(x.pretty())\n")
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
