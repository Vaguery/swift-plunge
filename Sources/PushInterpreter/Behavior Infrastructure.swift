//
//  Instructions.swift
//  PropellerWithStructs
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


class Behavior {
    var name: PushInstruction
    var parameters: [PushStack]
    var needs: [PushStack: Int] {
        var result = [PushStack: Int]()
        for v in parameters {
            result[v, default:0] += 1
        }
        return result
    }
    var collector: [any Item] = []
    var isMissingArgs: Bool = false
    var transformer: ([any Item]) -> [Router]
    var results: [Router] = []
    
    
    init(_ label: PushInstruction, takes: [PushStack], fxn: @escaping ([any Item]) -> [Router]) {
        self.name = label
        self.parameters = takes
        self.transformer = fxn
    }
    
    
    func isSatisfied(by interpreter: Interpreter) -> Bool {
        for (k,v) in self.needs {
            if (interpreter.stacks[k]?.count ?? 0) < v { return false }
        }
        return true
    }
    
    
    func reset() {
        self.collector.removeAll()
        self.results.removeAll()
        self.isMissingArgs = false
    }
    
    
    // will not work if isSatisfied == false
    func gather(from interpreter: Interpreter) {
        if self.isSatisfied(by: interpreter) {
            for p in self.parameters {
                let item = interpreter.stacks[p]?.popFirst()
                self.collector.append(item!)
                self.isMissingArgs = false
            }
        } else {
            self.isMissingArgs = true
        }
    }
    
    
    func transform(on interpreter: Interpreter) {
        self.results = self.transformer(self.collector)
    }
    
    
    func distribute(to interpreter: Interpreter, items: [Router]) {
        for i in items {
            interpreter.stacks[i.stack]?.prepend(i.item)
        }
    }
    
    
    func act(on interpreter: Interpreter) {
        self.gather(from: interpreter)
        if self.isMissingArgs {
            let mistakes = [Router(.error, ErrorItem("« WARNING: \(self.name) missing args»"))]
            self.distribute(to: interpreter, items: mistakes)
        } else {
            transform(on: interpreter)
            distribute(to: interpreter, items: self.results)
        }
        self.reset()
    }
}


// subclass for behaviors that manipulate the Interpreter state more than pop/push
class BehaviorWithSideEffects : Behavior {
    var target: Interpreter? = nil
    var directModifier: (inout Interpreter, [any Item]) -> [Router]
    
    init(_ label: PushInstruction, takes: [PushStack], modifier: @escaping (inout Interpreter, [any Item]) -> [Router]) {
        self.directModifier = modifier
        super.init(label, takes: takes, fxn: {_ in return []})
    }
    
    override func act(on interpreter: Interpreter) {
        self.gather(from: interpreter)
        if self.isMissingArgs {
            let mistakes = [Router(.error, ErrorItem("« WARNING: \(self.name) missing args»"))]
            self.distribute(to: interpreter, items: mistakes)
        } else {
            var mutableInterpreter = interpreter
            self.results = directModifier(&mutableInterpreter, self.collector)
            distribute(to: interpreter, items: self.results)
        }
        self.reset()
    }
}


extension Behavior {
    static func netContingency(of items:(any Item)...) -> Bool {
        return items.map({$0.isContingent}).contains(true)
    }
}
