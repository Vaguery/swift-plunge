//
//  Interpreter+Decisions.swift
//  Plunge
//
//  The decision log's hooks into a run: conditionals, selections and counted
//  loops, logged and, for counterfactual runs, flipped or forced (#57; moved
//  out of Interpreter.swift 2026-11-20).
//

nonisolated extension Interpreter {
    /// Runs a conditional and logs its choice, if it took its arguments: the
    /// Boolean consumed is the sign it decided rather than refused.
    ///
    /// A decision named in `config.flippedDecisions` is taken the other way: the
    /// deciding Boolean is replaced, history and all, by its negation before the
    /// conditional runs.
    func logDecision(_ action: PushInstruction, _ behavior: Behavior) {
        var pending = Decision.pending(action, step: counter, stacks: stacks)
        let bools = stacks[.bool]?.count ?? 0
        let flips = pending != nil && config.flippedDecisions?.contains(decisionsMade) == true
        if flips, let top = stacks.item(at: 0, on: .bool) as? BoolItem {
            var negated = BoolItem(!top.value)
            negated.call = top.call
            stacks[.bool]![0] = negated
        }
        behavior.act(on: self)
        guard (stacks[.bool]?.count ?? 0) == bools - 1, pending != nil else { return }
        decisionsMade += 1
        pending?.flipped = flips
        if let pending { log(pending) }
    }

    /// Runs a key lookup or code-point run and logs its choice, when it has more
    /// than one thing it could do. A choice named in `config.forcedChoices` is
    /// forced: the deciding int, which the instruction reads and leaves, is
    /// replaced (history kept) by the forced option's for the instruction alone,
    /// and put back after it, so nothing else in the run sees the change.
    func logSelection(_ action: PushInstruction, _ behavior: Behavior) {
        guard let pending = Decision.pendingSelection(action, stacks: stacks) else {
            behavior.act(on: self)
            return
        }
        var chosen = pending.chosen
        var forced: IntItem?
        if let option = config.forcedChoices?[decisionsMade], pending.options.indices.contains(option),
           option != chosen {
            var replaced = IntItem(pending.options[option])
            replaced.call = pending.selector.call
            stacks[.int]![pending.at] = replaced
            chosen = option
            forced = replaced
        }
        behavior.act(on: self)
        if let forced, let left = stacks.item(at: pending.at, on: .int)?.exactly(IntItem.self),
           left.value == forced.value {
            stacks[.int]![pending.at] = pending.selector
        }
        log(Decision(step: counter, instruction: action, selector: pending.selector,
                                     options: pending.options, chosen: chosen, naming: pending.naming,
                                     forced: forced != nil))
        decisionsMade += 1
    }

    /// Runs a counted loop (`Decision.countedLoops`) and logs its count as a
    /// decision, when it has its arguments: the deciding int (the count, or a
    /// range's end) with its history, and the number of passes it will make. A
    /// count named in `config.forcedChoices` is forced to that many passes: the
    /// deciding int, which the loop consumes, is replaced by one that makes them,
    /// keeping its history.
    func logCount(_ action: PushInstruction, _ behavior: Behavior) {
        let range = action == .execDoRange
        guard let end = stacks.item(at: 0, on: .int)?.exactly(IntItem.self),
              stacks.item(at: 0, on: .code)?.exactly(CodeItem.self) != nil else {
            behavior.act(on: self)
            return
        }
        let origin = range ? stacks.item(at: 1, on: .int)?.exactly(IntItem.self) : nil
        let start = origin?.value
        if range && start == nil {
            behavior.act(on: self)
            return
        }
        func passes(_ value: Int) -> Int {
            guard let start else { return max(0, value) }
            return value == start ? 1 : abs(value - start)
        }
        var made = passes(end.value)
        var forced = false
        if let wanted = config.forcedChoices?[decisionsMade], wanted >= 0, wanted != made {
            var value = wanted
            if let start {
                // A range makes at least one pass; it keeps its direction.
                let direction = end.value < start ? -1 : 1
                value = start + direction * max(1, wanted)
            }
            var replaced = IntItem(value)
            replaced.call = end.call
            stacks[.int]![0] = replaced
            made = passes(value)
            forced = true
        }
        log(Decision(step: counter, instruction: action, count: end, passes: made,
                                     rangeStart: origin, forced: forced))
        decisionsMade += 1
        behavior.act(on: self)
    }

    /// Adds `decision` to the log, unless the log already holds
    /// `config.maxLoggedDecisions`: a logged decision keeps its deciding item,
    /// history and all, so a long loop's log is held to that many. Decisions past
    /// the limit still count as places (`decisionsMade`), so flips and forcing
    /// by place are unchanged.
    func log(_ decision: Decision) {
        guard let count = decisionLog?.count, count < config.maxLoggedDecisions else { return }
        decisionLog?.append(decision)
    }

    /// How many depths from the top a selection's options are probed at, every
    /// one; deeper, only the depth taken and the stack's bottom are.
    static let probedDepths = 64

    /// Whether structural steps should go through ``select(_:_:_:_:)``.
    var watchesSelections: Bool { decisionLog != nil || config.forcedChoices != nil }

    /// A selection's step: `step` run on `arguments` and `view`, with the choice
    /// logged when the depth (`arguments[0]`) could have done more than one thing,
    /// and forced to another option when `config.forcedChoices` names this place.
    ///
    /// The options are found by asking the step what each depth from 0 to the
    /// stack's count would do: depths are clamped into the stack, so no other
    /// depth does anything new. Neighboring depths that do the same thing are
    /// one option. Past ``probedDepths`` only the depth taken and the bottom are
    /// asked, so a deep stack's options are not all listed, but the one taken is.
    func select(_ name: PushInstruction, _ arguments: [any Item], _ view: StackView,
                _ step: ([any Item], StackView) -> StructuralStep) -> StructuralStep {
        guard Decision.depthSelections.contains(name), let depth = arguments.first?.exactly(IntItem.self) else {
            return step(arguments, view)
        }
        var options: [Int] = []
        var effects: [PositionEffect] = []
        var probe = arguments
        // Every depth near the top; past `probedDepths`, only the depth taken
        // and the bottom. Each probe's effect lists the positions it moves, so
        // probing every depth of a deep stack cost the square of its size.
        var depths = Array(0...min(view.count, Self.probedDepths - 1))
        for far in [min(max(depth.value, 0), view.count), view.count] where far > depths.last ?? 0 {
            depths.append(far)
        }
        for value in depths {
            probe[0] = IntItem(value)
            guard case .positions(let effect) = step(probe, view) else { return step(arguments, view) }
            if effects.last != effect {
                options.append(value)
                effects.append(effect)
            }
        }
        guard options.count > 1 else { return step(arguments, view) }
        var taken = options.lastIndex { $0 <= depth.value } ?? 0
        var forced = false
        if let option = config.forcedChoices?[decisionsMade], effects.indices.contains(option), option != taken {
            var replaced = IntItem(options[option])
            replaced.call = depth.call
            probe[0] = replaced
            taken = option
            forced = true
        } else {
            probe = arguments
        }
        log(Decision(step: counter, instruction: name, selector: depth, options: options,
                                     chosen: taken, forced: forced))
        decisionsMade += 1
        return step(probe, view)
    }
}
