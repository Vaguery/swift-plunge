//
//  Interpreter Robustness Tests.swift
//  PlungeTests
//
//  Coverage + edge-case tests supporting Proposal A:
//   - every registered Behavior runs its transform through the validated push
//     gate without tripping the stack-type invariant;
//   - an instruction with no registered behavior routes to .error instead of
//     trapping the interpreter loop.
//

@testable import Plunge
import Testing
import DequeModule

@Suite @MainActor
struct InterpreterRobustnessTests {

    /// A benign, well-typed representative Item for each stack, used to satisfy
    /// any behavior's argument needs (and to seed stacks that behaviors read
    /// directly, e.g. combinators) so the transform actually runs.
    func sample(for stack: PushStack) -> any Item {
        switch stack {
        case .bool:      return BoolItem(false)
        case .int:       return IntItem(1)
        case .double:    return DoubleItem(1.0)
        case .char:      return CharItem(Character("a"))
        case .string:    return StringItem("x")
        case .code:      return CodeItem([BoolItem(false)])
        case .vecBool:   return VecBoolItem([false, true])
        case .vecInt:    return VecIntItem([1, 2, 3])
        case .vecDouble: return VecDoubleItem([1.0, 2.0])
        case .vecString: return VecStringItem(["a", "b"])
        case .iterator:  return IteratorItem(
                            kind: .counting(stride: 1),
                            origin: IntItem(0),
                            destination: IntItem(3),
                            body: CodeItem([BoolItem(false)]),
                            emits: true
                         )
        case .exec:      return BoolItem(false)
        case .binding:       return BindingItem(key: 1, bound: StringItem("r"))
        case .error:     return ErrorItem("x")
        }
    }

    /// Drives every behavior in the language once. Each stack is seeded with
    /// several well-typed items so both the declared arguments and any direct
    /// stack reads are satisfied. If any behavior emitted a mis-tagged Router,
    /// `push(_:to:)` would fatalError — so reaching the end of the loop is the
    /// assertion that the whole language honors the stack-type invariant.
    @Test func `every behavior honors the stack-type invariant`() {
        #expect(!Interpreter.language.isEmpty)

        for (_, behavior) in Interpreter.language {
            let inty = Interpreter()
            for stack in PushStack.allCases where stack != .error {
                for _ in 0..<5 {
                    inty.stacks[stack]!.prepend(sample(for: stack))
                }
            }
            behavior.act(on: inty)
        }
    }

    /// An enumerated instruction with no registered behavior must be reported,
    /// not crash the step loop.
    @Test func `unknown instruction routes to error`() {
        let inty = Interpreter()
        // remove a behavior to simulate an unimplemented / de-registered one
        inty.behaviors[.intAdd] = nil
        inty.stacks[.exec]!.prepend(InstructionItem(.intAdd))

        inty.step()

        #expect(stackString(inty, .error).contains("intAdd is an unknown instruction"))
    }

    /// When a behavior's argument needs aren't met, its plan is `.short` and
    /// `act` must route a "missing args" ErrorItem — without consuming the
    /// arguments that *are* present. Exercises the `guard let … else` branch of
    /// `act` (formerly the `isMissingArgs` flag), which no other test reaches.
    @Test func `missing args routes to error`() {
        let inty = Interpreter()
        // .intAdd needs two ints; give it only one.
        inty.stacks[.int]!.prepend(IntItem(7))

        Interpreter.language[.intAdd]!.act(on: inty)

        #expect(stackString(inty, .error).contains("intAdd missing args"))
        // the lone argument is left untouched (a plan that fails commits nothing)
        #expect(inty.stacks[.int]!.count == 1)
        #expect((inty.stacks[.int]!.first as? IntItem)?.value == 7)
    }

    /// The language table is a build-once `static let`, so every access returns
    /// the *same* shared `Behavior` objects and every interpreter sees them.
    /// Under the former computed `static var` this identity check would fail —
    /// it is the assertion that actually pins the build-once/sharing contract.
    @Test func `language is built once and shared across interpreters`() {
        let first = Interpreter.language[.intAdd]
        let second = Interpreter.language[.intAdd]
        #expect(first === second)

        let a = Interpreter()
        let b = Interpreter()
        #expect(a.behaviors[.intAdd] === b.behaviors[.intAdd])
        #expect(a.behaviors[.intAdd] === Interpreter.language[.intAdd])
    }

    /// Reentrancy guard — the payoff of the nonisolated + Sendable conversion.
    /// Runs the single shared language table across many interpreters *truly
    /// concurrently* (each child task runs off the main actor on its own
    /// nonisolated `Interpreter`) and confirms every result is correct. If any
    /// Behavior held per-invocation mutable state, concurrent runs would corrupt
    /// each other's operands and some sums would be wrong. Distinct operands per
    /// interpreter make such a race detectable.
    @Test func `shared language is reentrant across concurrent interpreters`() async {
        let count = 200

        let results = await withTaskGroup(of: (index: Int, sum: Int).self) { group in
            for i in 0..<count {
                group.addTask {
                    let inty = Interpreter()
                    let (a, b) = (i, i * 3)
                    inty.run(
                        inputs: [:],
                        stacks: [:],
                        program: [IntItem(a), IntItem(b), InstructionItem(.intAdd)]
                    )
                    let top = (inty.stacks[.int]?.first as? IntItem)?.value ?? Int.min
                    return (index: i, sum: top)
                }
            }
            var collected: [(index: Int, sum: Int)] = []
            for await r in group { collected.append(r) }
            return collected
        }

        #expect(results.count == count)
        for (i, sum) in results {
            #expect(sum == i + i * 3)
        }
    }
}
