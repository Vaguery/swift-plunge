//
//  Crux RoundTrip Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/15/26.
//
//  The crux's one obligation, checked by actually doing it:
//
//      running an item's crux on a fresh interpreter reproduces that item's
//      value, on that item's stack.
//
//  The per-Behavior unit tests assert the literal `call` each Behavior records.
//  That pins against regression, but it cannot tell you the record is *true* —
//  an expectation written by reading the code transcribes whatever the code says,
//  bug and all. That is not hypothetical: `charGTE` recorded `.charGT`,
//  `stringReplaceChar` recorded a two-argument instruction for a three-argument
//  behavior, and `stringReplaceFirst` recorded the replace-all instruction. Only
//  re-running the reconstruction catches that class.
//
//  So this file re-runs it. Slow, and deliberately so — it sweeps the whole
//  language, which means new instructions are covered the day they are added.
//

import DequeModule
import Foundation
import Testing
@testable import PushInterpreter


// MARK: - The shared check

/// Whether an item's claim is one the language provably cannot honour yet, so
/// checking it would only re-find a gap already pinned by
/// `CruxRoundTripTests.knownGapsPendingCodeItemChange`.
///
/// That set is now empty, so this skips nothing — kept as the seam where a future
/// known gap would be declared, and because leaving it means the fuzzer reports a
/// skip count that must stay at zero.
///
/// It used to skip two shapes, both closed by the CodeItem change:
/// cruxes leaning on `execEq` (whose postfix `call` could not reach `.exec`
/// arguments; `execEq` has since been removed), and bare code blocks (which
/// scattered onto `.exec` instead of reaching `.code` — now they come to rest
/// there intact, so a block genuinely *is* its own crux).
@MainActor
func blockedByCodeItemModel(_ item: any Item) -> Bool {
    let names = item.crux().compactMap { ($0 as? InstructionItem)?.value }
    return names.contains(where: CruxRoundTripTests.knownGapsPendingCodeItemChange.contains)
}


/// `brokenClaim` and the whole crux-checking apparatus now live in
/// `DiagnosticTools/CruxDiagnostics.swift`, so that one place decides what
/// "broken" means for both this file's assertions and any exploratory sweep.
///
/// Read `inspectCrux` there before trusting a clean result from anything in this
/// file: it distinguishes a claim that *holds* from one that could not be checked
/// because the reconstruction ran out of steps, and `brokenClaim` — being a
/// pass/fail face — reports the second as nil.


@Suite @MainActor
struct CruxRoundTripTests {


    /// Deterministic, plausible arguments for a stack. Small non-negative ints
    /// because so many behaviors read one as an index or a count; strings with a
    /// space in them so `stringSplit` has something to do.
    func synthetic(for stack: PushStack, _ n: Int) -> (any Item)? {
        switch stack {
        case .bool:      BoolItem(n % 2 == 0)
        case .int:       IntItem(n + 1)
        case .double:    DoubleItem(Double(n) + 1.5)
        case .char:      CharItem(Character(UnicodeScalar(97 + UInt8(n % 26))))
        case .string:    StringItem(["ab cd", "ef", "ghi jk"][n % 3])
        case .code:      CodeItem([IntItem(n + 1), IntItem(n + 2)])
        case .exec:      IntItem(n + 100)
        case .vecBool:   VecBoolItem([true, false, true])
        case .vecInt:    VecIntItem([n + 1, n + 2, n + 3])
        case .vecDouble: VecDoubleItem([1.5, 2.5, 3.5])
        case .vecString: VecStringItem(["pq", "rs", "tu"])
        case .iterator:  IteratorItem(
                            kind: .counting(stride: 1),
                            origin: IntItem(n),
                            destination: IntItem(n + 5),
                            body: CodeItem([IntItem(n + 1)]),
                            emits: true,
                            cursor: n % 3
                         )
        case .error:     nil   // never seeded; never checked
        }
    }

