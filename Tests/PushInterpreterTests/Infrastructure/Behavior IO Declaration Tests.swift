//
//  Behavior IO Declaration Tests.swift
//  PushInterpreterTests
//
//  Every Behavior declares what it produces (`Produces`, Roadmap #41). These
//  drive each one on varied, seeded stacks (the `BehaviorIOSurvey` sampler) and
//  check that what it returns stays inside what it declares, so the language's
//  input-output map is a property of the definitions that running confirms.
//

@testable import PushInterpreter
import Testing

@Suite
struct BehaviorIODeclarationTests {

    static let trials = 20

    /// The stacks of `routers`, sorted, so a declared list compares as a multiset.
    static func stacks(_ routers: [Router]) -> [PushStack] {
        routers.map(\.stack).sorted { $0.rawValue < $1.rawValue }
    }

    static func sorted(_ stacks: [PushStack]) -> [PushStack] {
        stacks.sorted { $0.rawValue < $1.rawValue }
    }

    static func counts(_ inty: Interpreter) -> [PushStack: Int] {
        Dictionary(uniqueKeysWithValues: PushStack.allCases.map { ($0, inty.stacks[$0]!.count) })
    }

    /// Whether `part` is a sub-multiset of `whole`.
    static func isSubmultiset(_ part: [PushStack], of whole: [PushStack]) -> Bool {
        var remaining = whole
        for stack in part {
            guard let index = remaining.firstIndex(of: stack) else { return false }
            remaining.remove(at: index)
        }
        return true
    }

    /// What `routers` would deliver if run to the end on an otherwise empty
    /// interpreter: the stacks that grew.
    static func delivered(by routers: [Router]) -> Set<PushStack> {
        let inty = Interpreter()
        for router in routers { inty.push(router.item, to: router.stack) }
        inty.run(stepLimit: 5_000)
        return Set(PushStack.allCases.filter { ![.exec, .iterator].contains($0) && !inty.stacks[$0]!.isEmpty })
    }

    /// Why `results` (the non-error Routers) fall outside `produces`, or nil if
    /// they do not.
    static func violation(_ results: [Router], of produces: Produces) -> String? {
        let got = stacks(results)
        switch produces {
        case .results(let declared):
            return got == sorted(declared) ? nil : "gave \(got), declared \(declared)"
        case .alternatives(let options):
            return options.contains { sorted($0) == got } ? nil : "gave \(got), declared one of \(options)"
        case .deferred(let stack):
            guard results.count == 1, results[0].stack == .exec,
                  PushStack.defaultStack(for: results[0].item) == stack
            else { return "gave \(got), declared a deferred .\(stack)" }
            return nil
        case .input:
            return got == [.exec] ? nil : "gave \(got), declared an input on .exec"
        case .delivery(let stack):
            guard got.allSatisfy({ [.exec, .iterator].contains($0) }) else { return "gave \(got), declared a loop" }
            let landed = delivered(by: results)
            return landed.isSubset(of: [stack]) ? nil : "delivered to \(landed), declared .\(stack)"
        case .positions:
            // A loop that copies (`DupTimes`) hands back an iterator and its play.
            return got.allSatisfy { [.exec, .iterator].contains($0) } ? nil : "gave \(got), declared positions"
        case .continuation:
            return nil
        case .printout:
            return got.isEmpty ? nil : "gave \(got), declared the printout"
        }
    }

    /// Every instruction, sorted, so each runs as its own case and in parallel.
    static let instructions = Interpreter.language.keys.sorted { $0.rawValue < $1.rawValue }

