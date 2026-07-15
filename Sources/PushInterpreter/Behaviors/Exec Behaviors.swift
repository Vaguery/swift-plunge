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
            takes: [.bool, .code],
            // Provenance: every result here is combinatory. The body copies are
            // duplications of the block (law 1b — containment leaves no mark),
            // and the `.execWhile` and `.codeDo` tokens are freshly minted
            // (law 4). Nothing is derived, so nothing records a `call`.
            fxn: { a in
                let (x, body) = (a[0] as! BoolItem, a[1])

                var bodyCopy = body
                bodyCopy.isContingent = x.isContingent

                // Always runs the body at least once — `.exec` top→bottom is
                // body, .codeDo.
                var results = [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, bodyCopy),
                ]

                if x.value {
                    // …then re-supplies the body to `.code` and hands off to
                    // `.execWhile`, which consults the next BOOL.
                    var yCopy2 = body
                    yCopy2.isContingent = Behavior.netContingency(of:x,body)

                    results.insert(
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile,
                                isContingent: x.isContingent
                            )
                        ),
                        at: 0
                    )
                    results.insert(Router(.exec, yCopy2), at: 1)
                }
                return results
            }
        )

    // based on https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L13-L32
    //

    static let execDoCount_Behavior =
        Behavior(
            .execDoCount,
            takes: [.int, .code],
            // Provenance: all combinatory. `body` and `x` pass through unchanged
            // (law 1 — the round trip via `.exec` to reach `.code`/`.int` is
            // transit, not relocation), and the `.execDoRange` token is freshly
            // minted (law 4). `newEndPoint` is the literal 0 whatever the
            // arguments were, so it is its own crux and records nothing.
            fxn: { a in
                let (x, body) = (a[0] as! IntItem, a[1])

                var results = [Router]()
                let counter = x.value

                if counter < 1 {
                    // Both arguments are returned to where they came from.
                    results = [
                        Router(.code, body),
                        Router(.exec, x),
                    ]
                } else {
                    var newInstruction = InstructionItem(.execDoRange)
                    newInstruction.isContingent = Behavior.netContingency(
                        of: x,
                        body
                    )

                    var newEndPoint = IntItem(0)
                    newEndPoint.isContingent = Behavior.netContingency(of: x)

                    // Rewrites to `0 count body .execDoRange`, `.exec` top→bottom.
                    // The body must reach `.code` *before* `.execDoRange` fires,
                    // so it now precedes the token rather than following it.
                    results = [
                        Router(.exec, newInstruction),
                        Router(.exec, body),
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
            takes: [.int, .code],
            // Provenance: the body copies and the re-pushed `.execDoTimes` and
            // `.codeDo` tokens are combinatory (laws 1 and 4) and record nothing.
            // `newCounter` is the one derived value, and it folds — see
            // IteratorItem.
            fxn: { a in
                let (intArg, body) = (a[0], a[1])
                let counter = (intArg as! IntItem).value
                var bodyCopy = body
                bodyCopy.isContingent = Behavior.netContingency(of: intArg, body)

                var results = [Router]()

                if counter < 1 {
                    // No iteration: the body is returned to where it came from,
                    // which is now `.code`. It stays data rather than running,
                    // which is the whole point of the change.
                    results = [Router(.code, bodyCopy)]
                } else {
                    var newCounter = IntItem(counter - 1)
                    newCounter.isContingent =
                        Behavior.netContingency(of: intArg, body)
                    newCounter.call =
                        IteratorItem.steppedCall(from: intArg, by: -1)

                    var newInstruction = InstructionItem(.execDoTimes)
                    newInstruction.isContingent =
                        Behavior.netContingency( of: intArg, body )

                    // The continuation, `.exec` top→bottom:
                    //
                    //   body      lands on .code
                    //   .codeDo   pops it back off and spreads it → runs it
                    //   counter-1 lands on .int
                    //   body      lands on .code, re-supplying it for next pass
                    //   .execDoTimes  takes .int + .code — both now waiting
                    //
                    // Both halves fall out of the new rule rather than needing
                    // machinery: pushing a CodeItem to `.exec` re-supplies `.code`,
                    // and `[body, .codeDo]` runs it. Routers are listed in reverse
                    // because `distribute` prepends each in turn.
                    results = [
                        Router(.exec, newInstruction),
                        Router(.exec, bodyCopy),
                        Router(.exec, newCounter),
                        Router(.exec, InstructionItem(.codeDo)),
                        Router(.exec, bodyCopy),
                    ]
                }
                return results
            }
        )

    //        // using my own code as an example from: https://github.com/Vaguery/klapaucius/blob/17b55eb76feaa520a85d4df93597cccffe6bdba4/src/push/type/module/exec.clj#L83-L112
    static let execDoRange_Behavior =
        Behavior(
            .execDoRange,
            takes: [.int, .int, .code],
            // Provenance: the body copies, the re-pushed `.execDoRange` and
            // `.codeDo` tokens, and the passed-through bounds (`x`, `y`) are all
            // combinatory — laws 1 and 4 — and record nothing. `newCounter` is
            // the sole derived value.
            //
            // This is where `.call` used to blow up: `newCounter` recorded
            // `[y, x, .execDoRange]` where `y` is the PREVIOUS counter, so the
            // chain deepened once per iteration — and `y x .execDoRange` does
            // not produce `y+1` in any case. It now folds to one node.
            fxn: { a in
                let (x, y, body) = (a[0], a[1], a[2])
                let end = (x as! IntItem).value
                let start = (y as! IntItem).value
                var bodyCopy = body
                bodyCopy.isContingent = Behavior.netContingency(of: x, y)

                var results = [Router]()

                // start - end can overflow, and abs traps on Int.min; when the
                // subtraction overflows the two are far apart (not the base case)
                let (difference, tooFarApart) = start.subtractingReportingOverflow(end)
                if !tooFarApart && difference.magnitude <= 1 {
                    // Last pass: leave the index on `.int` and run the body once.
                    // `.exec` top→bottom: y, body, .codeDo
                    results = [
                        Router(.exec, InstructionItem(.codeDo)),
                        Router(.exec, bodyCopy),
                        Router(.exec, y),
                    ]
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

                    // `.exec` top→bottom:
                    //   y           the loop index, onto .int for the body to read
                    //   body        lands on .code
                    //   .codeDo     spreads it → this pass's body runs
                    //   newCounter  onto .int — the next start
                    //   x           onto .int — the end, so .int reads (end, start)
                    //   body        lands on .code, re-supplying it
                    //   .execDoRange
                    results = [
                        Router(.exec, newInstruction),
                        Router(.exec, bodyCopy),
                        Router(.exec, x),
                        Router(.exec, newCounter),
                        Router(.exec, InstructionItem(.codeDo)),
                        Router(.exec, bodyCopy),
                        Router(.exec, y),
                    ]
                }
                return results
            }
        )

    static let execIf_Behavior =
        Behavior(
            .execIf,
            takes: [.bool, .code, .code],
            // Provenance: selecting one of two blocks and discarding the other
            // changes no value, so this is a pure combinator (law 1) and records
            // nothing. The branch not taken simply never contributes to
            // anything's crux.
            //
            // The chosen block RUNS — `.exec` top→bottom is chosen, .codeDo.
            // Selecting a block *without* running it is what the `.code`
            // combinators are for.
            fxn: { a in
                // Argument order reverses when a code argument moves from `.exec`
                // to `.code`: `.exec` was read forward from the program, but
                // `.code` is a stack, so the LAST-written block is on top and
                // arrives as a[1]. The rest of the language reads postfix
                // arguments first-written-first (`2 3 .intSubtract` is 2-3, with
                // the 2 at a[1]), so `( then ) ( else ) .execIf` keeps that:
                // a[2] is `then`.
                let (x, elseBlock, thenBlock) = (a[0] as! BoolItem, a[1], a[2])
                var result = x.value ? thenBlock : elseBlock
                result.isContingent = x.isContingent
                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, result),
                ]
            }
        )

    static let execK_Behavior =
        Behavior(
            .execK,
            takes: [.code, .code],
            // The K combinator: keep the first, discard the second. Law 1 — no
            // value changes. The kept block runs, as it did when it was handed
            // back to `.exec`.
            fxn: { a in
                // `K x y = x` keeps the first-written block, which off `.code`
                // arrives as a[1] — see the note on `execIf` about the order
                // reversing with the move from `.exec`.
                let x = a[1]
                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, x),
                ]
            }
        )

    static let execY_Behavior =
        Behavior(
            .execY,
            takes: [.code],
            // Law 1 throughout: the block is duplicated and the `.execY` and
            // `.codeDo` tokens are freshly minted.
            //
            // `.exec` top→bottom: x, .codeDo, x, .execY — run the body, then
            // re-supply it to `.code` and recur. Routers are prepended one at a
            // time, so their order is the reverse of the resulting stack.
            fxn: { a in
                let x = a[0]
                return [
                    Router(.exec, InstructionItem(.execY)),
                    Router(.exec, x),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, x),
                ]
            }
        )

    static let execS_Behavior =
        Behavior(
            .execS,
            takes: [.code, .code, .code],
            // The S combinator: `S x y z` → `x z (y z)`. Pure rearrangement, so
            // law 1 — nothing is recorded.
            //
            // Each of the four runs needs its own `.codeDo`, since `.exec`
            // top→bottom is x, z, y, z and every one of them is a block. The
            // `(y z)` grouping flattens harmlessly: `.exec` is flat, so `x z (y z)`
            // and `x z y z` execute identically. The copies carry the net
            // contingency of all three arguments, as they did when unwrapping
            // spread the wrapper's contingency onto its children.
            fxn: { a in
                // Written `x y z .execS`, so off `.code` the top is z — see the
                // note on `execIf` about the order reversing with the move from
                // `.exec`.
                let (x, y, z) = (a[2], a[1], a[0])

                var yCopy = y
                yCopy.isContingent = Behavior.netContingency(of: x, y, z)
                var zCopy = z
                zCopy.isContingent = Behavior.netContingency(of: x, y, z)

                return [
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, zCopy),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, yCopy),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, z),
                    Router(.exec, InstructionItem(.codeDo)),
                    Router(.exec, x),
                ]
            }
        )

    static let execWhen_Behavior =
        Behavior(
            .execWhen,
            takes: [.bool, .code],
            // Law 1: the block passes through untouched when the guard holds,
            // and runs. When it does not hold, it is discarded.
            fxn: { a in
                var (x, body) = (a[0] as! BoolItem, a[1])
                var results = [Router]()

                if x.value {
                    body.isContingent = Behavior.netContingency(of: x, body)
                    results = [
                        Router(.exec, InstructionItem(.codeDo)),
                        Router(.exec, body),
                    ]
                }
                return results
            }
        )

    static let execWhile_Behavior =
        Behavior(
            .execWhile,
            takes: [.bool, .code],
            // Provenance: as `execDoWhile` — body copies (laws 1 and 1b) and
            // freshly minted continuation tokens (law 4). Nothing is derived.
            //
            // On a true guard, `.exec` top→bottom is body, .codeDo, body,
            // .execWhile: run the body, re-supply it to `.code`, and re-test the
            // next BOOL. A false guard consumes both and stops.
            fxn: { a in
                let (x, body) = (a[0] as! BoolItem, a[1])

                var results = [Router]()

                if x.value {
                    var bodyCopy = body
                    bodyCopy.isContingent = x.isContingent

                    var yCopy2 = body
                    yCopy2.isContingent = x.isContingent

                    results = [
                        Router(
                            .exec,
                            InstructionItem(
                                .execWhile,
                                isContingent: x.isContingent
                            )
                        ),
                        Router(.exec, yCopy2),
                        Router(.exec, InstructionItem(.codeDo)),
                        Router(.exec, bodyCopy),
                    ]
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
