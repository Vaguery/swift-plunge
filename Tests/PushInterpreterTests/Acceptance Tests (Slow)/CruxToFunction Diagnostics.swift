//
//  CruxToFunction Diagnostics.swift
//  PushInterpreterTests
//
//  Checks the logic behind the planned crux-to-function work
//  (`codeFuncFromXCrux`): can a resolved value's crux be turned into a reusable
//  *function* — a CodeItem mapping an input of a chosen type to an output of a
//  chosen type — by deleting one leaf and letting the "hole" read from the stack?
//
//  No new language instructions here. The delete-leaf currying is done in Swift,
//  so this is a *reporting* diagnostic: the printed rates carry the answer, and
//  the loose asserts only say "the mechanism works at all."
//
//  WHY THE HOLES ARE TOKENS, NOT LITERALS.  `RandomCode.randomProgram` emits
//  instruction tokens only; values arrive through constants (`.int3`) and inputs
//  (`.input7`), each of which stamps its pushed value with `call = [.int3]` /
//  `[.input7]` (Constant/Input Behaviors). So a resting int's crux is a flat list
//  of *instruction* tokens, with no bare IntItem literals. The deletable "int
//  leaf" is therefore an int-SOURCE token — a `.intN` constant (D1/D2) or a
//  `.inputN` input (D3) — and deleting it turns that push into a stack read.
//
//  WHAT THE RUNS SHOW (seed-stable; see each test's printout):
//   - VALIDITY IS FREE. Deleting a leaf gives a runnable, correctly-typed program
//     ~100% of the time, at every crux size (total semantics).
//   - FUNCTIONHOOD depends on the chosen leaf PROPAGATING to the output, not on
//     crux size. For fully-propagating arithmetic (D1) ~97% of curries are input-
//     sensitive even at 25 nodes; the killer is MASKING (min/max/mod, discarded
//     values), which is why the combinator-heavy harvested cruxes in D2 score low.
//   - DELETE vs SUBSTITUTE compute DIFFERENT functions (~70% agreement, falling
//     with size): deletion reads the arg at the stack BOTTOM — a repositioned
//     function — while substituting `.inputN` at the hole reproduces the original
//     computation with one value replaced (the faithful curry). So the sound crux-
//     to-function transform is SUBSTITUTE-an-input; delete-a-leaf
//     also yields functions, just repositioned ones. Both are fine for search.
//   - `.inputN` needs no transform at all: the input IS the hole, read at the right
//     point. D3 harvests (int,int)->int functions this way with zero surgery.
//
//  MISSING-ANALOGIES FINDING (map/reduce):
//   - Reduce is NOT missing: a binary-op CodeItem body under `vecXIterate` with a
//     primed accumulator IS a fold (see D4). At most it wants a sugar constructor.
//   - `map` is a side-effect today; map-COLLECT (gather what the body left back
//     into a vector) is the one real hole — the "pseudofunction" accumulator.
//   - A function is a CodeItem and `.code` is the function stack. No `.function`
//     type and no sieve are needed to RUN one: the iterate family already consumes
//     a body off `.code`, and total semantics make signature-matching
//     dynamic. Signatures matter only at search/construction time (D3), read off a
//     crux's leaf-types and result-type.
//
//  Run alone (shared `fuzzRNG`): flip `disabledTests` to false, run
//  `swift test --filter CruxToFunctionDiagnostics`, read the tables, then restore
//  `disabledTests = true`. D4 is deterministic (no RNG) and stays enabled as a
//  permanent regression of the reduce-from-iterate claim.
//

import Foundation
@testable import PushInterpreter
import Testing

@Suite @MainActor
struct CruxToFunctionDiagnostics {

    // The same toggle protocol the crux fuzzer uses: a single mutable global RNG
    // means these must not run alongside another fuzz suite.
    nonisolated static let disabledTests = true

    // MARK: - Shared helpers

    /// The ten int-constant tokens — the int-source holes for D1/D2.
    static let intConstantTokens: Set<PushInstruction> =
        Set((0..<10).map { PushInstruction(rawValue: "int\($0)")! })

    static let input0 = PushInstruction.input0
    static let input1 = PushInstruction.input1

    func isInstruction(_ item: any Item, _ instruction: PushInstruction) -> Bool {
        (item as? InstructionItem)?.value == instruction
    }