    /// Bindings every `.inputN` / typed constant resolves to, so behaviors that
    /// read them produce a value rather than an ErrorItem — and so a crux naming
    /// `.input3` can be re-run against the same binding.
    var bindings: (inputs: [PushInstruction: any Item], constants: [PushInstruction: any Item]) {
        var inputs: [PushInstruction: any Item] = [:]
        for i in 0..<10 {
            inputs[PushInstruction(rawValue: "input\(i)")!] = IntItem(i * 11)
        }
        var constants: [PushInstruction: any Item] = [:]
        for stack in [PushStack.int, .double, .string, .char, .vecInt, .vecDouble, .vecString, .vecBool] {
            for i in 0..<10 {
                if let name = PushInstruction(rawValue: "\(stack)\(i)"),
                   let value = synthetic(for: stack, i) {
                    constants[name] = value
                }
            }
        }
        return (inputs, constants)
    }

    /// A fresh interpreter with every stack seeded several deep. Generous on
    /// purpose: combinators peek below their arguments, and a behavior that
    /// cannot find its arguments produces only an ErrorItem, which tests
    /// nothing.
    func seeded(depth: Int = 4) -> Interpreter {
        let inty = Interpreter.recordingProvenance()
        let (inputs, constants) = bindings
        var initial: [PushStack: [any Item]] = [:]
        for stack in PushStack.allStacks where stack != .error {
            initial[stack] = (0..<depth).compactMap { synthetic(for: stack, $0) }
        }
        inty.load(inputs: inputs, constants: constants, stacks: initial)
        return inty
    }

    /// Runs `crux` on a clean interpreter (same bindings) and returns whatever
    /// comes to rest on `stack`.
    func reproduce(_ crux: [any Item], on stack: PushStack) -> (any Item)? {
        let redo = Interpreter.recordingProvenance()
        let (inputs, constants) = bindings
        // Relaxed caps, as `brokenClaim` uses: a reconstruction is one individual
        // explaining itself, not a population competing for throughput.
        redo.config = redo.config.reconstructing
        redo.config.stepLimit = 10_000
        redo.load(inputs: inputs, constants: constants, program: crux)
        redo.run(stepLimit: 10_000)
        return redo.stacks[stack]!.first
    }

    /// Every item a behavior left behind that makes a provenance claim worth
    /// checking: it records a `call`, and it has a stack to come to rest on.
    ///
    /// Skipping `defaultStack == nil` now skips only instruction tokens, which
    /// execute rather than land. It used to skip `IteratorItem` too, back when it
    /// was provenance-only; the type became first-class and this sweep picked it
    /// up automatically, exactly as intended.
    func claimsWorthChecking(in inty: Interpreter) -> [(item: any Item, stack: PushStack)] {
        var found: [(any Item, PushStack)] = []
        for stack in PushStack.allStacks where stack != .error {
            for item in inty.stacks[stack]! {
                guard !item.call.isEmpty,
                      let resting = PushStack.defaultStack(for: item)
                else { continue }
                found.append((item, resting))
            }
        }
        return found
    }


    /// Behaviors whose crux provably cannot round-trip. **Empty, and worth
    /// keeping that way.**
    ///
    /// It held five entries until the CodeItem change landed, and all five closed
    /// at once:
    ///
    /// - `codeAppend`, `codeEq`, `codeItemIsEmpty`, `codeWrapRoot` — a bare code
    ///   block used not to be its own crux. `crux()` returns `[self]` for an empty
    ///   `call`, and for every scalar that literal reproduces the value; a
    ///   `CodeItem` was the exception, because a block in a program unwrapped onto
    ///   `.exec` and scattered instead of reaching `.code`. Now it comes to rest
    ///   there intact, and `( 2 3 ) ( 1 2 ) .codeAppend` finds what it needs.
    /// - `execEq` — its crux had to be **prefix** (provenance law 3b), which
    ///   reproduced single-item operands only. It was removed (Roadmap #26):
    ///   `( A ) ( B ) .codeEq` asks the same question.
    ///
    /// Both halves of the assertion below matter: this fails if the set grows
    /// *and* if an entry silently starts passing. That is how the change was
    /// confirmed — the "these now round-trip" branch fired for all five.
    static let knownGapsPendingCodeItemChange: Set<PushInstruction> = []


