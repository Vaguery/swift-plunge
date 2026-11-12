//
//  BehaviorIOSurvey.swift
//  PlungeTests
//
//  A map of what every Behavior reads and writes. Inputs are
//  declared (`requirements`); outputs are not, since a Behavior's results are
//  `Router`s computed at run time. So this measures them: every instruction is
//  driven many times on varied, seeded stacks, and two layers are recorded apart:
//
//   1. **The body**: the Routers the Behavior returns (stack, item type, how
//      many), its own errors, and any direct writes (`BehaviorWithSideEffects`).
//   2. **The push gate**: what `Interpreter.push` then does with each Router,
//      landing it or refusing it at a size cap or `maxStackDepth`.
//
//  Starvation (a plan that comes up short) is a third thing, decided before the
//  body runs; it is counted but kept out of both.
//
//  Writes `behavior-io-survey.md` (summary) and `behavior-io-table.tsv` (one row
//  per instruction) to the temporary directory. Flip `disabled` to run.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct BehaviorIOSurvey {

    nonisolated static let disabled = true
    nonisolated static let trials = 150

    // MARK: - Random stack contents

    struct Sampler {
        var rng: SeededRNG

        mutating func pick<T>(_ options: [T]) -> T { options.randomElement(using: &rng)! }
        mutating func chance(_ odds: Double) -> Bool { Double.random(in: 0..<1, using: &rng) < odds }

        mutating func int() -> Int {
            chance(0.7) ? Int.random(in: -6...12, using: &rng)
                : pick([0, 100, 1_000, 999_999, -1_000, Int.max, Int.min])
        }
        mutating func double() -> Double {
            chance(0.7) ? pick([0, 1, -1, 0.5, 2.5, -3.75]) : pick([1e10, -1e300, 1e300, 1e-300])
        }
        mutating func string() -> String {
            chance(0.05) ? String(repeating: "x", count: 995)
                : pick(["", "a", "ab", "hello world", "a b  c", "Zé!"])
        }
        mutating func length() -> Int { chance(0.05) ? 995 : pick([0, 1, 2, 3, 5]) }
        mutating func instruction() -> PushInstruction { pick(Array(Interpreter.language.keys)) }

        mutating func code() -> CodeItem {
            if chance(0.04) { return CodeItem((0..<990).map { IntItem($0) }) }
            switch Int.random(in: 0..<6, using: &rng) {
            case 0: return CodeItem([])
            case 1: return CodeItem([IntItem(int())])
            case 2: return CodeItem([BoolItem(true), InstructionItem(.boolNot)])
            case 3: return CodeItem([IntItem(2), IntItem(3), InstructionItem(.intAdd)])
            case 4: return CodeItem([CodeItem([IntItem(3)]), StringItem("s")])
            default:
                let count = Int.random(in: 1...4, using: &rng)
                return CodeItem((0..<count).map { _ in InstructionItem(instruction()) })
            }
        }

        mutating func iterator() -> IteratorItem {
            let body: CodeItem? = chance(0.5) ? CodeItem([IntItem(1)]) : nil
            switch Int.random(in: 0..<5, using: &rng) {
            case 0: return IteratorItem(kind: .counting(stride: 1), origin: IntItem(0), destination: IntItem(5),
                                        body: body, emits: chance(0.5))
            case 1: return IteratorItem(kind: .elements(into: nil), origin: VecIntItem([1, 2, 3]), body: body,
                                        emits: true)
            case 2: return IteratorItem(kind: .letters, origin: StringItem("abc"), body: body, emits: true)
            case 3: return IteratorItem(kind: .words, origin: StringItem("a bc d"), body: body, emits: true)
            default: return IteratorItem(kind: .elements(into: nil), origin: VecStringItem(["p", "q"]), body: body,
                                         emits: true)
            }
        }

        mutating func item(for stack: PushStack) -> any Item {
            switch stack {
            case .bool: BoolItem(chance(0.5))
            case .int: IntItem(int())
            case .double: DoubleItem(double())
            case .char: CharItem(pick(Array("aZ 0!é")))
            case .string: StringItem(string())
            case .code: code()
            case .iterator: iterator()
            case .binding: BindingItem(key: int(), bound: chance(0.5) ? IntItem(int()) : code())
            case .exec: execItem()
            case .error: ErrorItem("seeded")
            default: vector(for: stack)
            }
        }

        mutating func execItem() -> any Item {
            if chance(0.5) { return code() }
            return InstructionItem(instruction())
        }

        mutating func vector(for stack: PushStack) -> any Item {
            switch stack {
            case .vecBool: VecBoolItem((0..<length()).map { _ in chance(0.5) })
            case .vecInt: VecIntItem((0..<length()).map { _ in int() })
            case .vecDouble: VecDoubleItem((0..<length()).map { _ in double() })
            default: VecStringItem((0..<length()).map { _ in pick(["", "a", "bc"]) })
            }
        }

        /// An interpreter with 0–7 items on every stack (mostly 2–7).
        mutating func interpreter() -> Interpreter {
            let inty = Interpreter()
            for stack in PushStack.allCases {
                let depth = chance(0.1) ? 0 : Int.random(in: 2...7, using: &rng)
                for _ in 0..<depth { inty.stacks[stack]!.append(item(for: stack)) }
            }
            return inty
        }
    }

    // MARK: - Observation

    /// What one instruction did across its trials.
    struct Record {
        var trials = 0
        var starved = 0
        /// Body signatures (sorted `stack:Type` Routers), errors included.
        var signatures: [String: Int] = [:]
        /// Body signatures with every error removed, for trials that returned
        /// something other than errors.
        var resultSignatures: [String: Int] = [:]
        var errorAlone = 0
        var errorWithResults = 0
        var errorKinds: [String: Int] = [:]
        var errorSamples: Set<String> = []
        var emptyResults = 0
        var directWrites: [String: Int] = [:]
        var passThrough = 0
        var refusals: [String: Int] = [:]
        var landed = 0
    }

    static func typeName(_ item: any Item) -> String {
        String(describing: type(of: item)).replacing("Item", with: "")
    }

    static func refusalCategory(_ text: String) -> String {
        for cap in ["maxVectorLength", "maxStringLength", "maxCodePoints", "maxCodeDepth", "maxItemWeight",
                    "maxStackDepth", "INVARIANT"] where text.contains(cap) { return cap }
        return String(text.prefix(40))
    }

    static func counts(_ inty: Interpreter) -> [PushStack: Int] {
        Dictionary(uniqueKeysWithValues: PushStack.allCases.map { ($0, inty.stacks[$0]!.count) })
    }

    func observe(_ name: PushInstruction, _ behavior: Behavior, sampler: inout Sampler, into record: inout Record) {
        let inty = sampler.interpreter()
        withFuzzSeed(UInt64(record.trials)) { RandomCode.setRandomConstants(in: inty) }
        record.trials += 1
        let planner = Planner(for: inty)
        guard case .ready(let arguments, let claims) = planner.plan(behavior.requirements) else {
            record.starved += 1
            return
        }
        planner.commit(claims)
        let before = Self.counts(inty)
        let routers = behavior.computeResults(from: arguments, on: inty)
        for (stack, count) in Self.counts(inty) where count != before[stack] {
            let change = count - before[stack]!
            record.directWrites[".\(stack) \(change > 0 ? "+" : "")\(change)", default: 0] += 1
        }
        noteBody(routers, arguments: arguments, into: &record)
        for router in routers { push(router, on: inty, into: &record) }
    }

    func noteBody(_ routers: [Router], arguments: [any Item], into record: inout Record) {
        let all = routers.map { ".\($0.stack):\(Self.typeName($0.item))" }.sorted()
        record.signatures[all.joined(separator: " "), default: 0] += 1
        let errors = routers.filter { $0.stack == .error }
        let results = routers.filter { $0.stack != .error }
        if routers.isEmpty { record.emptyResults += 1 }
        if !results.isEmpty {
            record.resultSignatures[results.map { ".\($0.stack):\(Self.typeName($0.item))" }.sorted()
                .joined(separator: " "), default: 0] += 1
        }
        if !errors.isEmpty { if results.isEmpty { record.errorAlone += 1 } else { record.errorWithResults += 1 } }
        for error in errors {
            if let item = error.item as? ErrorItem {
                record.errorKinds["\(item.kind)", default: 0] += 1
                if record.errorSamples.count < 4 { record.errorSamples.insert(String(item.value.prefix(70))) }
            }
        }
        if results.contains(where: { router in arguments.contains { $0.isEqual(to: router.item) } }) {
            record.passThrough += 1
        }
    }

    func push(_ router: Router, on inty: Interpreter, into record: inout Record) {
        let target = inty.stacks[router.stack]!.count
        let errors = inty.stacks[.error]!.count
        inty.push(router.item, to: router.stack)
        if router.stack != .error, inty.stacks[router.stack]!.count == target,
           inty.stacks[.error]!.count > errors, let refusal = inty.stacks[.error]!.first as? ErrorItem {
            record.refusals[Self.refusalCategory(refusal.value), default: 0] += 1
        } else {
            record.landed += 1
        }
    }

    // MARK: - The survey

    @Test(.disabled(if: disabled)) func `survey every behavior's outputs`() throws {
        var sampler = Sampler(rng: SeededRNG(seed: 41))
        var records: [PushInstruction: Record] = [:]
        for (name, behavior) in Interpreter.language.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            var record = Record()
            for _ in 0..<Self.trials { observe(name, behavior, sampler: &sampler, into: &record) }
            records[name] = record
        }
        let dir = FileManager.default.temporaryDirectory
        try BehaviorIOReport(records: records).summary()
            .write(to: dir.appending(path: "behavior-io-survey.md"), atomically: true, encoding: .utf8)
        try BehaviorIOReport(records: records).table()
            .write(to: dir.appending(path: "behavior-io-table.tsv"), atomically: true, encoding: .utf8)
        print("behavior I/O survey written to \(dir.path())")
    }
}
