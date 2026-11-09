//
//  Produces.swift
//  PushInterpreter
//
//  The output half of a Behavior's signature.
//

/// **What a Behavior puts out when it succeeds**, declared beside its
/// `requirements` so the language's input-output map is a property of the
/// definitions rather than something only running them can show.
///
/// Errors are never listed. Any Behavior can starve (its `requirements` say when),
/// and one tagged `.fallible` is a *partial* edge: outside its domain it writes
/// `.error` instead of these outputs. The size limits are a separate filter after
/// every edge (*Behavior input-output map.md*).
///
/// Most of the language is `results`, a fixed list of stacks. The other cases are
/// the shapes the 2026-11-08 survey found that a fixed list cannot state.
/// `Behavior IO Declaration Tests` drive every Behavior and check that what it
/// returns stays inside what it declares.
public nonisolated enum Produces: Hashable, Sendable {

    /// One result on each listed stack (a stack may repeat), in the order
    /// returned: `[.int]` for `intAdd`, `[.iterator, .int]` for
    /// `iteratorPeekStride`, `[.vecInt, .vecInt]` for a cut. Empty for an
    /// instruction that only consumes.
    case results([PushStack])

    /// One of a few fixed result lists, chosen by the arguments' values: an
    /// iterator getter's result type follows the iterator's kind, and a setter that
    /// finishes its loop hands the body to `.code` instead of an iterator.
    case alternatives([[PushStack]])

    /// One literal on `.exec`, which rests on `stack` one step later: a deferred
    /// push (the constants, `int0`…`vecString9`).
    case deferred(PushStack)

    /// The value bound to the instruction, deferred like a constant. Its stack is
    /// the input's type, which only a problem's training cases fix. (Named `binding`
    /// until 2026-11-09, when that word went to the `.binding` stack.)
    case input

    /// An iterator loop delivering elements to `stack` over the following steps:
    /// a promise, returned as an iterator and `.iteratorPlay`, not the elements
    /// (`vecIntPushAll`, `stringSplit`).
    case delivery(PushStack)

    /// Value-blind changes to `stack`'s positions — deleting, copying, moving —
    /// and no new value (the structural rules).
    case positions(PushStack)

    /// A write to the continuation. What it produces is whatever the program it
    /// carries does, which is not a type: a control edge, resolved by looking
    /// inside that program (the control class).
    case continuation

    /// The printout (the channels).
    case printout
}


public nonisolated extension Produces {

    /// The stacks this declaration can put a value on, with a deferred push
    /// counted at the stack it rests on. Empty for `continuation` and `input`,
    /// whose stacks are not fixed by the definition, and for `printout`.
    var valueStacks: Set<PushStack> {
        switch self {
        case .results(let stacks):        Set(stacks)
        case .alternatives(let options):  Set(options.flatMap { $0 })
        case .deferred(let stack):        [stack]
        case .delivery(let stack):        [stack]
        case .positions, .continuation, .input, .printout: []
        }
    }
}


nonisolated extension Produces {

    /// A loop's two endings: its body handed to `.code`, or nothing if it had
    /// none (`iteratorFarewell`).
    static let loopEnds: [[PushStack]] = [[.code], []]

    /// Every stack a contained item can rest on (`PushStack.defaultStack(for:)`):
    /// what an iterator getter may hand back when the field's type is not fixed.
    static let anyItem: [PushStack] = PushStack.allCases.filter { $0 != .error }

    /// An iterator handed back, with or without one field's value on one of
    /// `stacks`.
    static func iteratorAnd(_ stacks: [PushStack]) -> Produces {
        .alternatives([[.iterator]] + stacks.map { [.iterator, $0] })
    }
}
