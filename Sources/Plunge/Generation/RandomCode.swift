//
//  RandomCode.swift
//  Plunge
//
//  Created by Bill Tozier on 6/3/26.
//
//  Random programs and values, for exercising the weird edges of the language.
//
//  **This is test scaffolding that lives in the library**, deliberately. It is
//  carried here so it survives the repo split — but it is almost entirely
//  `internal`, so it is invisible to production code and reachable only from the
//  interpreter's own `@testable` tests. (Two helpers are `public`; see
//  `RandomCode`.) The real search process owns genome generation; nothing here
//  should end up on an evolutionary critical path.
//
//  A genome has two sets of genes: the constant *assignments* that travel with an
//  individual, and the *instruction* stream. Both belong to the Search side. What
//  the interpreter receives is a translated program plus a dictionary of constants
//  to merge before running — so this file samples programs of instructions, and
//  randomizes constants separately (`setRandomConstants`).
//

import Foundation


/// A deterministic RNG (SplitMix64) so a fuzz run reproduces exactly from its
/// seed. Every random choice here draws from `fuzzRNG`.
nonisolated struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A seeded generator that one fuzz run can own. A reference, so the draws a
/// scope makes advance the one generator that scope installed.
nonisolated final class FuzzRNGBox: @unchecked Sendable {
    var rng: SeededRNG
    init(seed: UInt64) { rng = SeededRNG(seed: seed) }
}

/// Which generator `fuzzRNG` draws from, per task.
///
/// **Scoped, so fuzz runs can share a test pass.** Swift Testing runs suites in
/// parallel, and when every draw came from one mutable global a concurrent drawer
/// broke the seed: the crux fuzz drew 21,123 claims on one run and 17,016 on the
/// next from the same seed, so each fuzz suite had to be disabled and run alone.
/// A run that installs its own box with `withFuzzSeed` draws only from it, and is
/// reproducible whatever else is running. Code that installs nothing shares
/// `shared`, exactly as before (and is as unreproducible in parallel as before).
nonisolated enum FuzzRNGScope {
    static let shared = FuzzRNGBox(seed: 0)
    @TaskLocal static var current: FuzzRNGBox = shared
}

/// Runs `body` with every random draw here coming from a fresh generator seeded
/// with `seed`, isolated from every other task. The way a fuzz run should seed.
func withFuzzSeed<T>(_ seed: UInt64, _ body: () throws -> T) rethrows -> T {
    try FuzzRNGScope.$current.withValue(FuzzRNGBox(seed: seed), operation: body)
}

/// The RNG for every random draw here: the current scope's (see `FuzzRNGScope`).
/// A computed variable, so the many `using: &fuzzRNG` call sites are unchanged,
/// and assigning `fuzzRNG = SeededRNG(seed:)` reseeds the current scope's box.
nonisolated var fuzzRNG: SeededRNG {
    get { FuzzRNGScope.current.rng }
    set { FuzzRNGScope.current.rng = newValue }
}


