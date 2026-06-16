//
//  Output Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/14/26.
//

import DequeModule


extension Interpreter {
    
    
    static var outputBehaviors:[PushInstruction : Behavior] {
        let result:[PushInstruction : Behavior] =
        [
            .printNewline:
                BehaviorWithSideEffects(
                .printNewline,
                takes: [],
                modifier: { (interpreter, _) in
                    interpreter.printout.append("\n")
                    return []
                }),
            
            .boolPrint:
                BehaviorWithSideEffects(
                .boolPrint,
                takes: [.bool],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! BoolItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),
            
            .charPrint:
                BehaviorWithSideEffects(
                .charPrint,
                takes: [.char],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! CharItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .execPrint:
                BehaviorWithSideEffects(
                .execPrint,
                takes: [.exec],
                modifier: { (interpreter, args) in
                    let (x) = args[0]
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .doublePrint:
                BehaviorWithSideEffects(
                .doublePrint,
                takes: [.double],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! DoubleItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .intPrint:
                BehaviorWithSideEffects(
                .intPrint,
                takes: [.int],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! IntItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .stringPrint:
                BehaviorWithSideEffects(
                .stringPrint,
                takes: [.string],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! StringItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .vecBoolPrint:
                BehaviorWithSideEffects(
                .vecBoolPrint,
                takes: [.vecBool],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! VecBoolItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .vecDoublePrint:
                BehaviorWithSideEffects(
                .vecDoublePrint,
                takes: [.vecDouble],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! VecDoubleItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .vecIntPrint:
                BehaviorWithSideEffects(
                .vecIntPrint,
                takes: [.vecInt],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! VecIntItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .vecStringPrint:
                BehaviorWithSideEffects(
                .vecStringPrint,
                takes: [.vecString],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! VecStringItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),

            .codePrint:
                BehaviorWithSideEffects(
                .codePrint,
                takes: [.code],
                modifier: { (interpreter, args) in
                    let (x) = args[0] as! CodeItem
                    interpreter.printout.append("\(x.pretty())\n")
                    return []
                }),
            
        ]
        
        
        return result
    }
}
