//
//  Collection Behaviors.swift
//  PushInterpreter
//
//  Reductions over whole collections (*Behavior coverage audit (2026-11-09)*,
//  P1). Each is written once and applied to every collection it
//  fits.
//
//  The rulings that shape them (audit §11, ruling 4):
//  - **Facts read and leave.** `Sum`, `Mean`, `Max` and `Min` report something
//    about a collection, so they are non-destructive queries (Design Principles
//    §5): the collection stays where it was, and the crux cleans it up.
//  - **`Max` and `Min` are member reads.** They take an element *out*, so the
//    element keeps its own history when it has one (`Containment`), exactly as
//    `Nth` does. Ties go to the first occurrence.
//  - **Orders are total**, so every result is deterministic: a NaN counts as
//    greater than every number.
//  - **No `Sort`** (the user, 2026-11-09): basic Push benchmarks ask for
//    sorting to be evolved, and a built-in would answer them in one step.
//

nonisolated extension Interpreter {

    // MARK: - Orders

    /// A total order on doubles: the usual one, with NaN greater than every number.
    @Sendable static func doublePrecedes(_ a: Double, _ b: Double) -> Bool {
        a < b || (!a.isNaN && b.isNaN)
    }

    /// Where the first greatest (`greatest`) or first least element is.
    static func extremePosition<E>(_ values: [E], greatest: Bool, by precedes: (E, E) -> Bool) -> Int {
        var best = 0
        for index in values.indices.dropFirst() {
            let better = greatest ? precedes(values[best], values[index]) : precedes(values[index], values[best])
            if better { best = index }
        }
        return best
    }


    // MARK: - Factories

    /// The greatest (or least) element of a vector, read out of it; an error if
    /// the vector is empty.
    static func extremeBehavior<V: VectorItem>(
        _ instruction: PushInstruction, making itemType: V.Type, greatest: Bool,
        by precedes: @escaping @Sendable (V.Element, V.Element) -> Bool
    ) -> Behavior {
        Behavior.extracting(instruction, reads: V.self) { x throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty vector in .\(instruction)", kind: .emptyCollection)
            }
            return Extraction(x, at: extremePosition(x.value, greatest: greatest, by: precedes))
        }
    }


    // MARK: - Sums and means

    /// The sum of a vecInt's elements; 0 for an empty one. Refuses on overflow,
    /// as `intAdd` does.
    static let vecIntSum_Behavior =
        Behavior.operation(.vecIntSum, reads: VecIntItem.self, gives: IntItem.self) { x throws(Refusal) in
            var total = 0
            for value in x {
                let (sum, overflowed) = total.addingReportingOverflow(value)
                guard !overflowed else { throw Refusal("Overflow in .vecIntSum") }
                total = sum
            }
            return total
        }

    /// The mean of a vecInt's elements, as a double; an error if it is empty.
    /// Summed as doubles, so it cannot overflow.
    static let vecIntMean_Behavior =
        Behavior.operation(.vecIntMean, reads: VecIntItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard !x.isEmpty else { throw Refusal("Empty vector in .vecIntMean", kind: .emptyCollection) }
            return x.reduce(0.0) { $0 + Double($1) } / Double(x.count)
        }

    /// The sum of a vecDouble's elements; 0 for an empty one. Refuses a result
    /// that is not finite, as `doubleAdd` does.
    static let vecDoubleSum_Behavior =
        Behavior.operation(.vecDoubleSum, reads: VecDoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let total = x.reduce(0.0, +)
            guard total.isFinite else { throw Refusal("Overflow in .vecDoubleSum") }
            return total
        }

    /// The mean of a vecDouble's elements; an error if it is empty or the mean is
    /// not finite.
    static let vecDoubleMean_Behavior =
        Behavior.operation(.vecDoubleMean, reads: VecDoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            guard !x.isEmpty else { throw Refusal("Empty vector in .vecDoubleMean", kind: .emptyCollection) }
            let mean = x.reduce(0.0, +) / Double(x.count)
            guard mean.isFinite else { throw Refusal("Overflow in .vecDoubleMean") }
            return mean
        }


    // MARK: - Greatest and least

    static let vecIntMax_Behavior =
        extremeBehavior(.vecIntMax, making: VecIntItem.self, greatest: true, by: <)
    static let vecIntMin_Behavior =
        extremeBehavior(.vecIntMin, making: VecIntItem.self, greatest: false, by: <)
    static let vecDoubleMax_Behavior =
        extremeBehavior(.vecDoubleMax, making: VecDoubleItem.self, greatest: true, by: doublePrecedes)
    static let vecDoubleMin_Behavior =
        extremeBehavior(.vecDoubleMin, making: VecDoubleItem.self, greatest: false, by: doublePrecedes)
    static let vecStringMax_Behavior =
        extremeBehavior(.vecStringMax, making: VecStringItem.self, greatest: true, by: <)
    static let vecStringMin_Behavior =
        extremeBehavior(.vecStringMin, making: VecStringItem.self, greatest: false, by: <)

    /// The greatest (least) character of a string, read out of it; an error for
    /// an empty string.
    static func stringExtremeBehavior(_ instruction: PushInstruction, greatest: Bool) -> Behavior {
        Behavior.extracting(instruction, reads: StringItem.self) { x throws(Refusal) in
            guard !x.value.isEmpty else {
                throw Refusal("Empty string in .\(instruction)", kind: .emptyCollection)
            }
            return Extraction(x, at: extremePosition(Array(x.value), greatest: greatest, by: <))
        }
    }

    static let stringMax_Behavior = stringExtremeBehavior(.stringMax, greatest: true)
    static let stringMin_Behavior = stringExtremeBehavior(.stringMin, greatest: false)


    // MARK: - The family

    static let collectionBehaviors: [PushInstruction: Behavior] = [
        .vecIntSum: vecIntSum_Behavior,
        .vecIntMean: vecIntMean_Behavior,
        .vecDoubleSum: vecDoubleSum_Behavior,
        .vecDoubleMean: vecDoubleMean_Behavior,
        .vecIntMax: vecIntMax_Behavior,
        .vecIntMin: vecIntMin_Behavior,
        .vecDoubleMax: vecDoubleMax_Behavior,
        .vecDoubleMin: vecDoubleMin_Behavior,
        .vecStringMax: vecStringMax_Behavior,
        .vecStringMin: vecStringMin_Behavior,
        .stringMax: stringMax_Behavior,
        .stringMin: stringMin_Behavior,
    ]
}
