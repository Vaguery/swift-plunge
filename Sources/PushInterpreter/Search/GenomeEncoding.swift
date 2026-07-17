//
//  GenomeEncoding.swift
//  PushInterpreter
//
//  Created by William Tozier on 7/13/26.
//

/// The genome encodings the interpreter knows how to translate into a runnable
/// `[any Item]` program.
///
/// This is the single seam through which a different encoding scheme is passed
/// in: call sites take a `GenomeEncoding` and call `translate(_:)`, so adding a
/// scheme means adding a case here and its translator — no call site changes.
///
/// - `plushy`: the linear Plushy encoding (`Plushy.plushy2push`), where structure
///   is carried by open/close control tokens.
/// - `fibonacci`: a flat item stream whose leading blocks have **implied**
///   Fibonacci lengths (1, 1, 2, 3, 5…) until about a third of it is used, the
///   rest flat. A testing genome: the lengths are not genes, so a search cannot
///   move them.
/// - `forestGenome`: TODO — the same shape as `fibonacci` with the block lengths
///   **encoded as genes**, which is the evolvable version. It shares
///   `BlockPacking`; only the source of the lengths differs.
/// - `bb9`: TODO — placeholder scheme, not yet implemented.
public nonisolated enum GenomeEncoding: String, Sendable, Codable, Hashable, CaseIterable {
    case plushy
    case fibonacci
    case forestGenome
    case bb9

    /// Translate raw genome tokens into a runnable program using this scheme.
    ///
    /// The `[Any]` input mirrors the current `Plushy` token stream; the eventual
    /// `ForestGenome`/`BB9` representations may refine it when they land.
    public func translate(_ genome: [Any]) -> [any Item] {
        switch self {
        case .plushy:
            Plushy.plushy2push(genome)
        case .fibonacci:
            FibonacciGenome.translate(genome)
        case .forestGenome:
            ForestGenome.translate(genome)  // TODO: not yet implemented
        case .bb9:
            BB9.translate(genome)           // TODO: not yet implemented
        }
    }
}
