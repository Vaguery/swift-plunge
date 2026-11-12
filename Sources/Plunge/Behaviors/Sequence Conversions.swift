//
//  Sequence Conversions.swift
//  Plunge
//
//  The rest of the collection operations without functions (2026-11-12; the
//  rules are in `Sequence Behaviors.swift`): frequencies, prefix sums,
//  conversions between vector types and digits, ordering vectors of bools,
//  chunks and windows, and the root-level code operations.
//

nonisolated extension Behavior {

    /// **Two results of different kinds from one argument** (`Frequencies`: the
    /// distinct values, then their counts). On two stacks, each records the
    /// instruction and then the pop that clears the other; on one stack, the
    /// selecting crux (provenance law 5), the first produced ending deepest.
    static func dividing<A: ValueItem, R1: ValueItem, R2: ValueItem>(
        _ label: PushInstruction,
        takes: A.Type,
        gives first: R1.Type, _ second: R2.Type,
        tags: Set<InstructionTag> = [],
        _ body: @escaping @Sendable (A.Value) -> (R1.Value, R2.Value)
    ) -> Behavior {
        typed(label, stacks: [A.pushStack], reading: false, gives: R1.pushStack,
              produces: .results([R1.pushStack, R2.pushStack]), tags: tags) { args, call, recording in
            let (a, b) = body(args[0].exactly(A.self)!.value)
            if R1.pushStack == R2.pushStack {
                return [
                    Router(R1.pushStack, R1(a, call: recording(Behavior.selecting(0, of: 2, on: R1.pushStack,
                                                                                  from: call.written)))),
                    Router(R2.pushStack, R2(b, call: recording(Behavior.selecting(1, of: 2, on: R2.pushStack,
                                                                                  from: call.written))))
                ]
            }
            let clearSecond = [InstructionItem(R2.pushStack.popInstruction)]
            let clearFirst = [InstructionItem(R1.pushStack.popInstruction)]
            return [
                Router(R1.pushStack, R1(a, call: recording(call.recorded(producing: R1.pushStack,
                                                                         after: clearSecond)))),
                Router(R2.pushStack, R2(b, call: recording(call.recorded(producing: R2.pushStack,
                                                                         after: clearFirst))))
            ]
        }
    }
}

