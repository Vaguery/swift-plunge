//
//  Error Tally Tests.swift
//  PlungeTests
//
//  The `errorCount*` instructions read a lazy per-kind tally
//  (`StackSet.errorCount(of:)`) instead of scanning `.error`, which is unbounded
//  and made two stress-run programs take minutes. The tally is only right if
//  every way `.error` changes is one it accounts for, so these hold it to a full
//  recount: mid-run, across reuse of one interpreter, and after direct writes.
//

@testable import Plunge
import DequeModule
import Testing

@Suite
struct ErrorTallyTests {

    func recount(_ inty: Interpreter, _ kind: ErrorKind) -> Int {
        inty.stacks[.error]!.count { ($0 as? ErrorItem)?.kind == kind }
    }

    func expectTallyMatches(_ inty: Interpreter, _ context: String) {
        for kind in ErrorKind.allCases {
            #expect(inty.stacks.errorCount(of: kind) == recount(inty, kind), "\(kind) \(context)")
        }
    }

    /// The 200 benchmark programs, all run on **one** interpreter (so `load`'s
    /// reset is exercised), with the tally queried every few steps.
    @Test func `the tally matches a recount through random runs`() {
        let inty = Interpreter()
        inty.config = ThroughputBenchmark().searchSettings(recordsProvenance: false)
        var queries = 0
        for (index, program) in ThroughputBenchmark().benchmarkPrograms().enumerated() {
            inty.load(program: program)
            inty.recomputeLiveWeight()
            while inty.counter < inty.config.stepLimit && !inty.stacks[.exec]!.isEmpty {
                inty.step()
                if inty.counter % 37 == 0 {
                    expectTallyMatches(inty, "program \(index), step \(inty.counter)")
                    queries += 1
                }
            }
            expectTallyMatches(inty, "program \(index), end")
        }
        #expect(queries > 1_000)
    }

    @Test func `reset, direct writes and clearing start the tally over`() {
        let inty = Interpreter()
        for _ in 0..<5 { inty.place(ErrorItem("starved", kind: .missingArgument), on: .error) }
        #expect(inty.stacks.errorCount(of: .missingArgument) == 5)

        inty.reset()
        inty.place(ErrorItem("starved", kind: .missingArgument), on: .error)
        #expect(inty.stacks.errorCount(of: .missingArgument) == 1)

        // A wholesale assignment of the slot, as tests do, longer than before.
        inty.stacks[.error] = Deque((0..<8).map { _ in ErrorItem("no input", kind: .missingInput) })
        expectTallyMatches(inty, "after assigning .error")

        inty.clear(.error)
        expectTallyMatches(inty, "after clearing .error")
        inty.place(ErrorItem("x", kind: .other), on: .error)
        expectTallyMatches(inty, "after clearing and pushing")
    }

    @Test func `the instructions report the tally`() {
        let inty = Interpreter()
        inty.load(program: [InstructionItem(.intAdd), InstructionItem(.intAdd), InstructionItem(.input3),
                            InstructionItem(.errorMissingArgCount), InstructionItem(.errorMissingInputCount),
                            InstructionItem(.boolAnd), InstructionItem(.errorMissingArgCount)])
        inty.run()
        #expect(inty.stacks[.int]!.compactMap { ($0 as? IntItem)?.value } == [3, 1, 2])
    }
}