    /// The sweep. Every registered behavior, driven with synthetic arguments;
    /// every resulting provenance claim re-run and checked.
    ///
    /// `pretty()` is the comparison rather than `==` deliberately: `==` compares
    /// `call` too, and a reproduced item legitimately carries different
    /// provenance from the original. The claim is about the *value*.
    @Test func `every behavior's recorded provenance reproduces its value`() {
        var checked = 0
        var behaviorsWithClaims = 0
        var broken: Set<PushInstruction> = []
        var detail: [String] = []

        for name in Interpreter.language.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let inty = seeded()
            Interpreter.language[name]!.act(on: inty)

            let claims = claimsWorthChecking(in: inty)
            if !claims.isEmpty { behaviorsWithClaims += 1 }

            for (item, resting) in claims {
                checked += 1
                let crux = item.crux()
                let reproduced = reproduce(crux, on: resting)
                if reproduced?.pretty() != item.pretty() {
                    broken.insert(name)
                    detail.append(
                        """
                        .\(name) → \(resting) item \(item.pretty())
                            crux: \(CodeItem(crux).pretty())
                            reproduced: \(reproduced?.pretty() ?? "nothing")
                        """
                    )
                }
            }
        }

        print("crux round-trip: \(checked) claims across \(behaviorsWithClaims) behaviors "
              + "(of \(Interpreter.language.count) registered); \(broken.count) behaviors failed")

        let unexpected = broken.subtracting(Self.knownGapsPendingCodeItemChange)
        let fixed = Self.knownGapsPendingCodeItemChange.subtracting(broken)

        for line in detail where unexpected.contains(where: { line.hasPrefix(".\($0) ") }) {
            print(line)
        }

        let unexpectedNames = unexpected.map(\.rawValue).sorted().joined(separator: ", ")
        let fixedNames = fixed.map(\.rawValue).sorted().joined(separator: ", ")
        #expect(unexpected.isEmpty,
                "these record provenance that does not reproduce their value: \(unexpectedNames)")
        #expect(fixed.isEmpty,
                "these now round-trip — has the CodeItem change landed? remove them from knownGapsPendingCodeItemChange: \(fixedNames)")
        // Guards the sweep itself: if seeding silently stopped satisfying
        // behaviors, the checks above would pass while testing nothing.
        #expect(checked > 300, "sweep only checked \(checked) claims — is the seeding still working?")
    }
}


/// The same obligation, but against whole random programs rather than one
/// behavior at a time.
///
/// The per-behavior sweep drives each instruction once, in isolation, from clean
/// synthetic arguments. Real programs are where provenance actually gets hard:
/// values pass through loops, combinators shuffle them between positions, code
/// blocks are rearranged and duplicated, and an item's history ends up woven from
/// dozens of instructions that ran nowhere near each other. This runs programs to
/// completion and then asks every survivor on every stack to prove its history.
///
/// Architecturally a sibling of `Stress_Tests.random programs run`: same seeded
/// RNG (logged, so any run reproduces exactly), same replayable-JSON-on-failure
/// approach. What differs is what it watches for. The fuzzer watches for
/// overflows, errors, and blow-ups; this watches for provenance that lies.
@Suite @MainActor
struct CruxFuzzTests {

    // nonisolated so the `.disabled(if:)` trait can read it from the @Test
    // macro's Sendable context under Swift 6 language mode
    //
    // Disabled by default, like every other fuzz test here — and for a reason
    // worth knowing rather than by convention alone. `fuzzRNG` is a
    // `nonisolated(unsafe)` global, and Swift Testing runs suites in parallel, so
    // any other enabled test that draws from it (today: `Stress_Tests.set random
    // constants works`, via `setRandomConstants`) consumes this test's stream
    // mid-generation. Left enabled it is not reproducible: observed runs drew
    // 21,123 claims and 17,016 from the same seed.
    //
    // To run it (~2s): set this false AND run it alone —
    // `swift test --filter CruxFuzzTests` — because a filter alone only skips it,
    // and running it alongside the suite is what breaks the seed.
    //
    // The deterministic half of this file, the per-Behavior sweep above, needs no
    // RNG and stays enabled.
    nonisolated static let disabledTests = true

