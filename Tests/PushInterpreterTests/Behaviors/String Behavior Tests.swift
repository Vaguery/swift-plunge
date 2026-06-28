//
//  String Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/11/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct StringBehaviorTests {

    var inty = Interpreter()

    @Test func stringPop() {
        loadStrings(inty, strings: ["", "abcd"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringPop, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringPop, to: inty)
        #expect(stackString(inty, .string) == "[ ]")
    }

    @Test func stringButLast() {
        loadStrings(inty, strings: ["", "abcd"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringButLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringPop, to: inty)
        doThis(.stringButLast, to: inty)
        #expect(stackString(inty, .string) == "[ \"abc\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringConcat() {
        loadStrings(inty, strings: ["", "", "abcd", "123"], contingent: [2])
        #expect(stackString(inty, .string) == "[ \"\" \"\" \"abcd\" \"123\" ]")

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"123\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd\" \"123\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringConcat, to: inty)
        #expect(stackString(inty, .string) == "[ \"123abcd\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringConjChar() {
        loadChars(inty, chars: ["w", "•"], contingent:[1])
        loadStrings(inty, strings: ["", "abcd"])
        #expect(stackString(inty, .char) == "[ 'w' '•' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringConjChar, to: inty)
        #expect(stackString(inty, .char) == "[ '•' ]")
        #expect(stackString(inty, .string) == "[ \"w\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringConjChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"w•\" \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringSwap() {
        loadStrings(inty, strings: ["", "abcd", "efgh"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"efgh\" ]")

        doThis(.stringSwap, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcd\" \"\" \"efgh\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringPop, to: inty)
        doThis(.stringSwap, to: inty)
        #expect(stackString(inty, .string) == "[ \"efgh\" \"\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }

    @Test func stringContains() {
        loadStrings(inty, strings: ["", "abcd", "bc", "abcd"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"bc\" \"abcd\" ]")

        doThis(.stringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"bc\" \"abcd\" ]")
        #expect(topItem(inty, .bool).isContingent == true)
        
        doThis(.stringContains, to: inty)
        #expect(stackString(inty, .bool) == "[ true true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func stringContainsChar() {
        loadChars(inty, chars: ["x", "b"])
        loadStrings(inty, strings: ["", "abcd"], contingent:[1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'x' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" ]")

        doThis(.stringContainsChar, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringContainsChar, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }
    
    @Test func stringIndexOfChar() {
        loadChars(inty, chars: ["x", "b", "O"])
        loadStrings(inty, strings: ["", "abcd", "abcd"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'x' 'b' 'O' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcd\" \"abcd\" ]")

        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' 'O' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" \"abcd\" ]")

        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'O' ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" ]")
        #expect(topItem(inty, .int).isContingent == true)
        
        doThis(.stringIndexOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func stringDrop() {
        loadInts(inty, ints: [3, 0, 4, -14, 99])
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .int) == "[ 3 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringPop, to: inty)
        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcdef\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcdef\" ]")
        #expect(topItem(inty, .string).isContingent == true)
        
        doThis(.stringDrop, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringTake() {
        loadInts(inty, ints: [3, 0, 4, -14, 99])
        loadStrings(inty, strings: ["", "abcdefghij", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .int) == "[ 3 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" \"abcdefghij\" ]")

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ 0 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" \"abcdefghij\" ]")

        doThis(.stringPop, to:inty)
        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringPop, to:inty)
        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ -14 99 ]")
        #expect(stackString(inty, .string) == "[ \"abcd\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ 99 ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringTake, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }
    
    @Test func stringIsEmpty() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        #expect(topItem(inty, .string).isContingent == true)


        doThis(.stringIsEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }
    
    @Test func stringFirst() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringFirst, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")

        doThis(.stringFirst, to: inty)
        #expect(stackString(inty, .char) == "[ 'a' ]")
        #expect(stackString(inty, .string) == "[ ]")
    }
    
    @Test func stringLast() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringLast, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")

        doThis(.stringLast, to: inty)
        #expect(stackString(inty, .char) == "[ 'j' ]")
        #expect(stackString(inty, .string) == "[ ]")
   }
    
    @Test func stringLTE() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.stringLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func stringLT() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false false ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func stringGT() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }
    
    @Test func stringGTE() {
        loadStrings(inty, strings: ["abc", "xyz", "abc", "abc", "xyz", "abc"], contingent: [1])
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"xyz\" \"abc\" \"abc\" \"xyz\" \"abc\" ]")

        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"abc\" \"abc\" \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true ]")
        #expect(stackString(inty, .string) == "[ \"xyz\" \"abc\" ]")
        #expect(topItem(inty, .bool).isContingent == false)
        
        doThis(.stringGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true true ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func stringReverse() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringReverse, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringPop, to: inty)
        doThis(.stringReverse, to: inty)
        #expect(stackString(inty, .string) == "[ \"jihgfedcba\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringLength() {
        loadStrings(inty, strings: ["", "abcdefghij"], contingent: [1])
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghij\" ]")

        doThis(.stringLength, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcdefghij\" ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        
        doThis(.stringLength, to: inty)
        #expect(stackString(inty, .int) == "[ 10 0 ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func stringFromBool() {
        loadBools(inty, bools: [false, true], contingent: [1])
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromBool, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(stackString(inty, .string) == "[ \"false\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringFromBool, to: inty)
        #expect(stackString(inty, .bool) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"true\" \"false\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringFromChar() {
        loadChars(inty, chars: ["x", "-"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'x' '-' ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromChar, to: inty)
        #expect(stackString(inty, .char) == "[ '-' ]")
        #expect(stackString(inty, .string) == "[ \"x\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringFromChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"-\" \"x\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringFromDouble() {
        loadDoubles(inty, doubles: [1.1, 2.2], contingent: [1])
        #expect(stackString(inty, .double) == "[ 1.1 2.2 ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromDouble, to: inty)
        #expect(stackString(inty, .double) == "[ 2.2 ]")
        #expect(stackString(inty, .string) == "[ \"1.1\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringFromDouble, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"2.2\" \"1.1\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringFromInt() {
        loadInts(inty, ints: [11, -222], contingent: [1])
        #expect(stackString(inty, .int) == "[ 11 -222 ]")
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFromInt, to: inty)
        #expect(stackString(inty, .int) == "[ -222 ]")
        #expect(stackString(inty, .string) == "[ \"11\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringFromInt, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"-222\" \"11\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }
    
    @Test func stringNth() {
        loadInts(inty, ints: [11, 2, -222, 22], contingent: [2])
        loadStrings(inty, strings: ["", "abcdefghi", "abcdefghi", "abcdefghi"], contingent: [3])
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 11 2 -222 22 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"abcdefghi\" \"abcdefghi\" \"abcdefghi\" ]")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 2 -222 22 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghi\" \"abcdefghi\" \"abcdefghi\" ]")

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'c' ]")
        #expect(stackString(inty, .int) == "[ -222 22 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghi\" \"abcdefghi\" ]")
        #expect(topItem(inty, .char).isContingent == false)

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'a' 'c' ]")
        #expect(stackString(inty, .int) == "[ 22 ]")
        #expect(stackString(inty, .string) == "[ \"abcdefghi\" ]")
        #expect(topItem(inty, .char).isContingent == true)

        doThis(.stringNth, to: inty)
        #expect(stackString(inty, .char) == "[ 'e' 'a' 'c' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .char).isContingent == true)
    }

    @Test func stringParseToLetters() {
        loadStrings(inty, strings: ["", "live"], contingent: [1])
        #expect(stackString(inty, .string) == "[ \"\" \"live\" ]")

        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"live\" ]")

        doThis(.stringParseToLetters, to: inty)
        #expect(stackString(inty, .string) == "[ \"e\" \"v\" \"i\" \"l\" ]")
        #expect(topItem(inty, .string).index == 3)
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringPop, to: inty)
        #expect(topItem(inty, .string).index == 2)
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringOccurrencesOfChar() {
        loadChars(inty, chars: [" ","o","f"])
        loadStrings(inty, strings: ["", "boo", "bee"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ' ' 'o' 'f' ]")
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'o' 'f' ]")
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(stackString(inty, .string) == "[ \"boo\" \"bee\" ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'f' ]")
        #expect(stackString(inty, .int) == "[ 2 0 ]")
        #expect(stackString(inty, .string) == "[ \"bee\" ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.stringOccurrencesOfChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .int) == "[ 0 2 0 ]")
        #expect(stackString(inty, .string) == "[ ]")
        #expect(topItem(inty, .int).isContingent == false)
    }

    @Test func stringRemoveChar() {
        loadChars(inty, chars: [" ","o","b"])
        loadStrings(inty, strings: ["", "boo", "bee"], contingent: [1])
        #expect(stackString(inty, .char) == "[ ' ' 'o' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .string) == "[ \"\" \"boo\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .string) == "[ \"b\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringRemoveChar, to: inty)
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .string) == "[ \"\" \"bee\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringReplaceChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("00 11 22", isContingent: true),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("-")),CharItem(Character("2")),
                         CharItem(Character(".")),CharItem(Character("2")),
                         CharItem(Character("!")),CharItem(Character(" ")),
                        ])
        
        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"00 11 22\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)

        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00 11 ..\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringReplaceChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00!11!..\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringReplaceFirstChar() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("00 11 22", isContingent: true),
                        ])
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("-")),CharItem(Character("2")),
                         CharItem(Character(".")),CharItem(Character("2")),
                         CharItem(Character("!")),CharItem(Character(" ")),
                        ])
        
        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"00 11 22\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)

        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00 11 .2\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringReplaceFirstChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"00!11 .2\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringReplace() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("-"), StringItem(""), StringItem("")
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"-\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(" a"),StringItem("1 "),StringItem("00 11 22", isContingent: true),
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) ==  "[ \"00 1 a22\" \"-\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("1234"),StringItem(" w"),StringItem("just write words"),
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"just1234rite1234ords\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),StringItem("t"),StringItem("just write words"),
                        ])

        doThis(.stringReplace, to: inty)
        #expect(stackString(inty, .string) == "[ \"jus wrie words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }

    @Test func stringReplaceFirst() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("-"), StringItem(""), StringItem("")
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"-\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(" a"),StringItem("1 "),StringItem("00 11 22", isContingent: true),
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) ==  "[ \"00 1 a22\" \"-\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("1234"),StringItem(" w"),StringItem("just write words"),
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"just1234rite words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),StringItem("t"),StringItem("just write words"),
                        ])

        doThis(.stringReplaceFirst, to: inty)
        #expect(stackString(inty, .string) == "[ \"jus write words\" ]")
        #expect(topItem(inty, .string).isContingent == false)
    }
    
    @Test func stringRest() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("abcde", isContingent: true)
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" \"abcde\" ]")

        doThis(.stringRest, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"abcde\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        
        doThis(.stringPop, to: inty)
        
        doThis(.stringRest, to: inty)
        #expect(stackString(inty, .string) == "[ \"bcde\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    
    @Test func stringSetChar() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(2),
                         IntItem(-222, isContingent: true),
                         IntItem(13),
                        ])
        
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                         StringItem("0123456789"),
                        ])
        
        inty.stacks[.char]!.prepend(
            contentsOf: [
                        CharItem(Character("-")),
                        CharItem(Character(".")),
                        CharItem(Character("?")),
                        CharItem(Character("+")),
                        ])
        
        #expect(stackString(inty, .int) == "[ 11 2 -222 13 ]")
        #expect(stackString(inty, .string) == "[ \"\" \"0123456789\" ]")

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" \"0123456789\" ]")
        
        doThis(.stringPop, to: inty)

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"01.3456789\" ]")
        #expect(topItem(inty, .string).isContingent == false)

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"?1.3456789\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringSetChar, to: inty)
        #expect(stackString(inty, .string) == "[ \"?1.+456789\" ]")
        #expect(topItem(inty, .string).isContingent == true)
    }

    @Test func stringSplit() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" ]")
        
        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ ]")

        doThis(.stringFlush, to: inty)

        inty.stacks[.string]!.prepend(
            contentsOf: [
                         StringItem("abcde", isContingent: true),
                        ])
        
        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ \"abcde\" ]")
        #expect(topItem(inty, .string).isContingent == true)

        doThis(.stringFlush, to: inty)

        
        inty.stacks[.string]!.prepend(
            contentsOf: [
                         StringItem("ab    cd \ne\tf")
                        ])
        
        doThis(.stringSplit, to: inty)
        #expect(stackString(inty, .string) == "[ \"f\" \"e\" \"cd\" \"ab\" ]")
        #expect(topItem(inty, .string).isContingent == false)
        #expect(topItem(inty, .string).index == 3)
    }
    
    @Test func `stringSubstring works for empty`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(2),
                         IntItem(2),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" ]")
    }

    @Test func `stringSubstring works for silly indices on empty strings`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),
                         IntItem(22),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"\" ]")
    }

    @Test func `stringSubstring works for nonempty with basic indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(4),
                         IntItem(2),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"ori\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with identical indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(4),
                         IntItem(4),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"i\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with weird indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(88),
                         IntItem(-11),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"gloria\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with 2 negative indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-22),
                         IntItem(-11),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"g\" ]")
    }
    
    @Test func `stringSubstring works for nonempty with 2 huge indices`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("gloria"),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(88),
                         IntItem(99),
                        ])
        
        doThis(.stringSubstring, to: inty)
        #expect(stackString(inty, .string) == "[ \"a\" ]")
    }

    @Test func `stringIterate works for an empty string`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem(""),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .int) == "[ 1 ]")

        doThis(.stringIterate, to: inty)
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
    }
        
    @Test func `stringIterate works for a nonempty string`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("boo"),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.intInc),
                        ])
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(1),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"boo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
        
        doThis(.stringIterate, to: inty)
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ .intInc \"oo\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 1 ]")
       
        inty.step()
        
        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ \"oo\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 2 ]")
       
        inty.step()

        #expect(stackString(inty, .string) == "[ \"oo\" ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 2 ]")
       
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ .intInc \"o\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 2 ]")
       
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ \"o\" .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 3 ]")
        
        inty.step()

        #expect(stackString(inty, .string) == "[ \"o\" ]")
        #expect(stackString(inty, .char) == "[ 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .intInc ]")
        #expect(stackString(inty, .int) == "[ 3 ]")
        
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ .intInc ]")
        #expect(stackString(inty, .int) == "[ 3 ]")
        
        inty.step()

        #expect(stackString(inty, .string) == "[ ]")
        #expect(stackString(inty, .char) == "[ 'o' 'o' 'b' ]")
        #expect(stackString(inty, .exec) == "[ ]")
        #expect(stackString(inty, .int) == "[ 4 ]")
        
        
    }

    
    @Test func `stringIterate might be weird when recursive`() {
        inty.stacks[.string]!.prepend(
            contentsOf: [StringItem("boo"), StringItem("tan"),
                        ])
        inty.stacks[.exec]!.prepend(
            contentsOf: [InstructionItem(.stringConjChar),
                        ])
        
        #expect(stackString(inty, .string) == "[ \"boo\" \"tan\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar ]")
        
        doThis(.stringIterate, to: inty)
        
        #expect(stackString(inty, .string) == "[ \"tan\" ]")
        #expect(stackString(inty, .char) == "[ 'b' ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar \"oo\" .stringIterate .stringConjChar ]")
        
        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanb\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ \"oo\" .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"oo\" \"tanb\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanb\" ]")
        #expect(stackString(inty, .char) == "[ 'o' ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar \"o\" .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanbo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ \"o\" .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"o\" \"tanbo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ .stringIterate .stringConjChar ]")

        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanbo\" ]")
        #expect(stackString(inty, .char) == "[ 'o' ]")
        #expect(stackString(inty, .exec) == "[ .stringConjChar ]")
        
        inty.step()
        
        #expect(stackString(inty, .string) == "[ \"tanboo\" ]")
        #expect(stackString(inty, .char) == "[ ]")
        #expect(stackString(inty, .exec) == "[ ]")
    }
    
    @Test func stringPushAllChars() {
        inty.stacks[.string]!.prepend(StringItem("", isContingent: false))
        inty.stacks[.string]!.prepend(StringItem("fizz"))
        inty.stacks[.string]!.prepend(StringItem("bar", isContingent: true))
        
        #expect(stackString(inty, .string) == "[ \"bar\" \"fizz\" \"\" ]")

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == true)
        #expect(topItem(inty, .char).index == 2)

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
        #expect(topItem(inty, .char).isContingent == false)
        #expect(topItem(inty, .char).index == 3)

        doThis(.stringPushAllChars, to: inty)
        #expect(stackString(inty, .char) == "[ 'z' 'z' 'i' 'f' 'r' 'a' 'b' ]")
    }
    


}
