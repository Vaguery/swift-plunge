//
//  Code Behaviors.swift
//  Propeller in Swift
//
//  Created by William Tozier on 6/17/26.
//

import DequeModule

//case codeContainer, codeContains, codeCutAtGap, codeCutRootAtGap, codeDepth, codeFlatten, codeFlattenPoint, codeFlattenRange, codeGather, codeIf, codeIndexOfPoint, codeInsertAtGap, codeIteratePoints, codeIterateRoot, codeLengthPoints, , codeNthPoint, codeNthRoot, codeRemovePoint, codeReplaceAllPoints, codeReplaceFirstPoint, codeWidth, codeWrapPoints


extension Interpreter {

    static let codeAppend_Behavior =
    Behavior(
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
    )

    static let codeLengthRoot_Behavior =
    Behavior(
        .codeLengthRoot,
        takes: [.code],
        fxn: {a in
            let (x) = (a[0] as! CodeItem)
            let result =
                IntItem(
                    x.value.count,
                    call: [x, InstructionItem(.codeLengthRoot)],
                    isContingent: Behavior.netContingency(of: x)
                    )
            return [ Router( .int, result) ]
        }
    )

    static let codeWrapRoot_Behavior =
    Behavior(
        .codeWrapRoot,
        takes: [.code],
        fxn: {a in
            let (x) = (a[0] as! CodeItem)
            let result =
                CodeItem(
                    [x],
                    call: [x, InstructionItem(.codeWrapRoot)],
                    isContingent: Behavior.netContingency(of: x)
                    )
            return [ Router( .code, result) ]
        }
    )

    static let codeIsEmpty_Behavior =
    Behavior(
        .codeIsEmpty,
        takes: [.code],
        fxn: {a in
            let (x) = (a[0] as! CodeItem)
            let result =
                BoolItem(
                    x.value.isEmpty,
                    call: [x, InstructionItem(.codeIsEmpty)],
                    isContingent: Behavior.netContingency(of: x)
                    )
            return [ Router( .bool, result) ]
        }
    )

    static let execQuote_Behavior =
    Behavior(
        .execQuote,
        takes: [.exec],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [InstructionItem(.execQuote), x]
            return [ Router(.code, result) ]
        }
    )

    static let intQuote_Behavior =
    Behavior(
        .intQuote,
        takes: [.int],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.intQuote)]
            return [ Router(.code, result) ]
        }
    )


    static let codeBehaviors:[PushInstruction : Behavior] =
    [
        .codeAppend : codeAppend_Behavior,
        .codeIsEmpty : codeIsEmpty_Behavior,
        .codeLengthRoot : codeLengthRoot_Behavior,
        .codeWrapRoot : codeWrapRoot_Behavior,
        .execQuote : execQuote_Behavior,
        .intQuote : intQuote_Behavior,

    ]
}