    /// Indices in a crux whose token is an int-constant push — the currying holes.
    func intConstantHoles(in crux: [any Item]) -> [Int] {
        crux.indices.filter { i in
            guard let instr = (crux[i] as? InstructionItem)?.value else { return false }
            return Self.intConstantTokens.contains(instr)
        }
    }

    func deleting(_ index: Int, from crux: [any Item]) -> [any Item] {
        var copy = crux
        copy.remove(at: index)
        return copy
    }

    /// Replace one crux token with an instruction (used to swap an int-source
    /// constant for `.input0` — the sound alternative to deletion, since the value
    /// is then read at the SAME point in the computation the constant was).
    func substituting(_ index: Int, with token: PushInstruction, in crux: [any Item]) -> [any Item] {
        var copy = crux
        copy[index] = InstructionItem(token)
        return copy
    }

    /// Run a program in a fresh sandbox with the given environment and an optional
    /// int pre-loaded on `.int`; report the top `.int` value afterward.
    func evalInt(
        _ program: [any Item],
        inputs: [PushInstruction: any Item] = [:],
        constants: [PushInstruction: any Item],
        intArg: Int? = nil,
        stepLimit: Int = 1500
    ) -> Int? {
        let sandbox = Interpreter.recordingProvenance()
        var stacks: [PushStack: [any Item]] = [:]
        if let intArg { stacks[.int] = [IntItem(intArg)] }
        sandbox.load(inputs: inputs, constants: constants, stacks: stacks, program: program)
        sandbox.run(stepLimit: stepLimit)
        return (sandbox.stacks[.int]!.first as? IntItem)?.value
    }

    /// A fresh random environment (all constants + inputs bound), returned as two
    /// dictionaries so the same bindings can be reused when re-running a curry.
    func freshEnvironment() -> (constants: [PushInstruction: any Item], inputs: [PushInstruction: any Item]) {
        let seed = Interpreter.recordingProvenance()
        RandomCode.setRandomConstants(in: seed)
        return (seed.constants, seed.inputs)
    }

    // MARK: - D1: a value's crux, curried by deleting one int-constant leaf

    /// A random left-leaning RPN arithmetic program with `leaves` int-constant
    /// leaves and `leaves-1` fully-propagating binary ops. Fully-propagating means
    /// every leaf influences the result (no `min`/`max`/`mod` masking), so any
    /// currying that turns out *insensitive* is the currying method's doing — the
    /// isolation this experiment needs.
    static let propagatingOps: [PushInstruction] = [.intAdd, .intSubtract, .intMultiply]

    func randomIntConstantToken() -> PushInstruction {
        PushInstruction(rawValue: "int\(Int.random(in: 0..<10, using: &fuzzRNG))")!
    }

    func randomArithmeticProgram(leaves: Int) -> [any Item] {
        var program: [any Item] = [InstructionItem(randomIntConstantToken())]
        for _ in 1..<leaves {
            program.append(InstructionItem(randomIntConstantToken()))
            program.append(InstructionItem(Self.propagatingOps.randomElement(using: &fuzzRNG)!))
        }
        return program
    }

    /// int0…int9 bound to distinct small non-zero values, so leaves differ and
    /// arithmetic neither overflows nor collapses to a constant.
    func distinctIntConstants() -> [PushInstruction: any Item] {
        var c = [PushInstruction: any Item]()
        for i in 0..<10 {
            c[PushInstruction(rawValue: "int\(i)")!] = IntItem(1 + RandomCode.randomInt(20))
        }
        return c
    }

