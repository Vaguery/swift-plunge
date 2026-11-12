//
//  Int Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/3/26.
//

@testable import Plunge
import Testing
import DequeModule

@Suite
struct IntBehaviorTests {

    var inty = Interpreter.recordingProvenance()

    @Test func intAdd() {
        loadInts(inty, ints: [9, 11, 7])
        #expect(stackString(inty, .int) == "[ 9 11 7 ]")

        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ 20 7 ]")
        #expect(callString(topItem(inty, .int)) == "( 11 9 .intAdd )")


        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ 27 ]")
        #expect(callString(topItem(inty, .int)) == "( 7 20 .intAdd )")
    }

    @Test func `intAdd handles overflow`() {
        loadInts(inty, ints: [1000, Int.max])
        #expect(stackString(inty, .int) == "[ 1000 9223372036854775807 ]")

        doThis(.intAdd, to: inty)
        #expect(stackString(inty, .int) == "[ ]")

        #expect(stackString(inty, .error).contains("Overflow in .intAdd") )
        #expect(callString(topItem(inty, .error)) == "( 9223372036854775807 1000 .intAdd )")
    }

    @Test func intDec() {
        loadInts(inty, ints: [9, 38])
        #expect(stackString(inty, .int) == "[ 9 38 ]")

        doThis(.intDec, to: inty)
        #expect(stackString(inty, .int) == "[ 8 38 ]")
        #expect(callString(topItem(inty, .int)) == "( 9 .intDec )")

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 38 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

        doThis(.intDec, to: inty)
        #expect(stackString(inty, .int) == "[ 37 ]")
        #expect(callString(topItem(inty, .int)) == "( 38 .intDec )")
    }

    @Test func `intDec handles overflow`() {
        loadInts(inty, ints: [Int.min])
        #expect(stackString(inty, .int) == "[ -9223372036854775808 ]")

        doThis(.intDec, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intDec")  )
        #expect(callString(topItem(inty, .error)) == "( -9223372036854775808 .intDec )")
    }

    @Test func intFromBool() {
        loadBools(inty, bools: [false, true])
        #expect(stackString(inty, .bool) == "[ false true ]")

        doThis(.intFromBool, to: inty)
        #expect(stackString(inty, .int) == "[ 0 ]")
        #expect(callString(topItem(inty, .int)) == "( false .intFromBool )")

        doThis(.intFromBool, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 ]")
        #expect(callString(topItem(inty, .int)) == "( true .intFromBool )")
    }

    @Test func intFromChar() {
        loadChars(inty, chars: ["W", "W", "😍"])
        #expect(stackString(inty, .char) == "[ 'W' 'W' '😍' ]")

        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 ]")
        #expect(callString(topItem(inty, .int)) == "( 'W' .intFromChar )")

        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 87 87 ]")
        #expect(callString(topItem(inty, .int)) == "( 'W' .intFromChar )")

        // Any single Unicode scalar has a code, not only ASCII.
        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ 128525 87 87 ]")
        #expect(callString(topItem(inty, .int)) == "( '😍' .intFromChar )")
    }

    /// A character made of several scalars (a flag is two) has no single code.
    @Test func `intFromChar refuses a character of several scalars`() {
        loadChars(inty, chars: ["🇺🇸"])
        doThis(.intFromChar, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .conversion)
        #expect(callString(topItem(inty, .error)) == "( '🇺🇸' .intFromChar )")
    }

    @Test func intFromDouble() {
        loadDoubles(inty, doubles: [1.23, 1.2e5, -100, Double.pi])
        #expect(stackString(inty, .double) == "[ 1.23 120000.0 -100.0 3.141592653589793 ]")

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 1 ]")
        #expect(callString(topItem(inty, .int)) == "( 1.23 .intFromDouble )")

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 120000 1 ]")
        #expect(callString(topItem(inty, .int)) == "( 120000.0 .intFromDouble )")

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ -100 120000 1 ]")
        #expect(callString(topItem(inty, .int)) == "( -100.0 .intFromDouble )")

        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ 3 -100 120000 1 ]")
        #expect(callString(topItem(inty, .int)) == "( 3.141592653589793 .intFromDouble )")

    }

    @Test func `intFromDouble handles non-finite and out-of-range doubles`() {
        // an infinite double would trap Int(_:); route it to .error instead
        loadDoubles(inty, doubles: [Double.infinity])
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intFromDouble"))
        #expect(callString(topItem(inty, .error)) == "( inf .intFromDouble )")

        // a finite double beyond Int's range would also trap
        loadDoubles(inty, doubles: [-1e40])
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intFromDouble"))
        #expect(callString(topItem(inty, .error)) == "( -1e+40 .intFromDouble )")

        // NaN as well
        loadDoubles(inty, doubles: [Double.nan])
        doThis(.intFromDouble, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func intFromString() {
        loadStrings(inty, strings: ["-172", "0", "00001", "1_000_000", " 172", "1 7 2"])
        #expect(stackString(inty, .string) == "[ \"-172\" \"0\" \"00001\" \"1_000_000\" \" 172\" \"1 7 2\" ]")

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ -172 ]")
        #expect(callString(topItem(inty, .int)) == "( \"-172\" .intFromString )")

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 0 -172 ]")
        #expect(callString(topItem(inty, .int)) == "( \"0\" .intFromString )")

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(callString(topItem(inty, .int)) == "( \"00001\" .intFromString )")

        // Not integers: each is an error now, where it used to vanish silently.
        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .conversion)
        #expect(callString(topItem(inty, .error)) == "( \"1_000_000\" .intFromString )")

        doThis(.intFromString, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -172 ]")
        #expect(callString(topItem(inty, .error)) == "( \" 172\" .intFromString )")
        #expect(inty.stacks[.error]!.count == 2)
    }

    @Test func intGT() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( 38 9 .intGT 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -4 4 .intGT 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -7 -7 .intGT 2 .intPopItems )")
    }

    @Test func intGTE() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( 38 9 .intGTE 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -4 4 .intGTE 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -7 -7 .intGTE 2 .intPopItems )")
    }

    @Test func intInc() {
        loadInts(inty, ints: [9, 38])
        #expect(stackString(inty, .int) == "[ 9 38 ]")

        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ 10 38 ]")
        #expect(callString(topItem(inty, .int)) == "( 9 .intInc )")

        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 38 ]")
        #expect(callString(topItem(inty, .int)) == "( )")

        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ 39 ]")
        #expect(callString(topItem(inty, .int)) == "( 38 .intInc )")
    }

    @Test func `intInc handles overflow`() {
        loadInts(inty, ints: [Int.max])
        #expect(stackString(inty, .int) == "[ 9223372036854775807 ]")

        doThis(.intInc, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intInc")  )
        #expect(callString(topItem(inty, .error)) == "( 9223372036854775807 .intInc )")
    }

    @Test func intLT() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 38 9 .intLT 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -4 4 .intLT 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -7 -7 .intLT 2 .intPopItems )")
    }

    @Test func intLTE() {
        loadInts(inty, ints: [9, 38, 4, -4, -7, -7])
        #expect(stackString(inty, .int) == "[ 9 38 4 -4 -7 -7 ]")

        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 38 9 .intLTE 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -4 4 .intLTE 2 .intPopItems )")

        doThis(.intPop, to: inty)
        doThis(.intPop, to: inty)
        doThis(.intLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -7 -7 .intLTE 2 .intPopItems )")
    }

    @Test func intMax() {
        loadInts(inty, ints: [9, 11, -7])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intMax, to: inty)
        #expect(stackString(inty, .int) == "[ 11 -7 ]")
        #expect(callString(topItem(inty, .int)) == "( 11 9 .intMax )")


        doThis(.intMax, to: inty)
        #expect(stackString(inty, .int) == "[ 11 ]")
        #expect(callString(topItem(inty, .int)) == "( -7 11 .intMax )")
    }

    @Test func intMin() {
        loadInts(inty, ints: [9, 11, -7])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intMin, to: inty)
        #expect(stackString(inty, .int) == "[ 9 -7 ]")
        #expect(callString(topItem(inty, .int)) == "( 11 9 .intMin )")


        doThis(.intMin, to: inty)
        #expect(stackString(inty, .int) == "[ -7 ]")
        #expect(callString(topItem(inty, .int)) == "( -7 9 .intMin )")
    }

    @Test func intMod() {
        loadInts(inty, ints: [9, 37, 0, -7])
        #expect(stackString(inty, .int) == "[ 9 37 0 -7 ]")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ 1 0 -7 ]")
        #expect(callString(topItem(inty, .int)) == "( 37 9 .intMod )")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ 0 -7 ]")
        #expect(callString(topItem(inty, .int)) == "( 0 1 .intMod )")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }

    @Test func `intMod doesn't divide by zero`() {
        loadInts(inty, ints: [0, 999])
        #expect(stackString(inty, .int) == "[ 0 999 ]")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Divide by zero .intMod") )
        #expect(callString(topItem(inty, .error)) == "( 999 0 .intMod )")
    }

    @Test func `intMod handles overflow`() {
        loadInts(inty, ints: [-1, Int.min])
        #expect(stackString(inty, .int) == "[ -1 -9223372036854775808 ]")

        doThis(.intMod, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intMod") )
        #expect(callString(topItem(inty, .error)) == "( -9223372036854775808 -1 .intMod )")
    }

    @Test func intMultiply() {
        loadInts(inty, ints: [9, 11, -7])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ 99 -7 ]")
        #expect(callString(topItem(inty, .int)) == "( 11 9 .intMultiply )")

        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ -693 ]")
        #expect(callString(topItem(inty, .int)) == "( -7 99 .intMultiply )")
    }

    @Test func `intMultiply handles overflow`() {
        loadInts(inty, ints: [1000, -Int.max])
        #expect(stackString(inty, .int) == "[ 1000 -9223372036854775807 ]")

        doThis(.intMultiply, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intMultiply")  )
        #expect(callString(topItem(inty, .error)) == "( -9223372036854775807 1000 .intMultiply )")
    }

    @Test func intQuot() {
        loadInts(inty, ints: [9, 37, -7])
        #expect(stackString(inty, .int) == "[ 9 37 -7 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ 4 -7 ]")
        #expect(callString(topItem(inty, .int)) == "( 37 9 .intQuot )")


        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ -1 ]")
        #expect(callString(topItem(inty, .int)) == "( -7 4 .intQuot )")

        loadInts(inty, ints: [0])
        #expect(stackString(inty, .int) == "[ 0 -1 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(callString(topItem(inty, .error)) == "( -1 0 .intQuot )")
    }

    @Test func `intQuot doesn't divide by zero`() {
        loadInts(inty, ints: [0, 999])
        #expect(stackString(inty, .int) == "[ 0 999 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Divide by zero .intQuot") )
        #expect(callString(topItem(inty, .error)) == "( 999 0 .intQuot )")
    }

    @Test func `intQuot handles overflow`() {
        loadInts(inty, ints: [-1, Int.min])
        #expect(stackString(inty, .int) == "[ -1 -9223372036854775808 ]")

        doThis(.intQuot, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intQuot")  )
        #expect(callString(topItem(inty, .error)) == "( -9223372036854775808 -1 .intQuot )")
    }

    @Test func intSubtract() {
        loadInts(inty, ints: [9, 11, -7])
        #expect(stackString(inty, .int) == "[ 9 11 -7 ]")

        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ 2 -7 ]")
        #expect(callString(topItem(inty, .int)) == "( 11 9 .intSubtract )")

        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ -9 ]")
        #expect(callString(topItem(inty, .int)) == "( -7 2 .intSubtract )")
    }

    @Test func `intSubtract handles overflow`() {
        loadInts(inty, ints: [1000, -Int.max])
        #expect(stackString(inty, .int) == "[ 1000 -9223372036854775807 ]")

        doThis(.intSubtract, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .intSubtract") )
        #expect(callString(topItem(inty, .error)) == "( -9223372036854775807 1000 .intSubtract )")
    }
}