    /// Runs `name`'s Behavior `trials` times on sampled stacks and checks each
    /// outcome: results inside the declaration, an error only from a `.fallible`
    /// Behavior (a refusal handing back at most its own arguments), and no stack
    /// changed in place except by a structural rule (its own) or control.
    @Test(arguments: instructions)
    func `results stay inside what the Behavior declares`(_ name: PushInstruction) {
        let behavior = Interpreter.language[name]!
        let index = Self.instructions.firstIndex(of: name)!
        var sampler = BehaviorIOSurvey.Sampler(rng: SeededRNG(seed: 41 + UInt64(index)))
        var ran = 0

        for trial in 0..<Self.trials {
            let inty = sampler.interpreter()
            if behavior.behaviorClass == .contextRead {   // the constants and inputs; slow to bind
                withFuzzSeed(UInt64(trial)) { RandomCode.setRandomConstants(in: inty) }
            }
            let planner = Planner(for: inty)
            guard case .ready(let arguments, let claims) = planner.plan(behavior.requirements) else { continue }
            planner.commit(claims)
            ran += 1
            let before = Self.counts(inty)
            let routers = behavior.computeResults(from: arguments, on: inty)

            let free: Set<PushStack> = switch behavior.produces {
            case .positions(let stack): [stack, .error]   // a copy refused at maxStackDepth
            case .continuation:         Set(PushStack.allCases)   // control can bury an element anywhere
            default:                    []
            }
            for (stack, count) in Self.counts(inty) where !free.contains(stack) {
                #expect(count == before[stack], "changed .\(stack) in place")
            }

            let errors = routers.filter { $0.stack == .error }
            let results = routers.filter { $0.stack != .error }
            guard !errors.isEmpty else {
                if let why = Self.violation(results, of: behavior.produces) { Issue.record("\(why)") }
                continue
            }
            // An unbound constant or input is the environment's error, not the edge's.
            let kinds = errors.compactMap { ($0.item as? ErrorItem)?.kind }
            let environmental = kinds.allSatisfy { [.missingConstant, .missingInput].contains($0) }
            if behavior.produces != .continuation, !environmental {
                #expect(behavior.tags.contains(.fallible),
                        "erred without `.fallible`: \((errors[0].item as? ErrorItem)?.value ?? "?")")
            }
            // A refusal may hand its arguments back untouched, and nothing else.
            let argumentStacks = Self.sorted(arguments.compactMap { PushStack.defaultStack(for: $0) })
            if !results.isEmpty, !Self.isSubmultiset(Self.stacks(results), of: argumentStacks) {
                if let why = Self.violation(results, of: behavior.produces) { Issue.record("refused, and \(why)") }
            }
        }
        #expect(ran > 0 || behavior.requirements.count > 4, "never found its arguments")
    }


    // MARK: - The map

    /// Which shape each instruction's output declaration has.
    static func shape(_ produces: Produces) -> String {
        switch produces {
        case .results(let stacks) where stacks.isEmpty: "nothing"
        case .results(let stacks) where stacks.count == 1: "one result"
        case .results: "fixed results"
        case .alternatives: "alternatives"
        case .deferred: "deferred"
        case .input: "input"
        case .delivery: "delivery"
        case .positions: "positions"
        case .continuation: "continuation"
        case .printout: "printout"
        }
    }

    /// The shape of the whole map, pinned so a change to it is noticed.
    @Test func `the map's shape`() {
        var counts: [String: Int] = [:]
        for signature in Interpreter.signatures.values { counts[Self.shape(signature.produces), default: 0] += 1 }
        #expect(Interpreter.signatures.count == Interpreter.language.count)
        #expect(counts == [
            "one result": 419, "fixed results": 81, "alternatives": 23,
            "deferred": 80, "input": 10, "delivery": 7,
            "positions": 170, "continuation": 42, "printout": 13
        ])
    }

    @Test func `backward chaining starts from the instructions producing a stack`() {
        let bools = Set(Interpreter.producers[.bool] ?? [])
        #expect(bools.isSuperset(of: [.intGT, .boolEq, .intStackIsEmpty, .boolAnd]))
        #expect(!bools.contains(.intAdd))
        #expect(Interpreter.producers[.int]?.contains(.int3) == true, "a constant counts where it rests")
        #expect(Interpreter.producers[.char]?.contains(.stringPushAllChars) == true,
                "a delivery counts where it delivers")
        #expect(Interpreter.producers.values.allSatisfy { !$0.contains(.execIf) }, "a continuation produces no type")
    }

    @Test func `a signature reads its inputs off the requirements`() {
        let construct = Interpreter.signatures[.vecIntConstruct]!
        #expect(construct.consumes == [.vecInt: 1])
        #expect(construct.variadic == [.int])
        #expect(construct.produces == .results([.vecInt]))

        let greater = Interpreter.signatures[.intGT]!
        #expect(greater.reads == [.int: 2] && greater.consumes.isEmpty)
        #expect(greater.produces == .results([.bool]) && !greater.isPartial)
        #expect(Interpreter.signatures[.intQuot]!.isPartial)

        #expect(Interpreter.signatures[.intYank]!.produces == .positions(.int))
        #expect(Interpreter.signatures[.intYank]!.needs == [.int: 2])
    }
}