/// How to divide random draws between the named parts of the language.
///
/// Weights are relative and need not sum to anything; a tag weighted 0 is never
/// drawn. Within a chosen tag, the draw is **uniform**.
///
/// **This is the knob the mix diagnostic turns**, and the reason it exists:
/// nobody knows the right proportions of environment, furniture and work.
/// `.equalShares` is a guess, not a finding.
nonisolated struct InstructionMix: Sendable {
    var weights: [InstructionRole: Double]
    /// An extra pool drawn beside the roles, with its own weight: how a mix
    /// concentrates a family that cuts across roles, such as the loops.
    /// Empty by default, and then it changes nothing about any draw.
    var focus: [PushInstruction] = []
    var focusWeight: Double = 0

    init(_ weights: [InstructionRole: Double]) {
        self.weights = weights
    }

    init(_ weights: [InstructionRole: Double], focus: [PushInstruction], weight: Double) {
        self.weights = weights
        self.focus = focus
        self.focusWeight = weight
    }

    /// The instructions that run a body again and again: every `.reEntrant`
    /// instruction (the iterates, the while loops, `.execY`, `.iteratorPlay`) plus
    /// the three counted loops that build an iterator and hand it to
    /// `.iteratorPlay`. Sorted, so a seed reproduces.
    static let loopInstructions: [PushInstruction] =
        (Interpreter.instructions(declaring: .reEntrant)
            .union([.execDoRange, .execDoTimes, .execDoCount]))
            .sorted { $0.rawValue < $1.rawValue }

    /// Equal shares of every role, plus the loops at twice a role's share: about
    /// two draws in seven are a loop. **Loops are where provenance is hardest**
    /// (long histories, sharing, folding, elision), and no other mix concentrates them;
    /// the crux fuzz runs under this as well as `.equalShares`.
    static let loopHeavy = InstructionMix(
        Dictionary(uniqueKeysWithValues: InstructionRole.allCases.map { ($0, 1.0) }),
        focus: loopInstructions, weight: 2)

    /// The vector and string instructions that are not combinators: the ones that
    /// put elements in, rearrange them and take them out. Sorted, so a seed
    /// reproduces.
    static let containerInstructions: [PushInstruction] =
        Interpreter.instructions(role: .other).union(Interpreter.instructions(role: .comparison))
            .filter { $0.rawValue.hasPrefix("vec") || $0.rawValue.hasPrefix("string") }
            .sorted { $0.rawValue < $1.rawValue }

    /// Equal shares of every role, plus the vector and string instructions at
    /// twice a role's share. **Members** (`Containment`) only matter when a
    /// program puts a computed element into a container and takes it out again,
    /// which a balanced mix almost never does; the crux fuzz runs under this so
    /// the fixed-point check covers them.
    static let containerHeavy = InstructionMix(
        Dictionary(uniqueKeysWithValues: InstructionRole.allCases.map { ($0, 1.0) }),
        focus: containerInstructions, weight: 2)

    /// Equal shares of every role — constants, inputs, the stack family,
    /// comparisons and everything else.
    ///
    /// **A role missing from this dictionary is drawn at weight zero**, not at some
    /// default: `randomRole()` filters to `weights[role] > 0`. So adding a role case
    /// without adding it here silently removes those instructions from every
    /// generated program. That is why `.comparison` appears below, and why a test
    /// asserts every role is reachable under this mix.
    static let equalShares = InstructionMix([
        .constant: 1, .input: 1, .stackFamily: 1, .comparison: 1, .other: 1
    ])

    /// Draw in proportion to how many instructions each tag holds — i.e. exactly
    /// what `language.keys.randomElement()` does. **This is not neutral**: it is
    /// about 23% stack family and 9% constants because that is the shape of the
    /// language, which nobody chose.
    static let uniformOverLanguage = InstructionMix(
        Dictionary(uniqueKeysWithValues: InstructionRole.allCases.map {
            ($0, Double(Interpreter.instructions(role: $0).count))
        })
    )

    /// One role weighted **3**, every other **2** — so the target takes
    /// `3 / (3 + 2(n-1))` of the draw and the rest share the remainder evenly.
    ///
    /// Stated as a ratio rather than a percentage because the percentage depends on
    /// how many roles there are: it was 33.3% / 22.2% ×3 with four roles and is
    /// 27.3% / 18.2% ×4 with five. The ratio is the thing that was chosen.
    static func enriched(_ role: InstructionRole) -> InstructionMix {
        InstructionMix(Dictionary(uniqueKeysWithValues:
            InstructionRole.allCases.map { ($0, $0 == role ? 3.0 : 2.0) }))
    }

    /// One role weighted **3**, every other **8** — the mirror of `enriched`,
    /// moving the same role by the same unit in the opposite direction.
    ///
    /// The symmetry is the point, which is why this is a ratio and not a round
    /// percentage: the target takes `3 / (3 + 8(n-1))` and the others share what is
    /// left, rather than each being handed a flat share chosen by hand.
    static func depleted(_ role: InstructionRole) -> InstructionMix {
        InstructionMix(Dictionary(uniqueKeysWithValues:
            InstructionRole.allCases.map { ($0, $0 == role ? 3.0 : 8.0) }))
    }

    /// The nine mixes the diagnostic sweeps: the balanced center, plus each tag
    /// **enriched** and **depleted** in turn.
    ///
    /// Orthogonal by design — one factor moved at a time, in both directions —
    /// so a difference can be attributed to the tag that moved rather than to a
    /// bespoke blend. `.uniformOverLanguage` is included last as the control: it
    /// is what drawing from `language.keys` gives you, and it is nobody's choice.
    static let standardSweep: [(name: String, mix: InstructionMix)] =
        [("equal", .equalShares)]
        + InstructionRole.allCases.map { ("\($0.rawValue)-rich", .enriched($0)) }
        + InstructionRole.allCases.map { ("\($0.rawValue)-poor", .depleted($0)) }
        + [("language-shaped", .uniformOverLanguage)]

    /// A role, chosen by weight. `InstructionRole.allCases` has a fixed order, so a
    /// seed reproduces the same draws.
    func randomRole() -> InstructionRole {
        let live = InstructionRole.allCases.compactMap { role -> (InstructionRole, Double)? in
            guard let weight = weights[role], weight > 0 else { return nil }
            return (role, weight)
        }
        guard let last = live.last else { return .other }
        var roll = Double.random(in: 0..<live.reduce(0) { $0 + $1.1 }, using: &fuzzRNG)
        for (role, weight) in live {
            roll -= weight
            if roll < 0 { return role }
        }
        return last.0
    }
}


