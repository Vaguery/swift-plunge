//
//  TunableCrux.swift
//  Plunge
//
//  An abstract crux with every input wrapped in a parametric transform whose
//  parameters are holes, and whose neutral setting changes nothing.
//  Added 2026-11-15.
//

/// Where a tunable crux puts its transforms.
public nonisolated enum TuningSite: Sendable, Hashable {
    /// On each input, at every place it is read.
    case inputs
    /// On the result.
    case output
}

/// **A crux whose inputs can be scaled, shifted and trimmed.** The distilled
/// crux `.input0 .input1 .intAdd` says "add the two inputs", but leaves nothing
/// to fit it to data with. The tunable crux wraps each input in a transform
/// whose parameters are control holes:
///
///     $0 $1 .intMultiply $2 .intAdd   $3 $4 .intMultiply $5 .intAdd   .intAdd
///
/// (holes 0 and 3 are the inputs; 1, 2, 4 and 5 are controls). Filled with each
/// control's neutral value (1 and 0 here) it gives exactly the crux it came
/// from, so fitting starts where the crux was and can only improve on it.
///
/// **The transforms, by type.** Each keeps the type and has a neutral setting.
///
/// | Type | Transform | Neutral |
/// |---|---|---|
/// | int, double | `x·a + b` | a = 1, b = 0 |
/// | bool | `(x and m) xor c`, which covers all four one-argument functions | m = true, c = false |
/// | char | its code point shifted by s | s = 0 |
/// | vecInt, vecDouble | every element scaled and shifted, `v[i]·a + b`; then framed and trimmed | a = 1, b = 0 |
/// | vecBool | every element `(v[i] and m) xor c`; then framed and trimmed | m = true, c = false |
/// | string, vecString | a prefix and a suffix joined on, then a number of items dropped from each end | empty, 0 |
///
/// Code blocks, functions, iterators and bindings get none: what to do with them
/// is left to discovery. Nonlinear transforms (a logarithm, a square) are too:
/// a crux that needs one should find it.
///
/// A tunable crux is an ``AbstractCrux`` whose roles include
/// ``AbstractCrux/Role/control(neutral:)``; its ``AbstractCrux/originalFillers``
/// put back the crux with every control neutral.
public nonisolated enum TunableCrux {
    /// One part of a transform: an instruction, or a control hole and its neutral
    /// value.
    enum Part {
        case instruction(PushInstruction)
        case control(any Item)
    }

    /// The transform for a value on `stack`, written after it; `nil` for a type
    /// that gets none.
    static func template(for stack: PushStack) -> [Part]? {
        switch stack {
        case .int:
            [.control(IntItem(1)), .instruction(.intMultiply), .control(IntItem(0)), .instruction(.intAdd)]
        case .double:
            [.control(DoubleItem(1)), .instruction(.doubleMultiply), .control(DoubleItem(0)), .instruction(.doubleAdd)]
        case .bool:
            [.control(BoolItem(true)), .instruction(.boolAnd), .control(BoolItem(false)), .instruction(.boolXor)]
        case .char:
            [.instruction(.intFromChar), .control(IntItem(0)), .instruction(.intAdd), .instruction(.charFromInt)]
        case .string:
            trimmed(empty: StringItem(""), swap: .stringSwap, concat: .stringConcat, drop: .stringDrop,
                    dropLast: .stringDropLast)
        case .vecInt:
            [.control(IntItem(1)), .instruction(.vecIntMultiplyInt), .control(IntItem(0)), .instruction(.vecIntAddInt)]
                + trimmed(empty: VecIntItem([]), swap: .vecIntSwap, concat: .vecIntConcat, drop: .vecIntDrop,
                          dropLast: .vecIntDropLast)
        case .vecDouble:
            [.control(DoubleItem(1)), .instruction(.vecDoubleMultiplyDouble), .control(DoubleItem(0)),
             .instruction(.vecDoubleAddDouble)]
                + trimmed(empty: VecDoubleItem([]), swap: .vecDoubleSwap, concat: .vecDoubleConcat,
                          drop: .vecDoubleDrop, dropLast: .vecDoubleDropLast)
        case .vecBool:
            [.control(BoolItem(true)), .instruction(.vecBoolAndBool), .control(BoolItem(false)),
             .instruction(.vecBoolXorBool)]
                + trimmed(empty: VecBoolItem([]), swap: .vecBoolSwap, concat: .vecBoolConcat, drop: .vecBoolDrop,
                          dropLast: .vecBoolDropLast)
        case .vecString:
            trimmed(empty: VecStringItem([]), swap: .vecStringSwap, concat: .vecStringConcat, drop: .vecStringDrop,
                    dropLast: .vecStringDropLast)
        default:
            nil
        }
    }

    /// `p x q` joined, then `d` items dropped from the front and `e` from the
    /// back: `x p .swap .concat q .concat d .drop e .dropLast`.
    private static func trimmed(empty: any Item, swap: PushInstruction, concat: PushInstruction,
                                drop: PushInstruction, dropLast: PushInstruction) -> [Part] {
        [.control(empty), .instruction(swap), .instruction(concat),
         .control(empty), .instruction(concat),
         .control(IntItem(0)), .instruction(drop),
         .control(IntItem(0)), .instruction(dropLast)]
    }
}

nonisolated extension DistilledCrux {
    /// This crux as a tunable crux: abstracted as ``abstracted(_:literals:limit:)``
    /// does, with a transform on each input (and, if `sites` says so, on the
    /// result) whose parameters are control holes. With `.perDistinct`, every use
    /// of an input shares one transform. See ``TunableCrux``.
    public func tunable(_ reading: AbstractCrux.Reading = .perDistinct, sites: Set<TuningSite> = [.inputs],
                        literals: Bool = true, limit: Int = 2_000) -> AbstractCrux? {
        var builder = AbstractCrux.Builder(reading: reading, literals: literals, sites: sites, limit: limit)
        return builder.build(item)
    }
}
