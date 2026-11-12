//
//  Pair Sieve Tests.swift
//  PlungeTests
//
//  The sieve used for pairs (2026-11-12): an element-wise operation takes the
//  top collection, then the first one below it with the same length
//  (`Behavior.sameLength`), consuming (`.takesFirst`) or reading and leaving
//  (`.readsFirst`). Also the `.nth` recorder target, for several results on one
//  stack.
//

@testable import Plunge
import Testing

@Suite
struct PairSieveTests {

    static let sameLength: Requirement = .takesFirst(.vecInt) { Behavior.sameLength($0, $1[0]) }
    static let readsSameLength: Requirement = .readsFirst(.vecInt) { Behavior.sameLength($0, $1[0]) }

    /// `[top, between, partner, bottom]` on `.vecInt`, top first.
    static func stacked() -> Interpreter {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([1, 2]), VecIntItem([7]), VecIntItem([3, 4]),
                                                   VecIntItem([5, 6])] as [any Item])
        return inty
    }

    @Test func `the partner is the first same-length vector below the top`() {
        let inty = Self.stacked()
        let planner = Planner(for: inty)
        guard case .ready(let arguments, let claims) = planner.plan([.takes(.vecInt), Self.sameLength]) else {
            Issue.record("[3, 4] matches [1, 2]"); return
        }
        #expect(arguments.map { $0.pretty() } == ["[1, 2]", "[3, 4]"])
        #expect(claims.map(\.index) == [0, 2])
        planner.commit(claims)
        #expect(stackString(inty, .vecInt) == "[ [7] [5, 6] ]", "the shorter vector between is left")
    }

    @Test func `a later take skips the sieved partner`() {
        let inty = Self.stacked()
        guard case .ready(let arguments, let claims) =
                Planner(for: inty).plan([.takes(.vecInt), Self.sameLength, .takes(.vecInt), .takes(.vecInt)])
        else { Issue.record("four vectors serve all four"); return }
        #expect(arguments.map { $0.pretty() } == ["[1, 2]", "[3, 4]", "[7]", "[5, 6]"])
        #expect(claims.map(\.index) == [0, 2, 1, 3])
    }

    @Test func `no same-length vector is a miss, a lone vector is short`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([1, 2]), VecIntItem([7])] as [any Item])
        guard case .miss(.vecInt, let claims) = Planner(for: inty).plan([.takes(.vecInt), Self.sameLength]) else {
            Issue.record("[7] does not match [1, 2]"); return
        }
        #expect(claims.map(\.index) == [0], "the top is still claimed")
        let lone = Interpreter()
        lone.stacks[.vecInt]!.prepend(VecIntItem([1, 2]))
        guard case .short(.vecInt) = Planner(for: lone).plan([.takes(.vecInt), Self.sameLength]) else {
            Issue.record("one vector is short of a pair"); return
        }
    }

    @Test func `a read sieve leaves its partner, and its miss takes nothing it read`() {
        let inty = Self.stacked()
        let planner = Planner(for: inty)
        guard case .ready(let arguments, let claims) = planner.plan([.reads(.vecInt), Self.readsSameLength]) else {
            Issue.record("[3, 4] matches [1, 2]"); return
        }
        #expect(arguments.map { $0.pretty() } == ["[1, 2]", "[3, 4]"])
        #expect(claims.map(\.consumed) == [false, false])
        planner.commit(claims)
        #expect(inty.stacks[.vecInt]!.count == 4, "a read takes nothing")

        let unmatched = Interpreter()
        unmatched.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([1, 2]), VecIntItem([7])] as [any Item])
        guard case .miss(.vecInt, let missClaims) =
                Planner(for: unmatched).plan([.reads(.vecInt), Self.readsSameLength]) else {
            Issue.record("[7] does not match [1, 2]"); return
        }
        Planner(for: unmatched).commit(missClaims)
        #expect(unmatched.stacks[.vecInt]!.count == 2)
    }

    /// A typed operation declared `pairedBy:` sieves its second argument, and its
    /// result's crux writes the pair adjacent, where a replay's sieve finds it
    /// first.
    @Test func `a paired operation finds its partner and replays`() {
        let add = Behavior.operation(.vecIntConcat, takes: VecIntItem.self, VecIntItem.self, gives: VecIntItem.self,
                                     pairedBy: Behavior.sameLength) { a, b in zip(a, b).map { $0 + $1 } }
        let inty = Interpreter.recordingProvenance()
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([1, 2]), VecIntItem([7]), VecIntItem([10, 20])]
                                      as [any Item])
        add.act(on: inty)
        #expect(stackString(inty, .vecInt) == "[ [11, 22] [7] ]")
        let result = inty.stacks[.vecInt]!.first!
        #expect(CodeItem(result.crux()).pretty() == "( [10, 20] [1, 2] .vecIntConcat )",
                "written order: the deeper partner first")
    }

    @Test func `the nth recorder reads any depth`() {
        let inty = Interpreter()
        inty.addRecorder(RecorderSpec("third", observing: .nth(.int, depth: 2), keeping: .finalOnly))
        inty.addRecorder(RecorderSpec("tenth", observing: .nth(.int, depth: 9), keeping: .finalOnly))
        inty.load(program: [IntItem(1), IntItem(2), IntItem(3), IntItem(4)])
        inty.run(stepLimit: 100)
        #expect((inty.recordedData("third")?.last as? IntItem)?.value == 2)
        #expect(inty.recordedData("tenth")?.last as? IntItem == nil)
    }
}
