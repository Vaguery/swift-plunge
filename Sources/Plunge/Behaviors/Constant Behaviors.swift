//
//  Constant Behaviors.swift
//  Plunge
//
//  Created by Bill Tozier on 5/31/26.
//

import DequeModule


nonisolated extension Interpreter {

    /// The behaviors of the listed constants, `.constant(0)` through
    /// `.constant(listedConstantCount - 1)`. Any other constant's behavior is made
    /// by `constantBehavior(_:)` when it is first needed.
    static var constantBehaviors: [PushInstruction: Behavior] {
        var result: [PushInstruction: Behavior] = [:]
        for slot in 0..<PushInstruction.listedConstantCount {
            result[.constant(slot)] = constantBehavior(slot)
        }
        return result
    }

    /// The behavior of `.constant(slot)`: push the value the individual binds to
    /// the slot, of whatever type, by way of `.exec`, or refuse when it binds none.
    static func constantBehavior(_ slot: Int) -> Behavior {
        let instructionName = PushInstruction.constant(slot)
        return Behavior.contextRead(instructionName, produces: .constant) { _, context in
                if var v = context.constants[instructionName] {
                    v.call = context.recording([InstructionItem(instructionName, read: v)])
                    return [Router(.exec, v)]
                } else {
                    // As the `.inputN` errors: records the same `[.constantN]` its
                    // success branch does, because a constant slot is environment
                    // state that a re-run supplies again.
                    return [Router(.error,
                                   ErrorItem("No constant assigned for \(instructionName)",
                                             kind: .missingConstant, source: instructionName,
                                             call: context.recording([InstructionItem(instructionName)])))]
                }
            }
            .described("Pushes the run's constant \(slot), of whatever type it is, by way of `.exec`; refuses when "
                       + "the run assigns none.")
    }
}
