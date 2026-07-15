//
//  Constant Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule


nonisolated extension Interpreter {
    
    // ten for each of:
    //    .int, .double, .string, .char, .vecInt, .vecFloat, .vecString, .vecBool
    
    static var constantBehaviors:[PushInstruction : Behavior] {
        var result:[PushInstruction : Behavior] = [:]
        
        let stacks:[PushStack] = [.int, .double, .string, .char, .vecInt, .vecDouble, .vecString, .vecBool]
        
        for stack in stacks {
            for i in 0..<10 {
                let instructionName = PushInstruction(rawValue: "\(stack)\(i)")!
                result[instructionName] =
                BehaviorWithSideEffects(
                    instructionName,
                    takes: [],
                    modifier: { (interpreter, collectedItems) in
                        if var v = interpreter.constants[instructionName] {
                            v.call = [InstructionItem(instructionName)]
                            return [Router(.exec, v)]
                        } else {
                            // As the `.inputN` errors: records the same
                            // `[.int3]` its success branch does, because a
                            // constant slot is environment state that a re-run
                            // supplies again. Not marked contingent — unlike
                            // inputs, this behavior's success branch does not
                            // mark its value either.
                            return [Router(.error,
                                           ErrorItem("No constant assigned for \(instructionName)",
                                                     call: [InstructionItem(instructionName)]))]
                        }
                    })
            }
        }
        return result
    }
}
