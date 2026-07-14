//
//  RandomCode.swift
//  PushInterpreterTests
//
//  Random program/value generators for the slow acceptance tests. Extracted
//  from Stress Tests so any acceptance test can share them. Test-only scaffolding
//  (the real search process owns genome generation), so it may reach into
//  interpreter internals via `@testable`.
//

import Foundation
@testable import PushInterpreter

nonisolated enum RandomCode {

    // A STABLE instruction pool: `Dictionary.keys` iterates in a per-process
    // random order, so drawing from it (even with a seeded RNG) is not
    // reproducible. Sorting by rawValue fixes the order.
    static let allInstructions: [PushInstruction] =
        Interpreter.language.keys.sorted { $0.rawValue < $1.rawValue }

    static func randomInstruction() -> PushInstruction {
        allInstructions.randomElement(using: &fuzzRNG)!
    }

    static func randomInt(_ scale: Int) -> Int {
        Int.random(in: -scale...scale, using: &fuzzRNG)
    }

    static func randomDouble(_ scale: Double) -> Double {
        Double.random(in: -scale...scale, using: &fuzzRNG)
    }

    static func randomChar() -> Character {
        let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return choices.randomElement(using: &fuzzRNG)!
    }

    static func randomString(_ len: Int) -> String {
        let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var result = ""
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 1...length {
            result.append(choices.randomElement(using: &fuzzRNG)!)
        }
        return result
    }

    static func randomVecString(_ len: Int) -> [String] {
        var result = [String]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 1...length {
            result.append(randomString(len))
        }
        return result
    }

    static func randomVecInt(_ scale: Int, _ len: Int) -> [Int] {
        var result = [Int]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 1...length {
            result.append(randomInt(scale))
        }
        return result
    }

    static func randomVecDouble(_ scale: Double, _ len: Int) -> [Double] {
        var result = [Double]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 0..<length {
            result.append(randomDouble(scale))
        }
        return result
    }

    static func randomVecBool(_ len: Int) -> [Bool] {
        var result = [Bool]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 0..<length {
            result.append(Bool.random(using: &fuzzRNG))
        }
        return result
    }

    static func randomConstant() -> PushInstruction {
        let stacks: [PushStack] = [.char, .double, .int, .string, .vecBool, .vecInt, .vecDouble, .vecString]
        let stack = stacks.randomElement(using: &fuzzRNG)!
        return PushInstruction(rawValue: ("\(stack)\(Int.random(in: 0..<10, using: &fuzzRNG))"))!
    }

    static func randomInput(_ range: Int = 10) -> PushInstruction {
        let name = "input\(Int.random(in: 0..<range, using: &fuzzRNG))"
        return PushInstruction(rawValue: name)!
    }

    static func randomGenomeStuff() -> Any {
        return switch Int.random(in: 0..<20, using: &fuzzRNG) {
        case 0: PlushyControl.close
        case 1: PlushyControl.open
        case 2...6: randomInput()
        case 7...11: randomConstant()
        default: randomInstruction()
        }
    }

    // do not need CodeBlock because of Plushy Open and Close

    static func randomPlushy(_ items: Int) -> [Any] {
        var result: [Any] = []
        for _ in 0..<items {
            result.append(randomGenomeStuff())
        }
        return result
    }

    // TODO: pass in argument for biasing types sampled
    static func randomPushItem() -> any Item {
        switch Int.random(in: 0..<30, using: &fuzzRNG) {
        case 0: return IntItem(randomInt(100_000))
        case 1: return DoubleItem(randomDouble(100_000.0))
        case 2: return StringItem(randomString(20))
        case 3: return CharItem(randomChar())
        case 4: return VecIntItem(randomVecInt(100_000, 20))
        case 5: return VecBoolItem(randomVecBool(20))
        case 6: return VecDoubleItem(randomVecDouble(100_000.0, 20))
        case 7: return VecStringItem(randomVecString(20))
        case 8...10:
            let plush = RandomCode.randomPlushy(Int.random(in: 1..<20, using: &fuzzRNG))
            return CodeItem(Plushy.plushy2push(plush))
        case 11...20: return InstructionItem(PushInstruction(rawValue: "input\(Int.random(in: 0..<10, using: &fuzzRNG))")!)
        default: return InstructionItem(randomInstruction())
        }
    }

    static func setRandomConstants(in interpreter: Interpreter) {
        func token(_ name: String) -> PushInstruction { PushInstruction(rawValue: name)! }
        for i in (0..<10) {
            interpreter.constants[token("int\(i)")] = IntItem(randomInt(100_000))
            interpreter.constants[token("double\(i)")] = DoubleItem(randomDouble(100_000.0))
            interpreter.constants[token("string\(i)")] = StringItem(randomString(20))
            interpreter.constants[token("char\(i)")] = CharItem(randomChar())
            interpreter.constants[token("vecInt\(i)")] = VecIntItem(randomVecInt(100_000, 20))
            interpreter.constants[token("vecDouble\(i)")] = VecDoubleItem(randomVecDouble(100_000.0, 20))
            interpreter.constants[token("vecString\(i)")] = VecStringItem(randomVecString(20))
            interpreter.constants[token("vecBool\(i)")] = VecBoolItem(randomVecBool(20))
            let inputName = "input\(i)"
            let input = PushInstruction(rawValue: inputName)!
            // TODO: add a random Item generator
            interpreter.inputs[input] = randomPushItem()
        }
    }

    // TODO: pass in argument for biasing types sampled
    static func setRandomInputs(in interpreter: Interpreter) {
        for k in interpreter.inputs.keys {
            interpreter.inputs[k] = randomPushItem()
        }
    }
}
