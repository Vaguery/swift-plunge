//
//  PositionEffect.swift
//  PushInterpreter
//
//  A structural rule's whole effect, as data (Roadmap #43).
//

/// **A value-blind change to the positions of one stack** — what a structural
/// rule does, declared rather than performed. `Behavior.act` applies it in place.
///
/// Depths count from the top (0 is the top item) and arrive already clamped
/// (`Position`), measured on the stack as it stands once the Behavior's own
/// arguments are gone. Because nothing here can construct a value, provenance
/// law 1 holds by construction: a moved or copied item keeps its `call` untouched.
///
/// These are the structural rules of substructural logic: `delete` is weakening,
/// `copy` contraction, `move` exchange.
nonisolated enum PositionEffect: Sendable, Equatable {
    /// Remove the top `count` items (clamped to the depth): pop, `PopItems`, `Flush`.
    case delete(top: Int)
    /// Copy the item at `from` and put the copy at `to`, counted on the stack as it
    /// will be with the copy in it: dup (0 → 0), `YankDup` (n → 0), `DeepDup`
    /// (n → n, beside its original). A copy grows the stack, so it goes through
    /// the validated push and can be refused at `maxStackDepth`.
    case copy(from: Int, to: Int)
    /// Move the item at `from` to `to`: swap (1 → 0), rot (2 → 0), `Yank` (n → 0),
    /// `Shove` (0 → n).
    case move(from: Int, to: Int)
    /// Remove the item at `depth`: weakening below the top, as `delete` is at
    /// it. `bindingUnbind`, which finds the depth by the pair's key.
    case remove(at: Int)
}