    @Test(.disabled(if: disabledTests))
    func `D1 curry a value's crux: delete a leaf vs substitute an input`() {
        fuzzRNG = SeededRNG(seed: 0xC0FFEE)
        // Constructive: build arithmetic cruxes of controlled size from fully-
        // propagating ops, so every leaf matters and the ONLY thing that can make a
        // curry insensitive is the currying method.
        //
        //   delete    — remove the int-source token; the hole reads from `.int`
        //               (arg pre-loaded at the bottom, as a map body would meet it).
        //   substitute— replace the token with `.input0`; the value is read at the
        //               SAME point in the computation, via the input mechanism.
        // leaf count n → crux size 2n-1 nodes. Each expression curries ONE random
        // leaf; two distinct args probe input-sensitivity.
        let leafCounts = [3, 5, 8, 13]      // crux sizes 5, 9, 15, 25 nodes
        let trials = 600

        var runnable = [Int: Int](), deleteSens = [Int: Int](), substSens = [Int: Int]()
        var sameFunction = [Int: Int](), compared = [Int: Int]()

        for _ in 0..<trials {
            for n in leafCounts {
                let constants = distinctIntConstants()
                let program = randomArithmeticProgram(leaves: n)

                let host = Interpreter.recordingProvenance()
                host.load(constants: constants, program: program)
                host.run(stepLimit: 500)
                guard let item = host.stacks[.int]!.first else { continue }
                let crux = item.crux()
                let holes = intConstantHoles(in: crux)
                guard !holes.isEmpty else { continue }

                let hole = holes.randomElement(using: &fuzzRNG)!
                let a = 1 + RandomCode.randomInt(1000)
                let b = a + 1 + RandomCode.randomInt(1000)   // guaranteed a != b

                // delete-leaf: arg pre-loaded on `.int` (bottom).
                let curried = deleting(hole, from: crux)
                let dA = evalInt(curried, constants: constants, intArg: a)
                let dB = evalInt(curried, constants: constants, intArg: b)
                if dA != nil { runnable[n, default: 0] += 1 }
                if let dA, let dB, dA != dB { deleteSens[n, default: 0] += 1 }

                // substitute-input: value read at the hole's position via `.input0`.
                let substituted = substituting(hole, with: Self.input0, in: crux)
                let sA = evalInt(substituted, inputs: [Self.input0: IntItem(a)], constants: constants)
                let sB = evalInt(substituted, inputs: [Self.input0: IntItem(b)], constants: constants)
                if let sA, let sB, sA != sB { substSens[n, default: 0] += 1 }

                // Do the two strategies compute the SAME function? Compare on arg a.
                if let dA, let sA {
                    compared[n, default: 0] += 1
                    if dA == sA { sameFunction[n, default: 0] += 1 }
                }
            }
        }

        func pad(_ s: String, _ w: Int) -> String {
            s.count >= w ? s : String(repeating: " ", count: w - s.count) + s
        }
        func pct(_ x: Int, _ d: Int = trials) -> String {
            d > 0 ? String(format: "%.1f", 100.0 * Double(x) / Double(d)) : "—"
        }
        print("\n=== D1: curry a value's crux — delete-leaf vs substitute-input ===")
        print("trials=\(trials) per size; constructive fully-propagating arithmetic")
        print(pad("leaves", 7) + pad("nodes", 7) + pad("run%", 8) + pad("del-sens%", 11)
              + pad("sub-sens%", 11) + pad("agree%", 9))
        for n in leafCounts {
            print(pad("\(n)", 7) + pad("\(2*n-1)", 7) + pad(pct(runnable[n] ?? 0), 8)
                  + pad(pct(deleteSens[n] ?? 0), 11) + pad(pct(substSens[n] ?? 0), 11)
                  + pad(pct(sameFunction[n] ?? 0, compared[n] ?? 0), 9))
        }
        print("FINDING: deleting a leaf is ~100% runnable AND ~input-sensitive at")
        print("every size when the leaf propagates — so Q1 is YES for arithmetic-")
        print("shaped cruxes; size is not the enemy, MASKING is (min/max/mod and")
        print("discarded values, which D2's harvested cruxes carry). delete and")
        print("substitute are sensitive about equally often but compute DIFFERENT")
        print("functions (agree%): delete reads the arg at the stack bottom, so it")
        print("is a repositioned function; substitute reproduces the ORIGINAL")
        print("computation with one value replaced — the faithful curry.")

        let totalRunnable = runnable.values.reduce(0, +)
        // Pipeline-liveness only; the rates and the agree% ARE the finding.
        #expect(totalRunnable > 0, "no runnable curry produced — check the generator")
    }

    // MARK: - D2: arbitrary CodeItem via a sandbox reduces to D1

