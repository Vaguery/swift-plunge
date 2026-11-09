//
//  Constant Behaviors.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 5/31/26.
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
                Behavior.contextRead(instructionName, produces: .deferred(stack)) { _, context in
                        if var v = context.constants[instructionName] {
                            v.call = context.recording([InstructionItem(instructionName)])
                            return [Router(.exec, v)]
                        } else {
                            // As the `.inputN` errors: records the same
                            // `[.int3]` its success branch does, because a
                            // constant slot is environment state that a re-run
                            // supplies again.
                            return [Router(.error,
                                           ErrorItem("No constant assigned for \(instructionName)",
                                                     kind: .missingConstant,
                                                     call: context.recording([InstructionItem(instructionName)])))]
                        }
                    }
                .described(
                    "Pushes the run's constant \(i) for \(stack.plural), by way of `.exec`;"
                    + " refuses when the run assigns none."
                )
            }
        }
        return result
    }
}
