//
//  StructuralStep.swift
//  Plunge
//
//  What a structural rule asks for on one step.
//

/// The result of a structural rule's body: an effect on positions, applied in
/// place; a loop that delivers copies one per pass (`DupItems`, `DupTimes`, which
/// stay loops so that work takes time); or nothing at all.
nonisolated enum StructuralStep: Sendable {
    case positions(PositionEffect)
    case loop([Router])
    case unchanged
}
