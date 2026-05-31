//
//  Interpreter.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


struct InterpreterSettings {
    // https://github.com/lspector/propeller/blob/master/src/propeller/push/limits.cljc
    var stepLimit       : Int = 1000
    var stackCapacity   : Int = 1000
    var maxIntegerSize  : Int = 1_000_000
    var maxDoubleSize    : Double = 1_000_000.0
    var maxStringLength : Int = 1000
    var maxVectorLength : Int = 1000
    var maxCodePoints   : Int = 1000
    var maxCodeDepth    : Int = 1000
}


final class Interpreter {
    static func integrateInstructions(
        fromThese: [PushInstruction:Instruction],
        intoLanguage: inout [PushInstruction:Instruction]) {
        intoLanguage.merge(fromThese, uniquingKeysWith: { (first, _) in first })
    }
        
    static var language: [PushInstruction: Instruction] {
        var starter:[PushInstruction: Instruction] = [:]
//        integrateInstructions(fromThese: boolInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: charInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: combinatorInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: constantInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: execInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: doubleInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: inputInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: outputInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: intInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: stringInstructions, intoLanguage: &starter)
//        integrateInstructions(fromThese: vectorInstructions, intoLanguage: &starter)
        return starter
    }
    
    
    static let defaultSettings = InterpreterSettings()
    
    var behaviors: [PushInstruction: Instruction] = Interpreter.language
    var stacks: [PushStack: Deque<any Pushable>]
    var counter: Int = 0
    var inputs: [PushInstruction:any Pushable] = [:]
    var constants: [PushStack:[any Pushable]] = [.int:[], .double:[], .string:[],
                                             .char:[], .vecInt:[], .vecDouble:[],
                                             .vecString:[], .vecBool:[]]
    var config: InterpreterSettings = Interpreter.defaultSettings
    var program: [any Pushable] = []
    var printout: String = ""
    
    init(stacks: [PushStack : Deque<any Pushable>] = PushStack.emptyStacks()) {
        self.stacks = stacks
    }
        
    func pushItem(_ item: Router) {
        self.stacks[item.stack]?.prepend(item.item)
    }
    
    func load(inputs: [PushInstruction:any Pushable],
              stacks initial: [PushStack: [any Pushable]],
              program: [any Pushable]) {
        // settings reset
        self.counter = 0
        
        // inputs
        for (key,value) in inputs {
            self.inputs[key] = value
        }
        
        // initial stack items if any
        self.stacks = PushStack.emptyStacks()
        for (stack, items) in initial {
            self.stacks[stack]!.prepend(contentsOf: items)
        }
        
        // program to run
        self.program = program
        self.stacks[.exec]!.prepend(contentsOf: program)
    }
    
    
    
    func step() {
        if counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            let nextItem = stacks[.exec]!.popFirst()
            if nextItem is Code {
                let items = nextItem!.value as! [any Pushable]
                self.stacks[.exec]!.prepend(contentsOf: items)
            } else if nextItem!.value is PushInstruction {
                self.behaviors[nextItem!.value as! PushInstruction]?.act(on: self)
            } else {
                self.pushDefault(nextItem!)
            }
        }
        self.counter += 1
        // catch thrown errors from instructions
        // enforce config size limits
    }
    
    func run(inputs: [PushInstruction:any Pushable],
             stacks initial: [PushStack: [any Pushable]],
             program: [any Pushable],
             stepLimit: Int = Interpreter.defaultSettings.stepLimit) {
        
        load(inputs: inputs, stacks: initial, program: program)
        self.config.stepLimit = stepLimit
        while counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            self.step()
        }
    }
//    
//    func setConstantsRandomly() {
//        for _ in 1...10 {
//            self.constants[.int]!.append(PushItem.makeInt(RandomCode.randomInt(100)))
//            
//            self.constants[.double]!.append(
//                PushItem.makeDouble(RandomCode.randomDouble(100.0)))
//            
//            self.constants[.string]!.append(
//                PushItem.makeString(RandomCode.randomString(10)))
//            
//            self.constants[.char]!.append(
//                PushItem.makeChar(RandomCode.randomChar()))
//            
//            self.constants[.vecInt]!.append(
//                PushItem.makeVecInt(RandomCode.randomVecInt(100, 10)))
//            
//            self.constants[.vecBool]!.append(
//                PushItem.makeVecBool(RandomCode.randomVecBool(10)))
//            
//            self.constants[.vecDouble]!.append(
//                PushItem.makeVecDouble(RandomCode.randomVecDouble(100.0, 10)))
//            
//            self.constants[.vecString]!.append(
//                PushItem.makeVecString(RandomCode.randomVecString(10)))
//        }
//    }
}
//
extension Interpreter {
    
    func pushDefault(_ it: any Pushable) {
        switch it.value {
        case is Bool: self.stacks[.bool]?.prepend(it)
        case is Character: self.stacks[.char]?.prepend(it)
        case is Double: self.stacks[.double]?.prepend(it)
        case is Int: self.stacks[.int]?.prepend(it)
        case is String: self.stacks[.string]?.prepend(it)
        case is [Bool]: self.stacks[.vecBool]?.prepend(it)
        case is [Double]: self.stacks[.vecDouble]?.prepend(it)
        case is [Int]: self.stacks[.vecInt]?.prepend(it)
        case is [String]: self.stacks[.vecString]?.prepend(it)
        default : self.stacks[.error]?.prepend(it)
        }
    }
}


//
//    
//    func printState(history:Bool = false) -> String {
//        var state = ""
//        for (stack, items) in self.stacks.sorted(by: {$0.0 < $1.0}) {
//            if items.isEmpty { continue }
//            state += "\(stack): [ "
//            for i in items {
//                state += history ?
//                "\(i.hist())\n\t" :
//                "\(i.asString()) "
//            }
//            state += "]\n"
//        }
//        return state
//    }
//}
//
//extension Interpreter {
//    static func printInstructionCoverage() {
//        print()
//        print("Instruction Coverage:")
//        print("Defined: \(Interpreter.language.keys.count)")
//        print("Planned: \(PushInstruction.allCases.count)")
//    }
//}
//
//
//
