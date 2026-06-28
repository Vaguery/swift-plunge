//
//  Code Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/17/26.
//

import DequeModule

//case codeAppend, codeContainer, codeContains, codeCutAtGap, codeCutRoot, codeDepth, codeFlatten, codeFlattenPoint, codeFlattenRange, codeGather, codeIf, codeIndexOfPoint, codeInsertAtGap, codeIsEmpty, codeIteratePoints, codeIterateRoot, codeLengthPoints, codeLengthRoot, codeNthPoint, codeNthRoot, codeRemovePoint, codeReplaceAllPoints, codeReplaceFirstPoint, codeWidth, codeWrapRoot, codeWrapPoints



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
