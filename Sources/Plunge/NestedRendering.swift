//
//  NestedRendering.swift
//  Plunge
//

/// `pretty()` for the containers — blocks, iterators, pairs and functions — written as a loop over
/// an explicit stack instead of recursion.
///
/// Blocks hold iterators and iterators hold blocks, nested up to `maxCodeDepth`
/// levels, and a recursive rendering costs several stack frames per level. On a
/// concurrency worker thread (512 KB) a debug build overflowed rendering such a
/// structure about 600 levels deep, and the runaway guard renders the top of a
/// stack on every check. This produces exactly what the recursive form did: the
/// same pieces, in the same order.
nonisolated enum NestedRendering {
    private enum Piece {
        case text(String)
        case item(any Item)
    }

    static func render(_ root: any Item) -> String {
        var output = ""
        var pending: [Piece] = [.item(root)]
        while let piece = pending.popLast() {
            switch piece {
            case .text(let text):
                output += text
            case .item(let item):
                if let block = item.exactly(CodeItem.self) {
                    // `( ` then each child followed by a space, then `)`.
                    var pieces: [Piece] = [.text("( ")]
                    pieces.reserveCapacity(block.value.count * 2 + 2)
                    for child in block.value {
                        pieces.append(.item(child))
                        pieces.append(.text(" "))
                    }
                    pieces.append(.text(")"))
                    pending.append(contentsOf: pieces.reversed())
                } else if let iterator = item as? IteratorItem {
                    // `«origin→destination<middle> body»`.
                    var pieces: [Piece] = [.text("«"), .item(iterator.origin)]
                    if let destination = iterator.destination {
                        pieces.append(.text("→"))
                        pieces.append(.item(destination))
                    }
                    pieces.append(.text(iterator.prettyMiddle))
                    if let body = iterator.body {
                        pieces.append(.text(" "))
                        pieces.append(.item(body))
                    }
                    pieces.append(.text("»"))
                    pending.append(contentsOf: pieces.reversed())
                } else if let function = item.exactly(FunctionItem.self) {
                    // `ƒ( ⟨int⟩ 3 .intAdd )`: each hole written as its stack.
                    let holes = function.holes
                    let body = function.value.map { [Piece.item($0), .text(" ")] }
                    let laid = FunctionItem.merged(body, function.layout) { [Piece.text("⟨\(holes[$0].stack)⟩ ")] }
                    let pieces: [Piece] = [.text("ƒ( ")] + laid.flatMap { $0 } + [.text(")")]
                    pending.append(contentsOf: pieces.reversed())
                } else if let pair = item as? BindingItem {
                    // `⟨key ↦ value⟩`.
                    let pieces: [Piece] = [.text("⟨\(pair.key) ↦ "), .item(pair.bound), .text("⟩")]
                    pending.append(contentsOf: pieces.reversed())
                } else {
                    output += item.pretty()
                }
            }
        }
        return output
    }
}
