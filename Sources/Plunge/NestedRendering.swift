//
//  NestedRendering.swift
//  Plunge
//

/// `pretty()` for the containers — code blocks, iterators, pairs and functions — written as a loop over
/// an explicit stack instead of recursion.
///
/// Code blocks hold iterators and iterators hold code blocks, nested up to `maxCodeDepth`
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
                    // `«iter 0 to 5 by 1 at 2: ( body )»`: the source, named by
                    // its kind, then the cursor and whatever else says something.
                    var pieces: [Piece] = [.text("«\(PushStack.iterator.tag) ")]
                    pieces.append(contentsOf: Self.source(of: iterator))
                    pieces.append(.text(iterator.prettyState))
                    if let body = iterator.body {
                        pieces.append(.text(": "))
                        pieces.append(.item(body))
                    }
                    pieces.append(.text("»"))
                    pending.append(contentsOf: pieces.reversed())
                } else if let function = item.exactly(FunctionItem.self) {
                    // `«fn (int) -> int: $0 3 .intAdd»`: the holes' stacks and
                    // the output as a signature, each hole in the body as `$n`.
                    let body = function.value.map { [Piece.item($0)] }
                    let laid = FunctionItem.merged(body, function.layout) { [Piece.text("$\($0)")] }
                    var pieces: [Piece] = [.text("«\(PushStack.function.tag) \(function.prettySignature):")]
                    for part in laid { pieces.append(.text(" ")); pieces.append(contentsOf: part) }
                    pieces.append(.text("»"))
                    pending.append(contentsOf: pieces.reversed())
                } else if let pair = item as? BindingItem {
                    // `«bind: key -> value»`.
                    let pieces: [Piece] = [.text("«\(PushStack.binding.tag): \(pair.key) -> "),
                                           .item(pair.bound), .text("»")]
                    pending.append(contentsOf: pieces.reversed())
                } else {
                    output += item.pretty()
                }
            }
        }
        return output
    }

    /// An iterator's source, in words that name its kind, so two iterators of
    /// different kinds over the same origin never print alike.
    private static func source(of iterator: IteratorItem) -> [Piece] {
        func into(_ stack: PushStack?) -> [Piece] { stack.map { [.text(" into \($0)")] } ?? [] }
        let origin = Piece.item(iterator.origin)
        let destination = iterator.destination.map { [Piece.text(" to "), .item($0)] } ?? []
        switch iterator.kind {
        case .counting(let stride):
            return [origin] + destination + [.text(" by \(stride)")]
        case .repeating(let stack):
            let times = iterator.destination.map { [Piece.text(" "), .item($0), .text(" times")] } ?? []
            return [origin, .text(" repeated")] + times + into(stack)
        case .elements(let stack):
            return [.text("over "), origin] + destination + into(stack)
        case .letters:
            return [.text("letters of "), origin] + destination
        case .words:
            return [.text("words of "), origin] + destination
        case .points(let emission):
            return [.text("\(emission) points of "), origin] + destination
        }
    }
}
