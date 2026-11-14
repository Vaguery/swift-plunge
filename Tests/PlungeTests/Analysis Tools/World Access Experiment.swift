//
//  World Access Experiment.swift
//  PlungeTests
//
//  How readily can random code use a world's verbs, given to it as ready-made
//  Push, with no new instruction?
//
//  A mock world, a water-pouring puzzle, is played by the harness. After every
//  step it looks at the top of `.code`: a block shaped like a message,
//  `( "pour" 2 1 )` (a verb's name, then its int arguments), is consumed, applied
//  to the world, and a query's answer is pushed onto `.int`. That is the
//  proposed `.world` channel, simulated: the world watches a stack, takes each
//  new message, and replies.
//
//  The verbs are given to the program as message templates built from ordinary
//  instructions: `"pour" .stringQuote .intQuote .codeConcat .intQuote
//  .codeConcat` leaves `( "pour" i j )`, taking i and j from `.int`. Four
//  conditions:
//
//  - **none:** no verbs given; a message can only arise by chance.
//  - **function:** each verb a function on `.function`, its holes the ints it
//    takes (`.functionApply`, `.functionDo` and the function loops can use it).
//  - **binding:** each verb's template bound on `.binding` under a key from 20 up
//    (`.bindingDeref` runs it in place).
//  - **code:** each verb's template as a block on `.code` (`.codeDo` runs it).
//
//  Off unless `PUSH_WORLD_ACCESS` is set to the number of programs per
//  condition. Run:
//
//      PUSH_WORLD_ACCESS=2000 swift test -c release -Xswiftc -enable-testing \
//          --filter WorldAccessExperiment
//

import Foundation
@testable import Plunge
import Testing

/// Three jugs, an unlimited source, a sink, and a target vessel to fill to a goal.
nonisolated struct JugWorld {
    let capacities: [Int]
    let goal: Int
    var volumes: [Int]
    var target = 0
    var actions = 0, queries = 0

    init(capacities: [Int], goal: Int) {
        self.capacities = capacities
        self.goal = goal
        volumes = capacities.map { _ in 0 }
    }

    /// A verb: its name, how many ints it takes, and whether it answers.
    struct Verb {
        let name: String, arguments: Int, answers: Bool
    }

    static let verbs = [
        Verb(name: "fill", arguments: 1, answers: false), Verb(name: "empty", arguments: 1, answers: false),
        Verb(name: "pour", arguments: 2, answers: false), Verb(name: "pourTarget", arguments: 1, answers: false),
        Verb(name: "volume", arguments: 1, answers: true), Verb(name: "capacity", arguments: 1, answers: true),
        Verb(name: "target", arguments: 0, answers: true), Verb(name: "goal", arguments: 0, answers: true)
    ]

    func jug(_ i: Int) -> Int { ((i % capacities.count) + capacities.count) % capacities.count }

    /// Applies a message, if it is one: the verb's name and the right number of
    /// ints. Returns the answer for a query, an empty list for an action, and
    /// nil for anything that isn't a message.
    mutating func handle(_ block: CodeItem) -> [any Item]? {
        guard let name = block.value.first?.exactly(StringItem.self)?.value,
              let verb = Self.verbs.first(where: { $0.name == name }),
              block.value.count == verb.arguments + 1 else { return nil }
        let args = block.value.dropFirst().compactMap { $0.exactly(IntItem.self)?.value }
        guard args.count == verb.arguments else { return nil }
        if verb.answers {
            queries += 1
            return [IntItem(answer(name, args))]
        }
        actions += 1
        act(name, args)
        return []
    }

    func answer(_ name: String, _ args: [Int]) -> Int {
        switch name {
        case "volume": volumes[jug(args[0])]
        case "capacity": capacities[jug(args[0])]
        case "target": target
        default: goal
        }
    }

    mutating func act(_ name: String, _ args: [Int]) {
        switch name {
        case "fill": volumes[jug(args[0])] = capacities[jug(args[0])]
        case "empty": volumes[jug(args[0])] = 0
        case "pour":
            let (a, b) = (jug(args[0]), jug(args[1]))
            let moved = min(volumes[a], capacities[b] - volumes[b])
            volumes[a] -= moved
            volumes[b] += moved
        default:
            target += volumes[jug(args[0])]
            volumes[jug(args[0])] = 0
        }
    }

    // MARK: - The verbs as Push

    /// A verb's message template: its name quoted, then each argument quoted and
    /// joined on.
    static func template(_ name: String, arguments: Int) -> [any Item] {
        var body: [any Item] = [StringItem(name), InstructionItem(.stringQuote)]
        for _ in 0..<arguments { body += [InstructionItem(.intQuote), InstructionItem(.codeConcat)] }
        return body
    }

    /// A verb as a function: holes for its ints, each before its `.intQuote`.
    static func function(_ name: String, arguments: Int) -> FunctionItem {
        let holes = (0..<arguments).map { FunctionItem.Hole(stack: .int, positions: [2 + 2 * $0]) }
        return FunctionItem(body: template(name, arguments: arguments), holes: holes, output: .code)
    }
}

