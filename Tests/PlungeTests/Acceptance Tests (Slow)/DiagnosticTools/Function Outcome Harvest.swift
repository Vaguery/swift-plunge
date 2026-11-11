//
//  Function Outcome Harvest.swift
//  PlungeTests
//
//  Making programs as the app makes them, running them, and taking a
//  situation at every moment a function could be applied.
//

@testable import Plunge

extension FunctionOutcome {

    // MARK: - Programs, as the app makes them

    /// The app's constants (`Search Operators/RandomCode.swift`): small numbers,
    /// short strings, vectors of 0–5 elements (vecString 0–3).
    static func appConstants() -> [PushInstruction: any Item] {
        func small() -> Int { Int.random(in: -100...100, using: &fuzzRNG) }
        func letter() -> Character { Character(UnicodeScalar(UInt8.random(in: 97...122, using: &fuzzRNG))) }
        func word() -> String { String((0..<Int.random(in: 1...6, using: &fuzzRNG)).map { _ in letter() }) }
        func count(_ most: Int) -> Range<Int> { 0..<Int.random(in: 0...most, using: &fuzzRNG) }
        var constants: [PushInstruction: any Item] = [:]
        for slot in 0..<10 {
            func token(_ type: String) -> PushInstruction { PushInstruction(rawValue: "\(type)\(slot)")! }
            constants[token("int")] = IntItem(small())
            constants[token("double")] = DoubleItem(Double.random(in: -100...100, using: &fuzzRNG))
            constants[token("string")] = StringItem(word())
            constants[token("char")] = CharItem(letter())
            constants[token("vecInt")] = VecIntItem(count(5).map { _ in small() })
            constants[token("vecDouble")] = VecDoubleItem(count(5).map { _ in
                Double.random(in: -100...100, using: &fuzzRNG)
            })
            constants[token("vecString")] = VecStringItem(count(3).map { _ in word() })
            constants[token("vecBool")] = VecBoolItem(count(5).map { _ in Bool.random(using: &fuzzRNG) })
        }
        return constants
    }

    /// Benchmark-like inputs: a text problem binds `.input0` to a short sentence;
    /// a numeric one binds `.input0` and `.input1` to doubles.
    static func benchmarkInputs(text: Bool) -> [PushInstruction: any Item] {
        if text {
            let words = ["spin", "words", "hello", "welcome", "to", "the", "stage"]
            let sentence = (0..<Int.random(in: 2...5, using: &fuzzRNG)).map { _ in
                words[Int.random(in: 0..<words.count, using: &fuzzRNG)]
            }.joined(separator: " ")
            return [.input0: StringItem(sentence)]
        }
        return [.input0: DoubleItem(Double.random(in: -10...10, using: &fuzzRNG)),
                .input1: DoubleItem(Double.random(in: -10...10, using: &fuzzRNG))]
    }

    enum Regime: String, CaseIterable {
        /// The app's "Everything": uniform over the language, with only the
        /// benchmark's own input tokens.
        case everything = "everything (app-like)"
        /// The library fuzzers' role mix: a fifth of draws are input tokens,
        /// all ten of them bound.
        case equalShares = "equal role shares"
    }

    /// A program with the environment it runs in.
    struct Drawn {
        var program: [any Item]
        var inputs: [PushInstruction: any Item]
        var constants: [PushInstruction: any Item]
    }

    /// One program, its inputs and its constants, drawn for `regime`.
    static func draw(_ regime: Regime, text: Bool) -> Drawn {
        let constants = appConstants()
        var inputs = benchmarkInputs(text: text)
        let tokens: [any Item]
        switch regime {
        case .everything:
            let pool = RandomCode.allInstructions.filter { !Interpreter.inputSlots.contains($0) || inputs[$0] != nil }
            tokens = (0..<150).map { _ in InstructionItem(pool[Int.random(in: 0..<pool.count, using: &fuzzRNG)]) }
        case .equalShares:
            tokens = RandomCode.randomProgram(150, mix: .equalShares)
            // Sorted: a dictionary's order changes from one process to the next.
            let values = constants.sorted { $0.key.rawValue < $1.key.rawValue }.map(\.value)
            for slot in Interpreter.inputSlots where inputs[slot] == nil {
                inputs[slot] = values[Int.random(in: 0..<values.count, using: &fuzzRNG)]
            }
        }
        let permutation = (0..<8).map { _ in Double.random(in: 0...1, using: &fuzzRNG) }
        return Drawn(program: FibonacciGenome.translate(tokens, permutation: permutation),
                     inputs: inputs, constants: constants)
    }


    // MARK: - Harvesting

    struct Harvest {
        /// Each situation, with the families it is a situation for.
        var situations: [(Situation, [Family])] = []
        var naturalFirings = 0
        var naturalStarved = 0
    }

    static func snapshot(_ inty: Interpreter) -> [PushStack: [any Item]] {
        var stacks: [PushStack: [any Item]] = [:]
        for stack in PushStack.allCases where stack != .exec && stack != .error {
            stacks[stack] = Array(inty.stacks[stack] ?? [])
        }
        return stacks
    }

    static func harvest(_ regime: Regime, programs: Int) -> Harvest {
        var harvest = Harvest()
        for seed in 0..<programs {
            let drawn = withFuzzSeed(UInt64(seed)) { draw(regime, text: seed.isMultiple(of: 2)) }
            let inty = Interpreter()
            inty.config.stepLimit = budget
            inty.config.recordsProvenance = true
            inty.load(inputs: drawn.inputs, constants: drawn.constants, program: drawn.program)

            var steps = 0
            while inty.counter < inty.config.stepLimit, let next = inty.stacks[.exec]!.first {
                take(from: inty, next: next, steps: steps, drawn: drawn, into: &harvest)
                inty.step()
                steps += 1
            }
        }
        return harvest
    }

    /// The situation `inty` is in before it runs `next`, if it is one: a
    /// natural firing, or every hundredth step, an opportunity.
    static func take(from inty: Interpreter, next: any Item, steps: Int, drawn: Drawn, into harvest: inout Harvest) {
        let block = inty.stacks[.code]!.first as? CodeItem
        func situation(_ natural: Bool, _ collection: any Item, _ block: CodeItem) -> Situation {
            Situation(natural: natural, collection: collection, block: block, inputs: drawn.inputs,
                      constants: drawn.constants, stacks: snapshot(inty))
        }
        if let token = (next as? InstructionItem)?.value, let (family, stack) = functionInstructions[token] {
            harvest.naturalFirings += 1
            if let block, let collection = inty.stacks[stack]!.first {
                harvest.situations.append((situation(true, collection, block), [family]))
            } else {
                harvest.naturalStarved += 1
            }
        } else if steps > 0, steps.isMultiple(of: 100), let block {
            let available = collectionStacks.filter { !(inty.stacks[$0]!.isEmpty) }
            guard !available.isEmpty else { return }
            let stack = available[steps / 100 % available.count]
            harvest.situations.append((situation(false, inty.stacks[stack]!.first!, block), Family.allCases))
        }
    }
}
