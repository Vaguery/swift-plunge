//
//  Int Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/3/26.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct IntBehaviorTests {

    var inty = Interpreter()
    
    @Test func intAdd() {
        loadInts(inty, ints: [9, 11, 7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 11 7 ]")

        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ 20 7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        
        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ 27 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func `intAdd handles overflow`() {
        loadInts(inty, ints: [1000, Int.max])
        #expect(stackString(inty, .int) == "[ 1000 9223372036854775807 ]")

        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        
        #expect(stackString(inty, .error).contains("Overflow in .intAdd") )
    }

    @Test func intDec() {
        loadInts(inty, ints: [9, 38], contingent: [1])
        #expect(stackString(inty, .int) == "[ 9 38 ]")

        doThis(.intDec, to: inty)
        #expect(stackString(inty, .int) == "[ 8 38 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 38 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intDec, to: inty)
        #expect(stackString(inty, .int) == "[ 37 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func `intDec handles overflow`() {
        loadInts(inty, ints: [Int.min])
        #expect(stackString(inty, .int) == "[ -9223372036854775808 ]")

        doThis(.intDec, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intDec")  )
    }

    @Test func intFromBool() {
        loadBools(inty, bools: [false, true], contingent: [1])
        #expect(stackString(inty, .bool) == "[ false true ]")

        doThis(.intFromBool, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intFromBool, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intFromChar() {
        loadChars(inty, chars: ["W", "W", "😍"], contingent: [1,2])
        #expect(stackString(inty, .char) == "[ 'W' 'W' '😍' ]")

        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 87 ]")
        #expect(topItem(inty, .int).isContingent == true)

        // not ASCII therefore no result
        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 87 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intFromDouble() {
        loadDoubles(inty, doubles: [1.23, 1.2e5, -100, Double.pi], contingent: [1])
        #expect(stackString(inty, .double) == "[ 1.23 120000.0 -100.0 3.141592653589793 ]")

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 120000 1 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ -100 120000 1 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 3 -100 120000 1 ]")
        #expect(topItem(inty, .int).isContingent == false)

    }

    @Test func `intFromDouble handles non-finite and out-of-range doubles`() {
        // an infinite double would trap Int(_:); route it to .error instead
        loadDoubles(inty, doubles: [Double.infinity])
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intFromDouble"))

        // a finite double beyond Int's range would also trap
        loadDoubles(inty, doubles: [-1e40])
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intFromDouble"))

        // NaN as well
        loadDoubles(inty, doubles: [Double.nan])
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func intFromString() {
        loadStrings(inty, strings: ["-172", "0", "00001", "1_000_000", " 172", "1 7 2"], contingent:    [1])
        #expect(stackString(inty, .string) == "[ \"-172\" \"0\" \"00001\" \"1_000_000\" \" 172\" \"1 7 2\" ]")

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ -172 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(topItem(inty, .int).isContingent == false)
    }

    @Test func intGT() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intGT, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -4 -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intGT, to: inty)
        #expect(stackString(inty, .int) == "[ -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intGT, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func intGTE() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -4 -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .int) == "[ -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func intInc() {
        loadInts(inty, ints: [9, 38], contingent: [1])
        #expect(stackString(inty, .int) == "[ 9 38 ]")

        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ 10 38 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 38 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ 39 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func `intInc handles overflow`() {
        loadInts(inty, ints: [Int.max])
        #expect(stackString(inty, .int) == "[ 9223372036854775807 ]")

        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intInc")  )
    }

    @Test func intLT() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intLT, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -4 -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intLT, to: inty)
        #expect(stackString(inty, .int) == "[ -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intLT, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func intLTE() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -4 -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .int) == "[ -7 -7 ]")
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == true)

        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == false)
    }

    @Test func intMax() {
        loadInts(inty, ints: [9, 11, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intMax, to: inty)
        #expect(stackString(inty, .int) == "[ 11 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)


        doThis(.intMax, to: inty)
        #expect(stackString(inty, .int) == "[ 11 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intMin() {
        loadInts(inty, ints: [9, 11, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intMin, to: inty)
        #expect(stackString(inty, .int) == "[ 9 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)


        doThis(.intMin, to: inty)
        #expect(stackString(inty, .int) == "[ -7 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func intMod() {
        loadInts(inty, ints: [9, 37, 0, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 37 0 -7 ]")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ 0 -7 ]")
        #expect(topItem(inty, .int).isContingent == true)

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `intMod doesn't divide by zero`() {
        loadInts(inty, ints: [0, 999])
        #expect(stackString(inty, .int) == "[ 0 999 ]")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Divide by zero .intMod") )
    }

    @Test func `intMod handles overflow`() {
        loadInts(inty, ints: [-1, Int.min])
        #expect(stackString(inty, .int) == "[ -1 -9223372036854775808 ]")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intMod") )
    }

    @Test func intMultiply() {
        loadInts(inty, ints: [9, 11, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ 99 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ -693 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }

    @Test func `intMultiply handles overflow`() {
        loadInts(inty, ints: [1000, -Int.max])
        #expect(stackString(inty, .int) == "[ 1000 -9223372036854775807 ]")

        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intMultiply")  )
    }

    @Test func intQuot() {
        loadInts(inty, ints: [9, 37, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 37 -7 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)


        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")
        #expect(topItem(inty, .int).isContingent == true)

        loadInts(inty,ints: [0])
        #expect(stackString(inty, .int) == "[ 0 -1 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(topItem(inty, .error).isContingent == true)
    }

    @Test func `intQuot doesn't divide by zero`() {
        loadInts(inty, ints: [0, 999])
        #expect(stackString(inty, .int) == "[ 0 999 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Divide by zero .intQuot") )
    }

    @Test func `intQuot handles overflow`() {
        loadInts(inty, ints: [-1, Int.min])
        #expect(stackString(inty, .int) == "[ -1 -9223372036854775808 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intQuot")  )
    }

    @Test func intSubtract() {
        loadInts(inty, ints: [9, 11, -7], contingent: [2])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ 2 -7 ]")
        #expect(topItem(inty, .int).isContingent == false)

        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ -9 ]")
        #expect(topItem(inty, .int).isContingent == true)
    }
    
    @Test func `intSubtract handles overflow`() {
        loadInts(inty, ints: [1000, -Int.max])
        #expect(stackString(inty, .int) == "[ 1000 -9223372036854775807 ]")

        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intSubtract") )
    }
}
