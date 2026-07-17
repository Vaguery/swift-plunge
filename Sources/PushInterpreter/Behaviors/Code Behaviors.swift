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


    /// Drive an iterator to exhaustion and box what it emitted into one block.
    ///
    /// **This is the general form of collecting, and it never refuses.** A
    /// CodeItem is the vector-of-anything (see "The universal box" in Items.swift),
    /// so every iterator that emits anything at all has an answer here — including
    /// the ones `.vecFromIterator` must turn away: a tree walk emitting subtrees,
    /// a `.repeating` iterator carrying a block, an `.elements` walk over a mixed
    /// block, a string's chars. Read the pair the right way round and the
    /// asymmetry disappears: **a vector is the special case where the emissions
    /// are uniform scalars**, and this is the case that always applies.
    ///
    /// Provenance is law 3, exactly as `.vecFromIterator`: the block records its
    /// iterator and this instruction, and the iterator's own record rebuilds it at
    /// its cursor, so re-running collects the same sequence from the same place.
    /// The elements keep their own `call`s, which is what makes the block's crux
    /// say where each of its contents came from.
    ///
    /// An empty collect needs no special case here, and that is the difference
    /// from the vector form: `( )` is a perfectly good value, where an empty
    /// vector of *no particular type* is a question with no answer.
    ///
    /// **Order**: the body is handed back first so the collected block lands on
    /// top of it. Both go to `.code`, and the result is what the next instruction
    /// should find — a crux fragment has to leave its value on top or nothing
    /// composes.
    static let codeFromIterator_Behavior =
    Behavior(
        .codeFromIterator,
        takes: [.iterator],
        fxn: { a in
            let iterator = a[0] as! IteratorItem
            let collected = CodeItem(
                iterator.collected(),
                call: [iterator, InstructionItem(.codeFromIterator)],
                isContingent: Behavior.netContingency(of: iterator)
            )
            return Interpreter.iteratorFarewell(iterator) + [Router(.code, collected)]
        }
    )


    static let codeBehaviors:[PushInstruction : Behavior] =
    [
        .codeFromIterator : codeFromIterator_Behavior,
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
