//
//  Instructions.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import Foundation

// Propeller replica language

enum PushInstruction : String, CaseIterable {
    case intAdd, intSubtract, intMultiply, intGT, intGTE, intLT, intLTE, intQuot, intMod, intMax, intMin, intFromBool, intFromChar, intFromString, intInc, intDec, intFromFloat, intDup, intDupTimes, intDupItems, intEmpty, intEq, intFlush, intPop, intRot, intShove, intStackDepth, intSwap, intYank, intYankDup, intDeepDup
    
    case floatAdd, floatSubtract, floatMultiply, floatGT, floatGTE, floatLT, floatLTE, floatQuot, floatMod, floatMax, floatMin, floatFromBool, floatFromChar, floatFromString, floatInc, floatDec, floatDup, floatDupTimes, floatDupItems, floatEmpty, floatEq, floatFlush, floatPop, floatRot, floatShove, floatStackDepth, floatSwap, floatYank, floatYankDup, floatDeepDup, floatCos, floatSin, floatTan, floatFromInt
    
    case boolAnd, boolNot, boolOr, boolXor, boolInvertFirstThenAnd, boolInvertSecondThenAnd, boolFromFloat, boolFromInt, boolDup, boolDupTimes, boolDupItems, boolEmpty, boolEq, boolFlush, boolPop, boolRot, boolShove, boolStackDepth, boolSwap, boolYank, boolYankDup, boolDeepDup

    case charIsLetter, charIsDigit, charIsWhitespace, charFromFloat, charFromInt, charAllFromString, charDup, charDupTimes, charDupItems, charEmpty, charEq, charFlush, charPop, charRot, charShove, charStackDepth, charSwap, charYank, charYankDup, charDeepDup
    
    case codeAppend, codeDup, codeDupTimes, codeDupItems, codeEmpty, codeEq, codeFlush, codePop, codeRot, codeShove, codeStackDepth, codeSwap, codeYank, codeYankDup, codeDeepDup
    
    case execDoRange, execDoCount, execDoTimes, execIf, execWhen, execWhile, execDoWhile, execK, execS, execY, execDup, execDupTimes, execDupItems, execEmpty, execEq, execFlush, execPop, execRot, execShove, execStackDepth, execSwap, execYank, execYankDup, execDeepDup
    
    case printNewline, boolPrint, charPrint, stringPrint, intPrint, floatPrint, codePrint, execPrint,
         vecBoolPrint, vecIntPrint, vecFloatPrint, vecStringPrint
    
    case vecBoolDup, vecBoolDupTimes, vecBoolDupItems, vecBoolEmpty, vecBoolEq, vecBoolFlush, vecBoolPop, vecBoolRot, vecBoolShove, vecBoolStackDepth, vecBoolSwap, vecBoolYank, vecBoolYankDup, vecBoolDeepDup, vecBoolButLast, vecBoolConcat, vecBoolConj, vecBoolContains, vecBoolEmptyVector, vecBoolFirst, vecBoolIndexOf, vecBoolIterate, vecBoolLast, vecBoolLength, vecBoolNth, vecBoolOccurrencesOf, vecBoolPushAll, vecBoolRemove, vecBoolReplace, vecBoolReplaceFirst, vecBoolRest, vecBoolReverse, vecBoolSet, vecBoolSubVec, vecBoolTake, vecBoolDrop
        
    case vecFloatDup, vecFloatDupTimes, vecFloatDupItems, vecFloatEmpty, vecFloatEq, vecFloatFlush, vecFloatPop, vecFloatRot, vecFloatShove, vecFloatStackDepth, vecFloatSwap, vecFloatYank, vecFloatYankDup, vecFloatDeepDup, vecFloatButLast, vecFloatConcat, vecFloatConj, vecFloatContains, vecFloatEmptyVector, vecFloatFirst, vecFloatIndexOf, vecFloatIterate, vecFloatLast, vecFloatLength, vecFloatNth, vecFloatOccurrencesOf, vecFloatPushAll, vecFloatRemove, vecFloatReplace, vecFloatReplaceFirst, vecFloatRest, vecFloatReverse, vecFloatSet, vecFloatSubVec, vecFloatTake, vecFloatDrop

    case vecIntDup, vecIntDupTimes, vecIntDupItems, vecIntEmpty, vecIntEq, vecIntFlush, vecIntPop, vecIntRot, vecIntShove, vecIntStackDepth, vecIntSwap, vecIntYank, vecIntYankDup, vecIntDeepDup, vecIntButLast, vecIntConcat, vecIntConj, vecIntContains, vecIntEmptyVector, vecIntFirst, vecIntIndexOf, vecIntIterate, vecIntLast, vecIntLength, vecIntNth, vecIntOccurrencesOf, vecIntPushAll, vecIntRemove, vecIntReplace, vecIntReplaceFirst, vecIntRest, vecIntReverse, vecIntSet, vecIntSubVec, vecIntTake, vecIntDrop

    case vecStringDup, vecStringDupTimes, vecStringDupItems, vecStringEmpty, vecStringEq, vecStringFlush, vecStringPop, vecStringRot, vecStringShove, vecStringStackDepth, vecStringSwap, vecStringYank, vecStringYankDup, vecStringDeepDup, vecStringButLast, vecStringConcat, vecStringConj, vecStringContains, vecStringEmptyVector, vecStringFirst, vecStringIndexOf, vecStringIterate, vecStringLast, vecStringLength, vecStringNth, vecStringOccurrencesOf, vecStringPushAll, vecStringRemove, vecStringReplace, vecStringReplaceFirst, vecStringRest, vecStringReverse, vecStringSet, vecStringSubVec, vecStringTake, vecStringDrop

    case stringButLast, stringConcat, stringConjChar, stringContains, stringContainsChar, stringDrop, stringEmptyString, stringFirst, stringFromBool, stringFromChar, stringFromFloat, stringFromInt, stringIndexOfChar, stringIterate, stringLast, stringLength, stringNth, stringOccurrencesOfChar, stringParseToChars, stringRemoveChar, stringReplace, stringReplaceChar, stringReplaceFirst, stringReplaceFirstChar, stringRest, stringReverse, stringSetChar, stringSplit, stringSubstring, stringTake, stringDup, stringDupTimes, stringDupItems, stringFlush, stringPop, stringRot, stringShove, stringStackDepth, stringSwap, stringYank, stringYankDup, stringDeepDup, stringEq, stringGT, stringGTE, stringLT, stringLTE, stringEmpty
    
    case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9
    
    case char0, char1, char2, char3, char4, char5, char6, char7, char8, char9,
         string0, string1, string2, string3, string4, string5, string6, string7, string8, string9,
         int0, int1, int2, int3, int4, int5, int6, int7, int8, int9,
         float0, float1, float2, float3, float4, float5, float6, float7, float8, float9,
         vecBool0, vecBool1, vecBool2, vecBool3, vecBool4, vecBool5, vecBool6, vecBool7, vecBool8, vecBool9,
         vecString0, vecString1, vecString2, vecString3, vecString4, vecString5, vecString6, vecString7, vecString8, vecString9,
         vecInt0, vecInt1, vecInt2, vecInt3, vecInt4, vecInt5, vecInt6, vecInt7, vecInt8, vecInt9,
         vecFloat0, vecFloat1, vecFloat2, vecFloat3, vecFloat4, vecFloat5, vecFloat6, vecFloat7, vecFloat8, vecFloat9
}