nonisolated extension Interpreter {

    // MARK: - Frequencies

    /// The distinct elements in order, and how many times each occurs.
    static func tally<E, K: Hashable>(_ values: [E], key: (E) -> K, by precedes: (E, E) -> Bool) -> ([E], [Int]) {
        var counts: [K: Int] = [:], firsts: [E] = []
        for value in values {
            let k = key(value)
            if counts[k] == nil { firsts.append(value) }
            counts[k, default: 0] += 1
        }
        let order = sortedPositions(firsts, by: precedes)
        return (order.map { firsts[$0] }, order.map { counts[key(firsts[$0])]! })
    }

    static func frequenciesBehavior<V: VectorItem>(
        _ label: PushInstruction, _ type: V.Type, by precedes: @escaping @Sendable (V.Element, V.Element) -> Bool
    ) -> Behavior {
        Behavior.dividing(label, takes: V.self, gives: V.self, VecIntItem.self) { x in
            tally(x, key: V.key, by: precedes)
        }
        .described("Counts each distinct element: gives the distinct elements in ascending order, then a vector of "
                   + "ints with how many times each occurs" + (V.pushStack == .vecInt ? ", on top" : "") + ".")
    }

    static let vecBoolFrequencies_Behavior = frequenciesBehavior(.vecBoolFrequencies, VecBoolItem.self,
                                                                 by: boolPrecedes)
    static let vecIntFrequencies_Behavior = frequenciesBehavior(.vecIntFrequencies, VecIntItem.self) { $0 < $1 }
    static let vecDoubleFrequencies_Behavior = frequenciesBehavior(.vecDoubleFrequencies, VecDoubleItem.self,
                                                                   by: doublePrecedes)
    static let vecStringFrequencies_Behavior = frequenciesBehavior(.vecStringFrequencies, VecStringItem.self) {
        $0 < $1
    }

    static let stringFrequencies_Behavior =
        Behavior.dividing(.stringFrequencies, takes: StringItem.self, gives: StringItem.self, VecIntItem.self) { x in
            let (chars, counts) = tally(Array(x), key: { $0 }, by: { $0 < $1 })
            return (String(chars), counts)
        }
        .described("Counts each distinct char: gives the distinct chars in Unicode order as a string, then a vector "
                   + "of ints with how many times each occurs.")

    // MARK: - Prefix sums

    static let vecIntPrefixSums_Behavior =
        Behavior.operation(.vecIntPrefixSums, takes: VecIntItem.self, gives: VecIntItem.self) { x throws(Refusal) in
            var total = 0, sums: [Int] = []
            for value in x {
                total = try IntArithmetic.add(total, value, .vecIntPrefixSums)
                sums.append(total)
            }
            return sums
        }
        .described("Running totals: element i is the sum of elements 0 through i; refuses on overflow.")

    static let vecDoublePrefixSums_Behavior =
        Behavior.operation(.vecDoublePrefixSums, takes: VecDoubleItem.self,
                           gives: VecDoubleItem.self) { x throws(Refusal) in
            var total = 0.0, sums: [Double] = []
            for value in x {
                total = try DoubleArithmetic.add(total, value, .vecDoublePrefixSums)
                sums.append(total)
            }
            return sums
        }
        .described("Running totals: element i is the sum of elements 0 through i; refuses a total that is not "
                   + "finite.")

    // MARK: - Conversions

    static let vecDoubleFromVecInt_Behavior =
        Behavior.operation(.vecDoubleFromVecInt, takes: VecIntItem.self, gives: VecDoubleItem.self) { x in
            x.map { Double($0) }
        }
        .described("Converts every int to the nearest double.")

    static let vecIntFromVecDouble_Behavior =
        Behavior.operation(.vecIntFromVecDouble, takes: VecDoubleItem.self,
                           gives: VecIntItem.self) { x throws(Refusal) in
            var result: [Int] = []
            for (index, value) in x.enumerated() {
                guard value.isFinite, value >= Double(Int.min), value < Double(Int.max) else {
                    throw Refusal("at index \(index): Overflow in .vecIntFromVecDouble: \(value) → Int")
                }
                result.append(Int(value))
            }
            return result
        }
        .described("Converts every double, truncating toward zero; refuses one that is not finite or out of range, "
                   + "naming the index.")

    static let vecIntFromVecBool_Behavior =
        Behavior.operation(.vecIntFromVecBool, takes: VecBoolItem.self, gives: VecIntItem.self) { x in
            x.map { $0 ? 1 : 0 }
        }
        .described("Converts every bool: true is 1, false is 0.")

    static let vecIntFromInt_Behavior =
        Behavior.operation(.vecIntFromInt, takes: IntItem.self, gives: VecIntItem.self) { n in
            String(n.magnitude).compactMap { $0.wholeNumberValue }
        }
        .described("The decimal digits of an int, most significant first, ignoring its sign: `-305 .vecIntFromInt` "
                   + "gives [3, 0, 5].")

    static let intFromVecInt_Behavior =
        Behavior.operation(.intFromVecInt, takes: VecIntItem.self, gives: IntItem.self) { x throws(Refusal) in
            var total = 0
            for digit in x {
                total = try IntArithmetic.add(IntArithmetic.multiply(total, 10, .intFromVecInt), digit, .intFromVecInt)
            }
            return total
        }
        .described("Reads a vector of ints as decimal digits, most significant first: [3, 0, 5] gives 305 (any "
                   + "int counts as a digit's value); an empty vector gives 0; refuses on overflow.")

    // MARK: - Ordering vectors of bools

    static let vecBoolLT_Behavior =
        Behavior.operation(.vecBoolLT, reads: VecBoolItem.self, VecBoolItem.self, gives: BoolItem.self) { a, b in
            a.lexicographicallyPrecedes(b, by: boolPrecedes)
        }
        .described("Compares lexicographically, false before true, leaving both: `a b .vecBoolLT` gives a < b.")
    static let vecBoolLTE_Behavior =
        Behavior.operation(.vecBoolLTE, reads: VecBoolItem.self, VecBoolItem.self, gives: BoolItem.self) { a, b in
            !b.lexicographicallyPrecedes(a, by: boolPrecedes)
        }
        .described("Compares lexicographically, false before true, leaving both: `a b .vecBoolLTE` gives a ≤ b.")
    static let vecBoolGT_Behavior =
        Behavior.operation(.vecBoolGT, reads: VecBoolItem.self, VecBoolItem.self, gives: BoolItem.self) { a, b in
            b.lexicographicallyPrecedes(a, by: boolPrecedes)
        }
        .described("Compares lexicographically, false before true, leaving both: `a b .vecBoolGT` gives a > b.")
    static let vecBoolGTE_Behavior =
        Behavior.operation(.vecBoolGTE, reads: VecBoolItem.self, VecBoolItem.self, gives: BoolItem.self) { a, b in
            !a.lexicographicallyPrecedes(b, by: boolPrecedes)
        }
        .described("Compares lexicographically, false before true, leaving both: `a b .vecBoolGTE` gives a ≥ b.")
    static let vecBoolMax_Behavior =
        extremeBehavior(.vecBoolMax, making: VecBoolItem.self, greatest: true, by: boolPrecedes)
    static let vecBoolMin_Behavior =
        extremeBehavior(.vecBoolMin, making: VecBoolItem.self, greatest: false, by: boolPrecedes)

    // MARK: - Chunks and windows

    /// The start and length of each piece: consecutive chunks of `size`, or
    /// every window of `size` (sliding by one).
    static func pieces(_ count: Int, size: Int, sliding: Bool) -> [(start: Int, length: Int)] {
        let size = max(1, size)
        if sliding {
            guard count >= size else { return [] }
            return (0...(count - size)).map { ($0, size) }
        }
        return stride(from: 0, to: count, by: size).map { ($0, min(size, count - $0)) }
    }

    /// `v n .label`: the pieces of `v`, as a block of vectors.
    static func piecesBehavior<V: VectorItem>(_ label: PushInstruction, _ type: V.Type, sliding: Bool) -> Behavior {
        Behavior.operation(label, takes: V.self, IntItem.self, gives: CodeItem.self) { x, n throws(Refusal) in
            let parts = pieces(x.count, size: n, sliding: sliding)
            try checkSize(parts.reduce(0) { $0 + $1.length }, label)
            return parts.map { V(Array(x[$0.start ..< $0.start + $0.length]), call: []) }
        }
        .described(sliding
                   ? "Every window: `v n .\(label)` gives a block of the vectors of n consecutive elements, sliding "
                     + "by one (none when n exceeds the length; n below 1 counts as 1); refuses a result over the "
                     + "size limit."
                   : "Chunks: `v n .\(label)` gives a block of the vectors of n consecutive elements, the last "
                     + "possibly shorter (n below 1 counts as 1).")
    }

    static let vecBoolChunks_Behavior = piecesBehavior(.vecBoolChunks, VecBoolItem.self, sliding: false)
    static let vecIntChunks_Behavior = piecesBehavior(.vecIntChunks, VecIntItem.self, sliding: false)
    static let vecDoubleChunks_Behavior = piecesBehavior(.vecDoubleChunks, VecDoubleItem.self, sliding: false)
    static let vecStringChunks_Behavior = piecesBehavior(.vecStringChunks, VecStringItem.self, sliding: false)
    static let vecBoolWindows_Behavior = piecesBehavior(.vecBoolWindows, VecBoolItem.self, sliding: true)
    static let vecIntWindows_Behavior = piecesBehavior(.vecIntWindows, VecIntItem.self, sliding: true)
    static let vecDoubleWindows_Behavior = piecesBehavior(.vecDoubleWindows, VecDoubleItem.self, sliding: true)
    static let vecStringWindows_Behavior = piecesBehavior(.vecStringWindows, VecStringItem.self, sliding: true)

    static func stringPiecesBehavior(_ label: PushInstruction, sliding: Bool) -> Behavior {
        Behavior.operation(label, takes: StringItem.self, IntItem.self,
                           gives: VecStringItem.self) { x, n throws(Refusal) in
            let characters = Array(x)
            let parts = pieces(characters.count, size: n, sliding: sliding)
            try checkSize(parts.reduce(0) { $0 + $1.length }, label)
            return parts.map { String(characters[$0.start ..< $0.start + $0.length]) }
        }
        .described(sliding
                   ? "Every window: `s n .\(label)` gives the substrings of n consecutive chars, sliding by one "
                     + "(none when n exceeds the length; n below 1 counts as 1)."
                   : "Chunks: `s n .\(label)` gives the substrings of n consecutive chars, the last possibly "
                     + "shorter (n below 1 counts as 1).")
    }

    static let stringChunks_Behavior = stringPiecesBehavior(.stringChunks, sliding: false)
    static let stringWindows_Behavior = stringPiecesBehavior(.stringWindows, sliding: true)

    // MARK: - Code, at the root

    static let codeReverseRoot_Behavior =
        Behavior.operation(.codeReverseRoot, takes: CodeItem.self, gives: CodeItem.self) { x in Array(x.reversed()) }
        .described("Reverses the order of a block's root items.")

    static let codeFirstRoot_Behavior =
        Behavior.operation(.codeFirstRoot, takes: CodeItem.self, gives: CodeItem.self) { x throws(Refusal) in
            guard let first = x.first else {
                throw Refusal("Empty block in .codeFirstRoot", kind: .emptyCollection)
            }
            return boxedPointContents(first)
        }
        .described("Takes a block's first root item as a block; a leaf comes boxed as `( x )`; refuses an empty "
                   + "block.")

    static let codeLastRoot_Behavior =
        Behavior.operation(.codeLastRoot, takes: CodeItem.self, gives: CodeItem.self) { x throws(Refusal) in
            guard let last = x.last else {
                throw Refusal("Empty block in .codeLastRoot", kind: .emptyCollection)
            }
            return boxedPointContents(last)
        }
        .described("Takes a block's last root item as a block; a leaf comes boxed as `( x )`; refuses an empty "
                   + "block.")

    static let codeTakeRoot_Behavior =
        Behavior.operation(.codeTakeRoot, takes: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, n in
            Array(x.prefix(max(0, n)))
        }
        .described("Keeps the front: `( … ) n .codeTakeRoot` gives the first n root items, n clamped to 0 through "
                   + "the length.")

    static let codeDropRoot_Behavior =
        Behavior.operation(.codeDropRoot, takes: CodeItem.self, IntItem.self, gives: CodeItem.self) { x, n in
            Array(x.dropFirst(max(0, n)))
        }
        .described("Drops the front: `( … ) n .codeDropRoot` removes the first n root items, n clamped to 0 "
                   + "through the length.")
}
