//
//  Instructions.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


// Propeller replica language

public nonisolated enum PushInstruction : String, CaseIterable, Codable, Sendable {
    
    
    // BOOL instructions
    //
    case boolAnd, boolIfPThenQ, boolIfQThenP, boolNand, boolNor, boolNot, boolNotP, boolNotPandQ, boolNotQ, boolOr, boolP, boolPandNotQ, boolQ,  boolXnor, boolXor
    
    // bool comparison
    case boolEq
    
    // bool conversion
    case boolFromDouble, boolFromInt
    
    // bool combinators
    case boolDeepDup, boolDup, boolDupItems, boolDupTimes, boolStackIsEmpty, boolFlush, boolPop, boolPopItems, boolRot, boolShove, boolStackDepth, boolSwap, boolYank, boolYankDup


    // CHAR instructions
    //
    case charIsDigit, charIsLetter, charIsWhitespace
    
    // char comparison
    case charEq, charGT, charGTE, charLT, charLTE
    
    // char conversion
    case charFromDouble, charFromInt
    
    // char combinators
    case charDeepDup, charDup, charDupItems, charDupTimes, charStackIsEmpty, charFlush, charPop, charPopItems, charRot, charShove, charStackDepth, charSwap, charYank, charYankDup


    // CODE instructions
    // wherever a tree ordering is needed, it is pre-order (a node before its children)
    //
    case codeAppend, codeContainer, codeContains, codeCutAtGap, codeCutRootAtGap, codeDepth, codeDo, codeFlatten, codeFlattenOnce, codeFlattenPoint, codeFlattenRange, codePair, codeIf, codeDoIf, codeIndexOfPoint, codeInsertAtGap, codeItemIsEmpty, codeIteratePoints, codeIterateEmitPoints, codeIterateDoPoints, codeIterateRoot, codeLengthPoints, codeLengthRoot, codeNthPoint, codeNthRoot, codeDoNthPoint, codeDoNthRoot, codeEmitNthPoint, codeEmitNthRoot, codeRemovePoint, codeReplaceAllPoints, codeReplaceFirstPoint, codeWidth, codeWrapRoot, codeWrapPoints

    /// Drive an iterator to exhaustion and box everything it emitted into a block.
    ///
    /// **The general case of collecting**, and the reason it never refuses: a
    /// CodeItem is this language's vector-of-anything, so *every* iterator has an
    /// answer here. `.vecFromIterator` is the special case for when the emissions
    /// happen to be uniform scalars and a real vector will hold them.
    ///
    /// It is also one of the few genuine **producers** of `.code`, which is the
    /// language's structurally scarcest resource — until now, only the five quotes
    /// made new code out of anything (Stack economics, part 1).
    case codeFromIterator

    // code comparison
    case codeEq

    // code conversion
    case execQuote, intQuote, boolQuote, charQuote, stringQuote, doubleQuote

    /// Box a live iterator and park it on `.code`.
    ///
    /// The other quotes lift a *value* out of reach of its own stack's
    /// combinators. This one lifts a **loop** out of reach of a pending
    /// continuation, which is a sharper thing to want: `.iteratorPlay` advances
    /// whatever is on top of `.iterator` and does not name its iterator, so before
    /// this the only way to keep a loop from being advanced was to have a *second*
    /// loop to displace it with. A lone iterator could be re-aimed or killed, never
    /// shelved.
    ///
    /// `( «iter» ) .codeDo` gives it back: the block unwraps onto `.exec`, and an
    /// iterator is not an instruction, so `pushDefault` routes it home to
    /// `.iterator`. Nothing new was needed for the return trip.
    case iteratorQuote

    // code combinators
    case codeDeepDup, codeDup, codeDupItems, codeDupTimes, codeStackIsEmpty, codeFlush, codePop, codePopItems, codeRot, codeShove, codeStackDepth, codeSwap, codeYank, codeYankDup

    
    // DOUBLE instructions
    //
    case doubleAdd, doubleCos, doubleDec, doubleDivide, doubleInc, doubleMax, doubleMin, doublePeekMax, doublePeekMin, doubleMod, doubleMultiply, doubleQuot, doubleSin, doubleSubtract, doubleTan
    
    // double comparison
    case doubleEq, doubleGT, doubleGTE, doubleLT, doubleLTE
    
    // double conversion
    case doubleFromBool, doubleFromChar, doubleFromString, doubleFromInt
    
    // double combinators
    case doubleDeepDup, doubleDup, doubleDupItems, doubleDupTimes, doubleStackIsEmpty, doubleFlush, doublePop, doublePopItems, doubleRot, doubleShove, doubleStackDepth, doubleSwap, doubleYank, doubleYankDup


    // EXEC instructions
    //
    case execDoCount, execDoRange, execDoTimes, execDoWhile, execIf, execK, execS, execWhen, execWhile, execY
    
    // exec comparison: none. `execEq` was removed (2026-11-07): with blocks landing
    // on `.code` intact, `( A ) ( B ) .codeEq` asks the same question, and its
    // prefix crux could not reproduce derived operands (Roadmap #26).

    // exec conversion
    
    // exec combinators
    case execDeepDup, execDup, execDupItems, execDupTimes, execStackIsEmpty, execFlush, execPop, execPopItems, execRot, execShove, execStackDepth, execSwap, execYank, execYankDup

    
    
    // INPUT instructions
    //
    case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9

 
    
    // INT instructions
    //
    case intAdd, intDec, intInc, intMax, intMin, intPeekMax, intPeekMin, intMod, intMultiply, intQuot, intSubtract
    
    // int comparison
    case intEq, intGT, intGTE, intLT, intLTE
    
    // int conversion
    case intFromBool, intFromChar, intFromDouble, intFromString
    
    // int combinators
    case intDeepDup, intDup, intDupItems, intDupTimes, intStackIsEmpty, intFlush, intPop, intPopItems, intRot, intShove, intStackDepth, intSwap, intYank, intYankDup


    // ITERATOR instructions
    //
    // An iterator encapsulates the state of one loop: where it started, where it
    // ends, its stride, how far it has come, and the body it emits each pass.
    // Stepping is the only thing that moves it; the getters below are the only
    // things that read it.
    case iteratorStep, iteratorPlay, iteratorPlayDelayed, iteratorPopState

    // iterator getters
    //
    // `Peek` rather than the bare field name, because these are the language's
    // one deliberate exception to "an instruction eats its argument": they hand
    // the iterator back untouched. A live loop is not a value, and a getter that
    // killed it to report its stride would be useless in the body, which is
    // exactly where a program wants to ask. The name is the warning label.
    case iteratorPeekStart, iteratorPeekEnd, iteratorPeekStride, iteratorPeekBody
    case iteratorPeekLaps

    // iterator setters
    //
    // These re-aim a loop that is already running. They consume their new value
    // and hand the iterator back changed — so unlike `Peek` they are ordinary in
    // that respect, and only the iterator itself survives.
    //
    // **A change that finishes the loop destroys it.** Carry the counter past the
    // end, hand a counting iterator a string to count from, or set a negative
    // depth, and there is nothing left to emit — so nothing comes back. That is
    // the same rule every other path already follows: a spent iterator is not a
    // thing.
    case iteratorSetStart, iteratorSetEnd, iteratorSetCounter, iteratorSetDepth

    /// How many times a walking iterator goes round its source. Cycling is an
    /// attribute rather than a kind, and this is the only way to set it: no
    /// constructor takes it, so an iterator that never asks pays nothing — not an
    /// argument, and not a longer crux.
    ///
    /// **Refused for `.counting` and `.repeating`**, which keep their span in
    /// `destination`; laps there would be a second number meaning the same thing.
    /// A sawtooth counter is a cycling walk over a vector of the numbers.
    case iteratorSetLaps

    /// Rewind a loop: the cursor goes back to 0, and start, end, stride and body
    /// are left exactly as they were.
    ///
    /// It is not `0 .iteratorSetCounter` with fewer keystrokes. **It takes no
    /// arguments**, and `.int` is unmet more often than not (Stack economics), so
    /// the setter frequently cannot fire where this always can. In a language whose
    /// defining flaw is argument starvation, a zero-argument form of a useful
    /// operation earns its own instruction.
    case iteratorRestart

    // iterator construction
    //
    // All construct-only: they build an iterator and leave it alone, never
    // running it. They exist so `crux()` has something to say — an iterator's
    // record rebuilds it by state, and re-running that record has to produce the
    // iterator rather than run its loop.
    case iteratorFromIntRange
    case iteratorFromString, iteratorFromStringLetters, iteratorFromStringWords
    case iteratorFromVecBool, iteratorFromVecDouble, iteratorFromVecInt, iteratorFromVecString
    // A CodeItem is the universal box: it can hold any item, so ONE constructor
    // covers a repeating iterator over all thirteen stacks rather than thirteen.
    // The `IntoExec` variants exist because `.exec` is the one target that cannot
    // be derived from the element — its contents are heterogeneous *and* pending —
    // and a PushStack is not expressible as a Push value, so the exception has to
    // live in the name.
    case iteratorFromCode, iteratorFromCodeIntoExec, iteratorFromCodePoints, iteratorFromCodeEmitPoints, iteratorFromCodeDoPoints
    case iteratorRepeating, iteratorRepeatingIntoExec

    // iterator combinators
    case iteratorDeepDup, iteratorDup, iteratorDupItems, iteratorDupTimes, iteratorStackIsEmpty, iteratorEq, iteratorFlush, iteratorPop, iteratorPopItems, iteratorRot, iteratorShove, iteratorStackDepth, iteratorSwap, iteratorYank, iteratorYankDup


    // PRINT instructions
    //
    case boolPrint, charPrint, codePrint, doublePrint, execPrint, intPrint, iteratorPrint, printNewline, stringPrint, vecBoolPrint, vecDoublePrint, vecIntPrint, vecStringPrint
    
    
    // STRING instructions
    //
    case stringButLast, stringConcat, stringConjChar, stringContains, stringContainsChar, stringDrop, stringFirst, stringIndexOfChar, stringItemIsEmpty, stringIterate, stringLast, stringLength, stringNth, stringNthWord, stringOccurrencesOfChar, stringRemoveChar, stringReplace, stringReplaceChar, stringReplaceFirst, stringReplaceFirstChar, stringRest, stringReverse, stringSetChar, stringSplit, stringSubstring, stringTake, stringCut, stringDropLast, stringTakeLast, stringPeekNth

    // string comparison
    case stringEq, stringGT, stringGTE, stringLT, stringLTE
    
    // string conversion
    case stringFromBool, stringFromChar, stringFromDouble, stringFromInt, stringParseToLetters, stringPushAllChars
    
    // string combinators
    case stringDeepDup, stringDup, stringDupItems, stringDupTimes, stringStackIsEmpty, stringFlush, stringPop, stringPopItems, stringRot, stringShove, stringStackDepth, stringSwap, stringYank, stringYankDup


    
    // VECBOOL instructions
    //
    case vecBoolButLast, vecBoolConcat, vecBoolConj, vecBoolContains, vecBoolDrop, vecBoolFirst, vecBoolIndexOf, vecBoolItemIsEmpty, vecBoolIterate, vecBoolLast, vecBoolLength, vecBoolNth, vecBoolOccurrencesOf, vecBoolRemove, vecBoolReplace, vecBoolReplaceFirst, vecBoolRest, vecBoolReverse, vecBoolSet, vecBoolSubVec, vecBoolTake, vecBoolCut, vecBoolContainsSubVec, vecBoolIndexOfSubVec, vecBoolOccurrencesOfSubVec, vecBoolReplaceSubVec, vecBoolReplaceFirstSubVec, vecBoolReadItems, vecBoolReadStack, vecBoolDropLast, vecBoolTakeLast, vecBoolPeekNth

    // vecBool comparison
    case vecBoolEq
    
    // vecBool conversion
    case vecBoolPushAll, vecBoolConstruct
    
    // vecBool combinators
    case vecBoolDeepDup, vecBoolDup, vecBoolDupItems, vecBoolDupTimes, vecBoolStackIsEmpty, vecBoolFlush, vecBoolPop, vecBoolPopItems, vecBoolRot, vecBoolShove, vecBoolStackDepth, vecBoolSwap, vecBoolYank, vecBoolYankDup

    
    /// Drive an iterator to exhaustion and collect what it emits into a vector of
    /// the matching type — the one vector instruction belonging to no one vector
    /// type, because **its result type is its argument's**. Hand it an
    /// Int-emitting iterator and a `vecInt` comes back; a Bool-emitting one and a
    /// `vecBool` does.
    ///
    /// That polymorphism is what lets this exist without a sieve. A genome cannot
    /// *ask* for "an iterator that emits Ints" — `.iterator` is homogeneous by
    /// type and heterogeneous by behaviour, and asking for the top one and hoping
    /// is all anything can do (see "Notes on Push/Sieve arguments.md"). So this
    /// takes whatever iterator is there and answers in kind, rather than
    /// demanding a type it has no way to find.
    case vecFromIterator

    // VECDOUBLE instructions
    //
    case vecDoubleButLast, vecDoubleConcat, vecDoubleConj, vecDoubleContains, vecDoubleDrop, vecDoubleFirst, vecDoubleIndexOf, vecDoubleItemIsEmpty, vecDoubleIterate, vecDoubleLast, vecDoubleLength, vecDoubleNth, vecDoubleOccurrencesOf, vecDoubleRemove, vecDoubleReplace, vecDoubleReplaceFirst, vecDoubleRest, vecDoubleReverse, vecDoubleSet, vecDoubleSubVec, vecDoubleTake, vecDoubleCut, vecDoubleContainsSubVec, vecDoubleIndexOfSubVec, vecDoubleOccurrencesOfSubVec, vecDoubleReplaceSubVec, vecDoubleReplaceFirstSubVec, vecDoubleReadItems, vecDoubleReadStack, vecDoubleLT, vecDoubleLTE, vecDoubleGT, vecDoubleGTE, vecDoubleDropLast, vecDoubleTakeLast, vecDoublePeekNth

    // vecDouble comparison
    case vecDoubleEq
    
    // vecDouble conversion
    case vecDoublePushAll, vecDoubleConstruct
    
    // vecDouble combinators
    case vecDoubleDeepDup, vecDoubleDup, vecDoubleDupItems, vecDoubleDupTimes, vecDoubleStackIsEmpty, vecDoubleFlush, vecDoublePop, vecDoublePopItems, vecDoubleRot, vecDoubleShove, vecDoubleStackDepth, vecDoubleSwap, vecDoubleYank, vecDoubleYankDup

    
    
    // VECINT instructions
    //
    case vecIntButLast, vecIntConcat, vecIntConj, vecIntContains, vecIntDrop, vecIntFirst, vecIntIndexOf, vecIntItemIsEmpty, vecIntIterate, vecIntLast, vecIntLength, vecIntNth, vecIntOccurrencesOf, vecIntRemove, vecIntReplace, vecIntReplaceFirst, vecIntRest, vecIntReverse, vecIntSet, vecIntSubVec, vecIntTake, vecIntCut, vecIntContainsSubVec, vecIntIndexOfSubVec, vecIntOccurrencesOfSubVec, vecIntReplaceSubVec, vecIntReplaceFirstSubVec, vecIntReadItems, vecIntReadStack, vecIntLT, vecIntLTE, vecIntGT, vecIntGTE, vecIntDropLast, vecIntTakeLast, vecIntPeekNth

    // vecInt comparison
    case vecIntEq
    
    // vecInt conversion
    case vecIntPushAll, vecIntConstruct
    
    // vecInt combinators
    case vecIntDeepDup, vecIntDup, vecIntDupItems, vecIntDupTimes, vecIntStackIsEmpty, vecIntFlush, vecIntPop, vecIntPopItems, vecIntRot, vecIntShove, vecIntStackDepth, vecIntSwap, vecIntYank, vecIntYankDup

    
    // VECSTRING instructions
    //
    case vecStringButLast, vecStringConcat, vecStringConj, vecStringContains, vecStringDrop, vecStringFirst, vecStringIndexOf, vecStringItemIsEmpty, vecStringIterate, vecStringLast, vecStringLength, vecStringNth, vecStringOccurrencesOf, vecStringRemove, vecStringReplace, vecStringReplaceFirst, vecStringRest, vecStringReverse, vecStringSet, vecStringSubVec, vecStringTake, vecStringCut, vecStringContainsSubVec, vecStringIndexOfSubVec, vecStringOccurrencesOfSubVec, vecStringReplaceSubVec, vecStringReplaceFirstSubVec, vecStringReadItems, vecStringReadStack, vecStringLT, vecStringLTE, vecStringGT, vecStringGTE, vecStringDropLast, vecStringTakeLast, vecStringPeekNth

    // vecString comparison
    case vecStringEq
    
    // vecString conversion
    case vecStringPushAll, vecStringConstruct
    
    // vecString combinators
    case vecStringDeepDup, vecStringDup, vecStringDupItems, vecStringDupTimes, vecStringStackIsEmpty, vecStringFlush, vecStringPop, vecStringPopItems, vecStringRot, vecStringShove, vecStringStackDepth, vecStringSwap, vecStringYank, vecStringYankDup

    
    
    // CONSTANTS
    //
    // char constants
    case char0, char1, char2, char3, char4, char5, char6, char7, char8, char9
    
    // double constants
    case double0, double1, double2, double3, double4, double5, double6, double7, double8, double9

    // int constants
    case int0, int1, int2, int3, int4, int5, int6, int7, int8, int9

    // string constants
    // Collection reductions (Behavior coverage audit, P1)
    case vecIntSum, vecDoubleSum, vecIntMax, vecIntMin, vecDoubleMax, vecDoubleMin,
         vecStringMax, vecStringMin, stringMax, stringMin

    case string0, string1, string2, string3, string4, string5, string6, string7, string8, string9
    
    // vecBool constants
    case vecBool0, vecBool1, vecBool2, vecBool3, vecBool4, vecBool5, vecBool6, vecBool7, vecBool8, vecBool9
    
    // vecDouble constants
    case vecDouble0, vecDouble1, vecDouble2, vecDouble3, vecDouble4, vecDouble5, vecDouble6, vecDouble7, vecDouble8, vecDouble9
    
    // vecInt constants
    case vecInt0, vecInt1, vecInt2, vecInt3, vecInt4, vecInt5, vecInt6, vecInt7, vecInt8, vecInt9
    
    // vecString constants
    case vecString0, vecString1, vecString2, vecString3, vecString4, vecString5, vecString6, vecString7, vecString8, vecString9


    // Introspection
    case pushStepCount, errorStackDepth, errorMissingArgCount, errorMissingInputCount, errorMissingConstantCount

}

