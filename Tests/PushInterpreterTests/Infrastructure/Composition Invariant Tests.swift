//
//  Composition Invariant Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/17/26.
//
//  **A crux fragment leaves its value and nothing else, on any stack.**
//
//  This is the property that makes `crux()` compose: it flattens a call tree into
//  one postfix program by concatenating fragments, which is only correct if each
//  fragment leaves exactly its own value where the next instruction expects it.
//  "Sieve arguments.md" flags this as an untested accident (its question 4) and
//  recommends promoting it to a tested rule "regardless" — non-destructive queries
//  are what force the issue, so the rule is tested here.
//
//  The subtlety is that non-destructive queries keep their argument alive at run
//  time (for reuse) but their *crux* must clean it up (pop what it read) so the
//  fragment stays debris-free. These tests pin both halves: the argument survives
//  live, and the crux reproduces only the fact.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CompositionInvariantTests {

    /// Every stack a fresh interpreter holds after running `program`, rendered —
    /// so "only .int is non-empty" is one comparison.
    func stacksAfter(_ program: [any Item]) -> [PushStack: String] {
        let inty = Interpreter()
        inty.load(program: program)
        inty.run()
        var result = [PushStack: String]()
        for stack in PushStack.allCases {
            result[stack] = stackString(inty, stack)
        }
        return result
    }


    // MARK: - live keeps the argument; the crux cleans it up

    @Test func `a non-destructive query keeps its argument alive`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([1, 2, 3]))
        doThis(.vecIntLength, to: inty)

        #expect(stackString(inty, .int) == "[ 3 ]", "the fact")
        #expect(stackString(inty, .vecInt) == "[ [1, 2, 3] ]",
                "the vector survives the read, available for reuse")
    }

    /// The invariant itself: run a query's crux on a fresh interpreter and assert
    /// **only the fact's stack is non-empty.** The vector the query read is popped
    /// by the crux even though live execution kept it.
    @Test func `a query's crux leaves its value and nothing else`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([1, 2, 3]))
        doThis(.vecIntLength, to: inty)
        let length = topItem(inty, .int)

        let after = stacksAfter(length.crux())
        #expect(after[.int] == "[ 3 ]", "the crux reproduces the fact")
        for stack in PushStack.allCases where stack != .int {
            #expect(after[stack] == "[ ]", "debris left on .\(stack): \(after[stack] ?? "?")")
        }
    }

    @Test func `the query crux is a fixed point`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([4, 5, 6, 7]))
        doThis(.vecIntLength, to: inty)
        let length = topItem(inty, .int)

        let redo = Interpreter()
        redo.load(program: length.crux())
        redo.run()
        #expect(CodeItem(topItem(redo, .int).crux()).pretty()
                == CodeItem(length.crux()).pretty(),
                "re-running the crux must reconstruct it identically")
    }


    // MARK: - the cleanup pop is load-bearing

    /// **The reason the crux cleans up.** A program computes `nth(b, len(a))`,
    /// popping `a` after the (non-destructive) length so `nth` reads `b`. The
    /// length's crux fragment must pop the `a` it read, or the composed crux would
    /// leave `a` on top of `b` and `nth` would read `a` — a different, wrong value.
    @Test func `a composed query reproduces the value, not the debris`() {
        let inty = Interpreter()
        // a = [8,8] on top (the thing measured), b = [50,60,70] below (the nth
        // target). prepend(contentsOf:) puts the first element on top.
        inty.stacks[.vecInt]!.prepend(contentsOf: [VecIntItem([8, 8]),
                                                    VecIntItem([50, 60, 70])] as [any Item])
        //   .vecInt = [ [8,8]  [50,60,70] ]     (a on top, b below)
        doThis(.vecIntLength, to: inty)      // len(a) = 2, a survives on top
        doThis(.vecIntPop, to: inty)         // discard a → b is now on top
        doThis(.vecIntNth, to: inty)         // nth(b, 2) = b[2 % 3] = 70

        let answer = topItem(inty, .int)
        #expect((answer as? IntItem)?.value == 70, "nth read b, not a")

        // The crux of that 70 must reproduce 70 — which requires the length
        // fragment's cleanup pop to remove `a` so `nth` reads `b`. Without it the
        // crux would leave `a` on top and reproduce nth(a) = 8.
        let redo = Interpreter()
        redo.load(program: answer.crux())
        redo.run()
        #expect((topItem(redo, .int) as? IntItem)?.value == 70,
                "the composed crux reproduces 70, not the debris value 8")
        #expect(redo.stacks[.vecInt]!.isEmpty, "and leaves no vector debris")
    }

    /// **The collision case.** When the fact lands on a stack it also read from —
    /// `vecIntOccurrencesOf` returns an `.int` count and read an `.int` needle —
    /// the crux cannot just pop that stack (it would discard the count); it swaps
    /// the count up past the needle instead. This checks the swap-cleanup crux
    /// leaves only the count.
    @Test func `a query whose result shares a stack with its argument still cleans up`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([7, 7, 7, 4]))
        inty.stacks[.int]!.prepend(IntItem(7))
        doThis(.vecIntOccurrencesOf, to: inty)
        let count = topItem(inty, .int)
        #expect((count as? IntItem)?.value == 3)

        let after = stacksAfter(count.crux())
        #expect(after[.int] == "[ 3 ]", "only the count — the needle was swapped out, not the result")
        #expect(after[.vecInt] == "[ ]", "and the vector cleaned up too")
    }

    /// A query nested inside a query: `len(v)` feeds an `.intGT` comparison later.
    /// Every fragment must stay debris-free for the whole to reproduce.
    @Test func `a query feeding a comparison composes cleanly`() {
        let inty = Interpreter()
        inty.stacks[.vecInt]!.prepend(VecIntItem([1, 2, 3, 4, 5]))
        inty.stacks[.int]!.prepend(IntItem(3))
        doThis(.vecIntLength, to: inty)   // 5, vector survives; .int = [5, 3]

        let length = topItem(inty, .int)
        #expect((length as? IntItem)?.value == 5)

        let after = stacksAfter(length.crux())
        #expect(after[.int] == "[ 5 ]")
        #expect(after[.vecInt] == "[ ]", "the length's crux left no vector behind")
    }
}
