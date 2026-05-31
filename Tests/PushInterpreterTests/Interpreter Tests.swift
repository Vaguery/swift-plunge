//
//  Interpreter tests.swift
//
//  Created by William Tozier on 5/30/26.
//

@testable import PropellerWithStructs
import Testing
import DequeModule


@MainActor
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
    
    let inputty:[PI: any Pushable] =
        [.input0 : Item<Int>(10), .input2 : Item<Double>(1.1e17)]
    
    let proggy:[any Pushable] =
        [Item<Int>(6), Item<PI>(.intAdd), Item<Int>(2)]
    
    
    let stacky:[PushStack: [any Pushable]] =
        [.bool: [Item<Bool>(false)]]
    
    
    let fakeAdd = Instruction(.intAdd, takes: [], fxn: {_ in [Router(.error, Error("I haz no stick"))]})


    @Test func newInterpreterHasReasonableDefaults() {
        #expect(inty.stacks.keys.sorted() == PushStack.allCases.sorted())
    }
    
    @Test
    func pushItem() {
        inty.pushItem(Router(.code, Code( [Item<Double>(2.3),
                                           Item<[Bool]>([true,false,true]) ] ) ) )
        #expect(inty.stacks[.code]!.count == 1)
    }
    
    
    @Test
    func loadWorks() {
        inty.load(inputs: inputty, stacks: stacky, program: proggy)
        
        // counter
        #expect(inty.counter == 0)
        
        // inputs
        #expect(inty.inputs[.input0]!.value as! Int == 10)
        #expect(inty.inputs[.input2]!.value as! Double == 1.1e+17)
        
        // initial stack values
        #expect(inty.stacks[.bool]!.count == 1)
        #expect(inty.stacks[.bool]![0].value as! Bool == false)

        // initial program
        #expect(inty.program.count == proggy.count)
        #expect(inty.stacks[.exec]!.count == 3)
        #expect(stackString(inty, .exec) == "[ 6 intAdd 2 ]")
        
        #expect(inty.stacks.count == PushStack.allCases.count)
    }
    
    @Test func steppingPushesMostItems() {
        let everythingProggy:[any Pushable] =
            [Item<Int>(6),
             Item<Bool>(false),
             Item<Double>(1.23),
             Item<String>("foo"),
             Item<Character>(Character("😂")),
             Item<[String]>(["foo", "bar"]),
             Item<[Int]>([1,2,3]),
             Item<[Double]>([1.1, 2.2, 3.3]),
             Item<[Bool]>([true,false,true]),
             Code([Item<Int>(777), Item<Int>(888)]),
             Item<PI>(.intAdd)

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
        #expect(stackString(inty, .exec) == "[ 777 888 intAdd ]")
        #expect(inty.stacks[.exec]!.count == 3)

        inty.step()
        inty.step()
        inty.step()
        
        #expect(inty.stacks[.error]!.count == 1)
        #expect(stackString(inty, .error) == "[ Error: \"I haz no stick\" ]")
        #expect(inty.stacks[.exec]!.count == 0)

    }

    
    @Test func runningSeemsOK() {
        
        let everythingProggy:[any Pushable] =
        [Item<Int>(6),
         Item<Bool>(false),
         Item<Double>(1.23),
         Item<String>("foo"),
         Item<Character>(Character("😂")),
         Item<[String]>(["foo", "bar"]),
         Item<[Int]>([1,2,3]),
         Item<[Double]>([1.1, 2.2, 3.3]),
         Item<[Bool]>([true,false,true]),
         Code([Item<Int>(777), Item<Int>(888)]),
         Item<PI>(.intAdd)
        ]
        
        inty.behaviors[.intAdd] = fakeAdd
                
        inty.run(inputs: [:], stacks: [:], program: everythingProggy)
        #expect(inty.stacks[.exec]!.count == 0)
        #expect(inty.counter == 13)
    }
    
    
    @Test func instructionCoverageTest() {
        let coverage = Interpreter.reportInstructionCoverage()
        #expect(coverage != "")
    }
}
