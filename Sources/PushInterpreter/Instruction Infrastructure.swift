//
//  Instructions.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


// Propeller replica language

enum PushInstruction : String, CaseIterable {
        
    case intAdd, intSubtract, intMultiply, intGT, intGTE, intLT, intLTE, intQuot, intMod, intMax, intMin, intFromBool, intFromChar, intFromDouble, intFromString, intInc, intDec, intDup, intDupTimes, intDupItems, intEmpty, intEq, intFlush, intPop, intRot, intShove, intStackDepth, intSwap, intYank, intYankDup, intDeepDup
    
    case doubleAdd, doubleSubtract, doubleMultiply, doubleDivide, doubleGT, doubleGTE, doubleLT, doubleLTE, doubleQuot, doubleMod, doubleMax, doubleMin, doubleFromBool, doubleFromChar, doubleFromString, doubleInc, doubleDec, doubleDup, doubleDupTimes, doubleDupItems, doubleEmpty, doubleEq, doubleFlush, doublePop, doubleRot, doubleShove, doubleStackDepth, doubleSwap, doubleYank, doubleYankDup, doubleDeepDup, doubleCos, doubleSin, doubleTan, doubleFromInt
    
    case boolAnd, boolNot, boolOr, boolXor, boolInvertFirstThenAnd, boolInvertSecondThenAnd, boolFromDouble, boolFromInt, boolDup, boolDupTimes, boolDupItems, boolEmpty, boolEq, boolFlush, boolPop, boolRot, boolShove, boolStackDepth, boolSwap, boolYank, boolYankDup, boolDeepDup

    case charIsLetter, charIsDigit, charIsWhitespace, charFromDouble, charFromInt, charAllFromString, charDup, charDupTimes, charDupItems, charEmpty, charEq, charFlush, charPop, charRot, charShove, charStackDepth, charSwap, charYank, charYankDup, charDeepDup
    
    case codeAppend, codeDup, codeDupTimes, codeDupItems, codeEmpty, codeEq, codeFlush, codePop, codeRot, codeShove, codeStackDepth, codeSwap, codeYank, codeYankDup, codeDeepDup
    
    case execDoRange, execDoCount, execDoTimes, execIf, execWhen, execWhile, execDoWhile, execK, execS, execY, execDup, execDupTimes, execDupItems, execEmpty, execEq, execFlush, execPop, execRot, execShove, execStackDepth, execSwap, execYank, execYankDup, execDeepDup
    
    case printNewline, boolPrint, charPrint, stringPrint, intPrint, doublePrint, codePrint, execPrint,
         vecBoolPrint, vecIntPrint, vecDoublePrint, vecStringPrint
    
    case vecBoolDup, vecBoolDupTimes, vecBoolDupItems, vecBoolEmpty, vecBoolEq, vecBoolFlush, vecBoolPop, vecBoolRot, vecBoolShove, vecBoolStackDepth, vecBoolSwap, vecBoolYank, vecBoolYankDup, vecBoolDeepDup, vecBoolButLast, vecBoolConcat, vecBoolConj, vecBoolContains, vecBoolEmptyVector, vecBoolFirst, vecBoolIndexOf, vecBoolIterate, vecBoolLast, vecBoolLength, vecBoolNth, vecBoolOccurrencesOf, vecBoolPushAll, vecBoolRemove, vecBoolReplace, vecBoolReplaceFirst, vecBoolRest, vecBoolReverse, vecBoolSet, vecBoolSubVec, vecBoolTake, vecBoolDrop
        
