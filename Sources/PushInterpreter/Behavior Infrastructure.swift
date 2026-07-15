//
//  Behavior.swift
//  PushInterpreter
//
//  Created by William Tozier on 5/30/26.
//

import DequeModule
import Foundation


nonisolated class Behavior: @unchecked Sendable {
    // @unchecked: Behavior is non-final (BehaviorWithSideEffects subclasses it),
    // so Sendable cannot be checked automatically. All stored state is immutable
    // (`let`) and Sendable and the stored closures are `@Sendable`, so a single
    // shared instance is safe to run from many interpreters/tasks at once.
    let name: PushInstruction
    let parameters: [PushStack]
    var needs: [PushStack: Int] {
        var result = [PushStack: Int]()
        for v in parameters {
            result[v, default:0] += 1
        }
        return result
    }
    let transformer: @Sendable ([any Item]) -> [Router]


    init(_ label: PushInstruction, takes: [PushStack], fxn: @escaping @Sendable ([any Item]) -> [Router]) {
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


    /// Pops one item per parameter, in order, and returns them — or `nil` when
    /// the interpreter can't satisfy every stack demand. Returning the result
    /// (instead of mutating a shared `collector`) is what lets one shared
    /// `Behavior` instance run from many interpreters without racing.
    func gather(from interpreter: Interpreter) -> [any Item]? {
        guard self.isSatisfied(by: interpreter) else { return nil }
        var collected = [any Item]()
        collected.reserveCapacity(self.parameters.count)
        for p in self.parameters {
            collected.append(interpreter.stacks[p]!.popFirst()!)
        }
        return collected
    }


    func distribute(to interpreter: Interpreter, items: [Router]) {
        for i in items {
            interpreter.push(i.item, to: i.stack)
        }
    }


    /// The single seam subclasses vary: pure behaviors run their `transformer`,
    /// while `BehaviorWithSideEffects` mutates the interpreter directly. Keeping
    /// this apart from `act` lets the surrounding pipeline — arg-gathering,
    /// distribution, and future Interpreter-mode hooks — be written just once.
    func computeResults(from arguments: [any Item], on interpreter: Interpreter) -> [Router] {
        self.transformer(arguments)
    }


    final func act(on interpreter: Interpreter) {
        guard let arguments = self.gather(from: interpreter) else {
            let mistakes = [Router(.error, ErrorItem("\(self.name) missing args"))]
            self.distribute(to: interpreter, items: mistakes)
            return
        }
        self.distribute(
            to: interpreter,
            items: self.computeResults(from: arguments, on: interpreter)
        )
    }
}


// subclass for behaviors that manipulate the Interpreter state more than pop/push
nonisolated class BehaviorWithSideEffects : Behavior, @unchecked Sendable {
    // restated from Behavior: this subclass adds a stored `let directModifier`,
    // which is itself `@Sendable` and immutable, so the type stays safe to share.
    let directModifier: @Sendable (inout Interpreter, [any Item]) -> [Router]

    init(_ label: PushInstruction, takes: [PushStack], modifier: @escaping @Sendable (inout Interpreter, [any Item]) -> [Router]) {
        self.directModifier = modifier
        super.init(label, takes: takes, fxn: {_ in return []})
    }

    override func computeResults(from arguments: [any Item], on interpreter: Interpreter) -> [Router] {
        var mutableInterpreter = interpreter
        return directModifier(&mutableInterpreter, arguments)
    }
}


nonisolated extension Behavior {
    static func netContingency(of items:(any Item)...) -> Bool {
        return items.map({$0.isContingent}).contains(true)
    }


    /// The `call` for one of several results a Behavior puts on a single stack —
    /// provenance law 5 (Items.swift).
    ///
    /// `producedAt` is the result's position in the Router order, `of` is how
    /// many of this Behavior's results land on `stack`, and `from` is the source
    /// that produces them all. Because `distribute` prepends Routers one at a
    /// time, the first produced ends up deepest, so surfacing it takes
    /// `total - 1 - producedAt` pops — counted from the END of the results, not
    /// from the production order.
    ///
    /// The pops are recorded as ordinary items in the returned `call`, which is
    /// why `crux()` needs no special case for multi-result instructions: it
    /// walks the array and each element speaks for itself. The topmost result
    /// needs no discard and gets `source` unchanged.
    static func selecting(
        _ producedAt: Int,
        of total: Int,
        on stack: PushStack,
        from source: [any Item]
    ) -> [any Item] {
        let pops = total - 1 - producedAt
        guard pops > 0 else { return source }
        return source + [
            IntItem(pops),
            InstructionItem(stack.popItemsInstruction),
        ]
    }
}
