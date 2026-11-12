//
//  Function Stack Behaviors.swift
//  Plunge
//
//  Instructions on functions themselves (2026-11-12): apply one to the stacks,
//  compose two, fill a hole, count the holes, and iterate one from a seed.
//
//  - **`functionApply`** runs the topmost function with an output on the
//    program's own values: it **takes** a filler for every hole from that hole's
//    stack, as the instruction itself would (the user's ruling), so a bare
//    `.intSubtract` applied to `a b` gives a − b. A stack short of fillers is a
//    missing argument. The application runs in a sandbox, its steps charged;
//    its result is the top of the function's output stack, and an application
//    that leaves nothing there refuses (`notFound`).
//  - **`functionCompose`**, written `f g .functionCompose`: g is the topmost
//    function with an output, f the next one down with a hole of that type;
//    the result is f after g, g's program in f's first such hole.
//  - **`functionFill`**: partial application. The topmost function with a hole
//    takes one item from its first hole's stack, which fills that hole wherever
//    it occurs, leaving a function with one hole fewer.
//  - **`functionArity`** reads the topmost function and counts its holes.
//  - **`functionIterate`**, `x n`: the topmost **step** function (a hole of its
//    own output type) applied n times from x; its other holes are read from
//    the run, as map's are.
//  - **`functionIterateUntil`**, written `x p f`: f the topmost step function,
//    p the topmost predicate on f's type below it; the orbit x, f(x), f(f(x)), …
//    up to and including the first value p holds for, as a vector (a string for
//    chars). Collatz in one instruction.
//
//  Results record the arguments in written order and the instruction; the
//  iterations add the fillers they read, cleared away as a query's are.
//