/// `public` only where a plain-import test needs it.
///
/// Most of this is `internal`: the interpreter's own `@testable` tests reach it,
/// and nothing outside the module can. The three exceptions are the value/genome
/// helpers used by "Runner Acceptance Tests", which drives the library through
/// its **public surface only** — deliberately, to prove the search process can —
/// and so cannot see internals even though it lives in the test target.
public nonisolated enum RandomCode {

    // A STABLE instruction pool: `Dictionary.keys` iterates in a per-process
    // random order, so drawing from it (even with a seeded RNG) is not
    // reproducible. Sorting by rawValue fixes the order.
    static let allInstructions: [PushInstruction] =
        Interpreter.language.keys.sorted { $0.rawValue < $1.rawValue }

    /// Uniform over the *whole* language — which means 34% combinators and 15%
    /// constants, because that is the language's shape rather than a decision.
    /// Prefer `randomInstruction(from:)`, which draws by tag.
    static func randomInstruction() -> PushInstruction {
        allInstructions.randomElement(using: &fuzzRNG)!
    }

    /// A tag by weight, then uniformly within it. A mix's `focus` pool, if any,
    /// is drawn first, in proportion to its weight against the roles' total.
    static func randomInstruction(from mix: InstructionMix) -> PushInstruction {
        if mix.focusWeight > 0, let pick = mix.focus.randomElement(using: &fuzzRNG) {
            let roleTotal = mix.weights.values.filter { $0 > 0 }.reduce(0, +)
            if Double.random(in: 0..<(roleTotal + mix.focusWeight), using: &fuzzRNG) < mix.focusWeight {
                return pick
            }
        }
        let role = mix.randomRole()
        // The tags partition the language and none is empty; there is a test.
        return Interpreter.sortedRoles[role]!.randomElement(using: &fuzzRNG)!
    }

    /// A flat gene stream: **instruction tokens only.**
    ///
    /// No literals — a Push program made this way has no `5` in it. Every value
    /// arrives through a constant (`.int3`) or an input (`.input7`) token, which
    /// is what lets a search optimize an individual's constant assignments
    /// independently of its program structure (see `Individual`), and is what the
    /// Plushy generator has always done.
    ///
    /// No `IteratorItem`s either, ever: an iterator is a live loop rather than a
    /// value, and the instructions construct them. There is a test.
    static func randomProgram(_ items: Int, mix: InstructionMix = .equalShares) -> [any Item] {
        (0..<items).map { _ in InstructionItem(randomInstruction(from: mix)) }
    }

    public static func randomInt(_ scale: Int) -> Int {
        Int.random(in: -scale...scale, using: &fuzzRNG)
    }

    public static func randomDouble(_ scale: Double) -> Double {
        Double.random(in: -scale...scale, using: &fuzzRNG)
    }

    static func randomChar() -> Character {
        let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return choices.randomElement(using: &fuzzRNG)!
    }

    static func randomString(_ len: Int) -> String {
        let choices = "     abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var result = ""
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 1...length {
            result.append(choices.randomElement(using: &fuzzRNG)!)
        }
        return result
    }

    static func randomVecString(_ len: Int) -> [String] {
        var result = [String]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 1...length {
            result.append(randomString(len))
        }
        return result
    }

    static func randomVecInt(_ scale: Int, _ len: Int) -> [Int] {
        var result = [Int]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 1...length {
            result.append(randomInt(scale))
        }
        return result
    }

    static func randomVecDouble(_ scale: Double, _ len: Int) -> [Double] {
        var result = [Double]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 0..<length {
            result.append(randomDouble(scale))
        }
        return result
    }

    static func randomVecBool(_ len: Int) -> [Bool] {
        var result = [Bool]()
        let length = Int.random(in: 1...len, using: &fuzzRNG)
        for _ in 0..<length {
            result.append(Bool.random(using: &fuzzRNG))
        }
        return result
    }

    /// Drawn from the tag rather than by rebuilding the token's name from parts,
    /// so it cannot invent a constant the language does not have.
    static func randomConstant() -> PushInstruction {
        Interpreter.sortedRoles[.constant]!.randomElement(using: &fuzzRNG)!
    }

    static func randomInput() -> PushInstruction {
        Interpreter.sortedRoles[.input]!.randomElement(using: &fuzzRNG)!
    }

    /// A random *value*, for binding to an input or a constant — **not a gene.**
    /// This is the genome's other half (the constant assignments), and unlike the
    /// program it can be any Item at all, including a code block.
    static func randomPushItem() -> any Item {
        switch Int.random(in: 0..<30, using: &fuzzRNG) {
        case 0: return IntItem(randomInt(100_000))
        case 1: return DoubleItem(randomDouble(100_000.0))
        case 2: return StringItem(randomString(20))
        case 3: return CharItem(randomChar())
        case 4: return VecIntItem(randomVecInt(100_000, 20))
        case 5: return VecBoolItem(randomVecBool(20))
        case 6: return VecDoubleItem(randomVecDouble(100_000.0, 20))
        case 7: return VecStringItem(randomVecString(20))
        case 8...10:
            // A random code block for a constant/input binding. Fibonacci-packing a
            // flat instruction stream gives a nested-ish block without the departed
            // Plushy genome (see FibonacciGenome, the retained test generator).
            return CodeItem(FibonacciGenome.translate(randomProgram(Int.random(in: 1..<20, using: &fuzzRNG))))
        case 11...20: return InstructionItem(randomInput())
        default: return InstructionItem(randomInstruction())
        }
    }

    static func setRandomConstants(in interpreter: Interpreter) {
        func token(_ name: String) -> PushInstruction { PushInstruction(rawValue: name)! }
        for i in (0..<10) {
            interpreter.constants[token("int\(i)")] = IntItem(randomInt(100_000))
            interpreter.constants[token("double\(i)")] = DoubleItem(randomDouble(100_000.0))
            interpreter.constants[token("string\(i)")] = StringItem(randomString(20))
            interpreter.constants[token("char\(i)")] = CharItem(randomChar())
            interpreter.constants[token("vecInt\(i)")] = VecIntItem(randomVecInt(100_000, 20))
            interpreter.constants[token("vecDouble\(i)")] = VecDoubleItem(randomVecDouble(100_000.0, 20))
            interpreter.constants[token("vecString\(i)")] = VecStringItem(randomVecString(20))
            interpreter.constants[token("vecBool\(i)")] = VecBoolItem(randomVecBool(20))
            let inputName = "input\(i)"
            let input = PushInstruction(rawValue: inputName)!
            interpreter.inputs[input] = randomPushItem()
        }
    }

    static func setRandomInputs(in interpreter: Interpreter) {
        for k in interpreter.inputs.keys {
            interpreter.inputs[k] = randomPushItem()
        }
    }
}
