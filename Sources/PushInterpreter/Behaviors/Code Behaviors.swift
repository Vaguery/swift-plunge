//
//  Code Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/17/26.
//

import DequeModule


extension Interpreter {
    
    static let codeBehaviors:[PushInstruction : Behavior] =
    [
        
        .codeAppend : Behavior(
            .codeAppend,
            takes: [.code, .code],
            fxn: {a in
                let (x, y) = (a[0] as! CodeItem, a[1] as! CodeItem)
                let result =
                    CodeItem(
                        y.value + x.value,
                        call: [y, x, InstructionItem(.codeAppend)],
                        isContingent: Behavior.netContingency(of: x,y)
                        )
                return [ Router( .code, result) ]
            }
        ),

        
    ]
}
