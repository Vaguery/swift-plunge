//
//  BehaviorClass.swift
//  PushInterpreter
//
//  What kind of thing a Behavior does to the interpreter's state.
//

/// **What a Behavior does to the interpreter's whole state.**
///
/// Treat every instruction as a function on one state with four parts besides the
/// data stacks: the **continuation** (`.exec`, the rest of the program), the
/// **environment** (inputs and constants), the **channels** (the printout and
/// `.error`) and the **clock** (the step counter). Every Behavior then factors into
/// at most four optional parts — read context, move positions, compute a pure
/// partial function on values, write — and falls into exactly one of these five
/// classes by which of them it is *for*.
///
/// **Declared, not derived.** Mechanism does not decide it: a constant reaches its
/// stack by way of `.exec`, `DupTimes` copies through an iterator loop, and
/// `vecIntPushAll` delivers its elements through a continuation, yet the first is a
/// context read, the second a structural rule and the third an operation. Like an
/// `InstructionTag`, this is judgment, written at the Behavior; unlike a tag, every
/// instruction has exactly one. `Behavior Class Tests` check each declaration
/// against what the Behavior can actually reach.
///
/// The classes match the provenance laws (Items.swift), which already drew the same
/// lines: rearranging records nothing (law 1), a result records its arguments and
/// instruction (law 3), and a state read becomes a stand-in (law 4b).
public nonisolated enum BehaviorClass: String, Sendable, Codable, Hashable, CaseIterable {

    /// **A pure, partial function on typed values.** Arithmetic, conversions,
    /// comparisons, constructors (iterators included), queries, iterator state
    /// changes, and the explode family. Outside its domain the result is an error.
    /// A `reads` query is the same function with its arguments
    /// copied first. Provenance law 3: the result records its arguments and the
    /// instruction.
    case operation

    /// **Value-blind rearrangement of positions**: deleting (pop, flush,
    /// `PopItems`), copying (dup, `DupItems`, `DupTimes`, `DeepDup`,
    /// `YankDup`) and reordering (swap, rot, `Yank`, `Shove`), the deep ones indexed
    /// by an int. These are the structural rules of substructural logic: weakening,
    /// contraction and exchange. Provenance law 1: rearranging records nothing.
    case structural

    /// **A source with no data arguments**: constants and inputs (reproducible), and
    /// state reads — `StackDepth`, `StackIsEmpty`, the error counts,
    /// `pushStepCount`, `readItems`, `readStack` — which are not, and so record
    /// stand-ins (law 4b). Only a count may be taken as an argument.
    case contextRead

    /// **A write to the continuation**: its output is the rest of the program, not
    /// a value of some type. `codeDo`, `execIf`, `execK`, the loop constructors, the code
    /// `Emit`/`Do`/`Iterate` instructions and `iteratorPlay` — Joy-style combinators
    /// over quotations. An iterator is a reified continuation with a cursor.
    case control

    /// **A sink**: the print instructions. (An operation's error branch is also
    /// a channel write, but it belongs to the operation that refused.)
    case channel
}


nonisolated extension Interpreter {

    /// The language partitioned by `BehaviorClass`. Built once, by asking each
    /// `Behavior` what it declared, so it cannot fall out of step with the
    /// definitions. Every class is present, even if empty.
    static let behaviorClasses: [BehaviorClass: Set<PushInstruction>] = {
        var result = Dictionary(uniqueKeysWithValues: BehaviorClass.allCases.map { ($0, Set<PushInstruction>()) })
        for (name, behavior) in language { result[behavior.behaviorClass, default: []].insert(name) }
        return result
    }()

    /// The instructions declaring `behaviorClass`.
    static func instructions(in behaviorClass: BehaviorClass) -> Set<PushInstruction> {
        behaviorClasses[behaviorClass] ?? []
    }

    /// The class `instruction` declares, or nil if the language has no such
    /// instruction.
    static func behaviorClass(of instruction: PushInstruction) -> BehaviorClass? {
        language[instruction]?.behaviorClass
    }
}
