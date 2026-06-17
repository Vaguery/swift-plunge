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
    
    
    // INT instructions
    //
    case intAdd, intSubtract, intMultiply, intQuot, intMod, intMax, intMin, intInc, intDec
    
    // int comparison
    case intEq, intGT, intGTE, intLT, intLTE
    
    // int conversion
    case intFromBool, intFromChar, intFromDouble, intFromString
    
    // int combinators
    case intDup, intDupTimes, intDupItems, intEmpty, intFlush, intPop, intRot, intShove, intStackDepth, intSwap, intYank, intYankDup, intDeepDup
    
    
    // DOUBLE instructions
    //
    case doubleAdd, doubleSubtract, doubleMultiply, doubleDivide, doubleQuot, doubleMod, doubleMax, doubleMin,  doubleInc, doubleDec, doubleCos, doubleSin, doubleTan
    
    // double comparison
    case doubleGT, doubleGTE, doubleLT, doubleLTE
    
    // double conversion
    case doubleFromBool, doubleFromChar, doubleFromString, doubleFromInt
    
    // double combinators
    case doubleDup, doubleDupTimes, doubleDupItems, doubleEmpty, doubleEq, doubleFlush, doublePop, doubleRot, doubleShove, doubleStackDepth, doubleSwap, doubleYank, doubleYankDup, doubleDeepDup
    
    
    // BOOL instructions
    //
    case boolAnd, boolNot, boolOr, boolXor, boolInvertFirstThenAnd, boolInvertSecondThenAnd
    
    // bool comparison
    case boolEq
    
    // bool conversion
    case boolFromDouble, boolFromInt
    
    // bool combinators
    case boolDup, boolDupTimes, boolDupItems, boolEmpty, boolFlush, boolPop, boolRot, boolShove, boolStackDepth, boolSwap, boolYank, boolYankDup, boolDeepDup

    
    
    // CHAR instructions
    //
    case charIsLetter, charIsDigit, charIsWhitespace, charAllFromString
    
    // char comparison
    case charEq
    
    // char conversion
    case charFromDouble, charFromInt
    
    // char combinators
    case charDup, charDupTimes, charDupItems, charEmpty,  charFlush, charPop, charRot, charShove, charStackDepth, charSwap, charYank, charYankDup, charDeepDup

    
    
    // CODE instructions
    //
    case codeAppend
    
    // code comparison
    case codeEq

    // code conversion

    // code combinators
    case codeDup, codeDupTimes, codeDupItems, codeEmpty, codeFlush, codePop, codeRot, codeShove, codeStackDepth, codeSwap, codeYank, codeYankDup, codeDeepDup


    // EXEC instructions
    //
    case execDoRange, execDoCount, execDoTimes, execIf, execWhen, execWhile, execDoWhile, execK, execS, execY
    
    // exec comparison
    case execEq
    
    // exec conversion
    
    // exec combinators
    case execDup, execDupTimes, execDupItems, execEmpty, execFlush, execPop, execRot, execShove, execStackDepth, execSwap, execYank, execYankDup, execDeepDup
    
    
    
    // INPUT instructions
    //
    case input0, input1, input2, input3, input4, input5, input6, input7, input8, input9

    

    // PRINT instructions
    //
    case printNewline, boolPrint, charPrint, stringPrint, intPrint, doublePrint, codePrint, execPrint, vecBoolPrint, vecIntPrint, vecDoublePrint, vecStringPrint
    
    
    
    // VECBOOL instructions
    //
    case vecBoolConcat, vecBoolConj, vecBoolContains, vecBoolIsEmpty, vecBoolFirst, vecBoolIndexOf, vecBoolIterate, vecBoolLast, vecBoolLength, vecBoolNth, vecBoolOccurrencesOf, vecBoolRemove, vecBoolReplace, vecBoolReplaceFirst, vecBoolRest, vecBoolReverse, vecBoolSet, vecBoolSubVec, vecBoolTake, vecBoolDrop, vecBoolButLast
    
    // vecBool comparison
    case vecBoolEq
    
    // vecBool conversion
    case vecBoolPushAll
    
    // vecBool combinators
    case vecBoolDup, vecBoolDupTimes, vecBoolDupItems, vecBoolEmpty,  vecBoolFlush, vecBoolPop, vecBoolRot, vecBoolShove, vecBoolStackDepth, vecBoolSwap, vecBoolYank, vecBoolYankDup, vecBoolDeepDup
        
    
    // VECDOUBLE instructions
    //
    case  vecDoubleButLast, vecDoubleConcat, vecDoubleConj, vecDoubleContains, vecDoubleIsEmpty, vecDoubleFirst, vecDoubleIndexOf, vecDoubleIterate, vecDoubleLast, vecDoubleLength, vecDoubleNth, vecDoubleOccurrencesOf,  vecDoubleRemove, vecDoubleReplace, vecDoubleReplaceFirst, vecDoubleRest, vecDoubleReverse, vecDoubleSet, vecDoubleSubVec, vecDoubleTake, vecDoubleDrop
    
    // vecDouble comparison
    case vecDoubleEq
    
    // vecDouble conversion
    case vecDoublePushAll
    
    // vecDouble combinators
    case vecDoubleDup, vecDoubleDupTimes, vecDoubleDupItems, vecDoubleEmpty, vecDoubleFlush, vecDoublePop, vecDoubleRot, vecDoubleShove, vecDoubleStackDepth, vecDoubleSwap, vecDoubleYank, vecDoubleYankDup, vecDoubleDeepDup

    
    
    // VECINT instructions
    //
    case  vecIntButLast, vecIntConcat, vecIntConj, vecIntContains, vecIntIsEmpty, vecIntFirst, vecIntIndexOf, vecIntIterate, vecIntLast, vecIntLength, vecIntNth, vecIntOccurrencesOf,  vecIntRemove, vecIntReplace, vecIntReplaceFirst, vecIntRest, vecIntReverse, vecIntSet, vecIntSubVec, vecIntTake, vecIntDrop

    // vecInt comparison
    case vecIntEq
    
    // vecInt conversion
    case vecIntPushAll
    
    // vecInt combinators
    case vecIntDup, vecIntDupTimes, vecIntDupItems, vecIntEmpty, vecIntFlush, vecIntPop, vecIntRot, vecIntShove, vecIntStackDepth, vecIntSwap, vecIntYank, vecIntYankDup, vecIntDeepDup

    
    // VECSTRING instructions
    //
    case  vecStringButLast, vecStringConcat, vecStringConj, vecStringContains, vecStringIsEmpty, vecStringFirst, vecStringIndexOf, vecStringIterate, vecStringLast, vecStringLength, vecStringNth, vecStringOccurrencesOf,  vecStringRemove, vecStringReplace, vecStringReplaceFirst, vecStringRest, vecStringReverse, vecStringSet, vecStringSubVec, vecStringTake, vecStringDrop
    
    // vecString comparison
    case vecStringEq
    
    // vecString conversion
    case vecStringPushAll
    
    // vecString combinators
    case vecStringDup, vecStringDupTimes, vecStringDupItems, vecStringEmpty, vecStringFlush, vecStringPop, vecStringRot, vecStringShove, vecStringStackDepth, vecStringSwap, vecStringYank, vecStringYankDup, vecStringDeepDup

    
    
    // STRING instructions
    //
    case stringButLast, stringConcat, stringConjChar, stringContains, stringContainsChar, stringDrop, stringIsEmpty, stringFirst, stringIndexOfChar, stringIterate, stringLast, stringLength, stringNth, stringOccurrencesOfChar, stringRemoveChar, stringReplace, stringReplaceChar, stringReplaceFirst, stringReplaceFirstChar, stringRest, stringReverse, stringSetChar, stringSplit, stringSubstring, stringTake
    
    // string comparison
    case stringEq, stringGT, stringGTE, stringLT, stringLTE
    
    // string conversion
    case stringFromBool, stringFromChar, stringFromDouble, stringFromInt, stringParseToChars
    
    // string combinators
    case stringDup, stringDupTimes, stringDupItems, stringFlush, stringPop, stringRot, stringShove, stringStackDepth, stringSwap, stringYank, stringYankDup, stringDeepDup, stringEmpty
    
    
    // CONSTANTS
    //
    // char constants
    case char0, char1, char2, char3, char4, char5, char6, char7, char8, char9
    
    // string constants
    case string0, string1, string2, string3, string4, string5, string6, string7, string8, string9
    
    // int constants
    case int0, int1, int2, int3, int4, int5, int6, int7, int8, int9
    
    // double constants
    case double0, double1, double2, double3, double4, double5, double6, double7, double8, double9
    
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

