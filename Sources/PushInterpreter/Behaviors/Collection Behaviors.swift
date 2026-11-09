//
//  Collection Behaviors.swift
//  PushInterpreter
//
//  Reductions over whole collections (*Behavior coverage audit (2026-11-09)*,
//  P1). Each is written once and applied to every collection it
//  fits.
//
//  The rulings that shape them (audit §11, ruling 4):
//  - **Facts read and leave.** `Sum`, `Max` and `Min` report something
//    about a collection, so they are non-destructive queries (Design Principles
//    §5): the collection stays where it was, and the crux cleans it up.
//  - **`Max` and `Min` are member reads.** They take an element *out*, so the
//    element keeps its own history when it has one (`Containment`), exactly as
//    `Nth` does. Ties go to the first occurrence.
//  - **Orders are total**, so every result is deterministic: a NaN counts as
//    greater than every number.
//  - **No `Sort` and no `Mean`** (the user, 2026-11-09): basic Push
//    benchmarks ask for sorting and averaging (PSB1 *Vector Average*) to be
//    evolved, and a built-in would answer them in one step. Average stays a
//    short composition: `.vecIntSum .vecIntLength .intQuot`.
//

nonisolated extension Interpreter {

    // MARK: - Orders

    /// A total order on doubles: the usual one, with NaN greater than every number.
    @Sendable static func doublePrecedes(_ a: Double, _ b: Double) -> Bool {
        DoubleKey(value: a) < DoubleKey(value: b)
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
        .described(
            "Pushes the \(greatest ? "greatest" : "least") element, leaving the vector"
            + (V.Scalar.pushStack == .double ? "; NaN counts as greater than every number" : "")
            + "; refuses an empty vector.")
    }


    // MARK: - Sums

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
        .described("Sums the elements, leaving the vector; an empty vector gives 0; refuses on overflow.")

    /// The sum of a vecDouble's elements; 0 for an empty one. Refuses a result
    /// that is not finite, as `doubleAdd` does.
    static let vecDoubleSum_Behavior =
        Behavior.operation(.vecDoubleSum, reads: VecDoubleItem.self, gives: DoubleItem.self) { x throws(Refusal) in
            let total = x.reduce(0.0, +)
            guard total.isFinite else { throw Refusal("Overflow in .vecDoubleSum") }
            return total
        }
        .described(
            "Sums the elements, leaving the vector; an empty vector gives 0; refuses a result that is not finite.")


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
        .described(
            "Pushes the \(greatest ? "greatest" : "least") char of the string, leaving the string; refuses an "
            + "empty string.")
    }

    static let stringMax_Behavior = stringExtremeBehavior(.stringMax, greatest: true)
    static let stringMin_Behavior = stringExtremeBehavior(.stringMin, greatest: false)


    // MARK: - Set operations (audit P1b)
    //
    // Sets as operations on the collections that exist, not as a type (audit
    // §7). `Distinct` keeps first occurrences. `Intersect` and `Difference` are
    // **filters**: they keep the first argument's elements that are (are not)
    // in the second, in the first's order and with its repeats, so
    // `"hello" "aeiou" .stringDifference` is `"hll"`; set semantics are one
    // `Distinct` away, and `Concat` then `Distinct` is the union. Each kept
    // element keeps its origin. `IsSubset` asks whether every element of the
    // first is in the second, and reads both. Membership is a hashed test whose
    // order never shows.

    static func distinctBehavior<V: VectorItem>(_ instruction: PushInstruction, making itemType: V.Type) -> Behavior
    where V.Element: Hashable {
        Behavior.assembling(instruction, takes: V.self, gives: V.self) { x in
            var seen = Set<V.Key>()
            let kept = x.value.indices.filter { seen.insert(V.key(x.value[$0])).inserted }
            let origins = x.origins()
            return Built(kept.map { x.value[$0] }, members: kept.map { origins[$0] })
        }
        .described("Removes repeated elements, keeping each first occurrence in order.")
    }

    /// Keeps the elements of the first vector that are (`keeping: true`) or are
    /// not in the second.
    static func filterBehavior<V: VectorItem>(
        _ instruction: PushInstruction, making itemType: V.Type, keeping: Bool
    ) -> Behavior where V.Element: Hashable {
        Behavior.assembling(instruction, takes: V.self, V.self, gives: V.self) { x, y in
            let other = Set(y.value.map(V.key))
            let kept = x.value.indices.filter { other.contains(V.key(x.value[$0])) == keeping }
            let origins = x.origins(0)
            return Built(kept.map { x.value[$0] }, members: kept.map { origins[$0] })
        }
        .described(
            "Filters: `a b .\(instruction)` keeps the elements of a that "
            + "\(keeping ? "also occur" : "do not occur") in b, in a's order, repeats included.")
    }

    static func isSubsetBehavior<V: VectorItem>(_ instruction: PushInstruction, making itemType: V.Type) -> Behavior
    where V.Element: Hashable {
        Behavior.operation(instruction, reads: V.self, V.self, gives: BoolItem.self) { x, y in
            Set(y.map(V.key)).isSuperset(of: x.map(V.key))
        }
        .described("Tells whether every element of a occurs in b: `a b .\(instruction)`, leaving both.")
    }

    static let vecBoolDistinct_Behavior = distinctBehavior(.vecBoolDistinct, making: VecBoolItem.self)
    static let vecIntDistinct_Behavior = distinctBehavior(.vecIntDistinct, making: VecIntItem.self)
    static let vecDoubleDistinct_Behavior = distinctBehavior(.vecDoubleDistinct, making: VecDoubleItem.self)
    static let vecStringDistinct_Behavior = distinctBehavior(.vecStringDistinct, making: VecStringItem.self)
    static let vecBoolIntersect_Behavior = filterBehavior(.vecBoolIntersect, making: VecBoolItem.self, keeping: true)
    static let vecIntIntersect_Behavior = filterBehavior(.vecIntIntersect, making: VecIntItem.self, keeping: true)
    static let vecDoubleIntersect_Behavior =
        filterBehavior(.vecDoubleIntersect, making: VecDoubleItem.self, keeping: true)
    static let vecStringIntersect_Behavior =
        filterBehavior(.vecStringIntersect, making: VecStringItem.self, keeping: true)
    static let vecBoolDifference_Behavior = filterBehavior(.vecBoolDifference, making: VecBoolItem.self, keeping: false)
    static let vecIntDifference_Behavior = filterBehavior(.vecIntDifference, making: VecIntItem.self, keeping: false)
    static let vecDoubleDifference_Behavior =
        filterBehavior(.vecDoubleDifference, making: VecDoubleItem.self, keeping: false)
    static let vecStringDifference_Behavior =
        filterBehavior(.vecStringDifference, making: VecStringItem.self, keeping: false)
    static let vecBoolIsSubset_Behavior = isSubsetBehavior(.vecBoolIsSubset, making: VecBoolItem.self)
    static let vecIntIsSubset_Behavior = isSubsetBehavior(.vecIntIsSubset, making: VecIntItem.self)
    static let vecDoubleIsSubset_Behavior = isSubsetBehavior(.vecDoubleIsSubset, making: VecDoubleItem.self)
    static let vecStringIsSubset_Behavior = isSubsetBehavior(.vecStringIsSubset, making: VecStringItem.self)

    // Strings: sets of characters.

    static let stringDistinct_Behavior =
        Behavior.assembling(.stringDistinct, takes: StringItem.self, gives: StringItem.self) { x in
            let characters = Array(x.value)
            var seen = Set<Character>()
            let kept = characters.indices.filter { seen.insert(characters[$0]).inserted }
            let origins = x.origins()
            return Built(String(kept.map { characters[$0] }), members: kept.map { origins[$0] })
        }
        .described("Removes repeated chars, keeping each first occurrence in order.")

    static func stringFilterBehavior(_ instruction: PushInstruction, keeping: Bool) -> Behavior {
        Behavior.assembling(instruction, takes: StringItem.self, StringItem.self, gives: StringItem.self) { x, y in
            let characters = Array(x.value)
            let other = Set(y.value)
            let kept = characters.indices.filter { other.contains(characters[$0]) == keeping }
            let origins = x.origins(0)
            return Built(String(kept.map { characters[$0] }), members: kept.map { origins[$0] })
        }
        .described(
            "Filters: `a b .\(instruction)` keeps the chars of a that \(keeping ? "also occur" : "do not occur") "
            + "in b, in a's order, repeats included.")
    }

    static let stringIntersect_Behavior = stringFilterBehavior(.stringIntersect, keeping: true)
    static let stringDifference_Behavior = stringFilterBehavior(.stringDifference, keeping: false)

    static let stringIsSubset_Behavior =
        Behavior.operation(.stringIsSubset, reads: StringItem.self, StringItem.self, gives: BoolItem.self) { x, y in
            Set(y).isSuperset(of: x)
        }
        .described("Tells whether every char of a occurs in b: `a b .stringIsSubset`, leaving both.")

    // Code: the root items, compared by value (Design Principles §9), so the one
    // multitype collection gets set operations too. Each kept item is the item
    // itself, with its own history (law 1b).

    static func contains(_ items: [any Item], _ item: any Item) -> Bool {
        items.contains { $0.isEqual(to: item) }
    }

    static let codeDistinct_Behavior =
        Behavior.composing(.codeDistinct, takes: CodeItem.self, gives: CodeItem.self) { x in
            var kept: [any Item] = []
            for item in x.value where !contains(kept, item) { kept.append(item) }
            return kept
        }
        .described(
            "Removes repeated items from a block, comparing by value and keeping each first occurrence in order.")

    static let codeIntersect_Behavior =
        Behavior.composing(.codeIntersect, takes: CodeItem.self, CodeItem.self, gives: CodeItem.self) { x, y in
            x.value.filter { contains(y.value, $0) }
        }
        .described(
            "Filters: `a b .codeIntersect` keeps the items of block a that also occur in b, compared by value, in "
            + "a's order, repeats included.")

    static let codeDifference_Behavior =
        Behavior.composing(.codeDifference, takes: CodeItem.self, CodeItem.self, gives: CodeItem.self) { x, y in
            x.value.filter { !contains(y.value, $0) }
        }
        .described(
            "Filters: `a b .codeDifference` keeps the items of block a that do not occur in b, compared by value, "
            + "in a's order, repeats included.")

    static let codeIsSubset_Behavior =
        Behavior.operation(.codeIsSubset, reads: CodeItem.self, CodeItem.self, gives: BoolItem.self) { x, y in
            x.allSatisfy { contains(y, $0) }
        }
        .described(
            "Tells whether every item of block a occurs in block b, compared by value: `a b .codeIsSubset`, "
            + "leaving both.")


    // MARK: - The family

    static let collectionBehaviors: [PushInstruction: Behavior] = [
        .vecIntSum: vecIntSum_Behavior,
        .vecDoubleSum: vecDoubleSum_Behavior,
        .vecIntMax: vecIntMax_Behavior,
        .vecIntMin: vecIntMin_Behavior,
        .vecDoubleMax: vecDoubleMax_Behavior,
        .vecDoubleMin: vecDoubleMin_Behavior,
        .vecStringMax: vecStringMax_Behavior,
        .vecStringMin: vecStringMin_Behavior,
        .stringMax: stringMax_Behavior,
        .stringMin: stringMin_Behavior,
        .vecBoolDistinct: vecBoolDistinct_Behavior,
        .vecIntDistinct: vecIntDistinct_Behavior,
        .vecDoubleDistinct: vecDoubleDistinct_Behavior,
        .vecStringDistinct: vecStringDistinct_Behavior,
        .stringDistinct: stringDistinct_Behavior,
        .codeDistinct: codeDistinct_Behavior,
        .vecBoolIntersect: vecBoolIntersect_Behavior,
        .vecIntIntersect: vecIntIntersect_Behavior,
        .vecDoubleIntersect: vecDoubleIntersect_Behavior,
        .vecStringIntersect: vecStringIntersect_Behavior,
        .stringIntersect: stringIntersect_Behavior,
        .codeIntersect: codeIntersect_Behavior,
        .vecBoolDifference: vecBoolDifference_Behavior,
        .vecIntDifference: vecIntDifference_Behavior,
        .vecDoubleDifference: vecDoubleDifference_Behavior,
        .vecStringDifference: vecStringDifference_Behavior,
        .stringDifference: stringDifference_Behavior,
        .codeDifference: codeDifference_Behavior,
        .vecBoolIsSubset: vecBoolIsSubset_Behavior,
        .vecIntIsSubset: vecIntIsSubset_Behavior,
        .vecDoubleIsSubset: vecDoubleIsSubset_Behavior,
        .vecStringIsSubset: vecStringIsSubset_Behavior,
        .stringIsSubset: stringIsSubset_Behavior,
        .codeIsSubset: codeIsSubset_Behavior
    ]
}
