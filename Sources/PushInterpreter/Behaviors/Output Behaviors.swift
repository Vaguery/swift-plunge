////
////  Output Behaviors.swift
////  Propeller in Swift
////
////  Created by William Tozier on 5/17/26.
////
//
//import DequeModule
//
//
//extension Interpreter {
//    
//    
//    static var outputInstructions:[PushInstruction : Instruction] {
//        var result:[PushInstruction : Instruction] =
//        [
//            .printNewline:
//            DirectInstruction(
//                .printNewline,
//                takes: [],
//                modifier: { (interpreter, _) in
//                    interpreter.printout.append("\n")
//                    return []
//                }),
//            
//            .boolPrint:
//            DirectInstruction(
//                .boolPrint,
//                takes: [.bool],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//            
//            .charPrint:
//            DirectInstruction(
//                .charPrint,
//                takes: [.char],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .execPrint:
//            DirectInstruction(
//                .execPrint,
//                takes: [.exec],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .floatPrint:
//            DirectInstruction(
//                .floatPrint,
//                takes: [.float],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .intPrint:
//            DirectInstruction(
//                .intPrint,
//                takes: [.int],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .stringPrint:
//            DirectInstruction(
//                .stringPrint,
//                takes: [.string],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .vecBoolPrint:
//            DirectInstruction(
//                .vecBoolPrint,
//                takes: [.vecBool],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .vecFloatPrint:
//            DirectInstruction(
//                .vecFloatPrint,
//                takes: [.vecFloat],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .vecIntPrint:
//            DirectInstruction(
//                .vecIntPrint,
//                takes: [.vecInt],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .vecStringPrint:
//            DirectInstruction(
//                .vecStringPrint,
//                takes: [.vecString],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//
//            .codePrint:
//            DirectInstruction(
//                .codePrint,
//                takes: [.code],
//                modifier: { (interpreter, args) in
//                    let (x) = args[0]
//                    interpreter.printout.append("\(x.asString())\n")
//                    return []
//                }),
//            
//        ]
//        
//        
//        return result
//    }
//}
