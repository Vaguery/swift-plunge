//
//  CodeGaps.swift
//  PushInterpreter
//
//  **A gap is a position *between* things in a tree.** Points are nodes; gaps are
//  the spaces around them, and the four instructions built on this file all need
//  the second rather than the first: a cut happens between two things, an
//  insertion happens between two things, and a wrap needs two betweens.
//
//  ## The model
//
//  Linearize the root's **contents** into tokens — a leaf is one token, a nested
//  block is `open`, its contents, `close` — and number the spaces between them:
//
//      ( 1 ( 2 3 ) 4 )   →   [ 1 , open , 2 , 3 , close , 4 ]     6 tokens
//
//      gap:              0   1      2   3      4       5   6      7 gaps
//
//  `gapCount` is `tokens.count + 1`, and an index wraps modulo it — the same wrap
//  `codeCutRootAtGap` uses, and for the same reason it gives:
//
//  > Gaps, not elements: a root of N items has N+1 gaps, from 0 (before
//  > everything) to N (after everything). That is what lets a cut reach the two
//  > extremes.
//
//  **The root's own boundary is deliberately not a token.** Excluding it is what
//  keeps gap 0 meaning "before the first item" and gap N "after the last", exactly
//  as at root level — so this generalizes `codeCutRootAtGap` rather than competing
//  with it. What the generalization adds is that interior gaps now reach *inside*
//  nested blocks: above, gap 2 is the head of `( 2 3 )` and gap 4 is its tail.
//  Head and tail are addressable at every level, not just the root's.
//
//  ## Rebuilding is total, because the halves of a cut are not balanced
//
//  Cutting `1 open 2 | 3 close 4` leaves one piece with an unclosed `open` and the
//  other with an unmatched `close`. Rather than refuse — which would make most
//  gaps uncuttable and the whole model pointless — `rebuilt(from:)` repairs:
//  an unmatched `close` is dropped, and anything still open at the end is closed.
//
//  So **every token sequence yields a CodeItem**, and nothing built on this can
//  fail on a malformed intermediate. What that buys is the law the cut is designed
//  around: no leaf is ever lost or reordered. What it costs is that nesting *on
//  the cut path* changes, so unlike `codeCutRootAtGap`, cut-then-`codeAppend` is
//  not the identity for an interior cut. A block split in two cannot reassemble;
//  that is a property of cutting trees, not a defect here.
//

import DequeModule


/// One position in a tree's linearization. Internal by design: a token exists
/// only between `gapTokens` and `rebuilt(from:)`, and none ever reaches a stack.
nonisolated enum CodeToken: Sendable {
    case item(any Item)
    case open
    case close
}


nonisolated extension CodeItem {

    /// This tree's contents as a flat token sequence. See the file note.
    var gapTokens: [CodeToken] {
        var out: [CodeToken] = []
        func walk(_ items: [any Item]) {
            for item in items {
                if let block = item.exactly(CodeItem.self) {
                    out.append(.open)
                    walk(block.value)
                    out.append(.close)
                } else {
                    out.append(.item(item))
                }
            }
        }
        walk(value)
        return out
    }

    /// How many gaps this tree has: one more than its token count, because the
    /// spaces before the first token and after the last both count.
    var gapCount: Int { gapTokens.count + 1 }

    /// Any int, landed on a real gap. The single place the wrap lives, so the four
    /// gap instructions cannot drift from each other or from `codeCutRootAtGap`.
    ///
    /// `magnitude` rather than `abs` for the same reason as everywhere else: `abs`
    /// traps on `Int.min`.
    func gapIndex(_ n: Int) -> Int {
        Int(n.magnitude % UInt(gapCount))
    }

    /// Parse tokens back into a tree, repairing imbalance as it goes — an
    /// unmatched `close` is dropped, and anything left open at the end is closed.
    /// Total: every sequence yields a tree. See the file note for why that matters.
    static func rebuilt(from tokens: [CodeToken]) -> CodeItem {
        var frames: [[any Item]] = [[]]
        for token in tokens {
            switch token {
            case .item(let item):
                frames[frames.count - 1].append(item)
            case .open:
                frames.append([])
            case .close:
                // Nothing open to close: drop it rather than refuse the parse.
                guard frames.count > 1 else { continue }
                let finished = frames.removeLast()
                frames[frames.count - 1].append(CodeItem(finished))
            }
        }
        // Auto-close whatever the cut left open.
        while frames.count > 1 {
            let finished = frames.removeLast()
            frames[frames.count - 1].append(CodeItem(finished))
        }
        return CodeItem(frames[0])
    }

    /// A new tree with every nested block **whose head or tail gap falls in
    /// `lo...hi`** replaced by its leaves.
    ///
    /// A block's head gap is the one just inside its `open`, and its tail gap the
    /// one just inside its `close` — the two positions a program would name to
    /// reach into it. Testing those rather than the block's outer edges is what
    /// makes the operation local: a block that merely *encloses* the range has its
    /// head before `lo` and its tail after `hi`, so it survives, and since the
    /// root has no tokens at all it is never flattened. Only blocks the range
    /// actually reaches into collapse.
    ///
    /// The walk is bottom-up, which reads like it might be wrong and is not: when
    /// an outer block qualifies, `flattenedLeaves()` discards whatever its
    /// children decided anyway, so the result is the same as deciding top-down.
    /// The cursor advances over the **original** contents regardless of what is
    /// emitted, so gap positions stay those of the tree that was asked about.
    func flatteningBlocks(inGapRange lo: Int, through hi: Int) -> CodeItem {
        var cursor = 0                     // the gap before the next token
        func rebuild(_ block: CodeItem) -> [any Item] {
            var out: [any Item] = []
            for child in block.value {
                guard let sub = child.exactly(CodeItem.self) else {
                    cursor += 1            // a leaf token
                    out.append(child)
                    continue
                }
                cursor += 1                // the `open` token
                let head = cursor
                let inner = rebuild(sub)
                let tail = cursor
                cursor += 1                // the `close` token

                if (lo...hi).contains(head) || (lo...hi).contains(tail) {
                    out.append(contentsOf: CodeItem(inner).flattenedLeaves())
                } else {
                    out.append(CodeItem(inner))
                }
            }
            return out
        }
        return CodeItem(rebuild(self))
    }
}
