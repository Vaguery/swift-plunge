//
//  Crux Attribution.swift
//  PlungeTests
//
//  Which tokens of a program each result comes from, and the program "combed":
//  rebuilt as a sequence of its results' cruxes.
//
//  Every item a run leaves has a history, and its crux is that history written
//  as a program. Attribution maps a history back onto the program that ran: for
//  each result, the program tokens its history passes through. It needs nothing
//  new from the library:
//
//  1. Every token of the program, at every depth inside code blocks, is given a
//     history of one item, a plain copy of itself. Its value and its crux are
//     unchanged, but it is now a history node with an identity
//     (`CruxSharing.Key`), and that identity travels with it: onto a stack, into
//     a block and back out, into another item's history.
//  2. The program runs one step at a time. Before each step the next item on
//     `.exec` names the token being run; the push log (`Interpreter.pushLog`)
//     names every new history node the step made.
//  3. Each result's history is walked back. A node made at a step belongs to
//     that step's token; a tagged token belongs to itself.
//
//  Tagging changes nothing a run computes (checked over every program the
//  experiments run). The cost is about one and a half plain runs, and walking
//  every result back about as much again.
//
//  A tool for analysis, not part of the library: it reaches internals
//  (`pushLog`, `CruxSharing.key`) that the public API does not offer. The
//  experiments that use it are in this folder, off unless asked for.
//

import Foundation
@testable import Plunge

/// A program's tokens, numbered in preorder: each top-level token, then the
/// contents of a code block right after the block itself.
nonisolated struct TokenTable {
    /// Each token's address: its index at each level, outermost first.
    var paths: [[Int]] = []
    /// Each token as it was written.
    var items: [any Item] = []
    /// The enclosing block's number, or -1 at the top level.
    var parents: [Int] = []
    /// Tagged tokens, by the identity of their one-item history.
    var numbers: [CruxSharing.Key: Int] = [:]

    var count: Int { items.count }
}

