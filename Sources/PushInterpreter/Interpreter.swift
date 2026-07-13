//
//  Interpreter.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


nonisolated struct InterpreterSettings: Sendable, Codable {
    // Loosely after https://github.com/lspector/propeller/blob/master/src/propeller/push/limits.cljc
    // Numeric magnitude caps are intentionally omitted: Int behaviors use
    // checked (…ReportingOverflow) arithmetic and Double behaviors reject
    // non-finite results, so neither can trap or grow memory unbounded.
    var stepLimit       : Int = 1_000
    var maxStackDepth   : Int = 10_000
    var maxStringLength : Int = 1_000
    var maxVectorLength : Int = 1_000
    var maxCodePoints   : Int = 1_000
    var maxCodeDepth    : Int = 1_000
    // Total recursive content (Item.weight) allowed in a single pushed item.
    // Supplements the per-dimension caps above to bound nested content — a
    // vector of long strings, or code whose leaves are large — that the
    // count-only caps cannot see.
    var maxItemWeight   : Int = 100_000
}


nonisolated final class Interpreter {
    
    static func integrateBehaviors(
        fromThese: [PushInstruction:Behavior],
        intoLanguage: inout [PushInstruction:Behavior]) {
        intoLanguage.merge(fromThese, uniquingKeysWith: { (first, _) in first })
    }
        
    /// Built exactly once, on first access, and shared by every `Interpreter`.
    /// Safe to share because `Behavior`s hold no per-invocation mutable state
    /// (see `Behavior.act`); this replaces the former per-instance rebuild.
    static let language: [PushInstruction: Behavior] = {
        var starter:[PushInstruction: Behavior] = [:]

        integrateBehaviors(fromThese: boolBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: charBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: combinatorBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: codeBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: constantBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: execBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: doubleBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: inputBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: outputBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: intBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: stringBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecBoolBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecDoubleBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecIntBehaviors, intoLanguage: &starter)
        integrateBehaviors(fromThese: vecStringBehaviors, intoLanguage: &starter)
        return starter
    }()
    
    
    static let defaultSettings = InterpreterSettings()
    
    var behaviors: [PushInstruction: Behavior] = Interpreter.language
    var stacks: [PushStack: Deque<any Item>]
    var counter: Int = 0
    var inputs: [PushInstruction:any Item] = [:]
    // Bound constant values, keyed by their constant instruction (e.g. `.int3`),
    // symmetric with `inputs`. A missing key means the constant is unassigned;
    // the constant behavior emits an ErrorItem for that case at runtime, so no
    // pre-seeding of nil slots is needed.
    var constants: [PushInstruction: any Item] = [:]
    var config: InterpreterSettings = Interpreter.defaultSettings
    var program: [any Item] = []
    var printout: String = ""
    // Use AnyRecorder for type erasure of Recorder generic type
    var recorders: [String: AnyRecorder] = [:]
    var recorderNames: [String] {
        recorders.keys.sorted()
    }
    
    init(stacks: [PushStack : Deque<any Item>] = PushStack.emptyStacks()) {
        self.stacks = stacks
    }
    
    init(program: [any Item]) {
        self.stacks = PushStack.emptyStacks()
        self.counter = 0
        self.recorders = [:]
    }
        
    /// The single validated entry point for pushing an item onto a stack.
    /// Every stack except `.exec` is homogeneous, so pushing an item a stack
    /// does not accept can only mean a mis-tagged `Router` (a programming bug).
    /// Trap immediately rather than corrupt the stack and defer the failure to
    /// some later `as!` in an unrelated Behavior.
    func push(_ item: any Item, to stack: PushStack) {
        // Refuse an oversized push at the boundary: an item too large by itself,
        // or one that would exceed the stack's depth, is replaced by an
        // ErrorItem on .error while the surrounding instruction's other results
        // push normally. .error (and the planned .memory) are exempt so overflow
        // reports can always land.
        if stack.enforcesSizeLimits {
            if let message = self.overflow(of: item) {
                self.stacks[.error]?.prepend(ErrorItem(message))
                return
            }
            if (self.stacks[stack]?.count ?? 0) >= config.maxStackDepth {
                self.stacks[.error]?.prepend(
                    ErrorItem(".\(stack) is full at maxStackDepth \(config.maxStackDepth)")
                )
                return
            }
        }
        self.requireAccepts(item, on: stack)
        self.stacks[stack]?.prepend(item)
    }

    /// Enforces the homogeneity invariant for any stack write. Every stack
    /// except `.exec` accepts a single Item type, so a rejected item can only
    /// mean a mis-tagged `Router` (or mis-typed setup) — a programming bug that
    /// should trap at its source, not corrupt the stack for a later `as!`.
    func requireAccepts(_ item: any Item, on stack: PushStack) {
        guard stack.accepts(item) else {
            fatalError(
                "Type mismatch: \(type(of: item)) pushed to .\(stack) stack"
            )
        }
    }

    func pushItem(_ item: Router) {
        self.push(item.item, to: item.stack)
    }
    
    func load(inputs: [PushInstruction:any Item] = [:],
              constants: [PushInstruction:any Item] = [:],
              stacks initial: [PushStack: [any Item]] = [:],
              program: [any Item] = [],
              recorders: [AnyRecorder] = []) {
        // settings reset
        self.counter = 0

        // inputs and constants (both keyed by instruction token)
        for (key,value) in inputs {
            self.inputs[key] = value
        }
        loadConstants(constants)

        // initial stack items if any
        self.stacks = PushStack.emptyStacks()
        for (stack, items) in initial {
            for item in items { self.requireAccepts(item, on: stack) }
            self.stacks[stack]!.prepend(contentsOf: items)
        }
        
        // program to run
        self.program = program
        self.stacks[.exec]!.prepend(contentsOf: program)
        
        for r in recorders {
            self.recorders[r.name] = r
        }
    }
    
    func record() {
        for key in recorders.keys {
            recorders[key]?.record(interpreter: self)
        }
    }

    func unwrapCodeItem(code:CodeItem) {
        let items = code.value
        var result = [any Item]()

        for idx in (0..<items.count) {
            var copy = items[idx]
            copy.isContingent = Behavior.netContingency(of: code, copy)
            result.append(copy)
        }
        self.stacks[.exec]!.prepend(contentsOf: result)
    }

    func step() {
        if counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            let nextItem = stacks[.exec]!.popFirst()
            if nextItem is CodeItem {
                unwrapCodeItem(code: nextItem as! CodeItem)
            } else if nextItem is InstructionItem {
                let action = (nextItem as! InstructionItem).value
                if let behavior = self.behaviors[action] {
                    behavior.act(on: self)
                } else {
                    // an enumerated instruction with no registered behavior
                    // (e.g. planned-but-unimplemented) must not crash the loop
                    self.push(
                        ErrorItem("\(action) is an unknown instruction"),
                        to: .error
                    )
                }
            } else {
                self.pushDefault(nextItem!)
            }
        }
        self.record()
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
    
    func run(stepLimit: Int = Interpreter.defaultSettings.stepLimit) {
        while counter < config.stepLimit && !stacks[.exec]!.isEmpty {
            self.step()
        }
    }
    
    func reset() {
        self.counter = 0
        self.stacks = PushStack.emptyStacks()
        for r in self.recorders.keys {
            recorders[r]!.reset()
        }
    }
    
}


nonisolated extension Interpreter {
    
    func pushDefault(_ it: any Item) {
        switch it {
        case is BoolItem: self.push(it, to: .bool)
        case is CharItem: self.push(it, to: .char)
        case is DoubleItem: self.push(it, to: .double)
        case is IntItem: self.push(it, to: .int)
        case is StringItem: self.push(it, to: .string)
        case is VecBoolItem: self.push(it, to: .vecBool)
        case is VecDoubleItem: self.push(it, to: .vecDouble)
        case is VecIntItem: self.push(it, to: .vecInt)
        case is VecStringItem: self.push(it, to: .vecString)
        default : self.push(it, to: .error)
        }
    }
}


nonisolated extension Interpreter {
    static func reportBehaviorCoverage() -> String {
        var result = "Behavior Coverage:\n"
        result += "Defined: \(Interpreter.language.keys.count)\n"
        result += "Planned: \(PushInstruction.allCases.count)\n"
        let done = Set(Interpreter.language.keys)
        let needed = Set(PushInstruction.allCases)
        let missing = needed.subtracting(done)
        result += "Missing:\n\(missing)\n"
        return result
    }
}

