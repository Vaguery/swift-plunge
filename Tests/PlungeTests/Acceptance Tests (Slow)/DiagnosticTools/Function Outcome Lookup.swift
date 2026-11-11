//
//  Function Outcome Lookup.swift
//  PlungeTests
//
//  The lookups V12 and V14–V17 use: the first block on `.code` that meets a
//  criterion read off its instructions' signatures.
//

@testable import Plunge

extension FunctionOutcome {

    /// What a lookup asks of a block on `.code`: that one of its instructions…
    enum Criterion {
        /// …takes (consumes or reads) the element's type.
        case takesType
        /// …does the family's job on it: takes T and gives T (map), takes T and
        /// gives a bool (filter), takes two T and gives T (reduce).
        case doesFamilyJob
        /// …takes T and gives any value a map can collect: a transformer.
        case transforms

        @MainActor func matches(_ item: any Item, _ family: Family, _ stack: PushStack) -> Bool {
            guard let token = (item as? InstructionItem)?.value,
                  let signature = runner.signature(of: token) else { return false }
            let taken = arguments(signature, from: stack)
            let gives = signature.produces.valueStacks
            switch (self, family) {
            case (.takesType, _): return taken > 0
            case (.transforms, _): return taken > 0 && !gives.isDisjoint(with: scalarStacks)
            case (.doesFamilyJob, .map): return taken >= 1 && gives.contains(stack)
            case (.doesFamilyJob, .filter): return taken >= 1 && gives.contains(.bool)
            case (.doesFamilyJob, .reduce): return taken >= 2 && gives.contains(stack)
            }
        }
    }

    /// The first block on `.code`, top down, that meets the first criterion any
    /// block meets; nil if none meets any.
    static func lookup(_ family: Family, _ s: Situation, criteria: [Criterion]) -> CodeItem? {
        guard let stack = elements(of: s.collection)?.first.flatMap({ PushStack.defaultStack(for: $0) }) else {
            return nil
        }
        let blocks = (s.stacks[.code] ?? []).compactMap { $0 as? CodeItem }
        for criterion in criteria {
            if let found = blocks.first(where: { $0.value.contains { criterion.matches($0, family, stack) } }) {
                return found
            }
        }
        return nil
    }

    /// V12 and V14–V16: the block a lookup finds (the situation's own block if
    /// it finds none), applied under `variant`.
    static func classifyAfterLookup(_ variant: Variant, _ family: Family, _ s: Situation,
                                    criteria: [Criterion]) -> Outcome {
        var tried = s
        if let found = lookup(family, s, criteria: criteria) { tried.block = found }
        return classifyDirectly(Call(variant: variant, family: family, situation: tried))
    }
}
