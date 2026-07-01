//
//  Double Behavior Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/3/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite @MainActor
struct DoubleBehaviorTests {

    let inty = Interpreter()

    @Test func doubleAdd() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25], contingent: [2])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 7.5 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)
        
        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 1.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
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
                
        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleAdd:"))

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains(""))

    }

    @Test func doubleCos() {
        loadDoubles(inty, doubles: [0.0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        loadDoubles(inty, doubles: [Double.pi], contingent: [0])
        #expect(stackString(inty, .double) == "[ 3.141592653589793 1.0 ]")

        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ -1.0 1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        loadDoubles(inty, doubles: [-2.0 * Double.pi])
        #expect(stackString(inty, .double) == "[ -6.283185307179586 -1.0 1.0 ]")

        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -1.0 1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    @Test func doubleDec() {
        loadDoubles(inty, doubles: [0.0], contingent: [0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ -1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        loadDoubles(inty, doubles: [9])
        #expect(stackString(inty, .double) == "[ 9.0 -1.0 ]")

        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ 8.0 -1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    @Test func `doubleDec handles overflows`() {
        loadDoubles(inty, doubles: [0.0/0.0])

        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains( "Overflow in .doubleDec") )
    }

    @Test func doubleDivide() {
        loadDoubles(inty, doubles: [0.0, 7.0, 3.0, -6.0], contingent: [2])
        #expect(stackString(inty, .double) == "[ 0.0 7.0 3.0 -6.0 ]")

        doThis(.doubleDivide, to: inty)
        #expect(stackString(inty, .double) == "[ 3.0 -6.0 ]")

        doThis(.doublePop, to: inty)
        
        doThis(.doubleDivide, to: inty)
        #expect(stackString(inty, .double) == "[ -6.0 ]")
    }
    
    @Test func `doubleDivide records overflows`() {
        loadDoubles(inty, doubles: [0.0, 33])

        doThis(.doubleDivide, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleDivide:"))
        
    }

    @Test func doubleFromBool() {
        loadBools(inty, bools: [false, true], contingent: [1])
        #expect(stackString(inty, .bool) == "[ false true ]")

        doThis(.doubleFromBool, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleFromBool, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleFromChar() {
        loadChars(inty, chars: ["g", "😉", "\n"], contingent: [1])
        #expect(stackString(inty, .char) == "[ 'g' '😉' '\("\n")' ]")

        doThis(.doubleFromChar, to: inty)
        #expect(stackString(inty, .double) == "[ 103.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleFromChar, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 103.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        doThis(.doubleFromChar, to: inty)
        #expect(stackString(inty, .double) == "[ 10.0 0.0 103.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    @Test func doubleFromInt() {
        loadInts(inty, ints: [-11, 14_000, 0], contingent: [2])
        #expect(stackString(inty, .int) == "[ -11 14000 0 ]")

        doThis(.doubleFromInt, to: inty)
        #expect(stackString(inty, .double) == "[ -11.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleFromInt, to: inty)
        #expect(stackString(inty, .double) == "[ 14000.0 -11.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleFromInt, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 14000.0 -11.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleFromString() {
        loadStrings(inty, strings: ["-172", "0", "00001", "1_000_000", " 172", "1 7 2"], contingent:    [1])
        #expect(stackString(inty, .string) == "[ \"-172\" \"0\" \"00001\" \"1_000_000\" \" 172\" \"1 7 2\" ]")

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ -172.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 -172.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 -172.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 1.0 0.0 -172.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleFromString, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 0.0 1.0 0.0 -172.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    @Test func doubleGT() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25],
            contingent: [4]
        )
        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleGT, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleGT, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func doubleGTE() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25],
            contingent: [4]
        )

        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleGTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false true ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func doubleInc() {
        loadDoubles(inty, doubles: [0], contingent: [0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        loadDoubles(inty, doubles: [0])
        #expect(stackString(inty, .double) == "[ 0.0 1.0 ]")

        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    @Test func `doubleInc handles overflows`() {
        loadDoubles(inty, doubles: [1.0 / 0.0])
        #expect(stackString(inty, .double) == "[ inf ]")

        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains( "Overflow in .doubleInc") )

    }

    @Test func doubleLT() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25],
            contingent: [4]
        )

        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleLT, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleLT, to: inty)
        #expect(stackString(inty, .bool) == "[ false true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func doubleLTE() {
        loadDoubles(
            inty,
            doubles: [3.25, 4.25, 3.25, -4.25, -6.25, -6.25],
            contingent: [4]
        )
        #expect(stackString(inty, .double) == "[ 3.25 4.25 3.25 -4.25 -6.25 -6.25 ]")

        doThis(.doubleLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true false ]")
        #expect(topItem(inty, .bool).isContingent == false)

        doThis(.doubleLTE, to: inty)
        #expect(stackString(inty, .bool) == "[ true true false ]")
        #expect(topItem(inty, .bool).isContingent == true)
    }

    @Test func doubleMax() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25], contingent: [2])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMax, to: inty)
        #expect(stackString(inty, .double) == "[ 4.25 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)


        doThis(.doubleMax, to: inty)
        #expect(stackString(inty, .double) == "[ 4.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleMin() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25], contingent: [2])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMin, to: inty)
        #expect(stackString(inty, .double) == "[ 3.25 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)


        doThis(.doubleMin, to: inty)
        #expect(stackString(inty, .double) == "[ -6.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleMod() {
        loadDoubles(inty, doubles: [5, 11, -20, 21, 17], contingent: [2])
        #expect(stackString(inty, .double) == "[ 5.0 11.0 -20.0 21.0 17.0 ]")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -20.0 21.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ -0.0 21.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ 17.0 ]")
    }

    @Test func `doubleMod records overflows`() {
        loadDoubles(inty, doubles: [0.0, 33])
        #expect(stackString(inty, .double) == "[ 0.0 33.0 ]")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleMod:"))
    }

    @Test func doubleMultiply() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25], contingent: [2])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ 13.8125 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)


        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ -86.328125 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func `doubleMultiply records overflows`() {
        loadDoubles(inty, doubles: [Double.greatestFiniteMagnitude,Double.greatestFiniteMagnitude])

        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleMultiply"))
    }

    @Test func doubleQuot() {
        loadDoubles(inty, doubles: [5.0, 10, -20, 21, 17.0], contingent: [2])
        #expect(stackString(inty, .double) == "[ 5.0 10.0 -20.0 21.0 17.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ 2.0 -20.0 21.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -10.0 21.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -2.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -8.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        loadDoubles(inty, doubles: [0])
        #expect(stackString(inty, .double) == "[ 0.0 -8.0 ]")
    }

    @Test func `doubleQuot records overflows`() {
        loadDoubles(inty, doubles: [0.0, 33])
        #expect(stackString(inty, .double) == "[ 0.0 33.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleQuot:"))
    }

    @Test func doubleSin() {
        loadDoubles(inty, doubles: [0.0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        loadDoubles(inty, doubles: [Double.pi / 2.0], contingent: [0])
        #expect(stackString(inty, .double) == "[ 1.5707963267948966 0.0 ]")

        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        loadDoubles(inty, doubles: [-3.0 * Double.pi / 2.0])
        #expect(stackString(inty, .double) == "[ -4.71238898038469 1.0 0.0 ]")

        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 1.0 0.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    @Test func doubleSubtract() {
        loadDoubles(inty, doubles: [3.25, 4.25, -6.25], contingent: [2])
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)

        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ -7.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func `doubleSubtract records overflows`() {
        loadDoubles(inty, doubles: [Double.greatestFiniteMagnitude,-Double.greatestFiniteMagnitude])

        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ ]")
        #expect(stackString(inty, .error).contains("Overflow in .doubleSubtract:"))
    }

    @Test func doubleTan() {
        loadDoubles(inty, doubles: [0.0], contingent: [0])
        #expect(stackString(inty, .double) == "[ 0.0 ]")

        doThis(.doubleTan, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        loadDoubles(inty, doubles: [1.0])

        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")
    
        doThis(.doubleTan, to: inty)
        #expect(stackString(inty, .double) == "[ 1.557407724654902 0.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }
}
