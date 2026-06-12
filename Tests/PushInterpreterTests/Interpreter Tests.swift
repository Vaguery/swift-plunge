//
//  Interpreter tests.swift
//
//  Created by William Tozier on 5/30/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule


@Suite @MainActor
struct InterpreterTests {
    
    func stackString(_ interpreter:Interpreter, _ stack:PushStack) -> String {
        var result = "["
        let s = interpreter.stacks[stack]!
        for item in s {
            result += " \(item.pretty() )"
        }
        result += " ]"
        return result
    }

    
    
    let inty = Interpreter()
    
    let inputty:[PI: any Item] =
        [.input0 : IntItem(10), .input2 : DoubleItem(1.1e17)]
    
    let proggy:[any Item] =
        [IntItem(6), InstructionItem(.intAdd), IntItem(2)]
    
    
    let stacky:[PushStack: [any Item]] =
        [.bool: [BoolItem(false)]]
    
    
    let fakeAdd = Behavior(.intAdd, takes: [], fxn: {_ in [Router(.error, ErrorItem("I haz no stick"))]})


    @Test func newInterpreterHasReasonableDefaults() {
        #expect(inty.stacks.keys.sorted() == PushStack.allCases.sorted())
    }
    
    @Test func newInterpreterHasConstantDictionaryDefined() {
        #expect(inty.constants.keys.count == 8)

    }
    
    @Test
    func pushItem() {
        inty.pushItem(Router(.code, CodeItem( [DoubleItem(2.3),
                                           VecBoolItem([true,false,true]) ] ) ) )
        #expect(inty.stacks[.code]!.count == 1)
    }
    
    
    @Test
    func loadWorks() {
        inty.load(inputs: inputty, stacks: stacky, program: proggy)
        
        // counter
        #expect(inty.counter == 0)
        
        // inputs
        #expect(inty.inputs[.input0]! is IntItem)
        #expect(inty.inputs[.input2]! is DoubleItem)
        
        // initial stack values
        #expect(inty.stacks[.bool]!.count == 1)
        #expect( (inty.stacks[.bool]!.first is BoolItem) )

        // initial program
        #expect(inty.program.count == proggy.count)
        #expect(inty.stacks[.exec]!.count == 3)
        #expect(stackString(inty, .exec) == "[ 6 .intAdd 2 ]")
        
        #expect(inty.stacks.count == PushStack.allCases.count)
    }
    
    @Test func steppingPushesMostItems() {
        let everythingProggy:[any Item] =
            [IntItem(6),
             BoolItem(false),
             DoubleItem(1.23),
             StringItem("foo"),
             CharItem(Character("😂")),
             VecStringItem(["foo", "bar"]),
             VecIntItem([1,2,3]),
             VecDoubleItem([1.1, 2.2, 3.3]),
             VecBoolItem([true,false,true]),
             CodeItem([IntItem(777), IntItem(888)]),
             InstructionItem(.intAdd)

             ]

        inty.load(inputs: [:], stacks: [:], program: everythingProggy)
        
        inty.behaviors[.intAdd] = fakeAdd
        
        #expect(inty.stacks[.exec]!.count == 11)

        
        inty.step()
        #expect(inty.stacks[.int]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 10)
        
        inty.step()
        #expect(inty.stacks[.bool]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 9)

        inty.step()
        #expect(inty.stacks[.double]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 8)

        inty.step()
        #expect(inty.stacks[.string]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 7)

        inty.step()
        #expect(inty.stacks[.char]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 6)

        inty.step()
        #expect(inty.stacks[.vecString]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 5)

        inty.step()
        #expect(inty.stacks[.vecInt]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 4)

        inty.step()
        #expect(inty.stacks[.vecDouble]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 3)

        inty.step()
        #expect(inty.stacks[.vecBool]!.count == 1)
        #expect(inty.stacks[.exec]!.count == 2)
        
        inty.step()
        #expect(stackString(inty, .exec) == "[ 777 888 .intAdd ]")
        #expect(inty.stacks[.exec]!.count == 3)

        inty.step()
        inty.step()
        inty.step()
        
        #expect(inty.stacks[.error]!.count == 1)
        #expect(stackString(inty, .error) == "[ «I haz no stick» ]")
        #expect(inty.stacks[.exec]!.count == 0)

    }

    
    @Test func runningSeemsOK() {
        
        let everythingProggy:[any Item] =
        [IntItem(6),
         BoolItem(false),
         DoubleItem(1.23),
         StringItem("foo"),
         CharItem(Character("😂")),
         VecStringItem(["foo", "bar"]),
         VecIntItem([1,2,3]),
         VecDoubleItem([1.1, 2.2, 3.3]),
         VecBoolItem([true,false,true]),
         CodeItem([IntItem(777), IntItem(888)]),
         InstructionItem(.intAdd)
        ]
        
        inty.behaviors[.intAdd] = fakeAdd
                
        inty.run(inputs: [:], stacks: [:], program: everythingProggy)
        #expect(inty.stacks[.exec]!.count == 0)
        #expect(inty.counter == 13)
    }
    
    
    @Test func behaviorCoverageTest() {
        let coverage = Interpreter.reportBehaviorCoverage()
        #expect(coverage != "")
//         #expect(coverage == "88")
//         ^^ uncomment for the kludge to report how many are done
    }
}
