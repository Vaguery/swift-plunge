//
//  Stress Tests.swift
//  PropellerWithStructsUnitTests
//
//  Created by William Tozier on 6/20/26.
//

import DequeModule
import Foundation
@testable import PropellerWithStructs
import Testing


@Suite @MainActor
struct Stress_Tests {
    
    static let disabledTests = true

    
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
    
    
    struct RandomCode {
        @MainActor static func randomInstruction() -> PushInstruction {
            Interpreter.language.keys.randomElement()!
        }
    
        static func randomInt(_ scale:Int) -> Int {
            Int.random(in: -scale...scale)
        }
    
        static func randomDouble(_ scale:Double) -> Double {
            Double.random(in: -scale...scale)
        }
    
        static func randomChar() -> Character {
            let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            return choices.randomElement()!
        }
    
        static func randomString(_ len: Int) -> String {
            let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            var result = ""
            let length = Int.random(in: 1...len)
            for _ in 1...length {
                result.append(choices.randomElement()!)
            }
            return result
        }
    
        static func randomVecString(_ len: Int) -> [String] {
            var result = [String]()
            let length = Int.random(in: 1...len)
            for _ in 1...length {
                result.append(randomString(len))
            }
            return result
        }
    
        static func randomVecInt(_ scale:Int, _ len: Int) -> [Int] {
            var result = [Int]()
            let length = Int.random(in: 1...len)
            for _ in 1...length {
                result.append(randomInt(scale))
            }
            return result
        }
    
        static func randomVecDouble(_ scale:Double, _ len: Int) -> [Double] {
            var result = [Double]()
            let length = Int.random(in: 1...len)
            for _ in 0..<length {
                result.append(randomDouble(scale))
            }
            return result
        }
    
        static func randomVecBool(_ len: Int) -> [Bool] {
            var result = [Bool]()
            let length = Int.random(in: 1...len)
            for _ in 0..<length {
                result.append(Bool.random())
            }
            return result
        }
        
    
        static func randomConstant() -> PushInstruction {
            let stacks:[PushStack] = [.char, .double, .int, .string, .vecBool, .vecInt, .vecDouble, .vecString]
            let stack = stacks.randomElement()!
            return PushInstruction(rawValue: ("\(stack)\(Int.random(in: 0..<10))"))!
        }
    
        static func randomInput(_ range:Int = 10) -> PushInstruction {
            let name = "input\(Int.random(in: 0..<range))"
            return PushInstruction(rawValue: name)!
        }
        
        @MainActor static func randomGenomeStuff() -> Any {
            return switch Int.random(in: 0..<20) {
            case 0: PlushyControl.close
            case 1: PlushyControl.open
            case 2...4: randomInput()
            case 5...10: randomConstant()
            default: randomInstruction()
            }
        }
        
        // do not need CodeBlock because of Plushy Open and Close
        
        @MainActor static func randomPlushy(_ items: Int) -> [Any] {
            var result:[Any] = []
            for _ in 0..<items {
                result.append(randomGenomeStuff())
            }
            return result
        }
        
        @MainActor static func setRandomConstants(in interpreter: Interpreter) {
//            var constants: [PushStack:[(any Item)?]] = [
//                .int       : [IntItem?](repeating:nil, count:10),
//                .double    : [DoubleItem?](repeating:nil, count:10),
//                .string    : [StringItem?](repeating:nil, count:10),
//                .char      : [CharItem?](repeating:nil, count:10),
//                .vecInt    : [VecIntItem?](repeating:nil, count:10),
//                .vecDouble : [VecDoubleItem?](repeating:nil, count:10),
//                .vecString : [VecStringItem?](repeating:nil, count:10),
//                .vecBool   : [VecBoolItem?](repeating:nil, count:10)
//            ]
            for i in (0..<10) {
                interpreter.constants[.int]![i] = IntItem(randomInt(100_000))
                interpreter.constants[.double]![i] = DoubleItem(randomDouble(100_000.0))
                interpreter.constants[.string]![i] = StringItem(randomString(20))
                interpreter.constants[.char]![i] = CharItem(randomChar())
                interpreter.constants[.vecInt]![i] = VecIntItem(randomVecInt(100_000,20))
                interpreter.constants[.vecDouble]![i] = VecDoubleItem(randomVecDouble(100_000.0,20))
                interpreter.constants[.vecString]![i] = VecStringItem(randomVecString(20))
                interpreter.constants[.vecBool]![i] = VecBoolItem(randomVecBool(20))
//                var inputs: [PushInstruction:any Item] = [:]
                let inputName = "input\(i)"
                let input = PushInstruction(rawValue: inputName)!
                // TODO: add a random Item generator
                interpreter.inputs[input] = IntItem(77)
            }

        }
    
    }

    @Test func setRandomConstants() {
        RandomCode.setRandomConstants(in: inty)
        #expect(inty.constants[.int]!.count == 10)
        #expect(inty.constants[.int]!.compactMap({ $0 }).count == 10)
    }
        

    @Test(.disabled(if: Stress_Tests.disabledTests))
    func `random programs run`() {
        
        let start = Date.now

        for _ in (1...1000) {
            var p1 = RandomCode.randomPlushy(100)
            let program = Plushy.plushy2push(&p1)
            
            inty.load(program: program)
            RandomCode.setRandomConstants(in: inty)
            
            inty.run(stepLimit: 1000)
        }
        #expect( start.timeIntervalSinceNow.magnitude == 10)
    }

}
