//
//  RandomCode.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/3/26.
//
//  Random programs and values, for exercising the weird edges of the language.
//
//  **This is test scaffolding that lives in the library**, deliberately. It is
//  carried here so it survives the repo split — but it is almost entirely
//  `internal`, so it is invisible to production code and reachable only from the
//  interpreter's own `@testable` tests. (Three helpers are `public`; see
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
/// seed. Every random choice here draws from the shared `fuzzRNG`.
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

/// The shared RNG for every random draw here.
///
/// **A single mutable global, which is why fuzz suites must run alone**: Swift
/// Testing runs suites in parallel, and a concurrent drawer breaks the seed. Each
/// carries a `disabledTests` toggle for exactly this reason. It is global rather
/// than injected because otherwise every call site threads an RNG through, and
/// this is scaffolding — but if these are ever to run in parallel, this is the
/// thing to fix first.
nonisolated(unsafe) var fuzzRNG = SeededRNG(seed: 0)


/// How to divide random draws between the named parts of the language.
///
/// Weights are relative and need not sum to anything; a tag weighted 0 is never
/// drawn. Within a chosen tag, the draw is **uniform**.
///
/// **This is the knob the mix diagnostic turns**, and the reason it exists:
/// nobody knows the right proportions of environment, furniture and work.
/// `.equalShares` is a guess, not a finding.
nonisolated struct InstructionMix: Sendable {
    var weights: [InstructionTag: Double]

    init(_ weights: [InstructionTag: Double]) {
        self.weights = weights
    }

    /// Equal shares of constants, inputs, combinators and everything else.
    static let equalShares = InstructionMix([
        .constant: 1, .input: 1, .combinator: 1, .other: 1,
    ])

    /// Draw in proportion to how many instructions each tag holds — i.e. exactly
    /// what `language.keys.randomElement()` does. **This is not neutral**: it is
    /// 34% combinators and 15% constants because that is the shape of the
    /// language, which nobody chose.
    static let uniformOverLanguage = InstructionMix(
        Dictionary(uniqueKeysWithValues: InstructionTag.allCases.map {
            ($0, Double(Interpreter.instructions(tagged: $0).count))
        })
    )

    /// One tag at a **third**, the remainder split three ways: 33.3% / 22.2% ×3.
    /// (Weights 3:2:2:2 — ninths.)
    static func enriched(_ tag: InstructionTag) -> InstructionMix {
        InstructionMix(Dictionary(uniqueKeysWithValues:
            InstructionTag.allCases.map { ($0, $0 == tag ? 3.0 : 2.0) }))
    }

    /// One tag at a **ninth**, the remainder split three ways: 11.1% / 29.6% ×3.
    /// (Weights 3:8:8:8 — twenty-sevenths, which is what "an eighth-ninth each"
    /// comes to.)
    ///
    /// Deliberately not 10/30/30/30: the target is a ninth of the draw, and the
    /// other three share what is left rather than each taking a flat 30%. The
    /// arithmetic difference is small; the symmetry with `enriched` is the point,
    /// since both then move the same tag by the same unit in opposite directions.
    static func depleted(_ tag: InstructionTag) -> InstructionMix {
        InstructionMix(Dictionary(uniqueKeysWithValues:
            InstructionTag.allCases.map { ($0, $0 == tag ? 3.0 : 8.0) }))
    }

    /// The nine mixes the diagnostic sweeps: the balanced centre, plus each tag
    /// **enriched** and **depleted** in turn.
    ///
    /// Orthogonal by design — one factor moved at a time, in both directions —
    /// so a difference can be attributed to the tag that moved rather than to a
    /// bespoke blend. `.uniformOverLanguage` is included last as the control: it
    /// is what drawing from `language.keys` gives you, and it is nobody's choice.
    static let standardSweep: [(name: String, mix: InstructionMix)] =
        [("equal", .equalShares)]
        + InstructionTag.allCases.map { ("\($0.rawValue)-rich", .enriched($0)) }
        + InstructionTag.allCases.map { ("\($0.rawValue)-poor", .depleted($0)) }
        + [("language-shaped", .uniformOverLanguage)]

    /// A tag, chosen by weight. `InstructionTag.allCases` has a fixed order, so a
    /// seed reproduces the same draws.
    func randomTag() -> InstructionTag {
        let live = InstructionTag.allCases.compactMap { tag -> (InstructionTag, Double)? in
            guard let weight = weights[tag], weight > 0 else { return nil }
            return (tag, weight)
        }
        guard let last = live.last else { return .other }
        var roll = Double.random(in: 0..<live.reduce(0) { $0 + $1.1 }, using: &fuzzRNG)
        for (tag, weight) in live {
            roll -= weight
            if roll < 0 { return tag }
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
    /// Kept for the frozen Plushy path; prefer `randomInstruction(from:)`.
    static func randomInstruction() -> PushInstruction {
        allInstructions.randomElement(using: &fuzzRNG)!
    }

    /// A tag by weight, then uniformly within it.
    static func randomInstruction(from mix: InstructionMix) -> PushInstruction {
        let tag = mix.randomTag()
        // The tags partition the language and none is empty; there is a test.
        return Interpreter.sortedTags[tag]!.randomElement(using: &fuzzRNG)!
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
        Interpreter.sortedTags[.constant]!.randomElement(using: &fuzzRNG)!
    }

    static func randomInput() -> PushInstruction {
        Interpreter.sortedTags[.input]!.randomElement(using: &fuzzRNG)!
    }

    static func randomGenomeStuff() -> Any {
        return switch Int.random(in: 0..<20, using: &fuzzRNG) {
        case 0: PlushyControl.close
        case 1: PlushyControl.open
        case 2...6: randomInput()
        case 7...11: randomConstant()
        default: randomInstruction()
        }
    }

    // do not need CodeBlock because of Plushy Open and Close

    public static func randomPlushy(_ items: Int) -> [Any] {
        var result: [Any] = []
        for _ in 0..<items {
            result.append(randomGenomeStuff())
        }
        return result
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
            let plush = RandomCode.randomPlushy(Int.random(in: 1..<20, using: &fuzzRNG))
            return CodeItem(Plushy.plushy2push(plush))
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
