//
//  Lookup Behaviors.swift
//  Plunge
//
//  Lookup by pattern on the stacks themselves: the sieve made visible to a
//  program, and the language's keyed storage without a dictionary type.
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
//    error, and nothing consumed.
//  When the stack is `.int` itself, the copy goes down first and the position
//  on top of it, so whatever takes the position (a yank, a `…From`) pops it and
//  finds the copy on top and the match at that depth, as on any other stack.
//  (Until 2026-11-09 the copy went on top, burying the position.) To walk every
//  match on `.int`, drop the copy from under the position: `.intSwap .intPop`,
//  then `.intLookupEqualFrom`.
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
//  **The same kinds within a collection**: `xFind…` reads a
//  container and a probe of its element type, written in that order, and gives
//  the first element that matches with its index (index down, element on top),
//  or refuses. `…From` reads a start index as well. Alongside them, `IndexOf`
//  gains its `…From` forms, so every search inside a collection can resume.
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
        return Behavior.contextRead(name, takes: from ? [.int] : [], reads: [stack], observes: [stack],
                                    tags: [.fallible],
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
            // Routers land in order: on `.int` the position goes last, on top.
            return stack == .int
                ? [Router(.int, items[found]), Router(.int, position)]
                : [Router(.int, position), Router(stack, items[found])]
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
            return c.value.starts(with: p.value, by: V.same)
        }
    }

    static func vectorContaining<V: VectorItem>(_ type: V.Type) -> @Sendable (any Item, any Item) -> Bool
    where V.Element: Equatable {
        { probe, candidate in
            guard let p = probe as? V, let c = candidate as? V else { return false }
            guard !p.value.isEmpty else { return true }
            guard p.value.count <= c.value.count else { return false }
            return (0...(c.value.count - p.value.count)).contains { c.value[$0...].starts(with: p.value, by: V.same) }
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


    // MARK: - Within a collection

    /// The first index at or after `start` whose element satisfies `matches`.
    static func firstIndex(_ count: Int, from start: Int, where matches: (Int) -> Bool) -> Int? {
        (max(0, start)..<max(max(0, start), count)).first(where: matches)
    }

    /// The index at or after `start` whose element is nearest by `distance`,
    /// the first on a tie; an element with no distance is passed over.
    static func nearestIndex(_ count: Int, from start: Int, by distance: (Int) -> Double?) -> Int? {
        var best: (index: Int, distance: Double)?
        for index in max(0, start)..<max(max(0, start), count) {
            guard let d = distance(index), !d.isNaN else { continue }
            if best == nil || d < best!.distance { best = (index, d) }
        }
        return best?.index
    }

    /// A container and a probe of its element type (and a start, for `…From`),
    /// in written order.
    static func findBehavior<C: TracingItem & ValueItem>(
        _ name: PushInstruction, in container: C.Type, from: Bool,
        _ search: @escaping @Sendable (C, any Item, Int) -> Int?
    ) -> Behavior {
        if from {
            return Behavior.finding(name, reads: C.self, C.ElementItem.self, IntItem.self,
                                    gives: C.ElementItem.self) { c, probe, start throws(Refusal) in
                guard let i = search(c, probe, start.value) else {
                    throw Refusal("Not found in .\(name)", kind: .notFound)
                }
                return Found(c.element(at: i), at: i, in: c)
            }
        }
        return Behavior.finding(name, reads: C.self, C.ElementItem.self,
                                gives: C.ElementItem.self) { c, probe throws(Refusal) in
            guard let i = search(c, probe, 0) else { throw Refusal("Not found in .\(name)", kind: .notFound) }
            return Found(c.element(at: i), at: i, in: c)
        }
    }

    /// The first element matching the probe under a kind.
    static func find<C: TracingItem & ValueItem>(
        _ name: PushInstruction, in container: C.Type, from: Bool,
        _ matches: @escaping @Sendable (any Item, any Item) -> Bool
    ) -> Behavior {
        findBehavior(name, in: container, from: from) { c, probe, start in
            firstIndex(c.elementCount, from: start) {
                matches(probe, C.ElementItem(c.element(at: $0), call: []))
            }
        }
    }

    /// The element nearest the probe.
    static func findNearest<C: TracingItem & ValueItem>(
        _ name: PushInstruction, in container: C.Type, from: Bool,
        _ distance: @escaping @Sendable (any Item, any Item) -> Double?
    ) -> Behavior {
        findBehavior(name, in: container, from: from) { c, probe, start in
            nearestIndex(c.elementCount, from: start) {
                distance(probe, C.ElementItem(c.element(at: $0), call: []))
            }
        }
    }

    /// The first root item of a block that is a block matching the probe block:
    /// `( ( "a" 1 ) ( "b" 2 ) ) ( "b" ) .codeFindPrefix` gives `( "b" 2 )` and 1.
    static func codeFind(
        _ name: PushInstruction, from: Bool,
        _ matches: @escaping @Sendable (any Item, any Item) -> Bool
    ) -> Behavior {
        @Sendable func search(_ block: CodeItem, _ probe: CodeItem, _ start: Int) throws(Refusal) -> Found<[any Item]> {
            guard let i = firstIndex(block.value.count, from: start, where: { matches(probe, block.value[$0]) }) else {
                throw Refusal("Not found in .\(name)", kind: .notFound)
            }
            return Found((block.value[i] as! CodeItem).value, at: i)
        }
        if from {
            return Behavior.finding(name, reads: CodeItem.self, CodeItem.self, IntItem.self,
                                    gives: CodeItem.self) { block, probe, start throws(Refusal) in
                try search(block, probe, start.value)
            }
        }
        return Behavior.finding(name, reads: CodeItem.self, CodeItem.self,
                                gives: CodeItem.self) { block, probe throws(Refusal) in
            try search(block, probe, 0)
        }
    }

    /// `IndexOf` from a start, which a search that walks every occurrence needs:
    /// `v x start .vecIntIndexOfFrom`, `s c start .stringIndexOfFrom`, `hay needle start .stringIndexOfRunFrom`.
    /// The index is counted from the front, not from the start.
    static func indexOfFromBehavior<V: VectorItem>(_ name: PushInstruction, _ type: V.Type) -> Behavior
    where V.Element: Equatable {
        Behavior.operation(name, reads: V.self, V.Scalar.self, IntItem.self,
                           gives: IntItem.self) { v, x, start throws(Refusal) in
            guard let i = firstIndex(v.count, from: start, where: { v[$0] == x }) else {
                throw Refusal("Not found in .\(name)", kind: .notFound)
            }
            return i
        }
        .described(
            "Finds an element from an index: `v x i .\(name)` gives the index of the first x in v at index i"
            + " or later, leaving all three; refuses on a miss."
        )
    }

    static let stringIndexOfFrom_Behavior =
        Behavior.operation(.stringIndexOfFrom, reads: StringItem.self, CharItem.self, IntItem.self,
                           gives: IntItem.self) { s, c, start throws(Refusal) in
            let characters = Array(s)
            guard let i = firstIndex(characters.count, from: start, where: { characters[$0] == c }) else {
                throw Refusal("Not found in .stringIndexOfFrom: \(c)", kind: .notFound)
            }
            return i
        }
        .described(
            "Finds a char from an index: `s c i .stringIndexOfFrom` gives the index of the first c in s at index i"
            + " or later, leaving all three; refuses on a miss."
        )

    /// An empty needle is found at the start, if the start is within the string
    /// or at its end.
    static let stringIndexOfRunFrom_Behavior =
        Behavior.operation(.stringIndexOfRunFrom, reads: StringItem.self, StringItem.self, IntItem.self,
                           gives: IntItem.self) { hay, needle, start throws(Refusal) in
            let from = max(0, start)
            guard from <= hay.count,
                  let range = hay[hay.index(hay.startIndex, offsetBy: from)...].firstRange(of: needle) else {
                throw Refusal("Not found in .stringIndexOfRunFrom: \(needle)", kind: .notFound)
            }
            return hay.distance(from: hay.startIndex, to: range.lowerBound)
        }
        .described(
            "Finds a substring from an index: `s t i .stringIndexOfRunFrom` gives the index of the first t in s at index i"
            + " or later, leaving all three; an empty t is found at i; refuses on a miss."
        )

    static let indexOfFromBehaviors: [PushInstruction: Behavior] = [
        .vecBoolIndexOfFrom: indexOfFromBehavior(.vecBoolIndexOfFrom, VecBoolItem.self),
        .vecIntIndexOfFrom: indexOfFromBehavior(.vecIntIndexOfFrom, VecIntItem.self),
        .vecDoubleIndexOfFrom: indexOfFromBehavior(.vecDoubleIndexOfFrom, VecDoubleItem.self),
        .vecStringIndexOfFrom: indexOfFromBehavior(.vecStringIndexOfFrom, VecStringItem.self),
        .stringIndexOfFrom: stringIndexOfFrom_Behavior,
        .stringIndexOfRunFrom: stringIndexOfRunFrom_Behavior
    ]


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
            add(both(name, fromName) {
                matching($0, on: stack, from: $1, equal)
                    .described(
                        "Reads the top \(stack.noun) as a probe and copies the topmost one below that equals it"
                        + ($1 ? ", searching from depth i (at least 1)" : "")
                        + (stack == .int
                            ? ", then its depth + 1 on top of the copy"
                            : ", pushing its depth + 1 onto `.int`")
                        + "; refuses on a miss."
                    )
            })
        }

        // Nearest: the types with a distance.
        add(both(.intLookupNearest, .intLookupNearestFrom) {
            nearest($0, on: .int, from: $1, intDistance)
                .described(
                    "Reads the top int as a probe and copies the nearest one below it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", the topmost on a tie, then its depth + 1 on top of the copy"
                    + ($1 ? "; refuses when i is past the bottom." : ".")
                )
        })
        add(both(.doubleLookupNearest, .doubleLookupNearestFrom) {
            nearest($0, on: .double, from: $1, doubleDistance)
                .described(
                    "Reads the top double as a probe and copies the nearest one below it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", the topmost on a tie, pushing its depth + 1 onto `.int`"
                    + ($1 ? "; refuses when i is past the bottom." : ".")
                )
        })
        add(both(.charLookupNearest, .charLookupNearestFrom) {
            nearest($0, on: .char, from: $1, charDistance)
                .described(
                    "Reads the top char as a probe and copies the one below nearest it by code point"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", the topmost on a tie, pushing its depth + 1 onto `.int`"
                    + ($1 ? "; refuses when i is past the bottom." : ".")
                )
        })

        // Prefix and Containing: the collections.
        add(both(.stringLookupPrefix, .stringLookupPrefixFrom) {
            matching($0, on: .string, from: $1, stringPrefix)
                .described(
                    "Reads the top string as a probe and copies the topmost one below that begins with it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.stringLookupContaining, .stringLookupContainingFrom) {
            matching($0, on: .string, from: $1, stringContaining)
                .described(
                    "Reads the top string as a probe and copies the topmost one below that contains it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.codeLookupPrefix, .codeLookupPrefixFrom) {
            matching($0, on: .code, from: $1, codePrefix)
                .described(
                    "Reads the top block as a probe and copies the topmost one below whose items begin with its items"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.codeLookupContaining, .codeLookupContainingFrom) {
            matching($0, on: .code, from: $1, codeContaining)
                .described(
                    "Reads the top block as a probe and copies the topmost one below containing it, or its lone item,"
                    + " anywhere inside"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecBoolLookupPrefix, .vecBoolLookupPrefixFrom) {
            matching($0, on: .vecBool, from: $1, vectorPrefix(VecBoolItem.self))
                .described(
                    "Reads the top vector of bools as a probe and copies the topmost one below that begins with it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecIntLookupPrefix, .vecIntLookupPrefixFrom) {
            matching($0, on: .vecInt, from: $1, vectorPrefix(VecIntItem.self))
                .described(
                    "Reads the top vector of ints as a probe and copies the topmost one below that begins with it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecDoubleLookupPrefix, .vecDoubleLookupPrefixFrom) {
            matching($0, on: .vecDouble, from: $1, vectorPrefix(VecDoubleItem.self))
                .described(
                    "Reads the top vector of doubles as a probe and copies the topmost one below that begins with it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecStringLookupPrefix, .vecStringLookupPrefixFrom) {
            matching($0, on: .vecString, from: $1, vectorPrefix(VecStringItem.self))
                .described(
                    "Reads the top vector of strings as a probe and copies the topmost one below that begins with it"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecBoolLookupContaining, .vecBoolLookupContainingFrom) {
            matching($0, on: .vecBool, from: $1, vectorContaining(VecBoolItem.self))
                .described(
                    "Reads the top vector of bools as a probe and copies the topmost one below that contains it"
                    + " as a run"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecIntLookupContaining, .vecIntLookupContainingFrom) {
            matching($0, on: .vecInt, from: $1, vectorContaining(VecIntItem.self))
                .described(
                    "Reads the top vector of ints as a probe and copies the topmost one below that contains it"
                    + " as a run"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecDoubleLookupContaining, .vecDoubleLookupContainingFrom) {
            matching($0, on: .vecDouble, from: $1, vectorContaining(VecDoubleItem.self))
                .described(
                    "Reads the top vector of doubles as a probe and copies the topmost one below that contains it"
                    + " as a run"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        add(both(.vecStringLookupContaining, .vecStringLookupContainingFrom) {
            matching($0, on: .vecString, from: $1, vectorContaining(VecStringItem.self))
                .described(
                    "Reads the top vector of strings as a probe and copies the topmost one below that contains it"
                    + " as a run"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })

        // Shape: code.
        add(both(.codeLookupShape, .codeLookupShapeFrom) {
            matching($0, on: .code, from: $1, sameShape)
                .described(
                    "Reads the top block as a probe and copies the topmost one below with its shape"
                    + " (same nesting and instructions, atoms matching by type)"
                    + ($1 ? ", searching from depth i (at least 1)" : "")
                    + ", pushing its depth + 1 onto `.int`; refuses on a miss."
                )
        })
        return family
    }()

    /// Lookup within a collection, and `IndexOf` from a start: queries, so
    /// operations rather than context reads, kept apart from the stack lookups.
    static let findBehaviors: [PushInstruction: Behavior] = {
        var family: [PushInstruction: Behavior] = [:]
        func add(_ entries: [PushInstruction: Behavior]) { family.merge(entries) { first, _ in first } }
        add(both(.vecIntFindNearest, .vecIntFindNearestFrom) {
            findNearest($0, in: VecIntItem.self, from: $1, intDistance)
                .described(
                    $1
                        ? "Finds the element of v nearest x at index i or later (`v x i`), the first on a tie, pushing"
                          + " its index and then it, leaving all three; refuses when there is none."
                        : "Finds the element of v nearest x, the first on a tie, pushing its index and then it, leaving"
                          + " both; refuses on an empty v."
                )
        })
        add(both(.vecDoubleFindNearest, .vecDoubleFindNearestFrom) {
            findNearest($0, in: VecDoubleItem.self, from: $1, doubleDistance)
                .described(
                    $1
                        ? "Finds the element of v nearest x at index i or later, the first on a tie, pushing its index"
                          + " and it, leaving all three; refuses when there is none."
                        : "Finds the element of v nearest x, the first on a tie, pushing its index and it, leaving"
                          + " both; refuses on an empty v."
                )
        })
        add(both(.stringFindNearest, .stringFindNearestFrom) {
            findNearest($0, in: StringItem.self, from: $1, charDistance)
                .described(
                    $1
                        ? "Finds the char of s nearest c by code point at index i or later, the first on a tie, pushing"
                          + " its index and it, leaving all three; refuses when there is none."
                        : "Finds the char of s nearest c by code point, the first on a tie, pushing its index and it,"
                          + " leaving both; refuses on an empty s."
                )
        })
        add(both(.vecStringFindPrefix, .vecStringFindPrefixFrom) {
            find($0, in: VecStringItem.self, from: $1, stringPrefix)
                .described(
                    $1
                        ? "Finds the first string of v at index i or later that begins with s, pushing its index and"
                          + " it, leaving all three; refuses when none does."
                        : "Finds the first string of v that begins with s, pushing its index and it, leaving both;"
                          + " refuses when none does."
                )
        })
        add(both(.vecStringFindContaining, .vecStringFindContainingFrom) {
            find($0, in: VecStringItem.self, from: $1, stringContaining)
                .described(
                    $1
                        ? "Finds the first string of v at index i or later that contains s, pushing its index and it,"
                          + " leaving all three; refuses when none does."
                        : "Finds the first string of v that contains s, pushing its index and it, leaving both; refuses"
                          + " when none does."
                )
        })
        add(both(.codeFindPrefix, .codeFindPrefixFrom) {
            codeFind($0, from: $1, codePrefix)
                .described(
                    $1
                        ? "Finds a sub-block from root index i on: `( … ) ( p ) i .codeFindPrefixFrom` gives the first"
                          + " that begins with p's items, and its index; refuses on a miss."
                        : "Finds a sub-block: `( … ) ( p ) .codeFindPrefix` gives the first root item that is a block"
                          + " beginning with p's items, and its index; refuses on a miss."
                )
        })
        add(indexOfFromBehaviors)
        return family
    }()
}