nonisolated enum CruxAttribution {
    typealias Key = CruxSharing.Key

    // MARK: - Tagging

    /// The program with every token given a history of one item (a plain copy of
    /// itself), and the table that numbers them.
    static func tag(_ program: [any Item]) -> (program: [any Item], table: TokenTable) {
        var table = TokenTable()
        func tagged(_ item: any Item, path: [Int], parent: Int) -> any Item {
            let number = table.count
            table.paths.append(path)
            table.items.append(item)
            table.parents.append(parent)
            var token: any Item = item
            if let block = item.exactly(CodeItem.self) {
                token = CodeItem(block.value.enumerated().map { tagged($1, path: path + [$0], parent: number) })
            }
            var plain = token
            plain.call = []
            token.call = [plain]
            if let key = CruxSharing.key(token) { table.numbers[key] = number }
            return token
        }
        let program = program.enumerated().map { tagged($1, path: [$0], parent: -1) }
        return (program, table)
    }

    // MARK: - Running

    /// One attributed run.
    struct Run {
        let interpreter: Interpreter
        let table: TokenTable
        /// The token each step ran, or -1 for an item the program did not contain
        /// (an instruction a loop or a combinator put on `.exec`).
        var stepTokens: [Int] = []
        /// The step that made each history node pushed during the run.
        var nodeSteps: [Key: Int] = [:]
        /// Tokens taken off `.exec` at least once.
        var executed = Set<Int>()
        /// The first few thousand history nodes pushed, for their cruxes.
        var pushed: [any Item] = []
        var seconds = 0.0
    }

    static func run(_ program: [any Item], inputs: [PushInstruction: any Item],
                    constants: [PushInstruction: any Item], settings: InterpreterSettings) -> Run {
        let (tagged, table) = tag(program)
        let inty = Interpreter()
        inty.config = settings
        inty.config.recordsProvenance = true
        inty.config.maxCallWeight = 10_000_000
        inty.config.maxCallDepth = 1_000_000
        inty.load(inputs: inputs, constants: constants, program: tagged)
        var run = Run(interpreter: inty, table: table)
        inty.pushLog = []
        inty.recomputeLiveWeight()
        let clock = ContinuousClock(), start = clock.now
        while inty.counter < inty.config.stepLimit, let next = inty.stacks[.exec]!.first {
            let step = run.stepTokens.count
            let token = CruxSharing.key(next).flatMap { table.numbers[$0] } ?? -1
            if token >= 0 { run.executed.insert(token) }
            run.stepTokens.append(token)
            inty.pushLog!.removeAll(keepingCapacity: true)
            inty.step()
            for (_, item) in inty.pushLog! {
                guard let key = CruxSharing.key(item), table.numbers[key] == nil, run.nodeSteps[key] == nil else {
                    continue
                }
                run.nodeSteps[key] = step
                if run.pushed.count < 3_000 { run.pushed.append(item) }
            }
        }
        inty.pushLog = nil
        run.seconds = seconds(clock.now - start)
        return run
    }

    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    // MARK: - Walking back

    /// What one result's history passes through.
    struct Attribution {
        var tokens = Set<Int>()
        /// History nodes the push log never saw: made inside another item and
        /// never pushed alone. They inherit nothing, so their step is unknown.
        var unknownNodes = 0
        /// Stand-ins for histories cut short at the budget.
        var elided = 0
        /// Distinct history nodes walked.
        var nodes = 0
    }

    static func attribution(of root: any Item, in run: Run) -> Attribution {
        var result = Attribution()
        var seen = Set<Key>()
        var pending: [any Item] = [root]
        while let item = pending.popLast() {
            if let standIn = item.exactly(StandInItem.self) {
                if standIn.reason == .elided { result.elided += 1 }
                continue
            }
            appendContained(item, to: &pending)
            guard let key = CruxSharing.key(item), seen.insert(key).inserted else { continue }
            if let token = run.table.numbers[key] {
                result.tokens.insert(token)
                continue
            }
            result.nodes += 1
            if let step = run.nodeSteps[key] {
                if run.stepTokens[step] >= 0 { result.tokens.insert(run.stepTokens[step]) }
            } else {
                result.unknownNodes += 1
            }
            pending.append(contentsOf: item.call)
        }
        return result
    }

    /// The items a container holds as part of its value.
    static func appendContained(_ item: any Item, to pending: inout [any Item]) {
        if let block = item.exactly(CodeItem.self) {
            pending.append(contentsOf: block.value)
        } else if let function = item.exactly(FunctionItem.self) {
            pending.append(contentsOf: function.value)
        } else if let binding = item.exactly(BindingItem.self) {
            pending.append(binding.bound)
        } else if let iterator = item.exactly(IteratorItem.self) {
            pending.append(iterator.origin)
            if let destination = iterator.destination { pending.append(destination) }
            if let body = iterator.body { pending.append(body) }
        }
    }

    /// One item a run left, outside `.exec` and `.error`, with its attribution.
    struct Result {
        let stack: PushStack
        let depth: Int
        let item: any Item
        let attribution: Attribution
        var label: String { "\(stack)[\(depth)]" }
    }

    /// Every item the run left outside `.exec` and `.error`, top of each stack first.
    static func results(of run: Run) -> [Result] {
        PushStack.allStacks.filter { $0 != .exec && $0 != .error }.flatMap { stack in
            run.interpreter.stacks[stack]!.enumerated().map { depth, item in
                Result(stack: stack, depth: depth, item: item, attribution: attribution(of: item, in: run))
            }
        }
    }

    /// The results grouped into chunks: results whose token sets meet are one
    /// chunk. Each chunk is a list of indices into `results`; results with no
    /// token are in none.
    static func chunks(_ results: [Result]) -> [[Int]] {
        var owner = Array(results.indices)
        func find(_ i: Int) -> Int {
            var i = i
            while owner[i] != i { owner[i] = owner[owner[i]]; i = owner[i] }
            return i
        }
        var firstUser: [Int: Int] = [:]
        for (i, r) in results.enumerated() {
            for token in r.attribution.tokens {
                if let j = firstUser[token] { owner[find(i)] = find(j) } else { firstUser[token] = i }
            }
        }
        var groups: [Int: [Int]] = [:]
        for (i, r) in results.enumerated() where !r.attribution.tokens.isEmpty {
            groups[find(i), default: []].append(i)
        }
        return groups.values.sorted { $0[0] < $1[0] }
    }

    // MARK: - Combing

    /// One item of a flattened crux, with where it came from.
    struct Traced {
        let item: any Item
        /// The program token it came from, or -1 for an item the program did not
        /// contain (an instruction a loop put on `.exec`, or the inputs at load).
        let token: Int
        /// The step of the run that made it (for a literal, its last run before
        /// the value was used), or -1.
        let step: Int
    }

    /// `root`'s flattened crux (`CruxSharing.flattened`: every leaf in order, with
    /// no dup or yank to share a value), each item traced to its token and step.
    static func traced(_ root: any Item, in run: Run) -> [Traced] {
        var runs: [Int: [Int]] = [:]
        for (step, token) in run.stepTokens.enumerated() where token >= 0 { runs[token, default: []].append(step) }
        func lastRun(_ token: Int, before: Int) -> Int {
            guard let steps = runs[token] else { return -1 }
            if before < 0 { return steps.last! }
            return steps.last { $0 <= before } ?? steps.first!
        }
        func stepOf(_ item: any Item) -> Int? { CruxSharing.key(item).flatMap { run.nodeSteps[$0] } }
        var out: [Traced] = []
        // Pending work: an item, and the step of the node whose `call` holds it.
        var pending: [(item: any Item, parentStep: Int)] = [(root, stepOf(root) ?? -1)]
        while let (item, parentStep) = pending.popLast() {
            if let key = CruxSharing.key(item), let token = run.table.numbers[key] {
                // A program token: its one-item history is a plain copy of itself.
                out.append(Traced(item: item.call[0], token: token, step: lastRun(token, before: parentStep)))
            } else if item.call.isEmpty {
                // A leaf the parent's step made: its instruction, a stand-in, a count.
                let token = parentStep >= 0 ? run.stepTokens[parentStep] : -1
                out.append(Traced(item: item, token: token, step: parentStep))
            } else {
                let step = stepOf(item) ?? parentStep
                for child in item.call.reversed() { pending.append((child, step)) }
            }
        }
        return out
    }

    /// Runs `cruxes` in order on a fresh interpreter, each to its end before the
    /// next is added: `.exec` counts toward the memory guard, so loading them all
    /// at once can stop the run early. `.binding` is cleared after loading, since
    /// the pairs the interpreter binds from the inputs have cruxes of their own.
    static func rebuild(_ cruxes: [[any Item]], inputs: [PushInstruction: any Item],
                        constants: [PushInstruction: any Item], settings: InterpreterSettings) -> Interpreter {
        let redo = Interpreter()
        redo.config = settings
        redo.config.recordsProvenance = false
        redo.config.stepLimit = .max
        redo.load(inputs: inputs, constants: constants, program: [])
        redo.clear(.binding)
        for crux in cruxes {
            redo.place(contentsOf: crux, on: .exec)
            redo.run(stepLimit: redo.counter + max(1_000, crux.count * 50))
        }
        return redo
    }

    // MARK: - Cutting programs down

    /// The program with only the tokens `keep` accepts, and every block that holds
    /// one of them (with only those of its contents).
    static func sliced(_ program: [any Item], keep: (Int) -> Bool) -> [any Item] {
        var number = 0
        func walk(_ items: [any Item]) -> [any Item] {
            var out: [any Item] = []
            for item in items {
                let mine = number
                number += 1
                if let block = item.exactly(CodeItem.self) {
                    let inner = walk(block.value)
                    if keep(mine) { out.append(block) } else if !inner.isEmpty { out.append(CodeItem(inner)) }
                } else if keep(mine) {
                    out.append(item)
                }
            }
            return out
        }
        return walk(program)
    }

    /// The program without one token (and, for a block, its contents).
    static func deleting(_ program: [any Item], _ target: Int) -> [any Item] {
        var number = 0
        func walk(_ items: [any Item]) -> [any Item] {
            var out: [any Item] = []
            for item in items {
                let mine = number
                number += 1
                if let block = item.exactly(CodeItem.self) {
                    let inner = walk(block.value)
                    if mine != target { out.append(CodeItem(inner)) }
                } else if mine != target {
                    out.append(item)
                }
            }
            return out
        }
        return walk(program)
    }

    // MARK: - Reading results

    /// What a run leaves, outside `.exec` and `.error`, rendered.
    static func finalState(_ inty: Interpreter) -> [PushStack: [String]] {
        var state: [PushStack: [String]] = [:]
        for stack in PushStack.allStacks where stack != .exec && stack != .error {
            state[stack] = inty.stacks[stack]!.map { String($0.pretty().prefix(300)) }
        }
        return state
    }

    /// A crux with every input written `$in` and every constant `$c` followed by
    /// its type: the abstract crux, in which inputs, and constants of one type,
    /// are interchangeable. Nil when the crux reads no input.
    static func abstractShape(_ crux: [any Item]) -> (shape: String, constants: Int)? {
        let constantTypes: Set = ["int", "double", "string", "char", "vecInt", "vecDouble", "vecString", "vecBool"]
        var readsInput = false, constants = 0
        let words = crux.map { item -> String in
            guard let name = item.exactly(InstructionItem.self)?.value.rawValue else { return item.pretty() }
            if name.hasPrefix("input"), name.dropFirst(5).allSatisfy(\.isNumber) { readsInput = true; return "$in" }
            if let last = name.last, last.isNumber, constantTypes.contains(String(name.dropLast())) {
                constants += 1
                return "$c:" + name.dropLast()
            }
            return item.pretty()
        }
        return readsInput ? (words.joined(separator: " "), constants) : nil
    }

    /// The class of a token: its instruction's behavior class, "block" or "literal".
    static func kind(of item: any Item) -> String {
        if let instruction = item.exactly(InstructionItem.self)?.value {
            return Interpreter.language[instruction].map { "\($0.behaviorClass)" } ?? "unknown"
        }
        return item is CodeItem ? "block" : "literal"
    }
}
