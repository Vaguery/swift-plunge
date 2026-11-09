//
//  Ref Behaviors.swift
//  PushInterpreter
//
//  The `.ref` stack: keyed bindings, each variable a stack of its own
//  (*Behavior coverage audit (2026-11-09)* §9–§11, rulings 7–13; Roadmap #39).
//
//  **Binding.** `xRef` reads the top of X, leaves it, binds a copy to a fresh
//  key and pushes the key onto `.int`. `refRekey` gives the top pair another
//  key, shadowing that key's older binding: assignment, for every type at once.
//  `xWith` binds the top of X for the length of a body from `.code`; it is
//  written as `.xRef ( body ) .refScope`, and `refScope` runs a body with a key
//  on `.int` and removes that key's binding after.
//
//  **Looking up.** Every lookup reads its key from `.int` and leaves it, and a
//  miss is a refusal, as if `.ref` were empty (ruling I20). `refDeref` runs
//  what a key holds (a block's contents go to `.exec`; anything else lands on
//  its stack); `refDerefToCode` delivers it to `.code` as data (a block as it
//  is, anything else quoted). Their `…Below` forms take a depth from `.int` and
//  search from it, which reaches the older bindings a key shadows.
//  `refBindingDepth` gives that depth, `refUnbind` removes the topmost binding,
//  and `refNearestKey`, `refFloorKey` and `refKeyOf` find keys: by distance,
//  from below, and by value (a probe from `.code`).
//
//  **Nothing takes an argument from `.exec`** (ruling 12).
//

import DequeModule

