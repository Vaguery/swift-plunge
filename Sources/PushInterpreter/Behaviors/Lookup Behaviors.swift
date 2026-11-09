//
//  Lookup Behaviors.swift
//  PushInterpreter
//
//  Lookup by pattern on the stacks themselves (*Behavior coverage audit
//  (2026-11-09)* §8, rulings 5–6): the sieve made visible to a program, and the
//  language's keyed storage without a dictionary type.
//
//  **The rule.** The probe is the top of the stack, *read*, so a key is never
//  used up. The search runs top-down below it, and the first item that matches
//  the probe under the instruction's kind is the answer:
//  - a **copy** of the match goes on top of the stack, the match staying where
//    it was (a copy records nothing: it is the item, law 1);
//  - its **position** goes onto `.int`: the match's depth plus one, counted in
//    the stack as it was. That is where the match sits once the copy is on top
//    (so `xYank` or `xYankDup` reach it), and where the next search starts once
//    the copy has been used. The position depends on the stack's arrangement,
//    so it records a stand-in (law 4b), as `StackDepth` does;
//  - **no match is a refusal, as if the stack were empty**: a missing-arguments
//    error, and nothing consumed (ruling I20).
//  When the stack is `.int` itself, the position goes down first and the copy
//  on top of it.
//
//  **`…From`** takes a start from `.int` and searches from that depth down,
//  inclusive (never the probe itself). Walking every match is lookup, use the
//  copy, then `…From` with the position it left.
//
//  **The kinds**, from exact to total: `Equal`; `Prefix` (begins with the
//  probe's contents); `Containing` (contains the probe); `Shape` (code: the same
//  tree, with atoms of the same type standing for each other, as `cruxShape`
//  treats constants); `Nearest` (ints, doubles and chars, which have a distance;
//  ties go to the topmost, and it misses only when there is nothing below).
//

import DequeModule

