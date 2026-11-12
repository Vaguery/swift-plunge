//
//  Elementwise Behaviors.swift
//  Plunge
//
//  Element-wise operations on two vectors (2026-11-12): arithmetic, the dot
//  product, comparisons and logic, element by element.
//
//  **The pair is found by the sieve.** Written `a b .vecIntAdd`, `b` is the top
//  vector and `a` is the first vector below it **with the same length**
//  (`Behavior.sameLength`, the user's ruling): a shorter or longer vector in
//  between is passed over and left. None of that length is a miss (`notFound`),
//  which still takes `b` (the arithmetic and logic, which consume) or leaves it
//  (the dot product and comparisons, which read). A lone vector is a missing
//  argument. A crux writes the pair adjacent, `a b .vecIntAdd`, where a replay's
//  sieve finds `a` first.
//
//  Arithmetic refuses as its scalar instruction does (overflow, division by
//  zero, a double that is not finite), naming the index; it shares the scalar's
//  code (`IntArithmetic`, `DoubleArithmetic`). Comparisons follow the vector
//  rules (`VectorItem.key`): every NaN is one value, above every number. Their
//  names end in `Each`, since `vecIntLT` and its kin compare whole vectors.
//

nonisolated extension Interpreter {

    /// `a b .label`: the vector of `a[i] op b[i]`.
    static func elementwise<V: VectorItem>(
        _ label: PushInstruction, _ type: V.Type, _ verb: String, refuses: String,
        _ op: @escaping @Sendable (V.Element, V.Element, PushInstruction) throws(Refusal) -> V.Element
    ) -> Behavior {
        Behavior.operation(label, takes: V.self, V.self, gives: V.self,
                           pairedBy: Behavior.sameLength) { a, b throws(Refusal) in
            var result: [V.Element] = []
            result.reserveCapacity(a.count)
            for index in a.indices {
                do throws(Refusal) {
                    result.append(try op(a[index], b[index], label))
                } catch {
                    throw Refusal("at index \(index): \(error.message)", kind: error.kind)
                }
            }
            return result
        }
        .described("\(verb) element by element: `a b .\(label)` gives a[i] and b[i] combined, where b is the top "
                   + "\(V.pushStack.noun) and a the first one below it of the same length (a miss if there is "
                   + "none); refuses \(refuses), naming the index.")
    }

    /// `a b .label`: the vector of whether `a[i]` and `b[i]` stand in `relation`,
    /// read and left.
    static func elementwiseComparison<V: VectorItem>(
        _ label: PushInstruction, _ type: V.Type, _ relation: String,
        _ holds: @escaping @Sendable (V.Key, V.Key) -> Bool
    ) -> Behavior {
        Behavior.operation(label, reads: V.self, V.self, gives: VecBoolItem.self,
                           pairedBy: Behavior.sameLength) { a, b in
            zip(a, b).map { holds(V.key($0), V.key($1)) }
        }
        .described("Pushes whether each element of a is \(relation) the matching element of b: `a b .\(label)`, "
                   + "where b is the top \(V.pushStack.noun) and a the first one below it of the same length (a "
                   + "miss if there is none); leaves both.")
    }

    // MARK: - Arithmetic

    static let vecIntAdd_Behavior = elementwise(.vecIntAdd, VecIntItem.self, "Adds", refuses: "on overflow",
                                                IntArithmetic.add)
    static let vecIntSubtract_Behavior = elementwise(.vecIntSubtract, VecIntItem.self, "Subtracts (a − b)",
                                                     refuses: "on overflow", IntArithmetic.subtract)
    static let vecIntMultiply_Behavior = elementwise(.vecIntMultiply, VecIntItem.self, "Multiplies",
                                                     refuses: "on overflow", IntArithmetic.multiply)
    static let vecIntQuot_Behavior = elementwise(.vecIntQuot, VecIntItem.self, "Divides (a ÷ b, toward zero)",
                                                 refuses: "a zero divisor or overflow", IntArithmetic.quot)
    static let vecIntMod_Behavior = elementwise(.vecIntMod, VecIntItem.self, "Takes remainders (a mod b)",
                                                refuses: "a zero divisor or overflow", IntArithmetic.mod)

    static let vecDoubleAdd_Behavior = elementwise(.vecDoubleAdd, VecDoubleItem.self, "Adds",
                                                   refuses: "a result that is not finite", DoubleArithmetic.add)
    static let vecDoubleSubtract_Behavior = elementwise(.vecDoubleSubtract, VecDoubleItem.self, "Subtracts (a − b)",
                                                        refuses: "a result that is not finite",
                                                        DoubleArithmetic.subtract)
    static let vecDoubleMultiply_Behavior = elementwise(.vecDoubleMultiply, VecDoubleItem.self, "Multiplies",
                                                        refuses: "a result that is not finite",
                                                        DoubleArithmetic.multiply)
    static let vecDoubleDivide_Behavior = elementwise(.vecDoubleDivide, VecDoubleItem.self, "Divides (a ÷ b)",
                                                      refuses: "a result that is not finite",
                                                      DoubleArithmetic.divide)
    static let vecDoubleMod_Behavior = elementwise(.vecDoubleMod, VecDoubleItem.self, "Takes remainders (a mod b)",
                                                   refuses: "a result that is not finite", DoubleArithmetic.mod)

    // MARK: - Dot products

    static let vecIntDot_Behavior =
        Behavior.operation(.vecIntDot, reads: VecIntItem.self, VecIntItem.self, gives: IntItem.self,
                           pairedBy: Behavior.sameLength) { a, b throws(Refusal) in
            var sum = 0
            for index in a.indices {
                sum = try IntArithmetic.add(sum, IntArithmetic.multiply(a[index], b[index], .vecIntDot), .vecIntDot)
            }
            return sum
        }
        .described("Pushes the dot product of two vectors of ints, the sum of a[i] × b[i]: `a b .vecIntDot`, where b "
                   + "is the top vector and a the first one below it of the same length (a miss if there is none); "
                   + "leaves both; empty vectors give 0; refuses on overflow.")

    static let vecDoubleDot_Behavior =
        Behavior.operation(.vecDoubleDot, reads: VecDoubleItem.self, VecDoubleItem.self, gives: DoubleItem.self,
                           pairedBy: Behavior.sameLength) { a, b throws(Refusal) in
            var sum = 0.0
            for index in a.indices { sum += a[index] * b[index] }
            return try DoubleArithmetic.finite(sum, .vecDoubleDot, "a dot product of \(a.count) terms")
        }
        .described("Pushes the dot product of two vectors of doubles, the sum of a[i] × b[i]: `a b .vecDoubleDot`, "
                   + "where b is the top vector and a the first one below it of the same length (a miss if there is "
                   + "none); leaves both; empty vectors give 0; refuses a result that is not finite.")

    // MARK: - Comparisons

    static let vecBoolEqEach_Behavior = elementwiseComparison(.vecBoolEqEach, VecBoolItem.self, "equal to") { $0 == $1 }
    static let vecIntEqEach_Behavior = elementwiseComparison(.vecIntEqEach, VecIntItem.self, "equal to") { $0 == $1 }
    static let vecDoubleEqEach_Behavior =
        elementwiseComparison(.vecDoubleEqEach, VecDoubleItem.self, "equal to") { $0 == $1 }
    static let vecStringEqEach_Behavior =
        elementwiseComparison(.vecStringEqEach, VecStringItem.self, "equal to") { $0 == $1 }
    static let vecIntLTEach_Behavior = elementwiseComparison(.vecIntLTEach, VecIntItem.self, "less than") { $0 < $1 }
    static let vecIntGTEach_Behavior = elementwiseComparison(.vecIntGTEach, VecIntItem.self, "greater than") { $0 > $1 }
    static let vecDoubleLTEach_Behavior =
        elementwiseComparison(.vecDoubleLTEach, VecDoubleItem.self, "less than") { $0 < $1 }
    static let vecDoubleGTEach_Behavior = elementwiseComparison(.vecDoubleGTEach, VecDoubleItem.self,
                                                                "greater than") { $0 > $1 }
    static let vecStringLTEach_Behavior = elementwiseComparison(.vecStringLTEach, VecStringItem.self,
                                                                "less than") { $0 < $1 }
    static let vecStringGTEach_Behavior = elementwiseComparison(.vecStringGTEach, VecStringItem.self,
                                                                "greater than") { $0 > $1 }

    // MARK: - Logic

    static let vecBoolAnd_Behavior =
        Behavior.operation(.vecBoolAnd, takes: VecBoolItem.self, VecBoolItem.self, gives: VecBoolItem.self,
                           pairedBy: Behavior.sameLength) { a, b in zip(a, b).map { $0 && $1 } }
        .described("Ands element by element: `a b .vecBoolAnd` gives a[i] ∧ b[i], where b is the top vector and a "
                   + "the first one below it of the same length (a miss if there is none).")

    static let vecBoolOr_Behavior =
        Behavior.operation(.vecBoolOr, takes: VecBoolItem.self, VecBoolItem.self, gives: VecBoolItem.self,
                           pairedBy: Behavior.sameLength) { a, b in zip(a, b).map { $0 || $1 } }
        .described("Ors element by element: `a b .vecBoolOr` gives a[i] ∨ b[i], where b is the top vector and a "
                   + "the first one below it of the same length (a miss if there is none).")

    static let vecBoolNot_Behavior =
        Behavior.operation(.vecBoolNot, takes: VecBoolItem.self, gives: VecBoolItem.self) { a in a.map { !$0 } }
        .described("Negates every element of a vector of bools.")

    // MARK: - The family

    static let elementwiseBehaviors: [PushInstruction: Behavior] = [
        .vecIntAdd: vecIntAdd_Behavior,
        .vecIntSubtract: vecIntSubtract_Behavior,
        .vecIntMultiply: vecIntMultiply_Behavior,
        .vecIntQuot: vecIntQuot_Behavior,
        .vecIntMod: vecIntMod_Behavior,
        .vecDoubleAdd: vecDoubleAdd_Behavior,
        .vecDoubleSubtract: vecDoubleSubtract_Behavior,
        .vecDoubleMultiply: vecDoubleMultiply_Behavior,
        .vecDoubleDivide: vecDoubleDivide_Behavior,
        .vecDoubleMod: vecDoubleMod_Behavior,
        .vecIntDot: vecIntDot_Behavior,
        .vecDoubleDot: vecDoubleDot_Behavior,
        .vecBoolEqEach: vecBoolEqEach_Behavior,
        .vecIntEqEach: vecIntEqEach_Behavior,
        .vecDoubleEqEach: vecDoubleEqEach_Behavior,
        .vecStringEqEach: vecStringEqEach_Behavior,
        .vecIntLTEach: vecIntLTEach_Behavior,
        .vecIntGTEach: vecIntGTEach_Behavior,
        .vecDoubleLTEach: vecDoubleLTEach_Behavior,
        .vecDoubleGTEach: vecDoubleGTEach_Behavior,
        .vecStringLTEach: vecStringLTEach_Behavior,
        .vecStringGTEach: vecStringGTEach_Behavior,
        .vecBoolAnd: vecBoolAnd_Behavior,
        .vecBoolOr: vecBoolOr_Behavior,
        .vecBoolNot: vecBoolNot_Behavior
    ]
}
