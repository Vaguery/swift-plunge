//
//  Binding Lookup Behaviors.swift
//  PushInterpreter
//
//  The `.binding` stack's lookups: every one reads its key from `.int` and
//  leaves it. The derefs and `bindingDo` find a key's binding and run or deliver
//  its value; the key finders and key queries answer questions about the keys.
//  The binders, the pairs as data, and the family table are in
//  `Binding Behaviors.swift`.
//

nonisolated extension Interpreter {

    // MARK: - Lookups

    /// The binding for the key on `.int` (read), searched from the top, or from
    /// a depth taken from `.int` (`from`); `deliver` turns the value into
    /// results. A miss hands the depth back.
    static func refLookup(_ name: PushInstruction, from: Bool, tags: Set<InstructionTag> = [],
                          produces: Produces,
                          deliver: @escaping @Sendable (any Item, ReadContext) -> [Router]) -> Behavior {
        Behavior.contextRead(name, takes: from ? [.int] : [], observes: [.int, .binding], tags: tags.union([.fallible]),
                             produces: produces) { a, context in
            let handBack = from ? [Router(.int, a[0])] : []
            guard let key = context.items(of: .int).first as? IntItem else {
                return handBack + [refMissing(name, on: .int, context.recording)]
            }
            let pairs = context.items(of: .binding)
            let start = from ? (a[0] as! IntItem).value : 0
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
    static func bindingDeref(_ name: PushInstruction, from: Bool) -> Behavior {
        refLookup(name, from: from, produces: .continuation) { value, context in
            if let block = value.exactly(CodeItem.self) {
                // Each item addressed in its block, as `codeDo` places them.
                return Containment.contents(of: block, context.recording).reversed().map { Router(.exec, $0) }
            }
            return [Router(.exec, value)]
        }
        .described(
            from
                ? "Runs the value bound to key k at depth i or below on `.binding`, as `.bindingDeref` does, leaving k:"
                  + " `k i .bindingDerefFrom` reaches shadowed bindings; refuses when there is none."
                : "Runs the value bound to key k, leaving k: a block's contents go onto `.exec`, any other value"
                  + " lands on its stack; refuses when k is unbound."
        )
    }

    /// Delivers what a key holds to `.code`, as data.
    static func bindingDerefToCode(_ name: PushInstruction, from: Bool) -> Behavior {
        refLookup(name, from: from, produces: .results([.code])) { value, context in
            [Router(.code, asCode(value, by: name, context.recording))]
        }
        .described(
            from
                ? "Pushes the value bound to key k at depth i or below on `.binding` onto `.code`, as"
                  + " `.bindingDerefToCode` does, leaving k: `k i .bindingDerefToCodeFrom`;"
                  + " refuses when there is none."
                : "Pushes the value bound to key k onto `.code` as data, a block as it is and anything else quoted,"
                  + " leaving k; refuses when k is unbound."
        )
    }

    /// `bindingDo`: pops a key's topmost binding and runs its value, as `codeDo`
    /// runs the block it takes; `bindingDeref` is the reading form. The pop is
    /// placed on `.exec` above the value, so it runs first, while k is still the
    /// top of `.int` (an int value landing first would be read as the key).
    static let bindingDo_Behavior =
        refLookup(.bindingDo, from: false, produces: .continuation) { value, context in
            var routers: [Router] = if let block = value.exactly(CodeItem.self) {
                Containment.contents(of: block, context.recording).reversed().map { Router(.exec, $0) }
            } else {
                [Router(.exec, value)]
            }
            routers.append(Router(.exec, InstructionItem(.bindingPopKey)))
            return routers
        }
        .described("Pops key k's topmost binding and runs its value, as `.bindingDeref` does, leaving k; refuses when"
                   + " k is unbound.")

    /// The depth of a key's topmost binding, onto `.int`.
    static let bindingKeyDepth_Behavior =
        Behavior.contextRead(.bindingKeyDepth, observes: [.int, .binding], tags: [.fallible],
                             produces: .results([.int])) { _, context in
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
        Behavior.contextRead(name, observes: [.int, .binding], tags: [.fallible], produces: .results([.int])) { _, context in
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

    /// The least key at or above k; misses when every key is below it.
    static let bindingCeilingKey_Behavior = refKeyFinder(.bindingCeilingKey) { key, keys in
        keys.filter { $0 >= key }.min()
    }
        .described("Pushes the least bound key at or above k, leaving k; refuses when there is none.")

    /// A fact about key k (read from `.int`) computed from the keys on `.binding`,
    /// top first. An unbound key is an answer, not a refusal: it refuses only
    /// when there is no key to read.
    static func keyQuery(_ name: PushInstruction, gives stack: PushStack,
                         _ answer: @escaping @Sendable (_ key: Int, _ keys: [Int]) -> any Item) -> Behavior {
        Behavior.contextRead(name, observes: [.int, .binding], tags: [.fallible],
                             produces: .results([stack])) { _, context in
            guard let key = context.items(of: .int).first as? IntItem else {
                return [refMissing(name, on: .int, context.recording)]
            }
            let keys = context.items(of: .binding).compactMap { ($0 as? BindingItem)?.key }
            return [Router(stack, answer(key.value, keys).observed(by: name, context.recording))]
        }
    }

    static let bindingContainsKey_Behavior = keyQuery(.bindingContainsKey, gives: .bool) { key, keys in
        BoolItem(keys.contains(key))
    }
        .described("Pushes whether key k is bound, leaving k.")

    static let bindingOccurrencesOfKey_Behavior = keyQuery(.bindingOccurrencesOfKey, gives: .int) { key, keys in
        IntItem(keys.count { $0 == key })
    }
        .described(
            "Pushes how many bindings key k has, the shadowed ones included, leaving k; 0 when it is unbound.")

    /// Reverse lookup: the key of the topmost binding whose value is the block on
    /// top of `.code` (read), or the one item that block holds.
    static let bindingKeyOf_Behavior =
        Behavior.contextRead(.bindingKeyOf, observes: [.code, .binding], tags: [.fallible],
                             produces: .results([.int])) { _, context in
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
}