    /// Replaces the old `random programs produce legible cruxes`, which printed
    /// cruxes for a human to eyeball and asserted nothing.
    @Test(.disabled(if: CruxFuzzTests.disabledTests))
    func `every item a random program leaves has a runnable crux`() {
        // Reproduces exactly when this test runs alone; see the note on
        // `disabledTests` for why that qualifier is load-bearing. Failing cases
        // are written to disk as replayable JSON regardless, which is the
        // reproduction path that does not depend on the RNG.
        // **Several seeds, not one.** A single seed is not enough to see a rare
        // class: the #27 failures ran about 1 in 1,900 claims, and this test on
        // seed 20_260_715 alone reported zero while a 40-seed sweep found 95.
        // Seeds are spaced by a prime so consecutive streams do not overlap.
        let seeds: [UInt64] = (0..<8).map { 20_260_715 &+ $0 &* 7919 }
        let cases = 20            // random programs per seed
        let programItems = 150    // Plushy tokens per random genome

        var settings = InterpreterSettings.recordingProvenance   // it checks cruxes
        settings.stepLimit = 3_000

        let dir = FileManager.default.temporaryDirectory.appending(path: "push-crux-fuzz")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()

        func log(_ message: String) { print(message); fflush(stdout) }

        var itemsChecked = 0
        var skipped = 0
        var programsWithClaims = 0
        var findings: [String] = []

        for (seedIndex, seed) in seeds.enumerated() {
            fuzzRNG = SeededRNG(seed: seed)
            for caseIndex in 0..<cases {
                let caseId = "crux-\(seedIndex)-\(caseIndex)"
                let program = FibonacciGenome.translate(RandomCode.randomProgram(programItems))

                let inty = Interpreter.recordingProvenance()
                inty.config = settings
                inty.load(program: program)
                RandomCode.setRandomInputs(in: inty)
                RandomCode.setRandomConstants(in: inty)
                let inputs = inty.inputs
                let constants = inty.constants
                inty.run(stepLimit: settings.stepLimit)

                var claimsHere = 0
                var brokenHere: [String] = []
                for stack in PushStack.allStacks where stack != .error {
                    for item in inty.stacks[stack]! {
                        guard !item.call.isEmpty,
                              PushStack.defaultStack(for: item) != nil
                        else { continue }
                        guard !blockedByCodeItemModel(item) else { skipped += 1; continue }
                        claimsHere += 1
                        itemsChecked += 1
                        if let why = brokenClaim(
                            about: item, inputs: inputs, constants: constants, settings: settings
                        ) {
                            brokenHere.append("  .\(stack) \(item.pretty()): \(why)\n     crux: \(CodeItem(item.crux()).pretty())")
                        }
                    }
                }
                if claimsHere > 0 { programsWithClaims += 1 }

                if !brokenHere.isEmpty {
                    // Written to disk before reporting, so a case survives even if a
                    // later one takes the process down.
                    let individual = Individual(id: caseId, program: program, constants: constants)
                    let request = EvaluationRequest(
                        individuals: [individual],
                        trainingCases: [TrainingCase(id: caseId, inputs: inputs)],
                        pairings: [Pairing(individual: caseId, trainingCase: caseId)],
                        configuration: RunnerConfiguration(settings: settings)
                    )
                    let url = dir.appending(path: "\(caseId).json")
                    try? encoder.encode(request).write(to: url)
                    findings.append(
                        "\(caseId): \(brokenHere.count) of \(claimsHere) claims broken → \(url.path)\n"
                        + brokenHere.prefix(5).joined(separator: "\n")
                    )
                }
            }
        }

        log("crux fuzz (\(seeds.count) seeds × \(cases)): \(itemsChecked) claims across "
            + "\(programsWithClaims)/\(seeds.count * cases) programs; \(findings.count) programs with broken claims "
            + "(\(skipped) skipped, blocked on the CodeItem model)")
        for finding in findings.prefix(10) { log(finding) }
        if findings.count > 10 { log("… and \(findings.count - 10) more") }

        #expect(findings.isEmpty, "\(findings.count) random programs left items whose crux does not reproduce them")
        // Guards the test itself: a generator change that stopped producing
        // provenance would make the check above vacuous.
        #expect(itemsChecked > 100, "only \(itemsChecked) claims checked — is the generator still producing provenance?")
    }
}
