//
//  Double Behavior Tests.swift
//  PlungeTests
//
//  Created by Bill Tozier on 6/3/26.
//

@testable import Plunge
import Testing
import DequeModule
import Foundation

@Suite @MainActor
struct DoubleBehaviorTests {

    let inty = Interpreter.recordingProvenance()

    @Test func doubleAdd() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 7.5 -6.25 ]")
        #expect(callString(topItem(inty, .double)) == "( 4.25 3.25 .doubleAdd )")

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 1.25 ]")
        #expect(callString(topItem(inty, .double)) == "( -6.25 7.5 .doubleAdd )")
    }

    @Test func `doubleAdd records overflows`() {
        loadDoubles(
            inty,
            doubles: [
                Double.greatestFiniteMagnitude,
                Double.greatestFiniteMagnitude,
                55,
                1.0/0.0
            ]
        )

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 55.0 inf ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleAdd:"))
        #expect(callString(topItem(inty, .error)) == "( 1.7976931348623157e+308 1.7976931348623157e+308 .doubleAdd )")

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleAdd:"))
        #expect(callString(topItem(inty, .error)) == "( inf 55.0 .doubleAdd )")

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        // args exhausted on the third add → a missing-args error. (Was
        // `.contains("")`, a trivially-true placeholder whose overload
        // resolved differently once tests moved to the Swift 6 package.)
        #expect(stackString(inty, .error).contains("doubleAdd missing args"))
        // Transient stack state (law 4b), so a stand-in naming the instruction.
        #expect(callString(topItem(inty, .error))
                == "( .doubleAdd_actuallyWas_« ‼️ doubleAdd missing args: .double » )")

    }

    @Test func doubleCos() {
        loadDoubles(inty, doubles: [0.0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0.0 .doubleCos )")

        loadDoubles(inty, doubles: [Double.pi])
        #expect(stackString(inty, .double) == "[ 3.141592653589793 1.0 ]")

        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ -1.0 1.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 3.141592653589793 .doubleCos )")

        loadDoubles(inty, doubles: [-2.0 * Double.pi])
        #expect(stackString(inty, .double) == "[ -6.283185307179586 -1.0 1.0 ]")

        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -1.0 1.0 ]")
        #expect(callString(topItem(inty, .double)) == "( -6.283185307179586 .doubleCos )")
    }

    @Test func doubleDec() {
        loadDoubles(inty, doubles: [0.0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ -1.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0.0 .doubleDec )")

        loadDoubles(inty, doubles: [9])
        #expect(stackString(inty, .double) == "[ 9.0 -1.0 ]")

        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ 8.0 -1.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 9.0 .doubleDec )")
    }

    @Test func `doubleDec handles overflows`() {
        loadDoubles(inty, doubles: [0.0/0.0])

        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains( "Overflow in .doubleDec") )
        #expect(callString(topItem(inty, .error)) == "( nan .doubleDec )")
    }

    @Test func doubleDivide() {
        loadDoubles(inty, doubles: [7.0, 0.0, 3.0, -6.0])
        #expect(stackString(inty, .double) == "[ 7.0 0.0 3.0 -6.0 ]")

        doThis(.doubleDivide, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 3.0 -6.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0.0 7.0 .doubleDivide )")

        doThis(.doublePop, to: inty)

        doThis(.doubleDivide, to: inty)
        #expect(stackString(inty, .double) == "[ -2.0 ]")
        #expect(callString(topItem(inty, .double)) == "( -6.0 3.0 .doubleDivide )")
    }

    @Test func `doubleDivide records overflows`() {
        loadDoubles(inty, doubles: [0.0, 33])

        doThis(.doubleDivide, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleDivide:"))
        #expect(callString(topItem(inty, .error)) == "( 33.0 0.0 .doubleDivide )")

    }

    @Test func doubleFromBool() {
        loadBools(inty, bools: [false, true])
        #expect(stackString(inty, .bool) == "[ false true ]")

        doThis(.doubleFromBool, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(callString(topItem(inty, .double)) == "( false .doubleFromBool )")

        doThis(.doubleFromBool, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")
        #expect(callString(topItem(inty, .double)) == "( true .doubleFromBool )")
    }

    @Test func doubleFromChar() {
        loadChars(inty, chars: ["g", "😉", "\n"])
        #expect(stackString(inty, .char) == "[ 'g' '😉' '\("\n")' ]")

        doThis(.doubleFromChar, to: inty)
        #expect(stackString(inty, .double) == "[ 103.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 'g' .doubleFromChar )")

        // The Unicode scalar value, as `intFromChar` gives it (until 2026-11-09,
        // ASCII only, and 0.0 for this one).
        doThis(.doubleFromChar, to: inty)
        #expect(stackString(inty, .double) == "[ 128521.0 103.0 ]")
        #expect(callString(topItem(inty, .double)) == "( '😉' .doubleFromChar )")

        doThis(.doubleFromChar, to: inty)
        #expect(stackString(inty, .double) == "[ 10.0 128521.0 103.0 ]")
        #expect(callString(topItem(inty, .double)) == "( '\n' .doubleFromChar )")
    }

    @Test func doubleFromInt() {
        loadInts(inty, ints: [-11, 14_000, 0])
        #expect(stackString(inty, .int) == "[ -11 14000 0 ]")

        doThis(.doubleFromInt, to: inty)
        #expect(stackString(inty, .double) == "[ -11.0 ]")
        #expect(callString(topItem(inty, .double)) == "( -11 .doubleFromInt )")

        doThis(.doubleFromInt, to: inty)
        #expect(stackString(inty, .double) == "[ 14000.0 -11.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 14000 .doubleFromInt )")

        doThis(.doubleFromInt, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 14000.0 -11.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0 .doubleFromInt )")
    }

    @Test func doubleFromString() {
        loadStrings(inty, strings: ["-172", "0", "00001", "1_000_000", " 172", "1 7 2"])
        #expect(stackString(inty, .string) == "[ \"-172\" \"0\" \"00001\" \"1_000_000\" \" 172\" \"1 7 2\" ]")

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ -172.0 ]")
        #expect(callString(topItem(inty, .double)) == "( \"-172\" .doubleFromString )")

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 -172.0 ]")
        #expect(callString(topItem(inty, .double)) == "( \"0\" .doubleFromString )")

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 -172.0 ]")
        #expect(callString(topItem(inty, .double)) == "( \"00001\" .doubleFromString )")

        // Not numbers: each is an error now. They used to answer 0.0.
        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 -172.0 ]")
        #expect((topItem(inty, .error) as? ErrorItem)?.kind == .conversion)
        #expect(callString(topItem(inty, .error)) == "( \"1_000_000\" .doubleFromString )")

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 -172.0 ]")
        #expect(callString(topItem(inty, .error)) == "( \" 172\" .doubleFromString )")
    }

    @Test func `doubleFromString rejects non-finite strings`() {
        // "inf"/"nan"/"1e400" parse to non-finite doubles; reject them so they
        // cannot poison later numeric behaviors (e.g. .intFromDouble)
        loadStrings(inty, strings: ["inf", "nan", "1e400"])

        doThis(.doubleFromString, to: inty)   // "inf"
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleFromString"))
        #expect(callString(topItem(inty, .error)) == "( \"inf\" .doubleFromString )")

        doThis(.doubleFromString, to: inty)   // "nan"
        #expect(stackString(inty, .double) == "[ ]")

        doThis(.doubleFromString, to: inty)   // "1e400"
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleFromString"))
        #expect(callString(topItem(inty, .error)) == "( \"1e400\" .doubleFromString )")
    }

    @Test func `trig behaviors handle non-finite input`() {
        // cos/sin/tan of an infinite double are NaN; route to .error rather
        // than pushing a poison value onto the double stack
        loadDoubles(inty, doubles: [Double.infinity])
        doThis(.doubleTan, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleTan"))
        #expect(callString(topItem(inty, .error)) == "( inf .doubleTan )")

        loadDoubles(inty, doubles: [Double.infinity])
        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleCos"))
        #expect(callString(topItem(inty, .error)) == "( inf .doubleCos )")
    }

    @Test func doubleGT() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( 4.25 3.25 .doubleGT 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -4.25 3.25 .doubleGT 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -6.25 -6.25 .doubleGT 2 .doublePopItems )")
    }

    @Test func doubleGTE() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25])

        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(callString(topItem(inty, .bool)) == "( 4.25 3.25 .doubleGTE 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -4.25 3.25 .doubleGTE 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(callString(topItem(inty, .bool)) == "( -6.25 -6.25 .doubleGTE 2 .doublePopItems )")
    }

    @Test func doubleInc() {
        loadDoubles(inty, doubles: [0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0.0 .doubleInc )")

        loadDoubles(inty, doubles: [0])
        #expect(stackString(inty, .double) == "[ 0.0 1.0 ]")

        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 1.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0.0 .doubleInc )")
    }

    @Test func `doubleInc handles overflows`() {
        loadDoubles(inty, doubles: [1.0 / 0.0])
        #expect(stackString(inty, .double) == "[ inf ]")

        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains( "Overflow in .doubleInc") )
        #expect(callString(topItem(inty, .error)) == "( inf .doubleInc )")

    }

    @Test func doubleLT() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25])

        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 4.25 3.25 .doubleLT 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -4.25 3.25 .doubleLT 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -6.25 -6.25 .doubleLT 2 .doublePopItems )")
    }

    @Test func doubleLTE() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(callString(topItem(inty, .bool)) == "( 4.25 3.25 .doubleLTE 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -4.25 3.25 .doubleLTE 2 .doublePopItems )")

        doThis(.doublePop, to: inty)
        doThis(.doublePop, to: inty)
        doThis(.doubleLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(callString(topItem(inty, .bool)) == "( -6.25 -6.25 .doubleLTE 2 .doublePopItems )")
    }

    @Test func doubleMax() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMax, to: inty)
        #expect(stackString(inty, .double) == "[ 4.25 -6.25 ]")
        #expect(callString(topItem(inty, .double)) == "( 4.25 3.25 .doubleMax )")


        doThis(.doubleMax, to: inty)
        #expect(stackString(inty, .double) == "[ 4.25 ]")
        #expect(callString(topItem(inty, .double)) == "( -6.25 4.25 .doubleMax )")
    }

    @Test func doubleMin() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMin, to: inty)
        #expect(stackString(inty, .double) == "[ 3.25 -6.25 ]")
        #expect(callString(topItem(inty, .double)) == "( 4.25 3.25 .doubleMin )")


        doThis(.doubleMin, to: inty)
        #expect(stackString(inty, .double) == "[ -6.25 ]")
        #expect(callString(topItem(inty, .double)) == "( -6.25 3.25 .doubleMin )")
    }

    @Test func doubleMod() {
        loadDoubles(inty, doubles: [5, 11, -20, 21, 17])
        #expect(stackString(inty, .double) == "[ 5.0 11.0 -20.0 21.0 17.0 ]")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -20.0 21.0 17.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 11.0 5.0 .doubleMod )")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ -0.0 21.0 17.0 ]")
        #expect(callString(topItem(inty, .double)) == "( -20.0 1.0 .doubleMod )")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ 17.0 ]")
    }

    @Test func `doubleMod records overflows`() {
        loadDoubles(inty, doubles: [0.0, 33])
        #expect(stackString(inty, .double) == "[ 0.0 33.0 ]")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleMod:"))
        #expect(callString(topItem(inty, .error)) == "( 33.0 0.0 .doubleMod )")
    }

    @Test func doubleMultiply() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ 13.8125 -6.25 ]")
        #expect(callString(topItem(inty, .double)) == "( 4.25 3.25 .doubleMultiply )")


        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ -86.328125 ]")
        #expect(callString(topItem(inty, .double)) == "( -6.25 13.8125 .doubleMultiply )")
    }

    @Test func `doubleMultiply records overflows`() {
        loadDoubles(inty, doubles: [Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude])

        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleMultiply"))
        #expect(callString(topItem(inty, .error)) == "( 1.7976931348623157e+308 1.7976931348623157e+308 .doubleMultiply )")
    }

    @Test func doubleQuot() {
        loadDoubles(inty, doubles: [5.0, 10, -20, 21, 17.0])
        #expect(stackString(inty, .double) == "[ 5.0 10.0 -20.0 21.0 17.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ 2.0 -20.0 21.0 17.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 10.0 5.0 .doubleQuot )")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -10.0 21.0 17.0 ]")
        #expect(callString(topItem(inty, .double)) == "( -20.0 2.0 .doubleQuot )")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -2.0 17.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 21.0 -10.0 .doubleQuot )")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -8.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 17.0 -2.0 .doubleQuot )")

        loadDoubles(inty, doubles: [0])
        #expect(stackString(inty, .double) == "[ 0.0 -8.0 ]")
    }

    @Test func `doubleQuot records overflows`() {
        loadDoubles(inty, doubles: [0.0, 33])
        #expect(stackString(inty, .double) == "[ 0.0 33.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleQuot:"))
        #expect(callString(topItem(inty, .error)) == "( 33.0 0.0 .doubleQuot )")
    }

    @Test func doubleSin() {
        loadDoubles(inty, doubles: [0.0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0.0 .doubleSin )")

        loadDoubles(inty, doubles: [Double.pi / 2.0])
        #expect(stackString(inty, .double) == "[ 1.5707963267948966 0.0 ]")

        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 1.5707963267948966 .doubleSin )")

        loadDoubles(inty, doubles: [-3.0 * Double.pi / 2.0])
        #expect(stackString(inty, .double) == "[ -4.71238898038469 1.0 0.0 ]")

        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 1.0 0.0 ]")
        #expect(callString(topItem(inty, .double)) == "( -4.71238898038469 .doubleSin )")
    }

    @Test func doubleSubtract() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -6.25 ]")
        #expect(callString(topItem(inty, .double)) == "( 4.25 3.25 .doubleSubtract )")

        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ -7.25 ]")
        #expect(callString(topItem(inty, .double)) == "( -6.25 1.0 .doubleSubtract )")
    }

    @Test func `doubleSubtract records overflows`() {
        loadDoubles(inty, doubles: [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude])

        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleSubtract:"))
        #expect(callString(topItem(inty, .error)) == "( -1.7976931348623157e+308 1.7976931348623157e+308 .doubleSubtract )")
    }

    @Test func doubleTan() {
        loadDoubles(inty, doubles: [0.0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleTan, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 0.0 .doubleTan )")

        loadDoubles(inty, doubles: [1.0])

        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")

        doThis(.doubleTan, to: inty)
        // The platform's own tan(1): Darwin's libm gives 1.557407724654902, glibc's
        // 1.5574077246549023, one ulp apart.
        #expect(stackString(inty, .double) == "[ \(tan(1.0)) 0.0 ]")
        #expect(callString(topItem(inty, .double)) == "( 1.0 .doubleTan )")
    }
}
