//
//  FuzzSeed.swift
//  PlungeTests
//
//  One switch for trying new random programs in every fixed-seed fuzz suite
//  (2026-11-20).
//

import Foundation

/// **New programs on request.** The fuzz suites use fixed seeds, so each run
/// replays the programs the last one did, and a finding reproduces exactly. Set
/// `PUSH_FUZZ_SEED` to any number to shift every suite's seeds by it: the same
/// checks, on programs none of them has seen. Report the value with any finding.
/// Unset, the shift is 0 and the suites run as they always have.
nonisolated enum FuzzSeed {
    static let shift: UInt64 = ProcessInfo.processInfo.environment["PUSH_FUZZ_SEED"].flatMap(UInt64.init) ?? 0
}
