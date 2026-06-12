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
    var stepLimit       : Int    = 1000
    var stackCapacity   : Int    = 1000
    var maxIntegerSize  : Int    = 1_000_000
    var maxDoubleSize   : Double = 1_000_000.0
    var maxStringLength : Int    = 1000
    var maxVectorLength : Int    = 1000
    var maxCodePoints   : Int    = 1000
    var maxCodeDepth    : Int    = 1000
}


final class Interpreter {
    
    static func integrateBehaviors(
        fromThese: [PushInstruction:Behavior],
        intoLanguage: inout [PushInstruction:Behavior]) {
        intoLanguage.merge(fromThese, uniquingKeysWith: { (first, _) in first })
    }
        
    static var language: [PushInstruction: Behavior] {
        var starter:[PushInstruction: Behavior] = [:]
        
        integrateBehaviors(fromThese: boolBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: charBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: combinatorBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: constantBehaviors, intoLanguage: &starter)
//        integrateBehaviors(fromThese: execBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: doubleBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: inputBehaviors, intoLanguage: &starter)
//        integrateBehaviors(fromThese: outputBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: intBehaviors, intoLanguage: &starter)
//        integrateBehaviors(fromThese: stringBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecIntBehaviors, intoLanguage: &starter)
        return starter
    }
    
    
    static let defaultSettings = InterpreterSettings()
    
    var behaviors: [PushInstruction: Behavior] = Interpreter.language
    var stacks: [PushStack: Deque<any Item>]
    var counter: Int = 0
    var inputs: [PushInstruction:any Item] = [:]
    var constants: [PushStack:[(any Item)?]] = [
        .int       : [IntItem?](repeating:nil, count:10),
        .double    : [DoubleItem?](repeating:nil, count:10),
        .string    : [StringItem?](repeating:nil, count:10),
        .char      : [CharItem?](repeating:nil, count:10),
        .vecInt    : [VecIntItem?](repeating:nil, count:10),
        .vecDouble : [VecDoubleItem?](repeating:nil, count:10),
        .vecString : [VecStringItem?](repeating:nil, count:10),
        .vecBool   : [VecBoolItem?](repeating:nil, count:10)
    ]
    var config: InterpreterSettings = Interpreter.defaultSettings
    var program: [any Item] = []
    var printout: String = ""
    
    init(stacks: [PushStack : Deque<any Item>] = PushStack.emptyStacks()) {
        self.stacks = stacks
    }
        
    func pushItem(_ item: Router) {
        self.stacks[item.stack]?.prepend(item.item)
    }
    
    func load(inputs: [PushInstruction:any Item],
              stacks initial: [PushStack: [any Item]],
              program: [any Item]) {
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
            if nextItem is CodeItem {
                let items = (nextItem as! CodeItem).value
                self.stacks[.exec]!.prepend(contentsOf: items)
            } else if nextItem is InstructionItem {
                let action = (nextItem as! InstructionItem).value
                self.behaviors[action]!.act(on: self)
            } else {
                self.pushDefault(nextItem!)
            }
        }
        self.counter += 1
        // catch thrown errors from instructions
        // enforce config size limits
    }
    
    func run(inputs: [PushInstruction:any Item],
             stacks initial: [PushStack: [any Item]],
             program: [any Item],
             stepLimit: Int = Interpreter.defaultSettings.stepLimit) {
        
        load(inputs: inputs, stacks: initial, program: program)
        self.config.stepLimit = stepLimit
        while counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            self.step()
        }
    }

//    func createEmptyConstantTables() {
////        self.constants[.int] = [(any Pushable)?](repeating:nil, count:10)
//        self.constants[.double]!.reserveCapacity(10)
//        self.constants[.string]!.reserveCapacity(10)
//        self.constants[.char]!.reserveCapacity(10)
//        self.constants[.vecInt]!.reserveCapacity(10)
//        self.constants[.vecBool]!.reserveCapacity(10)
//        self.constants[.vecDouble]!.reserveCapacity(10)
//        self.constants[.vecString]!.reserveCapacity(10)
//    }
}


extension Interpreter {
    
    func pushDefault(_ it: any Item) {
        switch it {
        case is BoolItem: self.stacks[.bool]?.prepend(it)
        case is CharItem: self.stacks[.char]?.prepend(it)
        case is DoubleItem: self.stacks[.double]?.prepend(it)
        case is IntItem: self.stacks[.int]?.prepend(it)
        case is StringItem: self.stacks[.string]?.prepend(it)
        case is VecBoolItem: self.stacks[.vecBool]?.prepend(it)
        case is VecDoubleItem: self.stacks[.vecDouble]?.prepend(it)
        case is VecIntItem: self.stacks[.vecInt]?.prepend(it)
        case is VecStringItem: self.stacks[.vecString]?.prepend(it)
        default : self.stacks[.error]?.prepend(it)
        }
    }
}


extension Interpreter {
    static func reportBehaviorCoverage() -> String {
        var result = "Behavior Coverage:\n"
        result += "Defined: \(Interpreter.language.keys.count)\n"
        result += "Planned: \(PushInstruction.allCases.count)"
        return result
    }
}



