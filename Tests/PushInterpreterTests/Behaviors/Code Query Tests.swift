//
//  Code Query Tests.swift
//  PushInterpreterTests
//
//  Created by William Tozier on 7/18/26.
//
//  Whole-tree queries: codeLengthPoints, codeWidth, codeDepth (unary), and
//  codeContains, codeIndexOfPoint, codeContainer (binary). All non-destructive —
//  arguments survive, the crux pops what it read.
//

@testable import PushInterpreter
import Testing
import DequeModule

@Suite @MainActor
struct CodeQueryTests {

    /// ( (1 2) 3 ) — 5 points, 3 leaves, depth 2.
    let tree = CodeItem([CodeItem([IntItem(1), IntItem(2)]), IntItem(3)])

    func loaded(_ code: CodeItem) -> Interpreter {
        let inty = Interpreter()
        inty.stacks[.code]!.prepend(code)
        return inty
    }

    // MARK: - unary

    @Test func `lengthPoints, width, depth`() {
        let a = loaded(tree); doThis(.codeLengthPoints, to: a)
        #expect((topItem(a, .int) as! IntItem).value == 5)
        #expect(stackString(a, .code) == "[ ( ( 1 2 ) 3 ) ]", "the code survives")
        #expect(callString(topItem(a, .int)) == "( ( ( 1 2 ) 3 ) .codeLengthPoints 1 .codePopItems )")

        let b = loaded(tree); doThis(.codeWidth, to: b)
        #expect((topItem(b, .int) as! IntItem).value == 3, "leaves")

        let c = loaded(tree); doThis(.codeDepth, to: c)
        #expect((topItem(c, .int) as! IntItem).value == 2)

        // empty-block edges
        let e = loaded(CodeItem([CodeItem([]), IntItem(5)]))
        doThis(.codeLengthPoints, to: e)
        #expect((topItem(e, .int) as! IntItem).value == 3, "root, (), 5")
        let ew = loaded(CodeItem([CodeItem([]), IntItem(5)]))
        doThis(.codeWidth, to: ew)
        #expect((topItem(ew, .int) as! IntItem).value == 1, "the empty block has no leaf")
    }

    // MARK: - binary

    @Test func `contains checks any point, root included`() {
        // haystack on top (a[0]), target below (a[1])
        func contains(_ hay: CodeItem, _ target: any Item) -> Bool {
            let inty = Interpreter()
            inty.stacks[.code]!.prepend(contentsOf: [hay, target as! CodeItem] as [any Item])
            doThis(.codeContains, to: inty)
            return (topItem(inty, .bool) as! BoolItem).value
        }
        #expect(contains(tree, CodeItem([IntItem(1), IntItem(2)])), "the (1 2) subtree")
        #expect(contains(tree, tree), "a tree contains itself")
        #expect(!contains(tree, CodeItem([IntItem(9)])))
    }

    @Test func `contains survives both operands and cleans its crux`() {
        let inty = Interpreter()
        let target = CodeItem([IntItem(1), IntItem(2)])
        inty.stacks[.code]!.prepend(contentsOf: [tree, target] as [any Item])
        doThis(.codeContains, to: inty)
        #expect((topItem(inty, .bool) as! BoolItem).value)
        #expect(stackString(inty, .code) == "[ ( ( 1 2 ) 3 ) ( 1 2 ) ]", "both survive")
        #expect(callString(topItem(inty, .bool))
                == "( ( 1 2 ) ( ( 1 2 ) 3 ) .codeContains 2 .codePopItems )")

        let redo = Interpreter()
        redo.load(program: topItem(inty, .bool).crux())
        redo.run()
        #expect(stackString(redo, .bool) == "[ true ]")
        #expect(redo.stacks[.code]!.isEmpty, "crux popped both")
    }

    @Test func `a singleton needle finds a leaf; double-wrap finds the singleton subtree`() {
        func idxOf(_ hay: CodeItem, _ needle: CodeItem) -> Int {
            let inty = Interpreter()
            inty.stacks[.code]!.prepend(contentsOf: [hay, needle] as [any Item])
            doThis(.codeIndexOfPoint, to: inty)
            return (topItem(inty, .int) as! IntItem).value
        }
        // ( 5 ( 5 ) ): points 0:root 1:5(leaf) 2:(5)(subtree) 3:5(leaf inside)
        let mixed = CodeItem([IntItem(5), CodeItem([IntItem(5)])])
        #expect(idxOf(mixed, CodeItem([IntItem(5)])) == 1, "( 5 ) denotes leaf 5 → first leaf")
        #expect(idxOf(mixed, CodeItem([CodeItem([IntItem(5)])])) == 2, "(( 5 )) denotes subtree ( 5 )")
    }

    @Test func `indexOfPoint returns pre-order index or -1`() {
        func idx(_ hay: CodeItem, _ target: CodeItem) -> Int {
            let inty = Interpreter()
            inty.stacks[.code]!.prepend(contentsOf: [hay, target] as [any Item])
            doThis(.codeIndexOfPoint, to: inty)
            return (topItem(inty, .int) as! IntItem).value
        }
        #expect(idx(tree, CodeItem([IntItem(1), IntItem(2)])) == 1)
        #expect(idx(tree, CodeItem([IntItem(9)])) == -1)
    }

    @Test func `container returns the parent, and its crux (a code result) cleans up via swap`() {
        let inty = Interpreter()
        let target = CodeItem([IntItem(1), IntItem(2)])   // a root-level element
        inty.stacks[.code]!.prepend(contentsOf: [tree, target] as [any Item])
        doThis(.codeContainer, to: inty)
        // parent of a root-level element is the whole tree
        #expect(stackString(inty, .code) == "[ ( ( 1 2 ) 3 ) ( ( 1 2 ) 3 ) ( 1 2 ) ]",
                "the container (a copy of the tree), atop the two surviving operands")

        // the crux: result lands on .code (same stack it read), so swap-cleanup
        let container = topItem(inty, .code)
        #expect(callString(container)
                == "( ( 1 2 ) ( ( 1 2 ) 3 ) .codeContainer .codeSwap .codePop .codeSwap .codePop )")
        let redo = Interpreter()
        redo.load(program: container.crux())
        redo.run()
        #expect(stackString(redo, .code) == "[ ( ( 1 2 ) 3 ) ]", "reproduces just the container")
    }

    @Test func `container of a leaf (singleton needle) is its inner block`() {
        let inty = Interpreter()
        // needle ( 1 ) denotes the leaf 1, whose parent is the inner block ( 1 2 ).
        inty.stacks[.code]!.prepend(contentsOf: [tree, CodeItem([IntItem(1)])] as [any Item])
        doThis(.codeContainer, to: inty)
        #expect(stackString(inty, .code) == "[ ( 1 2 ) ( ( 1 2 ) 3 ) ( 1 ) ]",
                "the parent ( 1 2 ), atop the surviving operands")
    }

    @Test func `container of an absent needle pushes nothing`() {
        let inty = Interpreter()
        // needle ( 9 ) denotes leaf 9, which the tree does not contain.
        inty.stacks[.code]!.prepend(contentsOf: [tree, CodeItem([IntItem(9)])] as [any Item])
        doThis(.codeContainer, to: inty)
        #expect(stackString(inty, .code) == "[ ( ( 1 2 ) 3 ) ( 9 ) ]",
                "nothing pushed; operands untouched (nondestructive)")
    }
}