    case vecDoubleDup, vecDoubleDupTimes, vecDoubleDupItems, vecDoubleEmpty, vecDoubleEq, vecDoubleFlush, vecDoublePop, vecDoubleRot, vecDoubleShove, vecDoubleStackDepth, vecDoubleSwap, vecDoubleYank, vecDoubleYankDup, vecDoubleDeepDup, vecDoubleButLast, vecDoubleConcat, vecDoubleConj, vecDoubleContains, vecDoubleEmptyVector, vecDoubleFirst, vecDoubleIndexOf, vecDoubleIterate, vecDoubleLast, vecDoubleLength, vecDoubleNth, vecDoubleOccurrencesOf, vecDoublePushAll, vecDoubleRemove, vecDoubleReplace, vecDoubleReplaceFirst, vecDoubleRest, vecDoubleReverse, vecDoubleSet, vecDoubleSubVec, vecDoubleTake, vecDoubleDrop

    case vecIntDup, vecIntDupTimes, vecIntDupItems, vecIntEmpty, vecIntEq, vecIntFlush, vecIntPop, vecIntRot, vecIntShove, vecIntStackDepth, vecIntSwap, vecIntYank, vecIntYankDup, vecIntDeepDup, vecIntButLast, vecIntConcat, vecIntConj, vecIntContains, vecIntEmptyVector, vecIntFirst, vecIntIndexOf, vecIntIterate, vecIntLast, vecIntLength, vecIntNth, vecIntOccurrencesOf, vecIntPushAll, vecIntRemove, vecIntReplace, vecIntReplaceFirst, vecIntRest, vecIntReverse, vecIntSet, vecIntSubVec, vecIntTake, vecIntDrop

    case vecStringDup, vecStringDupTimes, vecStringDupItems, vecStringEmpty, vecStringEq, vecStringFlush, vecStringPop, vecStringRot, vecStringShove, vecStringStackDepth, vecStringSwap, vecStringYank, vecStringYankDup, vecStringDeepDup, vecStringButLast, vecStringConcat, vecStringConj, vecStringContains, vecStringEmptyVector, vecStringFirst, vecStringIndexOf, vecStringIterate, vecStringLast, vecStringLength, vecStringNth, vecStringOccurrencesOf, vecStringPushAll, vecStringRemove, vecStringReplace, vecStringReplaceFirst, vecStringRest, vecStringReverse, vecStringSet, vecStringSubVec, vecStringTake, vecStringDrop

    case stringButLast, stringConcat, stringConjChar, stringContains, stringContainsChar, stringDrop, stringEmptyString, stringFirst, stringFromBool, stringFromChar, stringFromDouble, stringFromInt, stringIndexOfChar, stringIterate, stringLast, stringLength, stringNth, stringOccurrencesOfChar, stringParseToChars, stringRemoveChar, stringReplace, stringReplaceChar, stringReplaceFirst, stringReplaceFirstChar, stringRest, stringReverse, stringSetChar, stringSplit, stringSubstring, stringTake, stringDup, stringDupTimes, stringDupItems, stringFlush, stringPop, stringRot, stringShove, stringStackDepth, stringSwap, stringYank, stringYankDup, stringDeepDup, stringEq, stringGT, stringGTE, stringLT, stringLTE, stringEmpty
    
    case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9
    
    case char0, char1, char2, char3, char4, char5, char6, char7, char8, char9,
         string0, string1, string2, string3, string4, string5, string6, string7, string8, string9,
         int0, int1, int2, int3, int4, int5, int6, int7, int8, int9,
         double0, double1, double2, double3, double4, double5, double6, double7, double8, double9,
         vecBool0, vecBool1, vecBool2, vecBool3, vecBool4, vecBool5, vecBool6, vecBool7, vecBool8, vecBool9,
         vecString0, vecString1, vecString2, vecString3, vecString4, vecString5, vecString6, vecString7, vecString8, vecString9,
         vecInt0, vecInt1, vecInt2, vecInt3, vecInt4, vecInt5, vecInt6, vecInt7, vecInt8, vecInt9,
         vecDouble0, vecDouble1, vecDouble2, vecDouble3, vecDouble4, vecDouble5, vecDouble6, vecDouble7, vecDouble8, vecDouble9
}

typealias PI = PushInstruction

