//
//  Code Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/17/26.
//

import DequeModule

//case codeContainer, codeContains, codeCutAtGap, codeCutRootAtGap, codeDepth, codeFlatten, codeFlattenPoint, codeFlattenRange, codeGather, codeIf, codeIndexOfPoint, codeInsertAtGap, codeIteratePoints, codeIterateRoot, codeLengthPoints, , codeNthPoint, codeNthRoot, codeRemovePoint, codeReplaceAllPoints, codeReplaceFirstPoint, codeWidth, codeWrapPoints

nonisolated extension Interpreter {

    static let codeAppend_Behavior =
        Behavior(
            .codeAppend,
            takes: [.code, .code],
            fxn: { a in
                let (x, y) = (a[0] as! CodeItem, a[1] as! CodeItem)
                let result =
                    CodeItem(
                        y.value + x.value,
                        call: [y, x, InstructionItem(.codeAppend)],
                        isContingent: Behavior.netContingency(of: x, y)
                    )
                return [Router(.code, result)]
            }
        )

    static let codeItemIsEmpty_Behavior =
        Behavior(
            .codeItemIsEmpty,
            takes: [.code],
            fxn: { a in
                let (x) = (a[0] as! CodeItem)
                let result =
                    BoolItem(
                        x.value.isEmpty,
                        call: [x, InstructionItem(.codeItemIsEmpty)],
                        isContingent: Behavior.netContingency(of: x)
                    )
                return [Router(.bool, result)]
            }
        )

    static let codeLengthRoot_Behavior =
        Behavior(
            .codeLengthRoot,
            takes: [.code],
            fxn: { a in
                let (x) = (a[0] as! CodeItem)
                let result =
                    IntItem(
                        x.value.count,
                        call: [x, InstructionItem(.codeLengthRoot)],
                        isContingent: Behavior.netContingency(of: x)
                    )
                return [Router(.int, result)]
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

    static let boolQuote_Behavior =
    Behavior(
        .boolQuote,
        takes: [.bool],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.boolQuote)]
            return [ Router(.code, result) ]
        }
    )

    static let stringQuote_Behavior =
    Behavior(
        .stringQuote,
        takes: [.string],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.stringQuote)]
            return [ Router(.code, result) ]
        }
    )

    static let charQuote_Behavior =
    Behavior(
        .charQuote,
        takes: [.char],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.charQuote)]
            return [ Router(.code, result) ]
        }
    )

    static let doubleQuote_Behavior =
    Behavior(
        .doubleQuote,
        takes: [.double],
        fxn: {a in
            let (x) = (a[0])
            var result = CodeItem([x])
            result.isContingent = Behavior.netContingency(of: x )
            result.call = [x, InstructionItem(.doubleQuote)]
            return [ Router(.code, result) ]
        }
    )


    /// Unwraps the top `.code` block onto `.exec`, so its contents run.
    ///
    /// This is the only way a block executes: the Interpreter pushes any
    /// `CodeItem` it meets on `.exec` to `.code` intact, so code is data until a
    /// program asks for it. It is `unwrapCodeItem` — which used to happen
    /// implicitly, on sight — promoted to an instruction.
    ///
    /// Note it cannot work the Push3 way. `CODE.DO` there pushes the block onto
    /// `EXEC`, where lists unwrap; here that would send it straight back to
    /// `.code`, forever. So it spreads the contents directly.
    ///
    /// Provenance: combinatory, law 1b. The block's own `call` is erased with the
    /// block, and each content keeps the `call` it already had — exposed as
    /// though it had been sitting there all along, unchanged from the time it
    /// went in. Being inside a block leaves no mark. Contingency does propagate:
    /// a block reached contingently makes its contents contingent.
    static let codeDo_Behavior =
    BehaviorWithSideEffects(
        .codeDo,
        takes: [.code],
        modifier: { (interpreter, collectedItems) in
            let block = collectedItems[0] as! CodeItem
            let contents = block.value.map { item -> any Item in
                var copy = item
                copy.isContingent = Behavior.netContingency(of: block, copy)
                return copy
            }
            interpreter.stacks[.exec]!.prepend(contentsOf: contents)
            return []
        }
    )


    static let codeBehaviors:[PushInstruction : Behavior] =
    [
        .boolQuote : boolQuote_Behavior,
        .charQuote : charQuote_Behavior,
        .codeAppend : codeAppend_Behavior,
        .codeDo : codeDo_Behavior,
        .codeItemIsEmpty : codeItemIsEmpty_Behavior,
        .codeLengthRoot : codeLengthRoot_Behavior,
        .codeWrapRoot : codeWrapRoot_Behavior,
        .doubleQuote : doubleQuote_Behavior,
        .execQuote : execQuote_Behavior,
        .intQuote : intQuote_Behavior,
        .stringQuote : stringQuote_Behavior,

    ]
}