@Suite
struct WorldAccessExperiment {

    nonisolated static let programs: Int? =
        ProcessInfo.processInfo.environment["PUSH_WORLD_ACCESS"].flatMap(Int.init)

    enum Condition: String, CaseIterable { case none, function, binding, code }

    /// What one condition's programs did.
    struct Tally {
        var programs = 0, calling = 0, calls = 0, actions = 0, queries = 0, verbsUsed = 0
        var usingFour = 0, solved = 0, closest = 0
        var origins: [String: Int] = [:]
        var verbCounts: [String: Int] = [:]
        /// For verbs on `.function`: how many function instructions ran, and how
        /// deep the shallowest verb was each time.
        var functionSteps = 0, verbDepthTotal = 0, verbsGoneSteps = 0
    }

    /// One puzzle: the jugs' capacities and the goal for the target vessel.
    struct Puzzle {
        let capacities: [Int], goal: Int
    }

    static let puzzles = [Puzzle(capacities: [3, 5, 8], goal: 4), Puzzle(capacities: [2, 7, 11], goal: 9),
                          Puzzle(capacities: [4, 9, 13], goal: 6)]

    @Test(.enabled(if: WorldAccessExperiment.programs != nil))
    func `random code reaching a world's verbs`() throws {
        let instructions = Runner().definedInstructions
        let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
        var lines = ["World access over \(Self.programs ?? 0) random programs per condition, 150 tokens, 1,000 steps",
                     ""]
        for condition in Condition.allCases {
            var tally = Tally()
            for seed in 1...UInt64(Self.programs ?? 0) {
                let made = DualModeStress.makeCase(seed: seed, instructions: instructions, loopers: loopers)
                let puzzle = Self.puzzles[Int(seed % UInt64(Self.puzzles.count))]
                Self.run(Array(made.program.prefix(150)), constants: made.constants, puzzle: puzzle,
                         condition: condition, into: &tally)
            }
            lines += Self.report(condition, tally)
        }
        let report = lines.joined(separator: "\n")
        let dir = ProcessInfo.processInfo.environment["PUSH_ATTRIBUTION_DIR"].map { URL(fileURLWithPath: $0) }
            ?? URL.temporaryDirectory
        try report.write(to: dir.appending(path: "world-access.txt"), atomically: true, encoding: .utf8)
        print(report)
    }

    /// The verbs, placed where `condition` puts them.
    static func given(_ condition: Condition) -> [PushStack: [any Item]] {
        let verbs = JugWorld.verbs
        switch condition {
        case .none: return [:]
        case .function: return [.function: verbs.map { JugWorld.function($0.name, arguments: $0.arguments) }]
        case .binding:
            return [.binding: verbs.enumerated().map { i, verb in
                BindingItem(key: 20 + i, bound: CodeItem(JugWorld.template(verb.name, arguments: verb.arguments)))
            }]
        case .code: return [.code: verbs.map { CodeItem(JugWorld.template($0.name, arguments: $0.arguments)) }]
        }
    }

