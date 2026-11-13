//
//  Predicate Behavior Tests.swift
//  PlungeTests
//
//  Collection operations that take a function: zip, scan, sort by a key, least
//  and greatest by a key, the predicate searches and the predicate cuts. The
//  function is the topmost on `.function` that fits, filled as map's is.
//

@testable import Plunge
import Testing

@Suite
struct PredicateBehaviorTests {

    static func run(_ program: [any Item], recording: Bool = true) -> Interpreter {
        let inty = recording ? Interpreter.recordingProvenance() : Interpreter()
        inty.load(program: program)
        inty.run(stepLimit: 10_000)
        return inty
    }

    static func op(_ name: PushInstruction) -> InstructionItem { InstructionItem(name) }

    /// `items` as a block, converted into its functions.
    static func derived(_ items: any Item...) -> [any Item] { [CodeItem(items), op(.codePushAllFunctions)] }

    /// Is-even, as a function: `x 2 .intMod 0 .intEq` (the bool function on top).
    static let isEven = derived(IntItem(2), op(.intMod), IntItem(0), op(.intEq))

    /// Every item on `stack` re-run from its crux alone: the same value, and no error.
    static func replays(_ inty: Interpreter, _ stack: PushStack) -> Bool {
        inty.stacks[stack]!.allSatisfy { item in
            let fresh = Interpreter()
            fresh.load(program: item.crux())
            fresh.run(stepLimit: 10_000)
            return fresh.stacks[stack]!.map { $0.pretty() } == [item.pretty()] && fresh.stacks[.error]!.isEmpty
        }
    }

    static func errorKinds(_ inty: Interpreter) -> [ErrorKind] {
        inty.stacks[.error]!.compactMap { ($0 as? ErrorItem)?.kind }
    }

    // MARK: - Zip, scan, keys

    @Test func `zip applies a two-hole function to matching elements`() {
        let inty = Self.run([VecIntItem([10, 20]), VecIntItem([7]), VecIntItem([1, 2]), Self.op(.intSubtract),
                             Self.op(.vecIntZip)])
        #expect(stackString(inty, .vecInt) == "[ [9, 18] [7] ]", "a b .intSubtract over the same-length pair")
        #expect(Self.replays(inty, .vecInt))

        let distances = Self.run([VecIntItem([1, 5]), VecIntItem([4, 1]), Self.op(.intGT), Self.op(.vecIntZip)])
        #expect(stackString(distances, .vecBool) == "[ [false, true] ]", "results collect as map's do")
    }

    @Test func `strings zip too`() {
        let inty = Self.run([Self.op(.stringConcat), VecStringItem(["a", "b"]), VecStringItem(["x", "y"]),
                             Self.op(.vecStringZip)])
        #expect(stackString(inty, .vecString) == "[ [\"ax\", \"by\"] ]")
        let chars = Self.run([Self.op(.charEq), StringItem("abc"), StringItem("abd"), Self.op(.stringZip)])
        #expect(stackString(chars, .vecBool) == "[ [true, true, false] ]")
    }

    @Test func `scan keeps every running value`() {
        let inty = Self.run(Self.derived(Self.op(.intAdd)) + [VecIntItem([1, 2, 3, 4]), Self.op(.vecIntScan)])
        #expect(stackString(inty, .vecInt) == "[ [1, 3, 6, 10] ]")
        #expect(Self.replays(inty, .vecInt))
        let leaders = Self.run([Self.op(.intMax), VecIntItem([2, 1, 5, 3]), Self.op(.vecIntScan)])
        #expect(stackString(leaders, .vecInt) == "[ [2, 2, 5, 5] ]")
        let empty = Self.run([Self.op(.intAdd), VecIntItem([]), Self.op(.vecIntScan)])
        #expect(stackString(empty, .vecInt) == "[ «vecInt []» ]")
    }

    @Test func `sort by a key is stable`() {
        let inty = Self.run([Self.op(.stringLength), VecStringItem(["ccc", "a", "bb", "d"]), Self.op(.vecStringSortBy)])
        #expect(stackString(inty, .vecString) == "[ [\"a\", \"d\", \"bb\", \"ccc\"] ]")
        #expect(Self.replays(inty, .vecString))
        // A bool key sorts false before true: the evens last.
        let evensLast = Self.run(Self.isEven + [VecIntItem([2, 1, 4, 3]), Self.op(.vecIntSortBy)])
        #expect(stackString(evensLast, .vecInt) == "[ [1, 3, 2, 4] ]")
    }

    @Test func `least and greatest by a key read the collection`() {
        // Both functions starve first and are shelved; MaxBy takes the top one.
        let inty = Self.run([Self.op(.stringLength), Self.op(.stringLength), VecStringItem(["bb", "a", "ccc"]),
                             Self.op(.vecStringMaxBy), Self.op(.vecStringMinBy)])
        #expect(stackString(inty, .string) == "[ \"a\" \"ccc\" ]")
        #expect(inty.stacks[.vecString]!.count == 1, "read and left")
        #expect(Self.replays(inty, .string))
        let empty = Self.run([Self.op(.intNegate), VecIntItem([]), Self.op(.vecIntMinBy)])
        // (Newest first: under it, the bare function's own starvation.)
        #expect(Self.errorKinds(empty).first == .emptyCollection)
    }

