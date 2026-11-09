//
//  Binding Behaviors.swift
//  PushInterpreter
//
//  The `.binding` stack: keyed bindings, each variable a stack of its own.
//
//  **Binding.** `xRef` reads the top of X, leaves it, binds a copy to a fresh
//  key and pushes the key onto `.int`. `bindingRekey` gives the top pair another
//  key, shadowing that key's older binding: assignment, for every type at once.
//  `xWith` binds the top of X for the length of a body from `.code`; it is
//  written as `.xRef ( body ) .bindingScope`, and `bindingScope` runs a body with
//  a key on `.int` and removes that key's binding after.
//
//  **Looking up.** Every lookup reads its key from `.int` and leaves it, and a
//  miss is a refusal, as if `.binding` were empty. `bindingDeref` runs
//  what a key holds (a block's contents go to `.exec`; anything else lands on
//  its stack); `bindingDerefToCode` delivers it to `.code` as data (a block as it
//  is, anything else quoted). Their `…Below` forms take a depth from `.int` and
//  search from it, which reaches the older bindings a key shadows.
//  `bindingKeyDepth` gives that depth, `bindingUnbind` removes the topmost
//  binding, and `bindingNearestKey`, `bindingFloorKey` and `bindingKeyOf` find
//  keys: by distance, from below, and by value (a probe from `.code`).
//
//  **Nothing takes an argument from `.exec`**.
//
//  **Names** (since 2026-11-09, when the stack was renamed from `.ref`): every
//  instruction that works on the stack is named for it, `binding…`, as
//  everywhere in the language. The verb *ref* survives only after a source
//  stack, for the binders: `intRef` makes a binding from an int as `intQuote`
//  makes a block from one. `xWith` follows them.
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
        (max(0, start)..<max(max(0, start), pairs.count)).first { (pairs[$0] as? BindingItem)?.key == key }
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
    /// item where it was, and pushes the key onto `.int`.
    static func refBinder(_ name: PushInstruction, of stack: PushStack) -> Behavior {
        Behavior.contextRead(name, tags: [.fallible], produces: .results([.binding, .int])) { _, context in
            let recording = context.recording
            guard let top = context.items(of: stack).first else {
                return [refMissing(name, on: stack, recording)]
            }
            let fresh = context.freshKey()
            let key = IntItem(fresh).observed(by: name, recording)
            let pair = BindingItem(key: fresh, bound: top,
                               call: recording(BindingItem.rebuilt(binding: top, to: key) ?? []))
            return [Router(.binding, pair), Router(.int, key)]
        }
        .described(
            "Binds a copy of the top \(stack.noun), left in place, to a fresh key and pushes the key onto `.int`."
        )
    }

    /// `xWith`: binds the top of `stack` for the length of a body taken from
    /// `.code`, as `.xRef ( body ) .bindingScope`. The top of `stack` must
    /// be there, so the binder cannot starve between the two.
    static func refWith(_ name: PushInstruction, binder: PushInstruction, of stack: PushStack) -> Behavior {
        Behavior.control(name, requires: [.takes(.code), .reads(stack)]) { a, _ in
            [Router(.exec, InstructionItem(.bindingScope)), Router(.exec, a[0]), Router(.exec, InstructionItem(binder))]
        }
        .described(
            "Binds a copy of the "
            + (stack == .code ? "block under the body" : "top \(stack.noun)")
            + " to a fresh key, runs a body block from `.code` with the key on `.int`, then removes the binding."
        )
    }

    /// `k ( body ) .bindingScope` runs the body with k on `.int`, then removes k's
    /// topmost binding: `k body… k .bindingUnbind .intPop`.
    static let bindingScope_Behavior =
        Behavior.control(.bindingScope, takes: [.int, .code]) { a, recording in
            // The body's items addressed in their block, as `codeDo` places them.
            let key = a[0], body = Containment.contents(of: a[1] as! CodeItem, recording)
            return [.place([key] + body + [key, InstructionItem(.bindingUnbind), InstructionItem(.intPop)])]
        }
        .described("Runs a body with key k pushed onto `.int`, then removes k's topmost binding: "
                   + "`k ( b ) .bindingScope`.")

    /// `k .bindingRekey` gives the top pair the key k.
    ///
    /// Only the last key matters, so a pair that was itself re-keyed is recorded
    /// as re-keyed once: its history up to that `bindingRekey`, then k. That is also
    /// what keeps a bound pair's crux a fixed point, since replaying it binds
    /// afresh and re-keys the fresh key away.
    static let bindingRekey_Behavior =
        Behavior(.bindingRekey, requires: [.takes(.binding), .takes(.int)], tags: [], behaviorClass: .operation,
                 body: .values { a, recording in
                     let pair = a[0] as! BindingItem, key = a[1] as! IntItem
                     let previous = pair.call
                     let before: [any Item] =
                         previous.count >= 2 && (previous.last as? InstructionItem)?.value == .bindingRekey
                         ? Array(previous.dropLast(2)) : [pair]
                     return [Router(.binding, BindingItem(key: key.value, bound: pair.bound,
                                                  call: recording(before + [key, InstructionItem(.bindingRekey)])))]
                 }, produces: .results([.binding]))
        .described("Gives the top binding the key k from `.int`, shadowing any older binding of k.")

    /// A fresh key onto `.int`: a deterministic gensym.
    static let bindingFreshKey_Behavior =
        Behavior.contextRead(.bindingFreshKey, produces: .results([.int])) { _, context in
            [Router(.int, IntItem(context.freshKey()).observed(by: .bindingFreshKey, context.recording))]
        }
        .described("Pushes a fresh key onto `.int`, one not drawn before in this run.")


    // MARK: - Pairs as data

    /// A pair as the block `( k value )`.
    static let bindingQuote_Behavior =
        Behavior(.bindingQuote, requires: [.takes(.binding)], tags: [], behaviorClass: .operation,
                 body: .values { a, recording in
                     let pair = a[0] as! BindingItem
                     return [Router(.code, CodeItem([IntItem(pair.key), pair.bound],
                                                    call: recording([pair, InstructionItem(.bindingQuote)])))]
                 }, produces: .results([.code]))
        .described("Turns the top binding into the block `( k value )` on `.code`.")

    /// The block `( k value )` as a pair; refused for any other shape, and for a
    /// value that cannot be bound (an iterator or a pair).
    static let bindingFromCode_Behavior =
        Behavior(.bindingFromCode, requires: [.takes(.code)], tags: [.fallible], behaviorClass: .operation,
                 body: .values { a, recording in
                     let block = a[0] as! CodeItem
                     let call = recording([block, InstructionItem(.bindingFromCode)])
                     guard block.value.count == 2, let key = block.value[0] as? IntItem,
                           !(block.value[1] is IteratorItem), !(block.value[1] is BindingItem) else {
                         return [Behavior.refusal("Not a ( key value ) pair in .bindingFromCode", kind: .conversion,
                                                  call: call)]
                     }
                     // The value as it is addressed in its block, so it keeps a history.
                     let bound = Containment.contents(of: block, recording)[1]
                     return [Router(.binding, BindingItem(key: key.value, bound: bound, call: call))]
                 }, produces: .alternatives([[.binding], [.error]]))
        .described("Turns a block `( k value )` into a binding; refuses any other shape, or a value that is an iterator"
                   + " or a binding.")


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
            let pairs = context.items(of: .binding)
            let start = below ? (a[0] as! IntItem).value : 0
            guard let depth = bindingDepth(of: key.value, in: pairs, from: start) else {
                return handBack + [refMissing(name, on: .binding, context.recording)]
            }
            return deliver((pairs[depth] as! BindingItem).bound, context)
        }
    }

    /// Runs what a key holds: a block's contents onto `.exec`, anything else to
    /// land on its stack. Its output is the rest of the program, as a control
    /// instruction's is, read out of the environment as an input's is. Not tagged
    /// re-entrant: it does not re-push itself, and a block that looks itself up
    /// recurses as `codeDo` of a block holding `codeDo` does.
    static func bindingDeref(_ name: PushInstruction, below: Bool) -> Behavior {
        refLookup(name, below: below, produces: .continuation) { value, context in
            if let block = value.exactly(CodeItem.self) {
                // Each item addressed in its block, as `codeDo` places them.
                return Containment.contents(of: block, context.recording).reversed().map { Router(.exec, $0) }
            }
            return [Router(.exec, value)]
        }
        .described(
            below
                ? "Runs the value bound to key k at depth i or below on `.binding`, as `.bindingDeref` does, leaving k:"
                  + " `k i .bindingDerefBelow` reaches shadowed bindings; refuses when there is none."
                : "Runs the value bound to key k, leaving k: a block's contents go onto `.exec`, any other value"
                  + " lands on its stack; refuses when k is unbound."
        )
    }

    /// Delivers what a key holds to `.code`, as data.
    static func bindingDerefToCode(_ name: PushInstruction, below: Bool) -> Behavior {
        refLookup(name, below: below, produces: .results([.code])) { value, context in
            [Router(.code, asCode(value, by: name, context.recording))]
        }
        .described(
            below
                ? "Pushes the value bound to key k at depth i or below on `.binding` onto `.code`, as"
                  + " `.bindingDerefToCode` does, leaving k: `k i .bindingDerefToCodeBelow`;"
                  + " refuses when there is none."
                : "Pushes the value bound to key k onto `.code` as data, a block as it is and anything else quoted,"
                  + " leaving k; refuses when k is unbound."
        )
    }

    /// The depth of a key's topmost binding, onto `.int`.
    static let bindingKeyDepth_Behavior =
        Behavior.contextRead(.bindingKeyDepth, tags: [.fallible], produces: .results([.int])) { _, context in
            guard let key = context.items(of: .int).first as? IntItem else {
                return [refMissing(.bindingKeyDepth, on: .int, context.recording)]
            }
            guard let depth = bindingDepth(of: key.value, in: context.items(of: .binding)) else {
                return [refMissing(.bindingKeyDepth, on: .binding, context.recording)]
            }
            return [Router(.int, IntItem(depth).observed(by: .bindingKeyDepth, context.recording))]
        }
        .described("Pushes the depth of key k's topmost binding on `.binding`, leaving k; refuses when k is unbound.")

    /// A key found from the key on `.int` (read) by `choose`, among the keys on
    /// `.binding` from the top down; onto `.int`, observed.
    static func refKeyFinder(_ name: PushInstruction,
                             choose: @escaping @Sendable (Int, [Int]) -> Int?) -> Behavior {
        Behavior.contextRead(name, tags: [.fallible], produces: .results([.int])) { _, context in
            guard let key = context.items(of: .int).first as? IntItem else {
                return [refMissing(name, on: .int, context.recording)]
            }
            let keys = context.items(of: .binding).map { ($0 as! BindingItem).key }
            guard let found = choose(key.value, keys) else {
                return [refMissing(name, on: .binding, context.recording)]
            }
            return [Router(.int, IntItem(found).observed(by: name, context.recording))]
        }
    }

    /// The key nearest k, the topmost on a tie; misses only on an empty `.binding`.
    static let bindingNearestKey_Behavior = refKeyFinder(.bindingNearestKey) { k, keys in
        keys.min { abs(Double($0) - Double(k)) < abs(Double($1) - Double(k)) }
    }
        .described("Pushes the bound key nearest k, the topmost on a tie, leaving k; refuses when nothing is bound.")

    /// The greatest key at or below k; misses when every key is above it.
    static let bindingFloorKey_Behavior = refKeyFinder(.bindingFloorKey) { k, keys in
        keys.filter { $0 <= k }.max()
    }
        .described("Pushes the greatest bound key at or below k, leaving k; refuses when there is none.")

    /// Reverse lookup: the key of the topmost binding whose value is the block on
    /// top of `.code` (read), or the one item that block holds.
    static let bindingKeyOf_Behavior =
        Behavior.contextRead(.bindingKeyOf, tags: [.fallible], produces: .results([.int])) { _, context in
            guard let probe = context.items(of: .code).first as? CodeItem else {
                return [refMissing(.bindingKeyOf, on: .code, context.recording)]
            }
            let target = probe.denotedItem
            guard let pair = context.items(of: .binding).lazy.compactMap({ $0 as? BindingItem })
                .first(where: { $0.bound.isEqual(to: probe) || $0.bound.isEqual(to: target) }) else {
                return [refMissing(.bindingKeyOf, on: .binding, context.recording)]
            }
            return [Router(.int, IntItem(pair.key).observed(by: .bindingKeyOf, context.recording))]
        }
        .described("Pushes the key of the topmost binding whose value is the block on `.code`, or its lone item,"
                   + " leaving the block; refuses on a miss.")

    /// Removes the topmost binding of the key on `.int` (read): weakening at the
    /// depth the key names.
    static let bindingUnbind_Behavior =
        Behavior(.bindingUnbind, requires: [.reads(.int)], tags: [.fallible], behaviorClass: .structural,
                 body: .structural(.binding) { a, view in
                     let key = (a[0] as! IntItem).value
                     let depth = (0..<view.count).first { (view.item(at: $0) as? BindingItem)?.key == key }
                     guard let depth else { return .loop([refMissing(.bindingUnbind, on: .binding, view.recording)]) }
                     return .positions(.remove(at: depth))
                 }, produces: .positions(.binding))
        .described("Removes key k's topmost binding, leaving k; refuses when k is unbound.")


    // MARK: - The family

    static let bindingBehaviors: [PushInstruction: Behavior] = {
        var family: [PushInstruction: Behavior] = [
            .bindingScope: bindingScope_Behavior,
            .bindingRekey: bindingRekey_Behavior,
            .bindingFreshKey: bindingFreshKey_Behavior,
            .bindingQuote: bindingQuote_Behavior,
            .bindingFromCode: bindingFromCode_Behavior,
            .bindingDeref: bindingDeref(.bindingDeref, below: false),
            .bindingDerefBelow: bindingDeref(.bindingDerefBelow, below: true),
            .bindingDerefToCode: bindingDerefToCode(.bindingDerefToCode, below: false),
            .bindingDerefToCodeBelow: bindingDerefToCode(.bindingDerefToCodeBelow, below: true),
            .bindingKeyDepth: bindingKeyDepth_Behavior,
            .bindingNearestKey: bindingNearestKey_Behavior,
            .bindingFloorKey: bindingFloorKey_Behavior,
            .bindingKeyOf: bindingKeyOf_Behavior,
            .bindingUnbind: bindingUnbind_Behavior
        ]
        for (stack, binder) in BindingItem.binders {
            family[binder] = refBinder(binder, of: stack)
            let with = PushInstruction(rawValue: "\(stack.rawValue)With")!
            family[with] = refWith(with, binder: binder, of: stack)
        }
        return family
    }()
}