nonisolated extension Interpreter {

    /// Every stack a hole can take or read from.
    static let holeSourceStacks: [PushStack] = PushStack.allCases.filter { ![.exec, .error].contains($0) }

    /// Every stack a function's value can land on.
    static let anyValue: Produces = .alternatives(holeSourceStacks.map { [$0] })

    static func asFunction(_ item: any Item) -> FunctionItem { item.exactly(FunctionItem.self)! }

    /// `item` as a function, in a requirement: after a sieve misses, the planner
    /// still asks the requirements that follow, with a stand-in in the miss's place.
    static func maybeFunction(_ item: any Item) -> FunctionItem? { item.exactly(FunctionItem.self) }

    /// Whether `item` is a step function: a hole of its own output's type.
    static func isStep(_ item: any Item) -> Bool {
        guard let function = item.exactly(FunctionItem.self), let output = function.output else { return false }
        return function.holeCount(on: output) >= 1
    }

    /// `item` carrying `call`.
    static func stamped(_ item: any Item, _ call: [any Item]) -> any Item {
        if item is any ValueItem { return rebuilt(item, call: call) }
        var copy = item
        copy.call = call
        return copy
    }

    // MARK: - Apply

    static let functionApply_Behavior: Behavior = {
        let withOutput: Requirement = .takesFirst(.function) { candidate, _ in
            candidate.exactly(FunctionItem.self)?.output != nil
        }
        let fillers: [Requirement] = holeSourceStacks.map { stack in
            .takesMany(stack) { maybeFunction($0[0])?.holeCount(on: stack) ?? 0 }
        }
        return Behavior(.functionApply, requires: [withOutput] + fillers, tags: [.fallible],
                        behaviorClass: .operation, body: .applying { a, context in
            let function = asFunction(a[0])
            // Each stack's fillers arrive top first; deepest first, they are the
            // order the instruction itself takes them in.
            var supply: [PushStack: [any Item]] = [:], written: [any Item] = []
            var next = 1
            for stack in holeSourceStacks {
                let count = function.holeCount(on: stack)
                let taken = Array(a[next ..< next + count].reversed())
                supply[stack] = taken
                written += taken
                next += count
            }
            var used: [PushStack: Int] = [:]
            let filled: [(any Item)?] = function.holes.map { hole in
                defer { used[hole.stack, default: 0] += 1 }
                return supply[hole.stack]![used[hole.stack, default: 0]]
            }
            let application = Application(function: function, fixed: filled, read: [], counts: [])
            do throws(ApplicationFailure) {
                guard let output = function.output, let result = try call(application, [], context) else {
                    return refusal(.functionApply, Refusal("the function left nothing on its output stack",
                                                           kind: .notFound), context)
                }
                return [Router(output, stamped(result, context.recording(
                    written + [function, InstructionItem(.functionApply)])))]
            } catch {
                return refusal(.functionApply, error.reason, context)
            }
        }, produces: anyValue)
        .described("Applies the topmost function on `.function` with an output to the program's values, taking a "
                   + "filler for each hole from its stack as the instruction itself would (`a b` and a bare "
                   + "`.intSubtract` give a − b), and pushes its result; refuses when it leaves none.")
    }()

    // MARK: - Compose and fill

    /// Why `function` with `copies` copies of `insert` in one hole would be over
    /// the run's `maxItemWeight`, or nil. A hole can occur at several places, so
    /// repeated composition can double a body each time; this is known from the
    /// weights alone, so a result that would be refused is never built.
    static func tooHeavy(_ function: FunctionItem, _ copies: Int, copiesOf insert: any Item,
                         _ context: ReadContext) -> Refusal? {
        let (added, overflow) = copies.multipliedReportingOverflow(by: insert.weight)
        let total = overflow ? Int.max : function.weight.addingReportingOverflow(added).0
        guard overflow || total < 0 || total > context.maxItemWeight else { return nil }
        return Refusal("the result would weigh about \(overflow || total < 0 ? "more than \(Int.max)" : "\(total)"), "
                       + "over the limit of \(context.maxItemWeight)", kind: .sizeRefusal)
    }

    static let functionCompose_Behavior: Behavior = {
        let inner: Requirement = .takesFirst(.function) { candidate, _ in
            candidate.exactly(FunctionItem.self)?.output != nil
        }
        let outer: Requirement = .takesFirst(.function) { candidate, resolved in
            guard let stack = maybeFunction(resolved[0])?.output else { return false }
            return candidate.exactly(FunctionItem.self).map { $0.holeCount(on: stack) >= 1 } == true
        }
        return Behavior(.functionCompose, requires: [inner, outer], tags: [.fallible], behaviorClass: .operation,
                        body: .applying { a, context in
            let (g, f) = (asFunction(a[0]), asFunction(a[1]))
            let hole = f.holes.first { $0.stack == g.output }!
            if let why = tooHeavy(f, hole.positions.count, copiesOf: g, context) {
                return refusal(.functionCompose, why, context)
            }
            let composed = f.composed(after: g, call: context.recording([f, g, InstructionItem(.functionCompose)]))!
            return [Router(.function, composed)]
        }, produces: .results([.function]))
        .described("Composes: `f g .functionCompose`, g the topmost function with an output and f the next with a "
                   + "hole of that type, gives f after g, g's program in f's first such hole; refuses a result "
                   + "over the size limit, before building it.")
    }()

    static let functionFill_Behavior: Behavior = {
        let withHole: Requirement = .takesFirst(.function) { candidate, _ in
            candidate.exactly(FunctionItem.self)?.holes.isEmpty == false
        }
        let filler: [Requirement] = holeSourceStacks.map { stack in
            .takesMany(stack) { maybeFunction($0[0])?.holes.first?.stack == stack ? 1 : 0 }
        }
        return Behavior(.functionFill, requires: [withHole] + filler, tags: [.fallible], behaviorClass: .operation,
                        body: .applying { a, context in
            let (function, value) = (asFunction(a[0]), a[1])
            if let why = tooHeavy(function, function.holes[0].positions.count, copiesOf: value, context) {
                return refusal(.functionFill, why, context)
            }
            let filled = function.filling(firstHoleWith: value,
                                          call: context.recording([value, function, InstructionItem(.functionFill)]))!
            return [Router(.function, filled)]
        }, produces: .results([.function]))
        .described("Partial application: the topmost function with a hole takes the top item of its first hole's "
                   + "stack, which fills that hole wherever it occurs, leaving a function with one hole fewer; "
                   + "refuses a result over the size limit, before building it.")
    }()

    static let functionArity_Behavior =
        Behavior(.functionArity, requires: [.reads(.function)], tags: [], behaviorClass: .operation,
                 body: .values { a, recording in
            let function = asFunction(a[0])
            return [Router(.int, IntItem(function.holes.count, call: recording(Behavior.reading(
                [.function: 1], producing: .int, from: [function, InstructionItem(.functionArity)]))))]
        }, produces: .results([.int]))
        .described("Counts the holes of the top function, leaving it.")

    // MARK: - Iterate

    static let functionIterate_Behavior: Behavior = {
        let step: Requirement = .takesFirst(.function) { candidate, _ in isStep(candidate) }
        let seed: [Requirement] = holeSourceStacks.map { stack in
            .takesMany(stack) { maybeFunction($0[0])?.output == stack ? 1 : 0 }
        }
        return Behavior(.functionIterate, requires: [step, .takes(.int)] + seed, tags: [.fallible],
                        behaviorClass: .operation, body: .applying { a, context in
            let (function, count, start) = (asFunction(a[0]), a[1].exactly(IntItem.self)!.value, a[2])
            let stack = function.output!
            let application: Application
            switch prepare(function, .step, over: stack, context) {
            case .failure(let why): return refusal(.functionIterate, why, context)
            case .success(let ready): application = ready
            }
            guard count >= 0 else {
                return refusal(.functionIterate, Refusal("a negative count, \(count)"), context)
            }
            var value = start
            for _ in 0..<count {
                do throws(ApplicationFailure) {
                    value = try call(application, [value], context) ?? value
                } catch {
                    return refusal(.functionIterate, error.reason, context)
                }
            }
            return [Router(stack, stamped(value, context.recording(application.recorded(
                .functionIterate, collections: [start, a[1]], producing: stack))))]
        }, produces: anyValue, observes: fillerStacks)
        .described("Iterates: `x n .functionIterate` applies the topmost step function on `.function` (a hole of "
                   + "its own output's type) n times from x; its other holes are read from the run; refuses a "
                   + "negative n, or when filler runs short or steps run out.")
    }()

    static let functionIterateUntil_Behavior: Behavior = {
        let step: Requirement = .takesFirst(.function) { candidate, _ in isStep(candidate) }
        let predicate: Requirement = .takesFirst(.function) { candidate, resolved in
            guard let stack = maybeFunction(resolved[0])?.output,
                  let function = candidate.exactly(FunctionItem.self) else { return false }
            return fits(function, .filter, over: stack)
        }
        let seed: [Requirement] = holeSourceStacks.map { stack in
            .takesMany(stack) { maybeFunction($0[0])?.output == stack ? 1 : 0 }
        }
        return Behavior(.functionIterateUntil, requires: [step, predicate] + seed, tags: [.fallible],
                        behaviorClass: .operation, body: .applying { a, context in
            iteratedUntil(asFunction(a[0]), asFunction(a[1]), from: a[2], context)
        }, produces: mapResults, observes: fillerStacks)
        .described("The orbit: `x p f .functionIterateUntil`, f the topmost step function on `.function` and p the "
                   + "topmost predicate on its type below it, gives x, f(x), f(f(x)), … up to and including the "
                   + "first value p holds for, as a vector (a string of chars); refuses an orbit over the size limit "
                   + "or one that cannot be collected, or when filler runs short or steps run out.")
    }()

    /// `functionIterateUntil`'s orbit, or its refusal.
    static func iteratedUntil(_ step: FunctionItem, _ predicate: FunctionItem, from start: any Item,
                              _ context: ReadContext) -> [Router] {
        let instruction = PushInstruction.functionIterateUntil
        let stack = step.output!
        let stepping: Application, testing: Application
        switch (prepare(step, .step, over: stack, context), prepare(predicate, .filter, over: stack, context)) {
        case (.failure(let why), _), (_, .failure(let why)): return refusal(instruction, why, context)
        case (.success(let f), .success(let p)): (stepping, testing) = (f, p)
        }
        var orbit = [start], value = start
        do throws(ApplicationFailure) {
            while try !holds(testing, value, context) {
                guard orbit.count < IteratorItem.collectionLimit else {
                    return refusal(instruction, Refusal("the orbit passed \(IteratorItem.collectionLimit) values",
                                                        kind: .sizeRefusal), context)
                }
                value = try call(stepping, [value], context) ?? value
                orbit.append(value)
            }
        } catch {
            return refusal(instruction, error.reason, context)
        }
        // Both functions read their fillers from the tops of the same stacks, so
        // the crux pushes the deeper of the two reads on each stack, once.
        var counts: [PushStack: Int] = [:]
        for (key, value) in stepping.counts + testing.counts { counts[key] = max(counts[key] ?? 0, value) }
        let sorted = counts.sorted { $0.key.rawValue < $1.key.rawValue }.map { (key: $0.key, value: $0.value) }
        let read = sorted.flatMap { Array(context.items(of: $0.key).prefix($0.value).reversed()) }
        guard let made = collected(orbit, call: []), let resting = PushStack.defaultStack(for: made) else {
            return refusal(instruction, "an orbit of .\(stack) values is not a collection", context)
        }
        let recorded = context.recording(Behavior.reading(sorted: sorted, producing: resting,
                                                          from: read + [start, predicate, step,
                                                                        InstructionItem(instruction)]))
        return [Router(resting, collected(orbit, call: recorded)!)]
    }

    // MARK: - Functions as loop bodies
    //
    // A function's body runs as code: on the program's own stacks, no sandbox,
    // each hole simply an argument its instructions take from the stacks as they
    // run (a bare `.intAdd` looped n times sums the top n + 1 ints). That is the
    // meaning a hole has in argument position, as in every bare function; a hole
    // deep in a derived body is whatever its stack holds when that point runs.
    //
    // Each form rewrites itself into its code loop: the function goes back onto
    // `.function`, `codeFromFunction` turns it into its body on `.code`, and the
    // code loop runs that. So the step limit, the loop counters and folding are
    // the code loops' own, and the body, a block, returns to `.code` afterward as
    // every loop's does.

    static let codeFromFunction_Behavior =
        Behavior(.codeFromFunction, requires: [.takes(.function)], tags: [], behaviorClass: .operation,
                 body: .values { a, recording in
            let function = asFunction(a[0])
            return [Router(.code, CodeItem(function.value,
                                           call: recording([function, InstructionItem(.codeFromFunction)])))]
        }, produces: .results([.code]))
        .described("A function's body as a block, its holes left out: run, each hole is an argument its "
                   + "instructions take from the stacks.")

    /// `function` turned into its body on `.code`, then `loop` run over it, with
    /// `arguments` back on their stacks first, in written order.
    static func looped(_ loop: PushInstruction, _ function: any Item, after arguments: [any Item]) -> [Router] {
        [Router(.exec, InstructionItem(loop)), Router(.exec, InstructionItem(.codeFromFunction)),
         Router(.exec, function)] + arguments.reversed().map { Router(.exec, $0) }
    }

    static let functionDo_Behavior =
        Behavior.control(.functionDo, takes: [.function]) { a, _ in looped(.codeDo, a[0], after: []) }
        .described("Runs the top function's body as code, once: `f .functionDo` is `f .codeFromFunction .codeDo`.")

    static let functionDoTimes_Behavior =
        Behavior.control(.functionDoTimes, takes: [.int, .function], tags: [.looping]) { a, _ in
            looped(.execDoTimes, a[1], after: [a[0]])
        }
        .described("Repeats the top function's body as code: `n f .functionDoTimes` is "
                   + "`n f .codeFromFunction .execDoTimes`; the body then returns to `.code` as a block.")

    static let functionDoCount_Behavior =
        Behavior.control(.functionDoCount, takes: [.int, .function], tags: [.looping]) { a, _ in
            looped(.execDoCount, a[1], after: [a[0]])
        }
        .described("Counts with the top function's body as code: `n f .functionDoCount` is "
                   + "`n f .codeFromFunction .execDoCount`, pushing 0 to n − 1 before each pass.")

    static let functionDoRange_Behavior =
        Behavior.control(.functionDoRange, takes: [.int, .int, .function], tags: [.looping]) { a, _ in
            // `.int` arrives top first: a[0] the end, a[1] the start; written a b.
            looped(.execDoRange, a[2], after: [a[1], a[0]])
        }
        .described("Steps an index with the top function's body as code: `a b f .functionDoRange` is "
                   + "`a b f .codeFromFunction .execDoRange`.")

    static let functionWhile_Behavior =
        Behavior.control(.functionWhile, takes: [.bool, .function], tags: [.looping]) { a, _ in
            looped(.execWhile, a[1], after: [a[0]])
        }
        .described("Loops with the top function's body as code while the top bool is true: `p f .functionWhile` is "
                   + "`p f .codeFromFunction .execWhile`.")

    static let functionIf_Behavior =
        Behavior.control(.functionIf, takes: [.bool, .function, .function]) { a, _ in
            // Written `p then else`: the else function is on top (a[1]).
            let (condition, elseFunction, thenFunction) = (a[0], a[1], a[2])
            return [Router(.exec, InstructionItem(.execIf)), Router(.exec, InstructionItem(.codeFromFunction)),
                    Router(.exec, elseFunction), Router(.exec, InstructionItem(.codeFromFunction)),
                    Router(.exec, thenFunction), Router(.exec, condition)]
        }
        .described("Runs one of two functions' bodies as code: `p then else .functionIf` is `p then "
                   + ".codeFromFunction else .codeFromFunction .execIf`.")

    // MARK: - The family

    static let functionStackBehaviors: [PushInstruction: Behavior] = [
        .codeFromFunction: codeFromFunction_Behavior,
        .functionDo: functionDo_Behavior,
        .functionDoTimes: functionDoTimes_Behavior,
        .functionDoCount: functionDoCount_Behavior,
        .functionDoRange: functionDoRange_Behavior,
        .functionWhile: functionWhile_Behavior,
        .functionIf: functionIf_Behavior,
        .functionApply: functionApply_Behavior,
        .functionCompose: functionCompose_Behavior,
        .functionFill: functionFill_Behavior,
        .functionArity: functionArity_Behavior,
        .functionIterate: functionIterate_Behavior,
        .functionIterateUntil: functionIterateUntil_Behavior
    ]
}