    static func run(_ program: [any Item], constants: [PushInstruction: any Item], puzzle: Puzzle,
                    condition: Condition, into tally: inout Tally) {
        var world = JugWorld(capacities: puzzle.capacities, goal: puzzle.goal)
        var inputs: [PushInstruction: any Item] = [.input3: IntItem(puzzle.goal)]
        for (slot, capacity) in zip([PushInstruction.input0, .input1, .input2], puzzle.capacities) {
            inputs[slot] = IntItem(capacity)
        }
        let inty = Interpreter()
        var settings = InterpreterSettings()
        settings.stepLimit = 1_000
        settings.maxLiveWeight = 256_000
        inty.config = settings
        inty.load(inputs: inputs, constants: constants, stacks: given(condition), program: program)
        inty.recomputeLiveWeight()
        var used = Set<String>()
        var calls = 0
        while inty.counter < settings.stepLimit, let next = inty.stacks[.exec]!.first {
            let origin = next.exactly(InstructionItem.self).map { ".\($0.value.rawValue)" } ?? "a literal"
            if condition == .function { noteVerbDepth(next, inty, &tally) }
            inty.step()
            // The world reads the newest block, once per step.
            guard let top = inty.stacks[.code]!.first?.exactly(CodeItem.self),
                  let name = top.value.first?.exactly(StringItem.self)?.value,
                  let reply = world.handle(top) else { continue }
            _ = inty.takeFirst(from: .code)
            for item in reply { inty.push(item, to: .int) }
            calls += 1
            used.insert(name)
            tally.origins[origin, default: 0] += 1
            tally.verbCounts[name, default: 0] += 1
        }
        tally.programs += 1
        tally.calls += calls
        if calls > 0 { tally.calling += 1 }
        tally.actions += world.actions
        tally.queries += world.queries
        tally.verbsUsed += used.count
        if used.count >= 4 { tally.usingFour += 1 }
        if world.target == puzzle.goal { tally.solved += 1 }
        if world.target > 0, abs(world.target - puzzle.goal) <= 1 { tally.closest += 1 }
    }

    static let verbFunctions = Set(JugWorld.verbs.map { JugWorld.function($0.name, arguments: $0.arguments).pretty() })

    /// Before a function instruction runs: how deep is the shallowest verb on `.function`?
    static func noteVerbDepth(_ next: any Item, _ inty: Interpreter, _ tally: inout Tally) {
        guard let name = next.exactly(InstructionItem.self)?.value.rawValue,
              name.hasPrefix("function") || name.hasSuffix("Map") || name.hasSuffix("Filter") else { return }
        tally.functionSteps += 1
        if let depth = inty.stacks[.function]!.firstIndex(where: { verbFunctions.contains($0.pretty()) }) {
            tally.verbDepthTotal += depth
        } else {
            tally.verbsGoneSteps += 1
        }
    }

    static func report(_ condition: Condition, _ t: Tally) -> [String] {
        func pct(_ a: Int) -> String { String(format: "%.1f%%", 100 * Double(a) / Double(max(t.programs, 1))) }
        func per(_ a: Int) -> String { String(format: "%.2f", Double(a) / Double(max(t.programs, 1))) }
        let origins = t.origins.sorted { $0.value > $1.value }.prefix(8).map { "\($0.key) \($0.value)" }
        let verbs = t.verbCounts.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }
        return [
            "── verbs given as \(condition.rawValue)",
            "  programs that called the world: \(pct(t.calling)); calls a program \(per(t.calls)) "
                + "(actions \(per(t.actions)), queries \(per(t.queries))); verbs used a program \(per(t.verbsUsed)); "
                + "four or more verbs: \(pct(t.usingFour))",
            "  target filled to the goal: \(pct(t.solved)); within one of it: \(pct(t.closest))",
            "  function instructions run: \(per(t.functionSteps)) a program; shallowest verb's mean depth then "
                + String(format: "%.1f", Double(t.verbDepthTotal) / Double(max(t.functionSteps - t.verbsGoneSteps, 1)))
                + "; no verb left: \(t.verbsGoneSteps) of \(t.functionSteps)",
            "  calls by verb: \(verbs.joined(separator: ", "))",
            "  the step that completed each message: \(origins.joined(separator: ", "))",
            ""
        ]
    }
}