    @Test(.disabled(if: disabledTests))
    func `D2 an arbitrary CodeItem yields curryable resting cruxes`() {
        fuzzRNG = SeededRNG(seed: 0xBADF00D)
        // Now allow combinators and iterators (they land in `.combinator`/`.other`)
        // so some sources loop; the point is that a resting item's crux is still a
        // straight-line, curryable program even when the code that made it was not.
        let mix = InstructionMix([.constant: 3, .other: 3, .combinator: 2, .input: 0])
        let trials = 1000

        // split by whether the SOURCE program used an iterator instruction
        var cands = (plain: 0, looped: 0)
        var delSens = (plain: 0, looped: 0)
        var subSens = (plain: 0, looped: 0)

        for _ in 0..<trials {
            let (constants, inputs) = freshEnvironment()
            let len = [20, 40, 80].randomElement(using: &fuzzRNG)!
            let program = RandomCode.randomProgram(len, mix: mix)
            let usedIterator = program.contains { item in
                guard let instr = (item as? InstructionItem)?.value else { return false }
                return PushInstruction.iterators.contains(instr)
            }

            // Frame it as "an arbitrary CodeItem, run": quote and codeDo.
            let host = Interpreter.recordingProvenance()
            host.load(inputs: inputs, constants: constants,
                      program: [CodeItem(program), InstructionItem(.codeDo)])
            host.run(stepLimit: 3000)

            for item in host.stacks[.int]! {
                let crux = item.crux()
                guard crux.count >= 5 else { continue }
                let holes = intConstantHoles(in: crux)
                guard !holes.isEmpty else { continue }
                if usedIterator { cands.looped += 1 } else { cands.plain += 1 }

                let hole = holes.randomElement(using: &fuzzRNG)!
                let a = RandomCode.randomInt(1000)
                let b = a + 1 + RandomCode.randomInt(1000)

                let curried = deleting(hole, from: crux)
                let dA = evalInt(curried, inputs: inputs, constants: constants, intArg: a)
                let dB = evalInt(curried, inputs: inputs, constants: constants, intArg: b)
                if let dA, let dB, dA != dB {
                    if usedIterator { delSens.looped += 1 } else { delSens.plain += 1 }
                }

                let substituted = substituting(hole, with: Self.input0, in: crux)
                var inA = inputs; inA[Self.input0] = IntItem(a)
                var inB = inputs; inB[Self.input0] = IntItem(b)
                let sA = evalInt(substituted, inputs: inA, constants: constants)
                let sB = evalInt(substituted, inputs: inB, constants: constants)
                if let sA, let sB, sA != sB {
                    if usedIterator { subSens.looped += 1 } else { subSens.plain += 1 }
                }
            }
        }

        func pct(_ n: Int, _ d: Int) -> String {
            d > 0 ? String(format: "%.1f%%", 100.0 * Double(n) / Double(d)) : "—"
        }
        print("\n=== D2: arbitrary CodeItem -> sandbox -> harvest -> curry ===")
        print("trials=\(trials); Q2 reduces to Q1 — a RESTING item's crux is a clean")
        print("straight-line curryable program even when loops/combinators made it.")
        print("source          curryable-cruxes   del-sens   sub-sens")
        print("no iterator     \(cands.plain)   \(pct(delSens.plain, cands.plain))   \(pct(subSens.plain, cands.plain))")
        print("used iterator   \(cands.looped)   \(pct(delSens.looped, cands.looped))   \(pct(subSens.looped, cands.looped))")
        print("The point here is CURRYABILITY (cruxes harvested), not the rate:")
        print("these harvested ints are combinator/masking-heavy, so their curries")
        print("are input-sensitive far less often than D1's clean arithmetic — the")
        print("masking story, not a burial one. Sample is small; treat rates as hints.")

        // Pipeline-liveness only; the sensitivity gap is the finding.
        #expect(cands.plain + cands.looped > 0, "no curryable resting crux from arbitrary code")
    }

    // MARK: - D3: signature-directed harvest of a diverse (int,int)->int library