typealias PI = PushInstruction

nonisolated extension PushInstruction: CustomStringConvertible {
    /// The case name, so interpolating an instruction never falls back to runtime
    /// reflection (profiling caught it in the step loop). Raw values are the case
    /// names, so the text is unchanged.
    public var description: String { rawValue }
}

nonisolated extension PushInstruction {
    /// This instruction's position in `allCases` — its slot in a `BehaviorTable`.
    ///
    /// Read straight from the enum's storage, which for a payload-free enum is the
    /// case's declaration index: `allCases` order, with nothing to maintain when a
    /// case is added. `Stack Ordinal Tests` pins the assumption; `unsafeBitCast`
    /// traps if the enum ever outgrows two bytes. The point is to avoid hashing:
    /// the enum is String-backed and hashes its raw string.
    @inline(__always)
    var ordinal: Int { Int(unsafeBitCast(self, to: UInt16.self)) }
}

/// Which `Behavior` runs for each instruction: an array in `PushInstruction.allCases`
/// order, addressed by `ordinal`. It reads like the dictionary it replaced —
/// `behaviors[.intAdd]`, `behaviors[.intAdd] = nil` to disable one — but a lookup
/// is an index, not a String hash.
///
/// Built from `Interpreter.language` once; copies share storage until one is
/// edited, so handing the same table to every interpreter in a batch is free.
nonisolated struct BehaviorTable: Sendable {
    private var slots: [Behavior?]

    init(_ language: [PushInstruction: Behavior], disabling disabled: Set<PushInstruction> = []) {
        var slots = [Behavior?](repeating: nil, count: PushInstruction.allCases.count)
        for (instruction, behavior) in language where !disabled.contains(instruction) {
            slots[instruction.ordinal] = behavior
        }
        self.slots = slots
    }

    subscript(instruction: PushInstruction) -> Behavior? {
        @inline(__always) get { slots[instruction.ordinal] }
        set { slots[instruction.ordinal] = newValue }
    }
}