    // MARK: - Searches

    @Test func `searches count, test and locate`() {
        let vector = VecIntItem([1, 4, 3, 6, 5])
        let count = Self.run(Self.isEven + [vector, Self.op(.vecIntOccurrencesWhere)])
        #expect(stackString(count, .int) == "[ 2 ]")
        #expect(count.stacks[.vecInt]!.count == 1, "read and left")
        #expect(Self.replays(count, .int))

        let first = Self.run(Self.isEven + [vector, Self.op(.vecIntIndexOfWhere)])
        #expect(stackString(first, .int) == "[ 1 ]")
        let last = Self.run(Self.isEven + [vector, Self.op(.vecIntLastIndexOfWhere)])
        #expect(stackString(last, .int) == "[ 3 ]")
        let found = Self.run(Self.isEven + [vector, Self.op(.vecIntFindWhere)])
        #expect(stackString(found, .int) == "[ 4 ]")
        #expect(Self.replays(found, .int))

        let some = Self.run(Self.isEven + [vector, Self.op(.vecIntContainsWhere)])
        let every = Self.run(Self.isEven + [vector, Self.op(.vecIntAllWhere)])
        let vacuous = Self.run(Self.isEven + [VecIntItem([]), Self.op(.vecIntAllWhere)])
        #expect(stackString(some, .bool) == "[ true ]")
        #expect(stackString(every, .bool) == "[ false ]")
        #expect(stackString(vacuous, .bool) == "[ true ]")

        let none = Self.run(Self.isEven + [VecIntItem([1, 3]), Self.op(.vecIntIndexOfWhere)])
        #expect(Self.errorKinds(none) == [.notFound])
    }

    @Test func `strings search their chars`() {
        let inty = Self.run([Self.op(.charIsDigit), StringItem("ab3c4"), Self.op(.stringFindWhere)])
        #expect(stackString(inty, .char) == "[ '3' ]")
        let count = Self.run([Self.op(.charIsDigit), StringItem("ab3c4"), Self.op(.stringOccurrencesWhere)])
        #expect(stackString(count, .int) == "[ 2 ]")
    }

    // MARK: - Cuts

    @Test func `take and drop while a predicate holds`() {
        let taken = Self.run(Self.isEven + [VecIntItem([2, 4, 5, 6]), Self.op(.vecIntTakeWhile)])
        #expect(stackString(taken, .vecInt) == "[ [2, 4] ]")
        #expect(Self.replays(taken, .vecInt))
        let dropped = Self.run([Self.op(.charIsWhitespace), StringItem("  hi there"), Self.op(.stringDropWhile)])
        #expect(stackString(dropped, .string) == "[ \"hi there\" ]")
    }

    @Test func `partition puts the holding elements below the others`() {
        let inty = Self.run(Self.isEven + [VecIntItem([1, 2, 3, 4]), Self.op(.vecIntPartition)])
        #expect(stackString(inty, .vecInt) == "[ [1, 3] [2, 4] ]")
        #expect(Self.replays(inty, .vecInt))
    }

    // MARK: - Finding the function

    @Test func `nothing that fits is a miss, an empty function stack starvation`() {
        let miss = Self.run([Self.op(.intAdd), VecIntItem([1, 2]), Self.op(.vecIntOccurrencesWhere)])
        #expect(Self.errorKinds(miss).first == .notFound, "on top of .intAdd's own starvation")
        #expect(miss.stacks[.vecInt]!.count == 1, "a read collection stays even on a miss")

        let starved = Self.run([VecIntItem([1, 2]), Self.op(.vecIntTakeWhile)])
        #expect(Self.errorKinds(starved) == [.missingArgument])
        #expect(stackString(starved, .vecInt) == "[ [1, 2] ]")
    }

    @Test func `other holes are read from the run and left`() {
        // `.intGT` with 2 on .int: each element x in its first hole, 2 in the second.
        let inty = Self.run([IntItem(2), Self.op(.intGT), VecIntItem([1, 3, 5]), Self.op(.vecIntOccurrencesWhere)])
        #expect(stackString(inty, .int) == "[ 2 2 ]", "the count, above the filler it read")
        #expect(Self.replays(inty, .int))
    }

    @Test func `values do not depend on recording`() {
        let program: [any Item] = Self.isEven + [VecIntItem([5, 2, 8, 1]), Self.op(.vecIntPartition)]
            + Self.isEven + [Self.op(.vecIntSortBy), Self.op(.intAdd), Self.op(.vecIntScan)]
        let on = Self.run(program)
        let off = Self.run(program, recording: false)
        for stack in PushStack.allCases where stack != .function {
            #expect(stackString(on, stack) == stackString(off, stack), "\(stack)")
        }
    }
}
