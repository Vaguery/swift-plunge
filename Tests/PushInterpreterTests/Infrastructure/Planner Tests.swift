//
//  Planner Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/16/26.
//
//  The Planner decides whether a Behavior may run and finds its arguments. Two
//  things are being tested here, and the second matters more than the first:
//
//  1. that a plan resolves requirements the way the language expects — in order,
//     claiming the topmost item nobody else has, counting a stack that is both
//     taken from and reached into only once;
//  2. that **a Behavior which cannot run takes nothing** — the all-or-nothing
//     bargain. That one used to be every Behavior's own to keep
//     by hand, and sixty of them failed to. It is now structural, so it is tested
//     structurally: the last test drives every instruction in the language.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct PlannerTests {

    func errorStrings(_ inty: Interpreter) -> [String] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.value }
    }

    /// Every stack's contents, rendered — a cheap way to say "nothing moved".
    func snapshot(_ inty: Interpreter) -> [PushStack: String] {
        var result = [PushStack: String]()
        for stack in PushStack.allCases where stack != .error {
            result[stack] = stackString(inty, stack)
        }
        return result
    }


    // MARK: - resolving

    /// Nothing is removed while planning, so the second `.int` cannot be found at
    /// index 0 — it is found at index 1, which is where a pair of pops would have
    /// left it. This is the whole reason claims carry an index.
    @Test func `requirements claim in order, topmost first`() {
        let inty = Interpreter()
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2), IntItem(3)] as [any Item])

        let plan = Planner(for: inty).plan([.takes(.int), .takes(.int)])

        guard case .ready(let arguments, let claims) = plan else {
            Issue.record("three ints is enough for two"); return
        }
        #expect((arguments[0] as? IntItem)?.value == 1)
        #expect((arguments[1] as? IntItem)?.value == 2)
        #expect(claims.map(\.index) == [0, 1])
        #expect(claims.map(\.consumed) == [true, true])
    }

    /// Planning reads. That is the point: an unsatisfiable Behavior must be able
    /// to discover it is unsatisfiable without paying for the discovery.
    @Test func `planning touches nothing, satisfied or not`() {
        let inty = Interpreter()
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2)] as [any Item])
        let before = snapshot(inty)

        _ = Planner(for: inty).plan([.takes(.int), .takes(.int)])
        #expect(snapshot(inty) == before, "a satisfied plan is still only a plan")

        _ = Planner(for: inty).plan([.takes(.int), .takes(.int), .takes(.int)])
        #expect(snapshot(inty) == before, "and a short plan pays nothing for looking")
    }

    /// `.needs` is the one that reaches without taking: it must find the item and
    /// then leave it exactly where it was.
    @Test func `a needed item is required but not consumed`() {
        let inty = Interpreter()
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2)] as [any Item])

        let planner = Planner(for: inty)
        guard case .ready(let arguments, let claims) = planner.plan([.takes(.int), .needs(.int, count: 1)])
        else { Issue.record("two ints is one taken and one needed"); return }

        // A needed item is not an argument — the Behavior never sees it.
        #expect(arguments.count == 1)
        planner.commit(claims)
        #expect(stackString(inty, .int) == "[ 2 ]", "the needed item stays where it sat")
    }

    /// The counts add, and they add because the claims stack up: the index is
    /// taken first, so the two it reaches for are at 1 and 2. One int is not
    /// three ints.
    @Test func `taking and needing the same stack adds up`() {
        let inty = Interpreter()
        let requirements: [Requirement] = [.takes(.int), .needs(.int, count: 2)]

        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2)] as [any Item])
        guard case .short(let stack) = Planner(for: inty).plan(requirements) else {
            Issue.record("two ints cannot serve a take and two needs"); return
        }
        #expect(stack == .int)

        inty.stacks[.int]!.prepend(IntItem(0))
        guard case .ready(_, let claims) = Planner(for: inty).plan(requirements) else {
            Issue.record("three ints is exactly enough"); return
        }
        #expect(claims.map(\.index) == [0, 1, 2])
        #expect(claims.map(\.consumed) == [true, false, false])
    }

    /// The requirement no static declaration could state — and the reason a
    /// planner is a planner rather than a tally. The count is a question asked of
    /// an argument that gathering has already resolved.
    @Test func `takesMany sizes itself from an earlier argument`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([9, 9, 9]))
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2), IntItem(3), IntItem(4)] as [any Item])

        let requirements: [Requirement] = [
            .takes(.vecInt),
            .takesMany(.int, count: { args in (args[0] as! VecIntItem).value.count })
        ]
        let planner = Planner(for: inty)
        guard case .ready(let arguments, let claims) = planner.plan(requirements) else {
            Issue.record("a 3-vector wants 3 of the 4 ints"); return
        }
        #expect(arguments.count == 4)
        planner.commit(claims)
        #expect(stackString(inty, .int) == "[ 4 ]", "it took exactly three, off the top")
    }

    /// The same requirements, one int short: it must refuse, and refusing must
    /// cost nothing — including the vector it had already resolved.
    @Test func `a short takesMany gives back the argument it had already found`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([9, 9, 9]))
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2)] as [any Item])
        let before = snapshot(inty)

        let plan = Planner(for: inty).plan([
            .takes(.vecInt),
            .takesMany(.int, count: { args in (args[0] as! VecIntItem).value.count })
        ])

        guard case .short(let stack) = plan else { Issue.record("two ints is not three"); return }
        #expect(stack == .int, "the vector was there; the ints were not")
        #expect(snapshot(inty) == before)
    }

    /// Commit removes deepest-first. Shallow-first would shift a deeper claim out
    /// from under itself and take the wrong item — the bug this ordering exists to
    /// prevent, on the stack where it would be invisible (every int looks alike
    /// until you check *which* ints are left).
    @Test func `commit removes the items it claimed and no others`() {
        let inty = Interpreter()
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2), IntItem(3), IntItem(4)] as [any Item])
        inty.stacks[.bool]!.prepend(contentsOf: [BoolItem(true), BoolItem(false)] as [any Item])

        let planner = Planner(for: inty)
        guard case .ready(_, let claims) = planner.plan([.takes(.int), .takes(.bool), .takes(.int)])
        else { Issue.record("all present"); return }
        planner.commit(claims)

        #expect(stackString(inty, .int) == "[ 3 4 ]")
        #expect(stackString(inty, .bool) == "[ false ]")
    }


    // MARK: - what a Behavior does with a plan

    /// The refusal names the stack it stopped at. Before the Planner, an error
    /// could only say that *something* was missing.
    @Test func `a refusal names the stack that came up short`() {
        let inty = Interpreter()
        inty.stacks[.int]!.prepend(IntItem(7))

        Interpreter.language[.intAdd]!.act(on: inty)
        #expect(errorStrings(inty) == ["intAdd missing args: .int"])

        // A Behavior short of a stack it never popped says so just as plainly.
        let other = Interpreter()
        other.stacks[.int]!.prepend(IntItem(0))
        Interpreter.language[.doubleYank]!.act(on: other)
        #expect(errorStrings(other) == ["doubleYank missing args: .double"],
                "it had its index; it had no doubles to yank")
    }

    /// `.vecIntConstruct` is the instruction the planner was built for, so it is
    /// worth watching it refuse: the shape is present, the scalars are not, and
    /// the shape is still there afterwards.
    @Test func `a dynamic requirement refuses like any other`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([9, 9, 9]))
        inty.stacks[.int]!.prepend(contentsOf: [IntItem(1), IntItem(2)] as [any Item])

        #expect(Interpreter.language[.vecIntConstruct]!.isSatisfied(by: inty) == false,
                "isSatisfied can now see a need no constant could state")

        Interpreter.language[.vecIntConstruct]!.act(on: inty)

        #expect(errorStrings(inty) == ["vecIntConstruct missing args: .int"])
        #expect(stackString(inty, .vecInt) == "[ [9, 9, 9] ]", "it did not eat its template")
        #expect(stackString(inty, .int) == "[ 1 2 ]")
    }

    /// **The all-or-nothing bargain, for the whole language at once.**
    ///
    /// Sixty behaviors once popped an index, found an empty stack, and errored
    /// having already eaten the argument. That was possible because each Behavior
    /// kept the bargain by hand. Now `act` plans before it commits, so the bargain
    /// is structural — and a structural property can be tested structurally rather
    /// than sixty times by hand.
    ///
    /// For every instruction, and every stack it draws on, this builds a state
    /// that is short on that stack and generous everywhere else, then runs it. Any
    /// instruction that says "missing args" must leave every stack but `.error`
    /// exactly as it found it.
    @Test func `no behavior in the language takes anything when it refuses`() {
        let robustness = InterpreterRobustnessTests()
        var refusals = 0

        for (instruction, behavior) in Interpreter.language {
            for starved in behavior.staticNeeds.keys {
                for depth in 0..<2 {
                    let inty = Interpreter()
                    for stack in PushStack.allCases where stack != .error {
                        let count = stack == starved ? depth : 4
                        for _ in 0..<count {
                            inty.stacks[stack]!.prepend(robustness.sample(for: stack))
                        }
                    }
                    let before = snapshot(inty)

                    behavior.act(on: inty)

                    let blamed = errorStrings(inty).first { $0.contains("missing args") }
                    guard let blamed else { continue }
                    refusals += 1

                    #expect(snapshot(inty) == before,
                            "\(instruction) refused but changed a stack: \(blamed)")
                    #expect(blamed.hasPrefix("\(instruction) missing args: ."))
                    // The blame must be a stack the instruction actually declared: one it
                    // needs, or, for a lookup's miss, one it observes.
                    let declared = (Array(behavior.staticNeeds.keys) + behavior.observes).map { ".\($0)" }
                    let named = declared.filter { blamed.hasSuffix($0) }
                    #expect(!named.isEmpty,
                            "\(instruction) blamed a stack it never declared: \(blamed)")
                }
            }
        }
        #expect(refusals > 100, "a sweep this starved should have provoked plenty of refusals")
    }
}
