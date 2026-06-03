////
////  RandomCode.swift
////  PropellerWithStructs
////
////  Created by William Tozier on 6/3/26.
////
//
//
//struct RandomCode {
//    static func randomInstruction() -> PushInstruction {
//        Interpreter.language.keys.randomElement()!
//    }
//    
//    static func randomInt(_ scale:Int) -> Int {
//        Int.random(in: -scale...scale)
//    }
//    
//    static func randomFloat(_ scale:Double) -> Double {
//        Double.random(in: -scale...scale)
//    }
//    
//    static func randomChar() -> Character {
//        let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
//        return choices.randomElement()!
//    }
//    
//    static func randomString(_ len: Int) -> String {
//        let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
//        var result = ""
//        let length = Int.random(in: 1...len)
//        for _ in 1...length {
//            result.append(choices.randomElement()!)
//        }
//        return result
//    }
//    
//    static func randomVecString(_ len: Int) -> [String] {
//        var result = [String]()
//        let length = Int.random(in: 1...len)
//        for _ in 1...length {
//            result.append(randomString(len))
//        }
//        return result
//    }
//    
//    static func randomVecInt(_ scale:Int, _ len: Int) -> [Int] {
//        var result = [Int]()
//        let length = Int.random(in: 1...len)
//        for _ in 1...length {
//            result.append(randomInt(scale))
//        }
//        return result
//    }
//    
//    static func randomVecFloat(_ scale:Double, _ len: Int) -> [Double] {
//        var result = [Double]()
//        let length = Int.random(in: 0..<len)
//        for _ in 0..<length {
//            result.append(randomFloat(scale))
//        }
//        return result
//    }
//    
//    static func randomVecBool(_ len: Int) -> [Bool] {
//        var result = [Bool]()
//        let length = Int.random(in: 0..<len)
//        for _ in 0..<length {
//            result.append(Bool.random())
//        }
//        return result
//    }
//    
//    static func randomConstant() -> PushInstruction {
//        let stacks:[PushStack] = [.char, .float, .int, .string, .vecBool, .vecInt, .vecFloat, .vecString]
//        let stack = stacks.randomElement()!
//        return PushInstruction(rawValue: ("\(stack)\(Int.random(in: 0..<10))"))!
//    }
//    
//
//        
//    static func randomInput(_ range:Int = 10) -> PushInstruction {
//        let name = "input\(Int.random(in: 0..<range))"
//        return PushInstruction(rawValue: name)!
//    }
//    
//    static func randomPlushy(items: Int,
//                      intScale: Int = 100,
//                      floatScale: Double = 100.0,
//                      collectionMax: Int = 10) -> [Any] {
//        var result:[Any] = []
//        for _ in 0..<items {
//            switch Int.random(in: 0..<20) {
//            case 0: result.append(PlushyControl.close)
//            case 1: result.append(PlushyControl.open)
//            case 2...4: result.append(randomInput())
//            case 5...10: result.append(randomConstant())
//            default: result.append(randomInstruction())
//            }
//        }
//        return result
//    }
//    
//}
