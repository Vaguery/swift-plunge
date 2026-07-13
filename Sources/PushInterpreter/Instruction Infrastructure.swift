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
    case boolDeepDup, boolDup, boolDupItems, boolDupTimes, boolStackIsEmpty, boolFlush, boolPop, boolRot, boolShove, boolStackDepth, boolSwap, boolYank, boolYankDup


    // CHAR instructions
    //
    case charIsDigit, charIsLetter, charIsWhitespace
    
    // char comparison
    case charEq, charGT, charGTE, charLT, charLTE
    
    // char conversion
    case charFromDouble, charFromInt
    
    // char combinators
    case charDeepDup, charDup, charDupItems, charDupTimes, charStackIsEmpty, charFlush, charPop, charRot, charShove, charStackDepth, charSwap, charYank, charYankDup


    // CODE instructions
    // wherever a tree ordering is needed, it is PostOrder unless specifically mentioned
    //
    case codeAppend, codeContainer, codeContains, codeCutAtGap, codeCutRootAtGap, codeDepth, codeFlatten, codeFlattenPoint, codeFlattenRange, codeGather, codeIf, codeIndexOfPoint, codeInsertAtGap, codeItemIsEmpty, codeIteratePoints, codeIterateRoot, codeLengthPoints, codeLengthRoot, codeNthPoint, codeNthRoot, codeRemovePoint, codeReplaceAllPoints, codeReplaceFirstPoint, codeWidth, codeWrapRoot, codeWrapPoints

    // code comparison
    case codeEq

    // code conversion
    case execQuote, intQuote, boolQuote, charQuote, stringQuote, doubleQuote

    // code combinators
    case codeDeepDup, codeDup, codeDupItems, codeDupTimes, codeStackIsEmpty, codeFlush, codePop, codeRot, codeShove, codeStackDepth, codeSwap, codeYank, codeYankDup

    
    // DOUBLE instructions
    //
    case doubleAdd, doubleCos, doubleDec, doubleDivide, doubleInc, doubleMax, doubleMin, doubleMod, doubleMultiply, doubleQuot, doubleSin, doubleSubtract, doubleTan
    
    // double comparison
    case doubleEq, doubleGT, doubleGTE, doubleLT, doubleLTE
    
    // double conversion
    case doubleFromBool, doubleFromChar, doubleFromString, doubleFromInt
    
    // double combinators
    case doubleDeepDup, doubleDup, doubleDupItems, doubleDupTimes, doubleStackIsEmpty, doubleFlush, doublePop, doubleRot, doubleShove, doubleStackDepth, doubleSwap, doubleYank, doubleYankDup


    // EXEC instructions
    //
    case execDoCount, execDoRange, execDoTimes, execDoWhile, execIf, execK, execS, execWhen, execWhile, execY
    
    // exec comparison
    case execEq
    
    // exec conversion
    
    // exec combinators
    case execDeepDup, execDup, execDupItems, execDupTimes, execStackIsEmpty, execFlush, execPop, execRot, execShove, execStackDepth, execSwap, execYank, execYankDup

    
    
    // INPUT instructions
    //
    case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9

 
    
    // INT instructions
    //
    case intAdd, intDec, intInc, intMax, intMin, intMod, intMultiply, intQuot, intSubtract
    
    // int comparison
    case intEq, intGT, intGTE, intLT, intLTE
    
    // int conversion
    case intFromBool, intFromChar, intFromDouble, intFromString
    
    // int combinators
    case intDeepDup, intDup, intDupItems, intDupTimes, intStackIsEmpty, intFlush, intPop, intRot, intShove, intStackDepth, intSwap, intYank, intYankDup


    // PRINT instructions
    //
    case boolPrint, charPrint, codePrint, doublePrint, execPrint, intPrint, printNewline, stringPrint, vecBoolPrint, vecDoublePrint, vecIntPrint, vecStringPrint
    
    
    // STRING instructions
    //
    case stringButLast, stringConcat, stringConjChar, stringContains, stringContainsChar, stringDrop, stringFirst, stringIndexOfChar, stringItemIsEmpty, stringIterate, stringLast, stringLength, stringNth, stringOccurrencesOfChar, stringRemoveChar, stringReplace, stringReplaceChar, stringReplaceFirst, stringReplaceFirstChar, stringRest, stringReverse, stringSetChar, stringSplit, stringSubstring, stringTake

    // string comparison
    case stringEq, stringGT, stringGTE, stringLT, stringLTE
    
    // string conversion
    case stringFromBool, stringFromChar, stringFromDouble, stringFromInt, stringParseToLetters, stringPushAllChars
    
    // string combinators
    case stringDeepDup, stringDup, stringDupItems, stringDupTimes, stringStackIsEmpty, stringFlush, stringPop, stringRot, stringShove, stringStackDepth, stringSwap, stringYank, stringYankDup


    
    // VECBOOL instructions
    //
    case vecBoolButLast, vecBoolConcat, vecBoolConj, vecBoolContains, vecBoolDrop, vecBoolFirst, vecBoolIndexOf, vecBoolItemIsEmpty, vecBoolIterate, vecBoolLast, vecBoolLength, vecBoolNth, vecBoolOccurrencesOf, vecBoolRemove, vecBoolReplace, vecBoolReplaceFirst, vecBoolRest, vecBoolReverse, vecBoolSet, vecBoolSubVec, vecBoolTake

    // vecBool comparison
    case vecBoolEq
    
    // vecBool conversion
    case vecBoolPushAll
    
    // vecBool combinators
    case vecBoolDeepDup, vecBoolDup, vecBoolDupItems, vecBoolDupTimes, vecBoolStackIsEmpty, vecBoolFlush, vecBoolPop, vecBoolRot, vecBoolShove, vecBoolStackDepth, vecBoolSwap, vecBoolYank, vecBoolYankDup

    
    // VECDOUBLE instructions
    //
    case vecDoubleButLast, vecDoubleConcat, vecDoubleConj, vecDoubleContains, vecDoubleDrop, vecDoubleFirst, vecDoubleIndexOf, vecDoubleItemIsEmpty, vecDoubleIterate, vecDoubleLast, vecDoubleLength, vecDoubleNth, vecDoubleOccurrencesOf, vecDoubleRemove, vecDoubleReplace, vecDoubleReplaceFirst, vecDoubleRest, vecDoubleReverse, vecDoubleSet, vecDoubleSubVec, vecDoubleTake

    // vecDouble comparison
    case vecDoubleEq
    
    // vecDouble conversion
    case vecDoublePushAll
    
    // vecDouble combinators
    case vecDoubleDeepDup, vecDoubleDup, vecDoubleDupItems, vecDoubleDupTimes, vecDoubleStackIsEmpty, vecDoubleFlush, vecDoublePop, vecDoubleRot, vecDoubleShove, vecDoubleStackDepth, vecDoubleSwap, vecDoubleYank, vecDoubleYankDup

    
    
    // VECINT instructions
    //
    case vecIntButLast, vecIntConcat, vecIntConj, vecIntContains, vecIntDrop, vecIntFirst, vecIntIndexOf, vecIntItemIsEmpty, vecIntIterate, vecIntLast, vecIntLength, vecIntNth, vecIntOccurrencesOf, vecIntRemove, vecIntReplace, vecIntReplaceFirst, vecIntRest, vecIntReverse, vecIntSet, vecIntSubVec, vecIntTake

    // vecInt comparison
    case vecIntEq
    
    // vecInt conversion
    case vecIntPushAll
    
    // vecInt combinators
    case vecIntDeepDup, vecIntDup, vecIntDupItems, vecIntDupTimes, vecIntStackIsEmpty, vecIntFlush, vecIntPop, vecIntRot, vecIntShove, vecIntStackDepth, vecIntSwap, vecIntYank, vecIntYankDup

    
    // VECSTRING instructions
    //
    case vecStringButLast, vecStringConcat, vecStringConj, vecStringContains, vecStringDrop, vecStringFirst, vecStringIndexOf, vecStringItemIsEmpty, vecStringIterate, vecStringLast, vecStringLength, vecStringNth, vecStringOccurrencesOf, vecStringRemove, vecStringReplace, vecStringReplaceFirst, vecStringRest, vecStringReverse, vecStringSet, vecStringSubVec, vecStringTake

    // vecString comparison
    case vecStringEq
    
    // vecString conversion
    case vecStringPushAll
    
    // vecString combinators
    case vecStringDeepDup, vecStringDup, vecStringDupItems, vecStringDupTimes, vecStringStackIsEmpty, vecStringFlush, vecStringPop, vecStringRot, vecStringShove, vecStringStackDepth, vecStringSwap, vecStringYank, vecStringYankDup

    
    
    // CONSTANTS
    //
    // char constants
    case char0, char1, char2, char3, char4, char5, char6, char7, char8, char9
    
    // double constants
    case double0, double1, double2, double3, double4, double5, double6, double7, double8, double9

    // int constants
    case int0, int1, int2, int3, int4, int5, int6, int7, int8, int9

    // string constants
    case string0, string1, string2, string3, string4, string5, string6, string7, string8, string9
    
    // vecBool constants
    case vecBool0, vecBool1, vecBool2, vecBool3, vecBool4, vecBool5, vecBool6, vecBool7, vecBool8, vecBool9
    
    // vecDouble constants
    case vecDouble0, vecDouble1, vecDouble2, vecDouble3, vecDouble4, vecDouble5, vecDouble6, vecDouble7, vecDouble8, vecDouble9
    
    // vecInt constants
    case vecInt0, vecInt1, vecInt2, vecInt3, vecInt4, vecInt5, vecInt6, vecInt7, vecInt8, vecInt9
    
    // vecString constants
    case vecString0, vecString1, vecString2, vecString3, vecString4, vecString5, vecString6, vecString7, vecString8, vecString9
         
}

typealias PI = PushInstruction

