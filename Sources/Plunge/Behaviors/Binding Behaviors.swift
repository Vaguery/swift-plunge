//
//  Binding Behaviors.swift
//  Plunge
//
//  The `.binding` stack: keyed bindings, each variable a stack of its own.
//
//  **Binding.** `xRef` reads the top of X, leaves it, binds a copy to a fresh
//  key and pushes the key onto `.int`. `xRefAs` is assignment: `v k .xRefAs`
//  takes the value and the key and binds one to the other, shadowing k's older
//  binding. `bindingRekey` gives the top pair another key, for every type at
//  once. `xWith` binds the top of X for the length of a body from `.code`; it is
//  written as `.xRef ( body ) .bindingScope`, and `bindingScope` runs a body with
//  a key on `.int` and pops that key's binding after.
//
//  **Looking up.** Every lookup reads its key from `.int` and leaves it, and a
//  miss is a refusal of kind `notFound`: the key was there, its binding was not. `bindingDeref` runs
//  what a key holds (a block's contents go to `.exec`; anything else lands on
//  its stack); `bindingDerefToCode` delivers it to `.code` as data (a block as it
//  is, anything else quoted). Their `…From` forms take a depth from `.int` and
//  search from it, which reaches the older bindings a key shadows.
//  `bindingKeyDepth` gives that depth, and `bindingNearestKey`,
//  `bindingFloorKey`, `bindingCeilingKey` and `bindingKeyOf` find keys: by
//  distance, from below, from above, and by value (a probe from `.code`).
//  `bindingContainsKey` and `bindingOccurrencesOfKey` ask whether a key is bound
//  and how many times; for them an unbound key is an answer, not a refusal.
//
//  **Taking apart.** `bindingPopKey` discards a key's topmost binding;
//  `bindingDo` pops it and runs its value, as `codeDo` runs the block it takes;
//  `bindingUnpack` takes the top pair apart, its value to its own stack and its
//  key onto `.int`, which `xRefAs` puts back together.
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
    /// For a stack that really is short; a key or probe that matched nothing is
    /// `refNotFound`.
    static func refMissing(_ name: PushInstruction, on stack: PushStack,
                           _ recording: ProvenanceRecording) -> [Router] {
        Behavior.starved(name, on: stack, recording)
    }

    /// A lookup whose key (or probe) was there and matched no binding: a miss,
    /// `notFound`, as a search's is. Observed (law 4b): it depends on what
    /// `.binding` held.
    static func refNotFound(_ name: PushInstruction, _ what: String, _ recording: ProvenanceRecording) -> Router {
        Router(.error, ErrorItem("\(name): \(what)", kind: .notFound).observed(by: name, recording))
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
        Behavior.contextRead(name, reads: [stack], observes: [stack],
                             produces: .results([.binding, .int])) { _, context in
            let recording = context.recording
            guard let top = context.items(of: stack).first else {
                return refMissing(name, on: stack, recording)
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

    /// `xRefAs`: assignment. `v k .xRefAs` takes the top of `stack` and the key
    /// from `.int` and binds the one to the other, shadowing any older binding of
    /// k. For `.int` both come off one stack, the value below the key, so that
    /// `.bindingUnpack .intRefAs` puts a pair back as it was.
    static func refAs(_ name: PushInstruction, of stack: PushStack) -> Behavior {
        Behavior(name, requires: [.takes(stack), .takes(.int)], tags: [], behaviorClass: .operation,
                 body: .values { args, recording in
                     // Each claim takes the topmost item left, so from one stack the key comes first.
                     let (value, key) = stack == .int ? (args[1], args[0] as! IntItem) : (args[0], args[1] as! IntItem)
                     return [Router(.binding, BindingItem(key: key.value, bound: value,
                                                          call: recording([value, key, InstructionItem(name)])))]
                 }, produces: .results([.binding]))
        .described(
            "Binds the top \(stack.noun) to key k from `.int`, taking both and shadowing any older binding of k: "
            + "`\(stack == .int ? "v k" : "x k") .\(name.rawValue)`.")
    }

    /// `k ( body ) .bindingScope` runs the body with k on `.int`, then removes k's
    /// topmost binding: `k body… k .bindingPopKey .intPop`.
    static let bindingScope_Behavior =
        Behavior.control(.bindingScope, takes: [.int, .code]) { a, recording in
            // The body's items addressed in their block, as `codeDo` places them.
            let key = a[0], body = Containment.contents(of: a[1] as! CodeItem, recording)
            return [.place([key] + body + [key, InstructionItem(.bindingPopKey), InstructionItem(.intPop)])]
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
                 }, produces: .results([.binding]))
        .described("Turns a block `( k value )` into a binding; refuses any other shape, or a value that is an iterator"
                   + " or a binding.")


    /// Removes the topmost binding of the key on `.int` (read): weakening at the
    /// depth the key names. Structural, because nothing is made: the position is
    /// chosen by key, and the pair at it is deleted.
    static let bindingPopKey_Behavior =
        Behavior(.bindingPopKey, requires: [.reads(.int)], tags: [.fallible], behaviorClass: .structural,
                 body: .structural(.binding) { a, view in
                     let key = (a[0] as! IntItem).value
                     let depth = (0..<view.count).first { (view.item(at: $0) as? BindingItem)?.key == key }
                     guard let depth else {
                         return .loop([refNotFound(.bindingPopKey, "key \(key) is unbound", view.recording)])
                     }
                     return .positions(.remove(at: depth))
                 }, produces: .positions(.binding))
        .observing(.binding)
        .described("Discards key k's topmost binding, leaving k, so an older binding of k shows through; refuses"
                   + " when k is unbound.")

    /// The stacks a bound value can come from, in a fixed order.
    static let boundStacks: [PushStack] = BindingItem.binders.keys.sorted { $0.rawValue < $1.rawValue }

    /// `bindingUnpack`: the top pair taken apart, its value to its own stack (a
    /// block as data) and its key onto `.int` above it; `xRefAs` is its inverse.
    /// The value is the item that was bound (law 1b); the key is made here, and
    /// its crux clears the value away beneath it, as a query's clears what it read.
    static let bindingUnpack_Behavior =
        Behavior(.bindingUnpack, requires: [.takes(.binding)], tags: [], behaviorClass: .operation,
                 body: .values { args, recording in
                     let pair = args[0] as! BindingItem
                     let resting = PushStack.defaultStack(for: pair.bound) ?? .code
                     let key = IntItem(pair.key, call: recording(Behavior.reading(
                        [resting: 1], producing: .int, from: [pair, InstructionItem(.bindingUnpack)])))
                     return [Router(resting, pair.bound), Router(.int, key)]
                 }, produces: .alternatives(boundStacks.map { [$0, .int] }))
        .described("Takes the top binding apart: its value onto its own stack (a block as data), then its key onto"
                   + " `.int`.")


    // MARK: - The family

    static let bindingBehaviors: [PushInstruction: Behavior] = {
        var family: [PushInstruction: Behavior] = [
            .bindingScope: bindingScope_Behavior,
            .bindingRekey: bindingRekey_Behavior,
            .bindingFreshKey: bindingFreshKey_Behavior,
            .bindingQuote: bindingQuote_Behavior,
            .bindingFromCode: bindingFromCode_Behavior,
            .bindingDeref: bindingDeref(.bindingDeref, from: false),
            .bindingDerefFrom: bindingDeref(.bindingDerefFrom, from: true),
            .bindingDerefToCode: bindingDerefToCode(.bindingDerefToCode, from: false),
            .bindingDerefToCodeFrom: bindingDerefToCode(.bindingDerefToCodeFrom, from: true),
            .bindingDo: bindingDo_Behavior,
            .bindingKeyDepth: bindingKeyDepth_Behavior,
            .bindingNearestKey: bindingNearestKey_Behavior,
            .bindingFloorKey: bindingFloorKey_Behavior,
            .bindingCeilingKey: bindingCeilingKey_Behavior,
            .bindingContainsKey: bindingContainsKey_Behavior,
            .bindingOccurrencesOfKey: bindingOccurrencesOfKey_Behavior,
            .bindingKeyOf: bindingKeyOf_Behavior,
            .bindingPopKey: bindingPopKey_Behavior,
            .bindingUnpack: bindingUnpack_Behavior
        ]
        for (stack, binder) in BindingItem.binders {
            family[binder] = refBinder(binder, of: stack)
            let with = PushInstruction(rawValue: "\(stack.rawValue)With")!
            family[with] = refWith(with, binder: binder, of: stack)
            let assigner = PushInstruction(rawValue: "\(stack.rawValue)RefAs")!
            family[assigner] = refAs(assigner, of: stack)
        }
        return family
    }()
}
