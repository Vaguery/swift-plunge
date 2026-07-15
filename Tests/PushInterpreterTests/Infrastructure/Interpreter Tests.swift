//
//  Interpreter tests.swift
//
//  Created by William Tozier on 5/30/26.
//

@testable import PushInterpreter
import Testing
import DequeModule


@Suite @MainActor
struct InterpreterTests {

    let inty = Interpreter()
    
    let inputty:[PI: any Item] =
        [.input0 : IntItem(10), .input2 : DoubleItem(1.1e17)]
    
    let proggy:[any Item] =
        [IntItem(6), InstructionItem(.intAdd), IntItem(2)]
    
    
    let stacky:[PushStack: [any Item]] =
        [.bool: [BoolItem(false)]]
    
    
    let fakeAdd = Behavior(.intAdd, takes: [], fxn: {_ in [Router(.error, ErrorItem("I haz no stick"))]})


    @Test func `new interpreter has reasonable defaults`() {
        #expect(inty.stacks.keys.sorted() == PushStack.allCases.sorted())
    }
    
    @Test func `new interpreter starts with no constants assigned`() {
        // Constants are keyed by instruction token (like inputs), so a fresh
        // interpreter has none until they are bound; unassigned tokens read nil.
        #expect(inty.constants.isEmpty)
        #expect(inty.constants[.int2] == nil)
    }
    
    @Test
    func `push item works`() {
        inty.pushItem(Router(.code, CodeItem( [DoubleItem(2.3),
                                           VecBoolItem([true,false,true]) ] ) ) )
        #expect(inty.stacks[.code]!.count == 1)
    }
    
    
    @Test
    func `interpreter load works`() {
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
    
    @Test func `stepping pushes most items`() {
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
        // The block used to scatter its contents back onto `.exec` here, growing
        // it to 3. It comes to rest on `.code` intact now, so `.exec` simply
        // shrinks like every other literal — code is data until a program asks
        // for it with `.codeDo`.
        #expect(stackString(inty, .code) == "[ ( 777 888 ) ]")
        #expect(inty.stacks[.exec]!.count == 1)

        inty.step()
        #expect(inty.stacks[.error]!.count == 1)
        #expect(stackString(inty, .error).contains("I haz no stick") )
        #expect(inty.stacks[.exec]!.count == 0)

    }

    
    @Test func `running seems ok`() {

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
        // 11, not 13: the code block is one step (resting on `.code`) where it
        // used to be three (unwrap, then 777, then 888).
        #expect(inty.counter == 11)
        #expect(stackString(inty, .code) == "[ ( 777 888 ) ]")
    }
    
    @Test func `resetting works`() {
        let topInt = Recorder<Int>(
            "topInt",
            instrumentation: {interpreter in
                guard interpreter.stacks[.int]!.count > 0 else {return nil}
                guard let top = interpreter.stacks[.int]!.first else {return nil}
                return (top as! IntItem).value
            })
        
        let prog:[any Item] = [
            BoolItem(false), BoolItem(true), IntItem(3),
            InstructionItem(.input0),
            InstructionItem(.input1),
            InstructionItem(.intAdd),
            InstructionItem(.intSwap)
        ]
        
        inty.recorders[topInt.name] = AnyRecorder(topInt)
        inty.load(inputs: [.input0: IntItem(4), .input1: IntItem(-11)],
                 stacks: [.int: []],
                 program: prog)
        #expect(stackString(inty, .int) == "[ ]")
        #expect(inty.recorderNames == ["topInt"])
        
        inty.run(stepLimit: 100)
        #expect(stackString(inty, .int) == "[ 3 -7 ]")
        #expect(inty.counter == 9)
        
        #expect(inty.recorders["topInt"]!.dataAsAnyArray.count == 9)
        #expect(inty.recorders["topInt"]!.dataAsAnyArray as! [Int?] == [
            nil, nil, Optional(3), Optional(3), Optional(4), Optional(4), Optional(-11), Optional(-7), Optional(3),
        ])

        inty.reset()
        #expect(stackString(inty, .int) == "[ ]")
        #expect(inty.program == prog)
        #expect(inty.counter == 0)
        #expect(inty.recorders["topInt"]!.dataAsAnyArray.count == 0)
        #expect(inty.recorders["topInt"]!.dataAsAnyArray as! [Int?] == [] )
    }
    
    
//    @Test
    @Test(.disabled("run manually to see the coverage"))
    func behaviorCoverageTest() {
        let coverage = Interpreter.reportBehaviorCoverage()
        #expect(coverage != "")
         #expect(coverage == "90128")
    }
}
