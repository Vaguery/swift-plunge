//
//  CodeItem Points Tests.swift
//  PushInterpreterTests
//
//  Created by Bill Tozier on 7/18/26.
//
//  The pre-order point walker on CodeItem — the shared foundation for the whole
//  code-tree instruction batch. Points are pre-order (node before children),
//  root at index 0, empty blocks count, vectors opaque. Tested here before any
//  behavior depends on it.
//

@testable import PushInterpreter
import Testing

@Suite @MainActor
struct CodeItemPointsTests {

    /// ( (1 2) 3 ) — the canonical example from the plan.
    let tree = CodeItem([CodeItem([IntItem(1), IntItem(2)]), IntItem(3)])

    @Test func `pre-order points, root first`() {
        let pts = tree.preorderPoints
        #expect(pts.count == 5)
        #expect(pts[0].pretty() == "( ( 1 2 ) 3 )", "index 0 is the whole tree")
        #expect(pts[1].pretty() == "( 1 2 )")
        #expect((pts[2] as? IntItem)?.value == 1)
        #expect((pts[3] as? IntItem)?.value == 2)
        #expect((pts[4] as? IntItem)?.value == 3)
        #expect(tree.pointCount == 5)
    }

    @Test func `point(at:) clamps the index to the points`() {
        // points: 0:root 1:(1 2) 2:1 3:2 4:3, count 5
        #expect(tree.point(at: 0).pretty() == "( ( 1 2 ) 3 )")
        #expect((tree.point(at: 4) as? IntItem)?.value == 3)
        #expect((tree.point(at: 9) as? IntItem)?.value == 3, "past the end is the last point")
        #expect((tree.point(at: 5) as? IntItem)?.value == 3, "past the end is the last point")
        #expect((tree.point(at: -1) as? CodeItem)?.pretty() == "( ( 1 2 ) 3 )", "below 0 is the root")
    }

    @Test func `empty blocks are points`() {
        // ( ( ) 5 )  →  0:root, 1:(), 2:5
        let t = CodeItem([CodeItem([]), IntItem(5)])
        #expect(t.pointCount == 3)
        #expect(t.preorderPoints[1].pretty() == "( )", "the empty block is a point")
        #expect((t.preorderPoints[2] as? IntItem)?.value == 5)
    }

    @Test func `vectors are opaque leaves`() {
        // ( [1,2,3] 9 ) — the vector is ONE point, not four.
        let t = CodeItem([VecIntItem([1, 2, 3]), IntItem(9)])
        #expect(t.pointCount == 3, "root, the vector, the 9")
        #expect((t.preorderPoints[1] as? VecIntItem)?.value == [1, 2, 3])
    }

    @Test func depth() {
        #expect(tree.depth == 2)
        #expect(CodeItem([IntItem(1), IntItem(2)]).depth == 1, "a flat block")
        #expect(CodeItem([]).depth == 0, "empty block")
        #expect(CodeItem([IntItem(1), CodeItem([IntItem(2), CodeItem([IntItem(3)])])]).depth == 3)
    }

    @Test func flatten() {
        #expect(tree.flattenedLeaves().map { ($0 as! IntItem).value } == [1, 2, 3])
        // Empty blocks contribute nothing.
        let withEmpty = CodeItem([IntItem(1), CodeItem([]), IntItem(2)])
        #expect(withEmpty.flattenedLeaves().count == 2)
    }

    @Test func `flatten once, one level only`() {
        // (1 (2 (3 4)) 5) → (1 2 (3 4) 5)
        let t = CodeItem([IntItem(1),
                          CodeItem([IntItem(2), CodeItem([IntItem(3), IntItem(4)])]),
                          IntItem(5)])
        let once = CodeItem(t.flattenedOnce())
        #expect(once.pretty() == "( 1 2 ( 3 4 ) 5 )")
    }

    @Test func `firstPointIndex finds a subtree or leaf, root included`() {
        #expect(tree.firstPointIndex(of: tree) == 0, "a tree contains itself at 0")
        #expect(tree.firstPointIndex(of: CodeItem([IntItem(1), IntItem(2)])) == 1)
        #expect(tree.firstPointIndex(of: IntItem(3)) == 4)
        #expect(tree.firstPointIndex(of: IntItem(99)) == nil)
    }

    @Test func parentContaining() {
        // parent of (1 2) is the root; parent of 1 is (1 2); parent of 3 is root.
        #expect(tree.parentContaining(CodeItem([IntItem(1), IntItem(2)]))?.pretty() == "( ( 1 2 ) 3 )")
        #expect(tree.parentContaining(IntItem(1))?.pretty() == "( 1 2 )")
        #expect(tree.parentContaining(IntItem(3))?.pretty() == "( ( 1 2 ) 3 )")
        #expect(tree.parentContaining(IntItem(99)) == nil)
    }

    @Test func replacingPoint() {
        // replace point 2 (the leaf 1) with 99
        let r = tree.replacingPoint(at: 2, with: IntItem(99)) as! CodeItem
        #expect(r.pretty() == "( ( 99 2 ) 3 )")
        // replace point 1 (the subtree (1 2)) with a leaf
        let r2 = tree.replacingPoint(at: 1, with: IntItem(0)) as! CodeItem
        #expect(r2.pretty() == "( 0 3 )")
        // replace root
        let r0 = tree.replacingPoint(at: 0, with: IntItem(7))
        #expect((r0 as? IntItem)?.value == 7)
    }

    @Test func removingPoint() {
        // remove point 2 (leaf 1)
        #expect(tree.removingPoint(at: 2).pretty() == "( ( 2 ) 3 )")
        // remove point 1 (subtree (1 2)) — the whole subtree goes
        #expect(tree.removingPoint(at: 1).pretty() == "( 3 )")
        // remove point 4 (leaf 3)
        #expect(tree.removingPoint(at: 4).pretty() == "( ( 1 2 ) )")
        // remove root → empty
        #expect(tree.removingPoint(at: 0).pretty() == "( )")
    }

    @Test func `replacingPoints by value, all or first`() {
        // ( 1 ( 1 2 ) 1 ) — replace every leaf 1 with 9
        let t = CodeItem([IntItem(1), CodeItem([IntItem(1), IntItem(2)]), IntItem(1)])
        let all = t.replacingPoints(equalTo: IntItem(1), with: IntItem(9), firstOnly: false) as! CodeItem
        #expect(all.pretty() == "( 9 ( 9 2 ) 9 )")
        let first = t.replacingPoints(equalTo: IntItem(1), with: IntItem(9), firstOnly: true) as! CodeItem
        #expect(first.pretty() == "( 9 ( 1 2 ) 1 )", "only the first pre-order match")
        // replacement is not re-scanned: replace (1 2) with (1 1) — the new 1s stay.
        let sub = t.replacingPoints(equalTo: CodeItem([IntItem(1), IntItem(2)]),
                                    with: CodeItem([IntItem(1), IntItem(1)]), firstOnly: false) as! CodeItem
        #expect(sub.pretty() == "( 1 ( 1 1 ) 1 )")
    }
}
