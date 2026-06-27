//
//  Recorder tests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 6/20/26.
//

import DequeModule
@testable import PropellerWithStructs
import Testing

@Suite @MainActor
struct Recorder_Tests {

    let inty = Interpreter()
    
    var topInt = Recorder<Int>(
        "topInt",
        instrumentation: {interpreter in
            guard interpreter.stacks[.int]!.count > 0 else {return nil}
            guard let top = interpreter.stacks[.int]!.first else {return nil}
            return (top as! IntItem).value
        })
    
    var secondInt = Recorder<Int>(
        "secondInt",
        instrumentation: {interpreter in
            guard interpreter.stacks[.int]!.count > 1 else {return nil}
            guard let second = interpreter.stacks[.int]?[1] else {return nil}
            return (second as! IntItem).value
        })

    
    @Test func recorderInitializes() {
        #expect(topInt.name == "topInt")
        #expect(topInt.data == [])
    }
    
    @Test mutating func recorderCanRecord() {
        topInt.record(interpreter: inty)
        #expect(topInt.data == [nil])

        inty.stacks[.int] = [IntItem(1), IntItem(2), IntItem(3)]
        topInt.record(interpreter: inty)
        #expect(topInt.data == [nil, Optional(1)])
    }
    
    @Test func recorderRecords() {
        inty.recorders[topInt.name] = AnyRecorder(topInt)
        inty.load(inputs: [.input0: IntItem(4), .input1: IntItem(-11)],
                 stacks: [.int: [IntItem(1), IntItem(2), IntItem(3)]],
                 program: [
                    InstructionItem(.input0),
                    InstructionItem(.input1),
                    InstructionItem(.intAdd),
                    InstructionItem(.intSwap)
                ])
        #expect(stackString(inty, .int) == "[ 1 2 3 ]")
        #expect(inty.recorderNames == ["topInt"])
        inty.run(stepLimit: 100)
        #expect(stackString(inty, .int) == "[ 1 -7 2 3 ]")
        #expect(inty.counter == 6)
        
        #expect(inty.recorders["topInt"]!.dataAsAnyArray.count == 6)
        #expect(inty.recorders["topInt"]!.dataAsAnyArray as! [Int?] == [Optional(1), Optional(4), Optional(4), Optional(-11), Optional(-7), Optional(1)])
    }

    
    @Test func recorderHandlesNil() {
        inty.recorders[topInt.name] = AnyRecorder(topInt)
        inty.load(inputs: [.input0: IntItem(4), .input1: IntItem(-11)],
                 stacks: [.int: []],
                 program: [
                    BoolItem(false), BoolItem(true), IntItem(3),
                    InstructionItem(.input0),
                    InstructionItem(.input1),
                    InstructionItem(.intAdd),
                    InstructionItem(.intSwap)
                ])
        #expect(stackString(inty, .int) == "[ ]")
        #expect(inty.recorderNames == ["topInt"])
        inty.run(stepLimit: 100)
        #expect(stackString(inty, .int) == "[ 3 -7 ]")
        #expect(inty.counter == 9)
        
        #expect(inty.recorders["topInt"]!.dataAsAnyArray.count == 9)
        #expect(inty.recorders["topInt"]!.dataAsAnyArray as! [Int?] == [
            nil, nil, Optional(3), Optional(3), Optional(4), Optional(4), Optional(-11), Optional(-7), Optional(3),
        ])
    }
    
    
    
    @Test func multipleRecorders() {
        inty.recorders[topInt.name] = AnyRecorder(topInt)
        inty.recorders[secondInt.name] = AnyRecorder(secondInt)
        
        inty.load(inputs: [.input0: IntItem(4), .input1: IntItem(-11)],
                 stacks: [.int: []],
                 program: [
                    BoolItem(false),
                    IntItem(3),
                    InstructionItem(.input0),
                    InstructionItem(.input1),
                    InstructionItem(.intFlush),
                    InstructionItem(.input1)
                ])
        #expect(stackString(inty, .int) == "[ ]")
        #expect(inty.recorderNames == ["secondInt","topInt"])
        inty.run(stepLimit: 100)
        #expect(stackString(inty, .int) == "[ -11 ]")
        #expect(inty.counter == 9)
        
        #expect(inty.recorders["topInt"]!.dataAsAnyArray.count == 9)
        #expect(inty.recorders["topInt"]!.dataAsAnyArray as! [Int?] == [nil, Optional(3), Optional(3), Optional(4), Optional(4), Optional(-11), nil, nil, Optional(-11)])
        
        #expect(inty.recorders["secondInt"]!.dataAsAnyArray.count == 9)
        #expect(inty.recorders["secondInt"]!.dataAsAnyArray as! [Int?] == [nil, nil, nil, Optional(3), Optional(3), Optional(4), nil, nil, nil])
    }

    
    @Test func `recorder reports all the data taking into account arguments`() {
        inty.recorders[topInt.name] = AnyRecorder(topInt)
        inty.load(inputs: [.input0: IntItem(4), .input1: IntItem(-11)],
                 stacks: [.int: []],
                 program: [
                    BoolItem(false), BoolItem(true), IntItem(3),
                    InstructionItem(.input0),
                    InstructionItem(.input1),
                    InstructionItem(.intAdd),
                    InstructionItem(.intSwap)
                ])
        inty.run(stepLimit: 100)
        #expect(stackString(inty, .int) == "[ 3 -7 ]")
        #expect(inty.counter == 9)
        
        let report1 = inty.recorders["topInt"]!.reportAll(steps:9) as! [Int?]
        #expect(report1.count == 9)
        #expect(report1 == [nil, nil, Optional(3), Optional(3), Optional(4), Optional(4), Optional(-11), Optional(-7), Optional(3)])
        
        let report2 = inty.recorders["topInt"]!.reportAll(steps:11, fillWithLast: true) as! [Int?]
        #expect(report2.count == 11)
        #expect(report2 == [nil, nil, Optional(3), Optional(3), Optional(4), Optional(4), Optional(-11), Optional(-7), Optional(3), Optional(3), Optional(3), ] )
        
        let report3 = inty.recorders["topInt"]!.reportAll(steps:1000, fillWithLast: false) as! [Int?]
        #expect(report3.count == 9)
        #expect(report3 == [nil, nil, Optional(3), Optional(3), Optional(4), Optional(4), Optional(-11), Optional(-7), Optional(3)])
        
        let report4 = inty.recorders["topInt"]!.reportAll(steps: 3) as! [Int?]
        #expect(report4.count == 9)
        #expect(report4 == [nil, nil, Optional(3), Optional(3), Optional(4), Optional(4), Optional(-11), Optional(-7), Optional(3)])
        
        let report5 = inty.recorders["topInt"]!.reportAll(steps: 3, trim: true) as! [Int?]
        #expect(report5.count == 3)
        #expect(report5 == [nil, nil, Optional(3), ])
    }

    
}
 
