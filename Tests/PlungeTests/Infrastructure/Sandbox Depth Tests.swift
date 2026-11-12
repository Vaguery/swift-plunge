//
//  Sandbox Depth Tests.swift
//  PlungeTests
//
//  A map, an iterator body or a derivation runs in a sandbox, and a sandbox can
//  start another. Every level is a chain of stack frames, and these tests run on
//  concurrency worker threads, whose stacks are small: unoptimized, one overflowed
//  between 80 and 160 levels. `Interpreter.maxSandboxDepth` refuses past 50.
//

@testable import Plunge
import Testing

@Suite
struct SandboxDepthTests {

    /// An iterator map whose body runs an iterator map, `depth` deep.
    static func nestedIteratorMaps(_ depth: Int) -> [any Item] {
        var body: [any Item] = [IntItem(1), InstructionItem(.intAdd)]
        for _ in 0..<depth {
            body = [VecIntItem([1]), CodeItem(body), InstructionItem(.iteratorOverVecInt),
                    InstructionItem(.vecFromIterator)]
        }
        return body
    }

    @Test func `nesting far past the limit is refused, not a crash`() {
        let inty = Interpreter()
        inty.load(program: Self.nestedIteratorMaps(300))
        inty.run()
        #expect(inty.stacks[.exec]!.isEmpty, "the run finished")
    }

    @Test func `a run at the limit starts no sandbox`() {
        let inty = Interpreter()
        inty.sandboxDepth = Interpreter.maxSandboxDepth
        inty.load(program: Self.nestedIteratorMaps(1))
        inty.run()
        #expect(inty.stacks[.error]!.contains { $0.pretty().contains("nested past") })
        let shallow = Interpreter()
        shallow.load(program: Self.nestedIteratorMaps(1))
        shallow.run()
        #expect(stackString(shallow, .vecInt) == "[ [2] ]", "one level below it maps as usual")
    }
}
