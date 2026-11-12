//
//  Sequence Behaviors.swift
//  Plunge
//
//  Collection operations without functions (2026-11-12): sort, the positions of
//  the extremes, product and mean, the last occurrence, ranges, rotation,
//  interleaving, repetition, frequencies, prefix sums, conversions between
//  vector types and digits, ordering for vectors of bools, chunks and windows,
//  and the root-level code operations the vectors already had.
//
//  The rules that shape them:
//  - **Orders are total and fixed.** Every NaN is one value above every number
//    (`DoubleKey`); false sorts before true; strings in Unicode order. Sorts
//    are stable.
//  - **Rearrangements keep element provenance** (sort, rotate, interleave,
//    repeat): each element of the result is the element that went in. New
//    values (sums, frequencies, conversions) carry none.
//  - **Queries read and leave** (the extremes' positions, product, mean, the
//    last occurrence); everything else takes its arguments.
//  - **Sizes are checked before anything is built** against
//    `IteratorItem.collectionLimit`, so `0 1000000000000 .vecIntRange` refuses
//    at once instead of allocating.
//

nonisolated extension Interpreter {

    // MARK: - Orders

    /// false before true.
    @Sendable static func boolPrecedes(_ a: Bool, _ b: Bool) -> Bool { !a && b }

    /// A size over `IteratorItem.collectionLimit`, refused before it is built.
    static func checkSize(_ count: Int, _ label: PushInstruction) throws(Refusal) {
        guard count <= IteratorItem.collectionLimit else {
            throw Refusal("\(label): \(count) elements is over the limit of \(IteratorItem.collectionLimit)",
                          kind: .sizeRefusal)
        }
    }

    /// The positions of `values` in stable order by `precedes`.
    static func sortedPositions<E>(_ values: [E], by precedes: (E, E) -> Bool) -> [Int] {
        values.indices.sorted { precedes(values[$0], values[$1]) || (!precedes(values[$1], values[$0]) && $0 < $1) }
    }

    /// Rotation to the left by `n`, any sign, modulo `count`.
    static func rotation(_ n: Int, _ count: Int) -> Int {
        guard count > 0 else { return 0 }
        let r = n % count
        return r < 0 ? r + count : r
    }

    // MARK: - Sort

    static func sortBehavior<V: VectorItem>(
        _ label: PushInstruction, _ type: V.Type, by precedes: @escaping @Sendable (V.Element, V.Element) -> Bool
    ) -> Behavior {
        Behavior.assembling(label, takes: V.self, gives: V.self) { x in
            let order = sortedPositions(x.value, by: precedes)
            let origins = x.origins()
            return Built(order.map { x.value[$0] }, members: order.map { origins[$0] })
        }
        .described("Sorts ascending, stably" + (V.Scalar.pushStack == .double ? "; NaN sorts last" : "")
                   + (V.Scalar.pushStack == .bool ? "; false before true" : "") + ".")
    }

    static let vecBoolSort_Behavior = sortBehavior(.vecBoolSort, VecBoolItem.self, by: boolPrecedes)
    static let vecIntSort_Behavior = sortBehavior(.vecIntSort, VecIntItem.self) { $0 < $1 }
    static let vecDoubleSort_Behavior = sortBehavior(.vecDoubleSort, VecDoubleItem.self, by: doublePrecedes)
    static let vecStringSort_Behavior = sortBehavior(.vecStringSort, VecStringItem.self) { $0 < $1 }

    static let stringSort_Behavior =
        Behavior.assembling(.stringSort, takes: StringItem.self, gives: StringItem.self) { x in
            let characters = Array(x.value)
            let order = sortedPositions(characters) { $0 < $1 }
            let origins = x.origins()
            return Built(String(order.map { characters[$0] }), members: order.map { origins[$0] })
        }
        .described("Sorts a string's chars in Unicode order, stably.")

    // MARK: - Where the extremes are

    static func extremeIndexBehavior<V: VectorItem>(
        _ label: PushInstruction, _ type: V.Type, greatest: Bool,
        by precedes: @escaping @Sendable (V.Element, V.Element) -> Bool
    ) -> Behavior {
        Behavior.operation(label, reads: V.self, gives: IntItem.self) { x throws(Refusal) in
            guard !x.isEmpty else { throw Refusal("Empty vector in .\(label)", kind: .emptyCollection) }
            return extremePosition(x, greatest: greatest, by: precedes)
        }
        .described("Pushes the index of the first \(greatest ? "greatest" : "least") element, leaving the vector"
                   + (V.Scalar.pushStack == .double ? "; NaN counts as greater than every number" : "")
                   + "; refuses an empty vector.")
    }

    static let vecIntIndexOfMax_Behavior = extremeIndexBehavior(.vecIntIndexOfMax, VecIntItem.self, greatest: true) {
        $0 < $1
    }
    static let vecIntIndexOfMin_Behavior = extremeIndexBehavior(.vecIntIndexOfMin, VecIntItem.self, greatest: false) {
        $0 < $1
    }
    static let vecDoubleIndexOfMax_Behavior =
        extremeIndexBehavior(.vecDoubleIndexOfMax, VecDoubleItem.self, greatest: true, by: doublePrecedes)
    static let vecDoubleIndexOfMin_Behavior =
        extremeIndexBehavior(.vecDoubleIndexOfMin, VecDoubleItem.self, greatest: false, by: doublePrecedes)
    static let vecStringIndexOfMax_Behavior =
        extremeIndexBehavior(.vecStringIndexOfMax, VecStringItem.self, greatest: true) { $0 < $1 }
    static let vecStringIndexOfMin_Behavior =
        extremeIndexBehavior(.vecStringIndexOfMin, VecStringItem.self, greatest: false) { $0 < $1 }

    // MARK: - Product and mean

    static let vecIntProduct_Behavior =
        Behavior.operation(.vecIntProduct, reads: VecIntItem.self, gives: IntItem.self) { x throws(Refusal) in
            var product = 1
            for value in x { product = try IntArithmetic.multiply(product, value, .vecIntProduct) }
            return product
        }
        .described("Multiplies the elements, leaving the vector; an empty vector gives 1; refuses on overflow.")

    static let vecDoubleProduct_Behavior =
        Behavior.operation(.vecDoubleProduct, reads: VecDoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            try DoubleArithmetic.finite(x.reduce(1.0, *), .vecDoubleProduct, "a product of \(x.count) factors")
        }
        .described("Multiplies the elements, leaving the vector; an empty vector gives 1; refuses a result that is "
                   + "not finite.")

    static let vecIntMean_Behavior =
        Behavior.operation(.vecIntMean, reads: VecIntItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard !x.isEmpty else { throw Refusal("Empty vector in .vecIntMean", kind: .emptyCollection) }
            return x.reduce(0.0) { $0 + Double($1) } / Double(x.count)
        }
        .described("Pushes the mean of the elements as a double, leaving the vector; refuses an empty vector.")

    static let vecDoubleMean_Behavior =
        Behavior.operation(.vecDoubleMean, reads: VecDoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard !x.isEmpty else { throw Refusal("Empty vector in .vecDoubleMean", kind: .emptyCollection) }
            return try DoubleArithmetic.finite(x.reduce(0.0, +) / Double(x.count), .vecDoubleMean,
                                               "a mean of \(x.count) values")
        }
        .described("Pushes the mean of the elements, leaving the vector; refuses an empty vector or a result that "
                   + "is not finite.")

    // MARK: - The last occurrence

    static func lastIndexOfBehavior<V: VectorItem>(_ label: PushInstruction, _ type: V.Type) -> Behavior {
        Behavior.operation(label, reads: V.self, V.Scalar.self, gives: IntItem.self) { x, y throws(Refusal) in
            guard let result = x.lastIndex(where: { V.same($0, y) }) else {
                throw Refusal("Not found in .\(label)", kind: .notFound)
            }
            return result
        }
        .described("Finds x from the end: `v x .\(label)` gives the index of its last occurrence, leaving both; "
                   + "refuses when x is absent.")
    }

    static let vecBoolLastIndexOf_Behavior = lastIndexOfBehavior(.vecBoolLastIndexOf, VecBoolItem.self)
    static let vecIntLastIndexOf_Behavior = lastIndexOfBehavior(.vecIntLastIndexOf, VecIntItem.self)
    static let vecDoubleLastIndexOf_Behavior = lastIndexOfBehavior(.vecDoubleLastIndexOf, VecDoubleItem.self)
    static let vecStringLastIndexOf_Behavior = lastIndexOfBehavior(.vecStringLastIndexOf, VecStringItem.self)

    static let stringLastIndexOf_Behavior =
        Behavior.operation(.stringLastIndexOf, reads: StringItem.self, CharItem.self,
                           gives: IntItem.self) { x, y throws(Refusal) in
            guard let index = x.lastIndex(of: y) else {
                throw Refusal("Not found in .stringLastIndexOf: \(y)", kind: .notFound)
            }
            return x.distance(from: x.startIndex, to: index)
        }
        .described("Finds a char from the end: `s c .stringLastIndexOf` gives the index of its last occurrence, "
                   + "leaving both; refuses when absent.")

    // MARK: - Ranges

    static let vecIntRange_Behavior =
        Behavior.operation(.vecIntRange, takes: IntItem.self, IntItem.self,
                           gives: VecIntItem.self) { a, b throws(Refusal) in
            let (span, overflowed) = b.subtractingReportingOverflow(a)
            guard !overflowed else { throw Refusal("vecIntRange: \(a) to \(b) is too long", kind: .sizeRefusal) }
            try checkSize(span.magnitude > UInt(Int.max) ? Int.max : Int(span.magnitude), .vecIntRange)
            return a <= b ? Array(a..<b) : Array(stride(from: a, to: b, by: -1))
        }
        .described("Counts from a toward b, b excluded: `a b .vecIntRange` gives [a, a+1, …, b−1], or counts down "
                   + "when b < a; refuses a range over the size limit.")

    static let vecIntRangeBy_Behavior =
        Behavior.operation(.vecIntRangeBy, takes: IntItem.self, IntItem.self, IntItem.self,
                           gives: VecIntItem.self) { a, b, step throws(Refusal) in
            guard step != 0 else { throw Refusal("vecIntRangeBy: a step of 0") }
            guard a == b || (b > a) == (step > 0) else {
                throw Refusal("vecIntRangeBy: a step of \(step) never reaches \(b) from \(a)")
            }
            let (span, overflowed) = b.subtractingReportingOverflow(a)
            guard !overflowed else { throw Refusal("vecIntRangeBy: \(a) to \(b) is too long", kind: .sizeRefusal) }
            let steps = (span.magnitude + step.magnitude - 1) / step.magnitude
            try checkSize(steps > UInt(Int.max) ? Int.max : Int(steps), .vecIntRangeBy)
            return Array(stride(from: a, to: b, by: step))
        }
        .described("Counts from a toward b by s, b excluded: `a b s .vecIntRangeBy`; refuses a step of 0, a step "
                   + "that goes the wrong way, or a range over the size limit.")

    // MARK: - Rotate, interleave, repeat

    static func rotateBehavior<V: VectorItem>(_ label: PushInstruction, _ type: V.Type) -> Behavior {
        Behavior.assembling(label, takes: V.self, IntItem.self, gives: V.self) { x, n in
            let k = rotation(n.value, x.value.count)
            let origins = x.origins()
            return Built(Array(x.value[k...] + x.value[..<k]), members: Array(origins[k...] + origins[..<k]))
        }
        .described("Rotates left: `v n .\(label)` moves the first n elements to the end (n of any sign, taken "
                   + "modulo the length).")
    }

    static func interleaveBehavior<V: VectorItem>(_ label: PushInstruction, _ type: V.Type) -> Behavior {
        Behavior.assembling(label, takes: V.self, V.self, gives: V.self) { x, y in
            let (left, right) = (x.origins(0), y.origins(1))
            var values: [V.Element] = [], members: [Origin] = []
            for index in 0..<max(x.value.count, y.value.count) {
                if index < x.value.count { values.append(x.value[index]); members.append(left[index]) }
                if index < y.value.count { values.append(y.value[index]); members.append(right[index]) }
            }
            return Built(values, members: members)
        }
        .described("Interleaves: `a b .\(label)` gives a[0] b[0] a[1] b[1] …, then the rest of the longer.")
    }

    static func repeatBehavior<V: VectorItem>(_ label: PushInstruction, _ type: V.Type) -> Behavior {
        Behavior.assembling(label, takes: V.self, IntItem.self, gives: V.self) { x, n throws(Refusal) in
            // Nothing to repeat is nothing, however many times: the size check
            // passes an empty vector, and n copies of nothing must not be built.
            guard !x.value.isEmpty, n.value > 0 else { return Built([], members: []) }
            let times = n.value
            let (total, overflowed) = x.value.count.multipliedReportingOverflow(by: times)
            try checkSize(overflowed ? Int.max : total, label)
            let origins = x.origins()
            return Built(Array(repeating: x.value, count: times).flatMap { $0 },
                         members: Array(repeating: origins, count: times).flatMap { $0 })
        }
        .described("Repeats: `v n .\(label)` gives v n times over; n ≤ 0 gives an empty vector; refuses a result "
                   + "over the size limit.")
    }

    static let vecBoolRotate_Behavior = rotateBehavior(.vecBoolRotate, VecBoolItem.self)
    static let vecIntRotate_Behavior = rotateBehavior(.vecIntRotate, VecIntItem.self)
    static let vecDoubleRotate_Behavior = rotateBehavior(.vecDoubleRotate, VecDoubleItem.self)
    static let vecStringRotate_Behavior = rotateBehavior(.vecStringRotate, VecStringItem.self)
    static let vecBoolInterleave_Behavior = interleaveBehavior(.vecBoolInterleave, VecBoolItem.self)
    static let vecIntInterleave_Behavior = interleaveBehavior(.vecIntInterleave, VecIntItem.self)
    static let vecDoubleInterleave_Behavior = interleaveBehavior(.vecDoubleInterleave, VecDoubleItem.self)
    static let vecStringInterleave_Behavior = interleaveBehavior(.vecStringInterleave, VecStringItem.self)
    static let vecBoolRepeat_Behavior = repeatBehavior(.vecBoolRepeat, VecBoolItem.self)
    static let vecIntRepeat_Behavior = repeatBehavior(.vecIntRepeat, VecIntItem.self)
    static let vecDoubleRepeat_Behavior = repeatBehavior(.vecDoubleRepeat, VecDoubleItem.self)
    static let vecStringRepeat_Behavior = repeatBehavior(.vecStringRepeat, VecStringItem.self)

    static let stringRotate_Behavior =
        Behavior.assembling(.stringRotate, takes: StringItem.self, IntItem.self, gives: StringItem.self) { x, n in
            let characters = Array(x.value)
            let k = rotation(n.value, characters.count)
            let origins = x.origins()
            return Built(String(characters[k...] + characters[..<k]), members: Array(origins[k...] + origins[..<k]))
        }
        .described("Rotates left: `s n .stringRotate` moves the first n chars to the end (n of any sign, taken "
                   + "modulo the length).")

    static let stringInterleave_Behavior =
        Behavior.assembling(.stringInterleave, takes: StringItem.self, StringItem.self,
                            gives: StringItem.self) { x, y in
            let (a, b) = (Array(x.value), Array(y.value))
            let (left, right) = (x.origins(0), y.origins(1))
            var characters: [Character] = [], members: [Origin] = []
            for index in 0..<max(a.count, b.count) {
                if index < a.count { characters.append(a[index]); members.append(left[index]) }
                if index < b.count { characters.append(b[index]); members.append(right[index]) }
            }
            return Built(String(characters), members: members)
        }
        .described("Interleaves chars: `a b .stringInterleave` gives a[0] b[0] a[1] b[1] …, then the rest of the "
                   + "longer.")

    static let stringRepeat_Behavior =
        Behavior.assembling(.stringRepeat, takes: StringItem.self, IntItem.self,
                            gives: StringItem.self) { x, n throws(Refusal) in
            guard !x.value.isEmpty, n.value > 0 else { return Built("", members: []) }
            let times = n.value
            let (total, overflowed) = x.value.count.multipliedReportingOverflow(by: times)
            try checkSize(overflowed ? Int.max : total, .stringRepeat)
            let origins = x.origins()
            return Built(String(repeating: x.value, count: times),
                         members: Array(repeating: origins, count: times).flatMap { $0 })
        }
        .described("Repeats: `s n .stringRepeat` gives s n times over; n ≤ 0 gives an empty string; refuses a "
                   + "result over the size limit.")

    // MARK: - The family

    static let sequenceBehaviors: [PushInstruction: Behavior] = [
        .vecBoolSort: vecBoolSort_Behavior, .vecIntSort: vecIntSort_Behavior,
        .vecDoubleSort: vecDoubleSort_Behavior, .vecStringSort: vecStringSort_Behavior,
        .stringSort: stringSort_Behavior,
        .vecIntIndexOfMax: vecIntIndexOfMax_Behavior, .vecIntIndexOfMin: vecIntIndexOfMin_Behavior,
        .vecDoubleIndexOfMax: vecDoubleIndexOfMax_Behavior, .vecDoubleIndexOfMin: vecDoubleIndexOfMin_Behavior,
        .vecStringIndexOfMax: vecStringIndexOfMax_Behavior, .vecStringIndexOfMin: vecStringIndexOfMin_Behavior,
        .vecIntProduct: vecIntProduct_Behavior, .vecDoubleProduct: vecDoubleProduct_Behavior,
        .vecIntMean: vecIntMean_Behavior, .vecDoubleMean: vecDoubleMean_Behavior,
        .vecBoolLastIndexOf: vecBoolLastIndexOf_Behavior, .vecIntLastIndexOf: vecIntLastIndexOf_Behavior,
        .vecDoubleLastIndexOf: vecDoubleLastIndexOf_Behavior,
        .vecStringLastIndexOf: vecStringLastIndexOf_Behavior, .stringLastIndexOf: stringLastIndexOf_Behavior,
        .vecIntRange: vecIntRange_Behavior, .vecIntRangeBy: vecIntRangeBy_Behavior,
        .vecBoolRotate: vecBoolRotate_Behavior, .vecIntRotate: vecIntRotate_Behavior,
        .vecDoubleRotate: vecDoubleRotate_Behavior, .vecStringRotate: vecStringRotate_Behavior,
        .stringRotate: stringRotate_Behavior,
        .vecBoolInterleave: vecBoolInterleave_Behavior, .vecIntInterleave: vecIntInterleave_Behavior,
        .vecDoubleInterleave: vecDoubleInterleave_Behavior, .vecStringInterleave: vecStringInterleave_Behavior,
        .stringInterleave: stringInterleave_Behavior,
        .vecBoolRepeat: vecBoolRepeat_Behavior, .vecIntRepeat: vecIntRepeat_Behavior,
        .vecDoubleRepeat: vecDoubleRepeat_Behavior, .vecStringRepeat: vecStringRepeat_Behavior,
        .stringRepeat: stringRepeat_Behavior,
        .vecBoolFrequencies: vecBoolFrequencies_Behavior, .vecIntFrequencies: vecIntFrequencies_Behavior,
        .vecDoubleFrequencies: vecDoubleFrequencies_Behavior,
        .vecStringFrequencies: vecStringFrequencies_Behavior, .stringFrequencies: stringFrequencies_Behavior,
        .vecIntPrefixSums: vecIntPrefixSums_Behavior, .vecDoublePrefixSums: vecDoublePrefixSums_Behavior,
        .vecDoubleFromVecInt: vecDoubleFromVecInt_Behavior, .vecIntFromVecDouble: vecIntFromVecDouble_Behavior,
        .vecIntFromVecBool: vecIntFromVecBool_Behavior, .vecIntFromInt: vecIntFromInt_Behavior,
        .intFromVecInt: intFromVecInt_Behavior,
        .vecBoolLT: vecBoolLT_Behavior, .vecBoolLTE: vecBoolLTE_Behavior, .vecBoolGT: vecBoolGT_Behavior,
        .vecBoolGTE: vecBoolGTE_Behavior, .vecBoolMax: vecBoolMax_Behavior, .vecBoolMin: vecBoolMin_Behavior,
        .vecBoolChunks: vecBoolChunks_Behavior, .vecIntChunks: vecIntChunks_Behavior,
        .vecDoubleChunks: vecDoubleChunks_Behavior, .vecStringChunks: vecStringChunks_Behavior,
        .stringChunks: stringChunks_Behavior,
        .vecBoolWindows: vecBoolWindows_Behavior, .vecIntWindows: vecIntWindows_Behavior,
        .vecDoubleWindows: vecDoubleWindows_Behavior, .vecStringWindows: vecStringWindows_Behavior,
        .stringWindows: stringWindows_Behavior,
        .codeReverseRoot: codeReverseRoot_Behavior, .codeFirstRoot: codeFirstRoot_Behavior,
        .codeLastRoot: codeLastRoot_Behavior, .codeTakeRoot: codeTakeRoot_Behavior,
        .codeDropRoot: codeDropRoot_Behavior
    ]
}