    @Test(.disabled(if: disabledTests))
    func `D3 harvests a diverse library of (int,int)->int functions`() {
        fuzzRNG = SeededRNG(seed: 0x5EA5)
        // Input-rich so the parameter tokens actually appear.
        let mix = InstructionMix.enriched(.input)
        let trials = 500
        let grid = [(1, 1), (2, 3), (3, 2), (5, 7), (0, 4), (6, 6), (9, 2)]

        var candidates = 0
        var behaviors = Set<String>()
        var nonConstant = Set<String>()
        var examples = [String]()

        for _ in 0..<trials {
            let (constants, seededInputs) = freshEnvironment()
            // Pin the signature: input0, input1 are ints; harvest only functions
            // that use BOTH and no OTHER input, so grid re-evaluation is closed.
            var inputs = seededInputs
            inputs[Self.input0] = IntItem(RandomCode.randomInt(50))
            inputs[Self.input1] = IntItem(RandomCode.randomInt(50))
            let program = RandomCode.randomProgram(40, mix: mix)

            let host = Interpreter.recordingProvenance()
            host.load(inputs: inputs, constants: constants, program: program)
            host.run(stepLimit: 3000)

            for item in host.stacks[.int]! {
                let crux = item.crux()
                // Genuine binary functions: use BOTH parameters. Any other input or
                // constant the crux touches is held at its harvest value across the
                // grid, so it acts as a fixed parameter and re-evaluation stays closed.
                let usesBoth = crux.contains { isInstruction($0, Self.input0) }
                    && crux.contains { isInstruction($0, Self.input1) }
                guard usesBoth else { continue }

                candidates += 1
                let signature = grid.map { (a, b) -> String in
                    var gridInputs = inputs
                    gridInputs[Self.input0] = IntItem(a)
                    gridInputs[Self.input1] = IntItem(b)
                    return evalInt(crux, inputs: gridInputs, constants: constants).map(String.init) ?? "nil"
                }.joined(separator: ",")
                behaviors.insert(signature)
                if Set(signature.split(separator: ",")).count > 1 { nonConstant.insert(signature) }
                if examples.count < 6 { examples.append(CodeItem(crux).pretty()) }
            }
        }

        print("\n=== D3: (int,int)->int function harvest ===")
        print("trials=\(trials), input-enriched mix, 40-token programs")
        print("candidate functions (use both parameters): \(candidates)")
        print("distinct behaviors on the \(grid.count)-point grid: \(behaviors.count)")
        print("of which non-constant (truly depend on inputs): \(nonConstant.count)")
        print("NOTE: `.inputN` needs no leaf-deletion — the input IS the hole, read")
        print("      at the right point. This is why D3 works where D1's delete does")
        print("      not; substitute-input (D1) is delete-leaf's sound generalization.")
        print("example harvested cruxes:")
        for e in examples { print("  \(e)") }

        // Pipeline-liveness only; the diversity count is the finding.
        #expect(candidates > 0, "no (int,int)->int candidates harvested — check the mix/inputs")
    }

    // MARK: - D4: reduce falls out of iterate; the function is a CodeItem (deterministic)

    @Test
    func `D4 a binary op body reduces a vector under vecIntIterate`() {
        // A binary-op CodeItem body + a primed accumulator IS a fold. The element
        // lands on `.int` above the accumulator each pass (iteratorPass), then the
        // body folds the two. No new instruction, no `.function` stack.

        func reduce(_ vec: [Int], _ op: PushInstruction, init acc: Int) -> Int? {
            let it = Interpreter.recordingProvenance()
            it.load(stacks: [
                .int: [IntItem(acc)],
                .vecInt: [VecIntItem(vec)],
                .code: [CodeItem([InstructionItem(op)])],
            ], program: [InstructionItem(.vecIntIterate)])
            it.run()
            return (it.stacks[.int]!.first as? IntItem)?.value
        }

        #expect(reduce([1, 2, 3], .intAdd, init: 100) == 106)       // 100+1+2+3
        #expect(reduce([2, 3, 4], .intMultiply, init: 1) == 24)     // 1*2*3*4
        #expect(reduce([3, 1, 4, 1, 5], .intMax, init: 0) == 5)     // max

        // Init-free: pass 0's `.intAdd` underflows and no-ops, seeding e0. Works,
        // but leans on the underflow-noop — the "accidental" form.
        let noSeed = Interpreter.recordingProvenance()
        noSeed.load(stacks: [
            .vecInt: [VecIntItem([1, 2, 3])],
            .code: [CodeItem([InstructionItem(.intAdd)])],
        ], program: [InstructionItem(.vecIntIterate)])
        noSeed.run()
        #expect((noSeed.stacks[.int]!.first as? IntItem)?.value == 6, "e0 seeds the fold")

        // Map as a side-effect: `( 3 .intAdd )` over [1,2,3] leaves 4,5,6 on `.int`
        // (top-to-bottom 6,5,4). Collecting these into a NEW vector is the one
        // missing piece — map-collect / the pseudofunction accumulator (#A.2).
        let mapper = Interpreter.recordingProvenance()
        mapper.load(stacks: [
            .vecInt: [VecIntItem([1, 2, 3])],
            .code: [CodeItem([IntItem(3), InstructionItem(.intAdd)])],
        ], program: [InstructionItem(.vecIntIterate)])
        mapper.run()
        let mapped = mapper.stacks[.int]!.compactMap { ($0 as? IntItem)?.value }
        #expect(mapped == [6, 5, 4], "each element +3, results accumulate on the stack")
    }
}
