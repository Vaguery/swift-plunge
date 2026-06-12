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
    
    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }
    
    func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> any Item {
        interpreter.stacks[stack]!.first!
    }

    func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }
    
    var inty = Interpreter()
    
    @Test func doubleAdd() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25), DoubleItem(4.25), DoubleItem(-6.25, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 7.5 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleAdd, to: inty)
        #expect(stackString(inty, .double) == "[ 1.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }
    
    
    @Test func doubleQuot() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(5.0), DoubleItem(10.0), DoubleItem(-20.0, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 5.0 10.0 -20.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ 2.0 -20.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -10.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.append(contentsOf: [DoubleItem(21.0), DoubleItem(17.0)])
        
        #expect(stackString(inty, .double) == "[ -10.0 21.0 17.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -2.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ -8.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

        inty.stacks[.double]!.prepend(contentsOf: [DoubleItem(0.0)])

        #expect(stackString(inty, .double) == "[ 0.0 -8.0 ]")

        doThis(.doubleQuot, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }
    
    
    
    @Test func doubleMod() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(5.0), DoubleItem(11.0), DoubleItem(-20.0, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 5.0 11.0 -20.0 ]")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -20.0 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ -0.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.append(contentsOf: [DoubleItem(21.0), DoubleItem(17.0)])
        
        #expect(stackString(inty, .double) == "[ -0.0 21.0 17.0 ]")

        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 17.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        doThis(.doubleMod, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(topItem(inty, .double).isContingent == true)

    }

    @Test func doubleMin() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25), DoubleItem(4.25), DoubleItem(-6.25, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMin, to: inty)
        #expect(stackString(inty, .double) == "[ 3.25 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleMin, to: inty)
        #expect(stackString(inty, .double) == "[ -6.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleMax() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25), DoubleItem(4.25), DoubleItem(-6.25, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMax, to: inty)
        #expect(stackString(inty, .double) == "[ 4.25 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleMax, to: inty)
        #expect(stackString(inty, .double) == "[ 4.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleSubtract() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25), DoubleItem(4.25), DoubleItem(-6.25, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleSubtract, to: inty)
        #expect(stackString(inty, .double) == "[ -7.25 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleMultiply() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25), DoubleItem(4.25), DoubleItem(-6.25, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 3.25 4.25 -6.25 ]")

        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ 13.8125 -6.25 ]")
        #expect(topItem(inty, .double).isContingent == false)

        
        doThis(.doubleMultiply, to: inty)
        #expect(stackString(inty, .double) == "[ -86.328125 ]")
        #expect(topItem(inty, .double).isContingent == true)
    }

    @Test func doubleFromInt() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-11), IntItem(14_000), IntItem(0, isContingent: true)])
        
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

    
    
    @Test func doubleGT() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25),
                         DoubleItem(4.25),
                         DoubleItem(3.25),
                         DoubleItem(-4.25),
                         DoubleItem(-6.25, isContingent: true),
                         DoubleItem(-6.25)])
        
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
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25),
                         DoubleItem(4.25),
                         DoubleItem(3.25),
                         DoubleItem(-4.25),
                         DoubleItem(-6.25, isContingent: true),
                         DoubleItem(-6.25)])
        
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
    
    @Test func doubleLTE() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25),
                         DoubleItem(4.25),
                         DoubleItem(3.25),
                         DoubleItem(-4.25),
                         DoubleItem(-6.25, isContingent: true),
                         DoubleItem(-6.25)])
        
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
    
    @Test func doubleLT() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(3.25),
                         DoubleItem(4.25),
                         DoubleItem(3.25),
                         DoubleItem(-4.25),
                         DoubleItem(-6.25, isContingent: true),
                         DoubleItem(-6.25)])
        
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
    
    
    @Test func doubleSin() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(0.0)])
        
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        
        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
        
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(Double.pi / 2.0, isContingent: true),]
            )
        
        #expect(stackString(inty, .double) == "[ 1.5707963267948966 0.0 ]")
    
        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(-3.0 * Double.pi / 2.0),]
            )
        
        #expect(stackString(inty, .double) == "[ -4.71238898038469 1.0 0.0 ]")
    
        doThis(.doubleSin, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 1.0 0.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    
    @Test func doubleCos() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(0.0)])
        
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        
        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
        
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(Double.pi, isContingent: true),]
            )
        
        #expect(stackString(inty, .double) == "[ 3.141592653589793 1.0 ]")
    
        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ -1.0 1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(-2.0 * Double.pi),]
            )
        
        #expect(stackString(inty, .double) == "[ -6.283185307179586 -1.0 1.0 ]")
    
        doThis(.doubleCos, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 -1.0 1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }
    
    @Test func doubleTan() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(0.0, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        
        doThis(.doubleTan, to: inty)
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.0),]
            )
        
        #expect(stackString(inty, .double) == "[ 1.0 0.0 ]")
    
        doThis(.doubleTan, to: inty)
        #expect(stackString(inty, .double) == "[ 1.557407724654902 0.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }

    
    @Test func doubleInc() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(0.0, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        
        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(0.0, isContingent: false)])
        
        #expect(stackString(inty, .double) == "[ 0.0 1.0 ]")
        
        doThis(.doubleInc, to: inty)
        #expect(stackString(inty, .double) == "[ 1.0 1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }
    
    @Test func doubleDec() {
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(0.0, isContingent: true)])
        
        #expect(stackString(inty, .double) == "[ 0.0 ]")
        
        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ -1.0 ]")
        #expect(topItem(inty, .double).isContingent == true)
        
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(9.0, isContingent: false)])
        
        #expect(stackString(inty, .double) == "[ 9.0 -1.0 ]")
        
        doThis(.doubleDec, to: inty)
        #expect(stackString(inty, .double) == "[ 8.0 -1.0 ]")
        #expect(topItem(inty, .double).isContingent == false)
    }
    
    @Test func doubleFromChar() {
        inty.stacks[.char]!.prepend(
            contentsOf: [CharItem(Character("g")),
                         CharItem(Character("😉"), isContingent: true),
                         CharItem(Character("\n")),]
        )
        
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

}
