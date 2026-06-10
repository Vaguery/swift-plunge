//
//  Combinator Instruction Tests.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 6/7/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule

@Suite
struct CombinatorInstructionTests {
    
    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }
    
    
    func topItem(_ interpreter: Interpreter, _ stack: PushStack) -> (any Item)? {
        interpreter.stacks[stack]!.first
    }

    func doThis(_ instruction:PushInstruction, to interpreter: Interpreter) {
        Interpreter.language[instruction]!.act(on: interpreter)
    }


    let inty = Interpreter()
    
    @Test func codeEq() {
        inty.stacks[.code]!.prepend(
            contentsOf: [CodeItem([IntItem(4),BoolItem(false)], isContingent: true),
                         CodeItem([IntItem(4),BoolItem(false)], isContingent: true),
                         CodeItem([IntItem(4),BoolItem(false)], isContingent: true),
                         CodeItem([IntItem(4),BoolItem(false)], isContingent: false),
                         CodeItem([IntItem(5),BoolItem(false)], isContingent: false),
                         CodeItem([IntItem(4),BoolItem(true)], isContingent: false),
                         ]
            )
        
        #expect(stackString(inty, .code) == "[ ( 4 false ) ( 4 false ) ( 4 false ) ( 4 false ) ( 5 false ) ( 4 true ) ]")
        
        doThis(.codeEq, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool)!.isContingent == true)
        
        doThis(.codeEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool)!.isContingent == true)
        
        doThis(.codeEq, to: inty)
        #expect(stackString(inty, .bool) == "[ false false true ]")
        #expect(topItem(inty, .bool)!.isContingent == false)
    }
    
    @Test func intSwap() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )
    
        #expect(stackString(inty, .int) == "[ 11 88 ]")
        
        doThis(.intSwap, to: inty)
        #expect(stackString(inty, .int) == "[ 88 11 ]")
        #expect(topItem(inty, .int)!.isContingent == true)
    }
    
    @Test func intPop() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )
    
        #expect(stackString(inty, .int) == "[ 11 88 ]")
        
        doThis(.intPop, to: inty)
        #expect(stackString(inty, .int) == "[ 88 ]")
        #expect(topItem(inty, .int)!.isContingent == true)
    }
    
    @Test func intStackDepth() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )
    
        #expect(stackString(inty, .int) == "[ 11 88 ]")
        
        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 2 11 88 ]")
        #expect(topItem(inty, .int)!.isContingent == true)
        
        doThis(.intStackDepth, to: inty)
        #expect(stackString(inty, .int) == "[ 3 2 11 88 ]")
        #expect(topItem(inty, .int)!.isContingent == true)
    }

    @Test func boolEmpty() {
        #expect(stackString(inty, .bool) == "[ ]")
        
        doThis(.boolEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ true ]")
        #expect(topItem(inty, .bool)!.isContingent == true)
        
        doThis(.boolEmpty, to: inty)
        #expect(stackString(inty, .bool) == "[ false true ]")
        #expect(topItem(inty, .bool)!.isContingent == true)
    }
    

    @Test func intFlush() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(88, isContingent: true)
                        ]
        )

        #expect(stackString(inty, .int) == "[ 11 88 ]")
        
        doThis(.intFlush, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
        
        doThis(.intFlush, to: inty)
        #expect(stackString(inty, .int) == "[ ]")
    }
    
    @Test func intRot() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(11),
                         IntItem(55, isContingent: true),
                         IntItem(999)
                        ]
        )

        #expect(stackString(inty, .int) == "[ 11 55 999 ]")
        
        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 999 11 55 ]")
        
        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 55 999 11 ]")
        
        doThis(.intRot, to: inty)
        #expect(stackString(inty, .int) == "[ 11 55 999 ]")
    }
    
    
    @Test func doubleDupTimes() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(3),  // should add three
                         IntItem(-3), // should add none
                         IntItem(0)   // should add none
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                        ])

        #expect(stackString(inty, .double) == "[ 1.1 ]")
        
        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 1.1 ]")
        
        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 1.1 ]")
        
        doThis(.doubleDupTimes, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 1.1 1.1 ]")
    }

    @Test func doubleDupItems() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),  // should dup none
                         IntItem(3),  // should dup 3
                         IntItem(0)   // should dup none
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                         DoubleItem(2.22),
                         DoubleItem(3.333),
                         DoubleItem(4.4444),
                        ])

        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleDupItems, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 1.1 2.22 3.333 4.4444 ]")
    }

    @Test func doubleYank() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),IntItem(2),IntItem(17),IntItem(0),IntItem(2),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                         DoubleItem(2.22),
                         DoubleItem(3.333),
                         DoubleItem(4.4444),
                        ])

        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 3.333 1.1 2.22 4.4444 ]")
        
        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 3.333 1.1 2.22 ]")
        
        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 3.333 1.1 2.22 ]")
        
        doThis(.doubleYank, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 4.4444 3.333 2.22 ]")
        #expect(topItem(inty, .double)!.isContingent == true )
    }

    
    @Test func doubleShove() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),IntItem(2),IntItem(17),IntItem(0),IntItem(2),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                         DoubleItem(2.22),
                         DoubleItem(3.333),
                         DoubleItem(4.4444),
                        ])

        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .double) == "[ 2.22 3.333 1.1 4.4444 ]")
        
        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .double) == "[ 3.333 1.1 2.22 4.4444 ]")
        
        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .double) == "[ 3.333 1.1 2.22 4.4444 ]")
        
        doThis(.doubleShove, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        #expect(topItem(inty, .double)!.isContingent == true )
    }

    
    @Test func doubleYankDup() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),IntItem(2),IntItem(17),IntItem(0),IntItem(2),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                         DoubleItem(2.22),
                         DoubleItem(3.333),
                         DoubleItem(4.4444),
                        ])

        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.22 1.1 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 2.22 1.1 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 4.4444 4.4444 2.22 1.1 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleYankDup, to: inty)
        #expect(stackString(inty, .double) == "[ 2.22 4.4444 4.4444 2.22 1.1 1.1 2.22 3.333 4.4444 ]")
        #expect(topItem(inty, .double)!.isContingent == true )
    }

    
    @Test func doubleDeepDup() {
        inty.stacks[.int]!.prepend(
            contentsOf: [IntItem(-3),IntItem(2),IntItem(17),IntItem(0),IntItem(2),
                        ])
        inty.stacks[.double]!.prepend(
            contentsOf: [DoubleItem(1.1),
                         DoubleItem(2.22),
                         DoubleItem(3.333),
                         DoubleItem(4.4444),
                        ])

        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 ]")
        
        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 4.4444 4.4444 ]")
        
        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 2.22 3.333 3.333 4.4444 4.4444 ]")
        
        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.22 3.333 3.333 4.4444 4.4444 ]")
        
        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.22 3.333 3.333 4.4444 4.4444 4.4444 ]")
        
        doThis(.doubleDeepDup, to: inty)
        #expect(stackString(inty, .double) == "[ 1.1 1.1 2.22 3.333 3.333 4.4444 4.4444 4.4444 4.4444 ]")
        #expect(topItem(inty, .double)!.isContingent == true )
    }

}