nonisolated extension Interpreter {

    // MARK: - Helpers

    /// A refusal as if `stack` were empty: missing arguments, observed (law 4b).
    static func refMissing(_ name: PushInstruction, on stack: PushStack,
                           _ recording: ProvenanceRecording) -> Router {
        Router(.error, ErrorItem(missingArgumentsFor: name, on: stack).observed(by: name, recording))
    }

    /// The depth of the topmost pair at or below `start` whose key is `key`.
    static func bindingDepth(of key: Int, in pairs: Deque<any Item>, from start: Int = 0) -> Int? {
        (max(0, start)..<max(max(0, start), pairs.count)).first { (pairs[$0] as? RefItem)?.key == key }
    }

    /// The quote instruction for each stack an item can be quoted from.
    static let quoters: [PushStack: PushInstruction] = [
        .bool: .boolQuote, .int: .intQuote, .double: .doubleQuote, .char: .charQuote, .string: .stringQuote,
        .vecBool: .vecBoolQuote, .vecInt: .vecIntQuote, .vecDouble: .vecDoubleQuote, .vecString: .vecStringQuote
    ]

    /// `item` as data on `.code`: a block as it is (a copy, law 1), anything else
    /// in a block of its own, recorded as its type's quote.
    static func asCode(_ item: any Item, by name: PushInstruction, _ recording: ProvenanceRecording) -> any Item {
        if let block = item.exactly(CodeItem.self) { return block }
        if let stack = PushStack.defaultStack(for: item), let quote = quoters[stack] {
            return CodeItem([item], call: recording([item, InstructionItem(quote)]))
        }
        return CodeItem([item]).observed(by: name, recording)
    }


    // MARK: - Binders

    /// `xRef`: binds a copy of the top of `stack` to a fresh key, leaving the
    /// item where it was, and pushes the key onto `.int` (ruling 9).
    static func refBinder(_ name: PushInstruction, of stack: PushStack) -> Behavior {
        Behavior.contextRead(name, tags: [.fallible], produces: .results([.ref, .int])) { _, context in
            let recording = context.recording
            guard let top = context.items(of: stack).first else {
                return [refMissing(name, on: stack, recording)]
            }
            let fresh = context.freshKey()
            let key = IntItem(fresh).observed(by: name, recording)
            let pair = RefItem(key: fresh, bound: top,
                               call: recording(RefItem.rebuilt(binding: top, to: key) ?? []))
            return [Router(.ref, pair), Router(.int, key)]
        }
    }

    /// `xWith`: binds the top of `stack` for the length of a body taken from
    /// `.code` (ruling 11), as `.xRef ( body ) .refScope`. The top of `stack` must
    /// be there, so the binder cannot starve between the two.
    static func refWith(_ name: PushInstruction, binder: PushInstruction, of stack: PushStack) -> Behavior {
        Behavior.control(name, requires: [.takes(.code), .reads(stack)]) { a, _ in
            [Router(.exec, InstructionItem(.refScope)), Router(.exec, a[0]), Router(.exec, InstructionItem(binder))]
        }
    }

    /// `k ( body ) .refScope` runs the body with k on `.int`, then removes k's
    /// topmost binding: `k body… k .refUnbind .intPop`.
    static let refScope_Behavior =
        Behavior.control(.refScope, takes: [.int, .code]) { a, recording in
            // The body's items addressed in their block, as `codeDo` places them.
            let key = a[0], body = Containment.contents(of: a[1] as! CodeItem, recording)
            return [.place([key] + body + [key, InstructionItem(.refUnbind), InstructionItem(.intPop)])]
        }

    /// `k .refRekey` gives the top pair the key k (ruling 10).
    ///
    /// Only the last key matters, so a pair that was itself re-keyed is recorded
    /// as re-keyed once: its history up to that `refRekey`, then k. That is also
    /// what keeps a bound pair's crux a fixed point, since replaying it binds
    /// afresh and re-keys the fresh key away.
    static let refRekey_Behavior =
        Behavior(.refRekey, requires: [.takes(.ref), .takes(.int)], tags: [], behaviorClass: .operation,
                 body: .values { a, recording in
                     let pair = a[0] as! RefItem, key = a[1] as! IntItem
                     let previous = pair.call
                     let before: [any Item] =
                         previous.count >= 2 && (previous.last as? InstructionItem)?.value == .refRekey
                         ? Array(previous.dropLast(2)) : [pair]
                     return [Router(.ref, RefItem(key: key.value, bound: pair.bound,
                                                  call: recording(before + [key, InstructionItem(.refRekey)])))]
                 }, produces: .results([.ref]))

    /// A fresh key onto `.int`: a deterministic gensym.
    static let refFresh_Behavior =
        Behavior.contextRead(.refFresh, produces: .results([.int])) { _, context in
            [Router(.int, IntItem(context.freshKey()).observed(by: .refFresh, context.recording))]
        }


    // MARK: - Pairs as data

    /// A pair as the block `( k value )`.
    static let refQuote_Behavior =
        Behavior(.refQuote, requires: [.takes(.ref)], tags: [], behaviorClass: .operation,
                 body: .values { a, recording in
                     let pair = a[0] as! RefItem
                     return [Router(.code, CodeItem([IntItem(pair.key), pair.bound],
                                                    call: recording([pair, InstructionItem(.refQuote)])))]
                 }, produces: .results([.code]))

    /// The block `( k value )` as a pair; refused for any other shape, and for a
    /// value that cannot be bound (an iterator or a pair).
    static let refFromCode_Behavior =
        Behavior(.refFromCode, requires: [.takes(.code)], tags: [.fallible], behaviorClass: .operation,
                 body: .values { a, recording in
                     let block = a[0] as! CodeItem
                     let call = recording([block, InstructionItem(.refFromCode)])
                     guard block.value.count == 2, let key = block.value[0] as? IntItem,
                           !(block.value[1] is IteratorItem), !(block.value[1] is RefItem) else {
                         return [Behavior.refusal("Not a ( key value ) pair in .refFromCode", kind: .conversion,
                                                  call: call)]
                     }
                     // The value as it is addressed in its block, so it keeps a history.
                     let bound = Containment.contents(of: block, recording)[1]
                     return [Router(.ref, RefItem(key: key.value, bound: bound, call: call))]
                 }, produces: .alternatives([[.ref], [.error]]))


    // MARK: - Lookups

    /// The binding for the key on `.int` (read), searched from the top, or from
    /// a depth taken from `.int` (`below`); `deliver` turns the value into
    /// results. A miss hands the depth back.
    static func refLookup(_ name: PushInstruction, below: Bool, tags: Set<InstructionTag> = [],
                          produces: Produces,
                          deliver: @escaping @Sendable (any Item, ReadContext) -> [Router]) -> Behavior {
        Behavior.contextRead(name, takes: below ? [.int] : [], tags: tags.union([.fallible]),
                             produces: produces) { a, context in
            let handBack = below ? [Router(.int, a[0])] : []
            guard let key = context.items(of: .int).first as? IntItem else {
                return handBack + [refMissing(name, on: .int, context.recording)]
            }
            let pairs = context.items(of: .ref)
            let start = below ? (a[0] as! IntItem).value : 0
            guard let depth = bindingDepth(of: key.value, in: pairs, from: start) else {
                return handBack + [refMissing(name, on: .ref, context.recording)]
            }
            return deliver((pairs[depth] as! RefItem).bound, context)
        }
    }

    /// Runs what a key holds: a block's contents onto `.exec`, anything else to
    /// land on its stack. Its output is the rest of the program, as a control
    /// instruction's is, read out of the environment as an input's is. Not tagged
    /// re-entrant: it does not re-push itself, and a block that looks itself up
    /// recurses as `codeDo` of a block holding `codeDo` does.
    static func refDeref(_ name: PushInstruction, below: Bool) -> Behavior {
        refLookup(name, below: below, produces: .continuation) { value, context in
            if let block = value.exactly(CodeItem.self) {
                // Each item addressed in its block, as `codeDo` places them.
                return Containment.contents(of: block, context.recording).reversed().map { Router(.exec, $0) }
            }
            return [Router(.exec, value)]
        }
    }

    /// Delivers what a key holds to `.code`, as data.
    static func refDerefToCode(_ name: PushInstruction, below: Bool) -> Behavior {
        refLookup(name, below: below, produces: .results([.code])) { value, context in
            [Router(.code, asCode(value, by: name, context.recording))]
        }
    }

    /// The depth of a key's topmost binding, onto `.int`.
    static let refBindingDepth_Behavior =
        Behavior.contextRead(.refBindingDepth, tags: [.fallible], produces: .results([.int])) { _, context in
            guard let key = context.items(of: .int).first as? IntItem else {
                return [refMissing(.refBindingDepth, on: .int, context.recording)]
            }
            guard let depth = bindingDepth(of: key.value, in: context.items(of: .ref)) else {
                return [refMissing(.refBindingDepth, on: .ref, context.recording)]
            }
            return [Router(.int, IntItem(depth).observed(by: .refBindingDepth, context.recording))]
        }

    /// A key found from the key on `.int` (read) by `choose`, among the keys on
    /// `.ref` from the top down; onto `.int`, observed.
    static func refKeyFinder(_ name: PushInstruction,
                             choose: @escaping @Sendable (Int, [Int]) -> Int?) -> Behavior {
        Behavior.contextRead(name, tags: [.fallible], produces: .results([.int])) { _, context in
            guard let key = context.items(of: .int).first as? IntItem else {
                return [refMissing(name, on: .int, context.recording)]
            }
            let keys = context.items(of: .ref).map { ($0 as! RefItem).key }
            guard let found = choose(key.value, keys) else {
                return [refMissing(name, on: .ref, context.recording)]
            }
            return [Router(.int, IntItem(found).observed(by: name, context.recording))]
        }
    }

    /// The key nearest k, the topmost on a tie; misses only on an empty `.ref`.
    static let refNearestKey_Behavior = refKeyFinder(.refNearestKey) { k, keys in
        keys.min { abs(Double($0) - Double(k)) < abs(Double($1) - Double(k)) }
    }

    /// The greatest key at or below k; misses when every key is above it.
    static let refFloorKey_Behavior = refKeyFinder(.refFloorKey) { k, keys in
        keys.filter { $0 <= k }.max()
    }

    /// Reverse lookup: the key of the topmost binding whose value is the block on
    /// top of `.code` (read), or the one item that block holds.
    static let refKeyOf_Behavior =
        Behavior.contextRead(.refKeyOf, tags: [.fallible], produces: .results([.int])) { _, context in
            guard let probe = context.items(of: .code).first as? CodeItem else {
                return [refMissing(.refKeyOf, on: .code, context.recording)]
            }
            let target = probe.denotedItem
            guard let pair = context.items(of: .ref).lazy.compactMap({ $0 as? RefItem })
                .first(where: { $0.bound.isEqual(to: probe) || $0.bound.isEqual(to: target) }) else {
                return [refMissing(.refKeyOf, on: .ref, context.recording)]
            }
            return [Router(.int, IntItem(pair.key).observed(by: .refKeyOf, context.recording))]
        }

    /// Removes the topmost binding of the key on `.int` (read): weakening at the
    /// depth the key names.
    static let refUnbind_Behavior =
        Behavior(.refUnbind, requires: [.reads(.int)], tags: [.fallible], behaviorClass: .structural,
                 body: .structural(.ref) { a, view in
                     let key = (a[0] as! IntItem).value
                     guard let depth = (0..<view.count).first(where: { (view.item(at: $0) as? RefItem)?.key == key })
                     else { return .loop([refMissing(.refUnbind, on: .ref, view.recording)]) }
                     return .positions(.remove(at: depth))
                 }, produces: .positions(.ref))


    // MARK: - The family

    static let refBehaviors: [PushInstruction: Behavior] = {
        var family: [PushInstruction: Behavior] = [
            .refScope: refScope_Behavior,
            .refRekey: refRekey_Behavior,
            .refFresh: refFresh_Behavior,
            .refQuote: refQuote_Behavior,
            .refFromCode: refFromCode_Behavior,
            .refDeref: refDeref(.refDeref, below: false),
            .refDerefBelow: refDeref(.refDerefBelow, below: true),
            .refDerefToCode: refDerefToCode(.refDerefToCode, below: false),
            .refDerefToCodeBelow: refDerefToCode(.refDerefToCodeBelow, below: true),
            .refBindingDepth: refBindingDepth_Behavior,
            .refNearestKey: refNearestKey_Behavior,
            .refFloorKey: refFloorKey_Behavior,
            .refKeyOf: refKeyOf_Behavior,
            .refUnbind: refUnbind_Behavior
        ]
        for (stack, binder) in RefItem.binders {
            family[binder] = refBinder(binder, of: stack)
            let with = PushInstruction(rawValue: "\(stack.rawValue)With")!
            family[with] = refWith(with, binder: binder, of: stack)
        }
        return family
    }()
}