nonisolated extension Interpreter {

    // MARK: - The rule

    /// A lookup on `stack`: `locate` finds the first match for `probe` among
    /// `items` at or below `start` (≥ 1), or nil.
    static func lookupBehavior(
        _ name: PushInstruction, on stack: PushStack, from: Bool,
        locate: @escaping @Sendable (_ probe: any Item, _ items: Deque<any Item>, _ start: Int) -> Int?
    ) -> Behavior {
        let produces: Produces = .results(stack == .int ? [.int, .int] : [stack, .int])
        return Behavior.contextRead(name, takes: from ? [.int] : [], tags: [.fallible],
                                    produces: produces) { a, context in
            let items = context.items(of: stack)
            let start = from ? max(1, (a[0] as! IntItem).value) : 1
            guard let probe = items.first, start < items.count,
                  let found = locate(probe, items, start) else {
                // As if the stack were empty: the start index is handed back.
                return (from ? [Router(.int, a[0])] : [])
                    + [Router(.error, ErrorItem(missingArgumentsFor: name, on: stack)
                        .observed(by: name, context.recording))]
            }
            let position = IntItem(found + 1).observed(by: name, context.recording)
            return [Router(.int, position), Router(stack, items[found])]
        }
    }

    /// A lookup whose kind is a predicate on (probe, candidate).
    static func matching(
        _ name: PushInstruction, on stack: PushStack, from: Bool,
        _ matches: @escaping @Sendable (any Item, any Item) -> Bool
    ) -> Behavior {
        lookupBehavior(name, on: stack, from: from) { probe, items, start in
            (start..<items.count).first { matches(probe, items[$0]) }
        }
    }

    /// A lookup for the nearest candidate by `distance`, the topmost on a tie; a
    /// candidate with no distance (a NaN) is passed over.
    static func nearest(
        _ name: PushInstruction, on stack: PushStack, from: Bool,
        _ distance: @escaping @Sendable (any Item, any Item) -> Double?
    ) -> Behavior {
        lookupBehavior(name, on: stack, from: from) { probe, items, start in
            var best: (index: Int, distance: Double)?
            for index in start..<items.count {
                guard let d = distance(probe, items[index]), !d.isNaN else { continue }
                if best == nil || d < best!.distance { best = (index, d) }
            }
            return best?.index
        }
    }


    // MARK: - The kinds

    @Sendable static func equal(_ probe: any Item, _ candidate: any Item) -> Bool { candidate.isEqual(to: probe) }

    static func vectorPrefix<V: VectorItem>(_ type: V.Type) -> @Sendable (any Item, any Item) -> Bool
    where V.Element: Equatable {
        { probe, candidate in
            guard let p = probe as? V, let c = candidate as? V else { return false }
            return c.value.starts(with: p.value)
        }
    }

    static func vectorContaining<V: VectorItem>(_ type: V.Type) -> @Sendable (any Item, any Item) -> Bool
    where V.Element: Equatable {
        { probe, candidate in
            guard let p = probe as? V, let c = candidate as? V else { return false }
            guard !p.value.isEmpty else { return true }
            guard p.value.count <= c.value.count else { return false }
            return (0...(c.value.count - p.value.count)).contains { c.value[$0...].starts(with: p.value) }
        }
    }

    @Sendable static func stringPrefix(_ probe: any Item, _ candidate: any Item) -> Bool {
        guard let p = probe as? StringItem, let c = candidate as? StringItem else { return false }
        return c.value.hasPrefix(p.value)
    }

    @Sendable static func stringContaining(_ probe: any Item, _ candidate: any Item) -> Bool {
        guard let p = probe as? StringItem, let c = candidate as? StringItem else { return false }
        return p.value.isEmpty || c.value.firstRange(of: p.value) != nil
    }

    /// The candidate block begins with the probe's root items.
    @Sendable static func codePrefix(_ probe: any Item, _ candidate: any Item) -> Bool {
        guard let p = probe as? CodeItem, let c = candidate as? CodeItem, p.value.count <= c.value.count else {
            return false
        }
        return zip(p.value, c.value).allSatisfy { $0.isEqual(to: $1) }
    }

    /// The probe (a one-item block standing for its item) is a point of the
    /// candidate, as `codeContains` asks.
    @Sendable static func codeContaining(_ probe: any Item, _ candidate: any Item) -> Bool {
        guard let p = probe as? CodeItem, let c = candidate as? CodeItem else { return false }
        return c.firstPointIndex(of: p.denotedItem) != nil
    }

    /// The same tree, with an atom matching any atom of its type; instructions
    /// must be the same instruction, since they are the structure.
    @Sendable static func sameShape(_ a: any Item, _ b: any Item) -> Bool {
        if let x = a as? CodeItem, let y = b as? CodeItem {
            return x.value.count == y.value.count && zip(x.value, y.value).allSatisfy { sameShape($0, $1) }
        }
        if let x = a as? InstructionItem, let y = b as? InstructionItem { return x.value == y.value }
        return type(of: a) == type(of: b)
    }

    @Sendable static func intDistance(_ probe: any Item, _ candidate: any Item) -> Double? {
        guard let p = probe as? IntItem, let c = candidate as? IntItem else { return nil }
        return abs(Double(c.value) - Double(p.value))
    }

    @Sendable static func doubleDistance(_ probe: any Item, _ candidate: any Item) -> Double? {
        guard let p = probe as? DoubleItem, let c = candidate as? DoubleItem else { return nil }
        return abs(c.value - p.value)
    }

    /// Distance between characters by their first Unicode scalar values.
    @Sendable static func charDistance(_ probe: any Item, _ candidate: any Item) -> Double? {
        guard let p = (probe as? CharItem)?.value.unicodeScalars.first,
              let c = (candidate as? CharItem)?.value.unicodeScalars.first else { return nil }
        return abs(Double(c.value) - Double(p.value))
    }


    // MARK: - The family

    /// Each lookup and its `…From` variant.
    static func both(_ name: PushInstruction, _ fromName: PushInstruction,
                     _ make: (PushInstruction, Bool) -> Behavior) -> [PushInstruction: Behavior] {
        [name: make(name, false), fromName: make(fromName, true)]
    }

    static let lookupBehaviors: [PushInstruction: Behavior] = {
        var family: [PushInstruction: Behavior] = [:]
        func add(_ entries: [PushInstruction: Behavior]) { family.merge(entries) { first, _ in first } }

        // Equal: on every value stack but `.bool`, whose two values make it moot.
        let equalStacks: [(PushStack, PushInstruction, PushInstruction)] = [
            (.int, .intLookupEqual, .intLookupEqualFrom),
            (.double, .doubleLookupEqual, .doubleLookupEqualFrom),
            (.char, .charLookupEqual, .charLookupEqualFrom),
            (.string, .stringLookupEqual, .stringLookupEqualFrom),
            (.code, .codeLookupEqual, .codeLookupEqualFrom),
            (.vecBool, .vecBoolLookupEqual, .vecBoolLookupEqualFrom),
            (.vecInt, .vecIntLookupEqual, .vecIntLookupEqualFrom),
            (.vecDouble, .vecDoubleLookupEqual, .vecDoubleLookupEqualFrom),
            (.vecString, .vecStringLookupEqual, .vecStringLookupEqualFrom)
        ]
        for (stack, name, fromName) in equalStacks {
            add(both(name, fromName) { matching($0, on: stack, from: $1, equal) })
        }

        // Nearest: the types with a distance.
        add(both(.intLookupNearest, .intLookupNearestFrom) { nearest($0, on: .int, from: $1, intDistance) })
        add(both(.doubleLookupNearest, .doubleLookupNearestFrom) { nearest($0, on: .double, from: $1, doubleDistance) })
        add(both(.charLookupNearest, .charLookupNearestFrom) { nearest($0, on: .char, from: $1, charDistance) })

        // Prefix and Containing: the collections.
        add(both(.stringLookupPrefix, .stringLookupPrefixFrom) { matching($0, on: .string, from: $1, stringPrefix) })
        add(both(.stringLookupContaining, .stringLookupContainingFrom) {
            matching($0, on: .string, from: $1, stringContaining)
        })
        add(both(.codeLookupPrefix, .codeLookupPrefixFrom) { matching($0, on: .code, from: $1, codePrefix) })
        add(both(.codeLookupContaining, .codeLookupContainingFrom) {
            matching($0, on: .code, from: $1, codeContaining)
        })
        add(both(.vecBoolLookupPrefix, .vecBoolLookupPrefixFrom) {
            matching($0, on: .vecBool, from: $1, vectorPrefix(VecBoolItem.self))
        })
        add(both(.vecIntLookupPrefix, .vecIntLookupPrefixFrom) {
            matching($0, on: .vecInt, from: $1, vectorPrefix(VecIntItem.self))
        })
        add(both(.vecDoubleLookupPrefix, .vecDoubleLookupPrefixFrom) {
            matching($0, on: .vecDouble, from: $1, vectorPrefix(VecDoubleItem.self))
        })
        add(both(.vecStringLookupPrefix, .vecStringLookupPrefixFrom) {
            matching($0, on: .vecString, from: $1, vectorPrefix(VecStringItem.self))
        })
        add(both(.vecBoolLookupContaining, .vecBoolLookupContainingFrom) {
            matching($0, on: .vecBool, from: $1, vectorContaining(VecBoolItem.self))
        })
        add(both(.vecIntLookupContaining, .vecIntLookupContainingFrom) {
            matching($0, on: .vecInt, from: $1, vectorContaining(VecIntItem.self))
        })
        add(both(.vecDoubleLookupContaining, .vecDoubleLookupContainingFrom) {
            matching($0, on: .vecDouble, from: $1, vectorContaining(VecDoubleItem.self))
        })
        add(both(.vecStringLookupContaining, .vecStringLookupContainingFrom) {
            matching($0, on: .vecString, from: $1, vectorContaining(VecStringItem.self))
        })

        // Shape: code.
        add(both(.codeLookupShape, .codeLookupShapeFrom) { matching($0, on: .code, from: $1, sameShape) })
        return family
    }()
}
