//
//  Constant Behaviors.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/31/26.
//

import DequeModule


extension Interpreter {
    
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
                        if let v = interpreter.constants[stack]?[i] {
                            // stored constants should be Item, not raw values
                            return [Router(.exec, v)]
                        } else {
                            return [Router(.error,
                                           ErrorItem("No constant assigned for \(instructionName)"))]
                        }
                    })
            }
        }
        return result
    }
}
