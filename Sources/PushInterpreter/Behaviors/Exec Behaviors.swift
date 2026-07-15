//
//  Exec Behaviors.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/2/26.
//

import DequeModule

nonisolated extension Interpreter {

    // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L335-L343
    //  "`:exec-do*while` pops the top of the `:exec` stack. It builds and pushes a continuation to the `:exec` stack which is `'([item] :exec-while [item])` (_Note_ the instruction is `:exec-while` in the continuation form)."
    static let execDoWhile_Behavior =
        Behavior(
            .execDoWhile,
            takes: [.bool, .exec],
            // Provenance: every result here is combinatory. The body copies are
            // duplications of `y` that stay on `.exec` (law 1), and the
            // `.execWhile` token is freshly minted (law 4). Nothing is derived,
            // so nothing records a `call`.
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1])

                var yCopy = y
                yCopy.isContingent = x.isContingent

                var results = [Router(.exec, yCopy)]

                if x.value {
                    results.append(
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile,
                                isContingent: x.isContingent
                            )
                        )
                    )
                    var yCopy2 = y
                    yCopy2.isContingent = Behavior.netContingency(of:x,y)

                    results.append(Router(.exec, yCopy2))
                }
                return results
            }
        )

    // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L13-L32
    //

    static let execDoCount_Behavior =
        Behavior(
            .execDoCount,
            takes: [.int, .exec],
            // Provenance: all combinatory. `y` and `x` pass through to `.exec`
            // unchanged (law 1 — the round trip back to `.int` via pushDefault
            // is transit, not relocation), and the `.execDoRange` token is
            // freshly minted (law 4). `newEndPoint` is the literal 0 whatever
            // the arguments were, so it is its own crux and records nothing.
            fxn: { a in
                let (x, y) = (a[0] as! IntItem, a[1])

                var results = [Router]()
                let counter = x.value

                if counter < 1 {
                    results = [
                        Router(.exec, y),
                        Router(.exec, x),
                    ]
                } else {
                    var newInstruction = InstructionItem(.execDoRange)
                    newInstruction.isContingent = Behavior.netContingency(
                        of: x,
                        y
                    )

                    var newEndPoint = IntItem(0)
                    newEndPoint.isContingent = Behavior.netContingency(of: x)

                    results = [
                        Router(.exec, y),
                        Router(.exec, newInstruction),
                        Router(.exec, x),
                        Router(.exec, newEndPoint),
                    ]
                }
                return results
            }
        )

    //        // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L183-L203
    static let execDoTimes_Behavior =
        Behavior(
            .execDoTimes,
            takes: [.int, .exec],
            // Provenance: the body copies and the re-pushed `.execDoTimes` token
            // are combinatory (laws 1 and 4) and record nothing. `newCounter` is
            // the one derived value, and it folds — see IteratorItem.
            fxn: { a in
                let (intArg, execArg) = (a[0], a[1])
                let counter = (intArg as! IntItem).value
                var yCopy = execArg
                yCopy.isContingent = Behavior.netContingency(of: intArg, execArg)

                var results = [Router]()

                if counter < 1 {
                    results = [Router(.exec, yCopy)]
                } else {
                    var newCounter = IntItem(counter - 1)
                    newCounter.isContingent =
                        Behavior.netContingency(of: intArg, execArg)
                    newCounter.call =
                        IteratorItem.steppedCall(from: intArg, by: -1)

                    var newInstruction = InstructionItem(.execDoTimes)
                    newInstruction.isContingent =
                        Behavior.netContingency( of: intArg, execArg )

                    // Was a single CodeItem pushed to `.exec` and unwrapped
                    // there; emitted as explicit Routers so the co-arity of 4 is
                    // visible rather than hidden inside a block. The order is
                    // the reverse of the block's contents, because `distribute`
                    // prepends each Router in turn where unwrapping prepended
                    // them as one run.
                    results = [
                        Router(.exec, yCopy),
                        Router(.exec, newInstruction),
                        Router(.exec, newCounter),
                        Router(.exec, execArg),
                    ]
                }
                return results
            }
        )

    //        // using my own code as an example from: https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L83-L112
    static let execDoRange_Behavior =
        Behavior(
            .execDoRange,
            takes: [.int, .int, .exec],
            // Provenance: the body copies (`zCopy`, `z`), the re-pushed
            // `.execDoRange` token, and the passed-through bounds (`x`, `y`) are
            // all combinatory — laws 1 and 4 — and record nothing. `newCounter`
            // is the sole derived value.
            //
            // This is where `.call` used to blow up: `newCounter` recorded
            // `[y, x, .execDoRange]` where `y` is the PREVIOUS counter, so the
            // chain deepened once per iteration — and `y x .execDoRange` does
            // not produce `y+1` in any case. It now folds to one node.
            fxn: { a in
                let (x, y, z) = (a[0], a[1], a[2])
                let end = (x as! IntItem).value
                let start = (y as! IntItem).value
                var zCopy = z
                zCopy.isContingent = Behavior.netContingency(of: x, y)

                var results = [Router]()

                // start - end can overflow, and abs traps on Int.min; when the
                // subtraction overflows the two are far apart (not the base case)
                let (difference, tooFarApart) = start.subtractingReportingOverflow(end)
                if !tooFarApart && difference.magnitude <= 1 {
                    results = [Router(.exec, zCopy), Router(.exec, y)]
                } else {
                    let direction = start < end ? 1 : -1
                    var newCounter = IntItem(start + direction)
                    newCounter.isContingent = Behavior.netContingency(
                        of: x,
                        y
                    )
                    newCounter.call =
                        IteratorItem.steppedCall(from: y, by: direction)

                    var newInstruction = InstructionItem(.execDoRange)
                    newInstruction.isContingent = Behavior.netContingency(
                        of: x,
                        y
                    )

                    results = [
                        Router(.exec, zCopy),
                        Router(.exec, newInstruction),
                        Router(.exec, x),
                        Router(.exec, newCounter),
                        Router(.exec, z),
                        Router(.exec, y),
                    ]
                }
                return results
            }
        )

    static let execIf_Behavior =
        Behavior(
            .execIf,
            takes: [.bool, .exec, .exec],
            // Provenance: selecting one of two `.exec` items and discarding the
            // other leaves the survivor exactly where it was, so this is a pure
            // combinator (law 1) and records nothing. The branch not taken
            // simply never contributes to anything's crux.
            fxn: { a in
                let (x, y, z) = (a[0] as! BoolItem, a[1], a[2])
                var result = x.value ? y : z
                result.isContingent = x.isContingent
                return [Router(.exec, result)]
            }
        )

    static let execK_Behavior =
        Behavior(
            .execK,
            takes: [.exec, .exec],
            // The K combinator: keep the first, discard the second. Law 1.
            fxn: { a in
                let x = a[0]
                return [
                    Router(.exec, x)
                ]
            }
        )

    static let execY_Behavior =
        Behavior(
            .execY,
            takes: [.exec],
            // Law 1 throughout: `x` is duplicated and the `.execY` token is
            // freshly minted.
            //
            // The continuation was one CodeItem pushed to `.exec` and unwrapped
            // there; it is emitted as explicit Routers so its co-arity is
            // visible. Routers are prepended one at a time, so their order is
            // the reverse of the resulting stack, top last.
            fxn: { a in
                let x = a[0]
                return [
                    Router(.exec, x),
                    Router(.exec, InstructionItem(.execY)),
                    Router(.exec, x),
                ]
            }
        )

    static let execS_Behavior =
        Behavior(
            .execS,
            takes: [.exec, .exec, .exec],
            // The S combinator: `S x y z` → `x z (y z)`. Pure rearrangement of
            // `.exec` items, so law 1 — nothing is recorded.
            //
            // The `(y z)` continuation was a CodeItem pushed to `.exec`; it is
            // emitted as explicit Routers instead. Unwrapping used to OR the
            // block's contingency onto its children, which is why the two copies
            // carry the net contingency of all three arguments.
            fxn: { a in
                let (x, y, z) = (a[0], a[1], a[2])

                var yCopy = y
                yCopy.isContingent = Behavior.netContingency(of: x, y, z)
                var zCopy = z
                zCopy.isContingent = Behavior.netContingency(of: x, y, z)

                return [
                    Router(.exec, zCopy),
                    Router(.exec, yCopy),
                    Router(.exec, z),
                    Router(.exec, x),
                ]
            }
        )

    static let execWhen_Behavior =
        Behavior(
            .execWhen,
            takes: [.bool, .exec],
            // Law 1: `y` passes through to `.exec` untouched when the guard holds.
            fxn: { a in
                var (x, y) = (a[0] as! BoolItem, a[1])
                var results = [Router]()

                if x.value {
                    y.isContingent = Behavior.netContingency(of: x, y)
                    results.append(
                        Router(.exec, y)
                    )
                }
                return results
            }
        )

    static let execWhile_Behavior =
        Behavior(
            .execWhile,
            takes: [.bool, .exec],
            // Provenance: as `execDoWhile` — body copies (law 1) and a freshly
            // minted continuation token (law 4). Nothing is derived.
            fxn: { a in
                let (x, y) = (a[0] as! BoolItem, a[1])

                var results = [Router]()

                if x.value {
                    var yCopy = y
                    yCopy.isContingent = x.isContingent
                    results.append(Router(.exec, yCopy))

                    results.append(
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile,
                                isContingent: x.isContingent
                            )
                        )
                    )

                    var yCopy2 = y
                    yCopy2.isContingent = x.isContingent

                    results.append(Router(.exec, yCopy2))
                }
                return results
            }
        )

    static let execBehaviors:[PushInstruction : Behavior] =
    [
        .execDoCount : execDoCount_Behavior,
        .execDoRange : execDoRange_Behavior,
        .execDoTimes : execDoTimes_Behavior,
        .execDoWhile : execDoWhile_Behavior,
        .execIf : execIf_Behavior,
        .execK : execK_Behavior,
        .execS : execS_Behavior,
        .execWhen : execWhen_Behavior,
        .execWhile : execWhile_Behavior,
        .execY : execY_Behavior,
    ]
}
