# Map and reduce from a crux-function

**BUILT 2026-11-09** (*Behavior coverage audit* P2, §11 step 3): `vecXMap`, `vecXFilter`, `vecXReduce`
and the `string` forms, in *Function Behaviors.swift*. Changed from this plan by later rulings: the result
type follows the data (the last value the function pushed; I17), an element with no result passes through
(I4), reduce folds from the first element with no seed, sub-run steps are charged to the run, and sub-runs
use the language's default limits. The plan below is kept as written.

*Design note. Written 2026-07-19, recording an approved-but-unstarted plan. The exploration behind it
is the crux-to-function diagnostic (`Tests/…/Acceptance Tests (Slow)/CruxToFunction Diagnostics.swift`,
committed `5f349b8`) plus the "map / filter — the pseudofunction work" line in `Roadmap.md` §A.2. Nothing
here is built yet; we are waiting to proceed. It is written down because it is a good plan and the argument
should not have to be reconstructed.*

## What this is for

The whole provenance apparatus — `call`, the crux, the round-trip obligation — exists so that an evolved
program can be *read*: given a value that turned `.input` arguments into something useful, recover a
runnable program that says how (`Provenance and the crux.md`). Once you can recover that program, the
obvious next move is to **reuse it as a subroutine**. Take the crux of a value, turn it into a function of
one argument, and apply that function to every element of a vector. That is map. Prime an accumulator and
apply a two-argument version left-to-right, and that is reduce.

This note is the concrete design for that reuse. It answers two questions the diagnostic left standing:
*what exactly is a "function" here*, and *what Behavior applies one to a vector without inventing new
machinery*.

## What a function is, and how the crux makes one

There is **no `.function` type**. A function is just a `CodeItem` whose holes are `.inputN` tokens — the
same tokens the interpreter already resolves against its `inputs` environment. `.code` is the function
stack; a function is an ordinary value living on it, and it is *run* by loading its `.value` into an
interpreter, exactly as any block runs.

The crux-to-function diagnostic (D3) established how to *build* one from a resolved value's crux, and which
construction is faithful:

- **Substituting** one int-source leaf of the crux with an `.inputN` token gives the **faithful curry**:
  the argument is read at the hole's own position in the computation, so `f(x)` reproduces the original
  value when `x` is the original leaf. This is the construction map/reduce assume.
- **Deleting** a leaf instead is ~100% runnable but gives a *repositioned* function — it reads the argument
  from wherever the stack happens to present it, not from the leaf's slot. Runnable, but not the subroutine
  you meant.
- Functionhood depends on the chosen leaf **propagating** to the result, not on crux size: even at 25
  nodes, a propagating arithmetic crux stays ~97% sensitive to its hole. Masking (a leaf whose value never
  reaches the output), not size, is the limiter.
- Crucially, **`.inputN` needs no surgery** — the input *is* the hole. A crux harvested straight off a
  `(int,int)->int` value already carries `.inputN` tokens wherever an input fed it (D3), so it is already a
  function of those inputs with nothing further to do.

That last point is the hinge of this whole design. Because a harvested/substituted function keeps its
`.inputN` tokens, applying it to an element is a matter of **rebinding those inputs** — no rewrite of the
body to read a stack, no conversion step. Contrast the stack-fed route below, which needs a body written to
read the stack and so *cannot* consume a harvested function directly.

## The critical decision: one Behavior, no iterator

The tempting shape is an iterator with an accumulator field — "walk the vector, run the body each pass,
gather what it leaves." **That is the wrong model, and getting it wrong was the category error this
revision corrects.**

Design Principles §4 draws the line: *the metered unit is items **produced**, not work **done***. An
iterator exists solely to meter the production of *multiple* items across passes, so that the runaway guard
has something to count. But:

- **Map produces one vector. Reduce produces one scalar.** One item each.
- The per-element sub-runs are *work*, not produced items. They are bounded by the vector's length
  (`maxVectorLength`, §11) and they evaporate when the step ends.
- The direct precedent is **`.codeFromIterator`**, which "collects up to a thousand values in a single
  step… because it produces one Item." Map/reduce are the same transaction: a single, synchronous Behavior
  action, like `stringContains` or `vecXSubVec`.

So there is **no `IteratorItem` anywhere in this path**, and `.iterator` stays empty across a map or
reduce. There is no step-budget-across-passes concern and nothing to hand to the runaway guard at the
map/reduce level — each sub-run self-governs under its *own* `stepLimit` and runaway guard, "like any other
loop, with no special pleading" (§4). This is not a metered loop; it is one computation that happens to do
a bounded amount of internal work.

## The mechanic

`BehaviorWithSideEffects` is the base, because the Behavior needs the live interpreter to (a) inherit the
parent's `constants`/`inputs`, so the function's *other* holes still resolve, and (b) run the body. Per
element, a fresh sub-`Interpreter` gives clean isolation: "temporarily redirect `.inputN` to this element"
needs no save/restore, because the parent environment is never touched.

One shared helper does the per-element apply:

```swift
// Run f in an isolated sub-interpreter with `bindings` layered over the parent
// environment; return the top of `resultStack`, or nil if it produced nothing.
func applyFunction(_ f: CodeItem, binding bindings: [PushInstruction: any Item],
                   over parent: Interpreter, resultStack: PushStack) -> (any Item)? {
    let sub = Interpreter()
    sub.constants = parent.constants          // inherit environment…
    sub.inputs    = parent.inputs             // …
    for (slot, value) in bindings { sub.inputs[slot] = value }   // …then redirect the parameter(s)
    sub.load(program: f.value)
    sub.run()                                 // self-governed by the sub's own stepLimit + runaway guard
    return sub.stacks[resultStack]!.first
}
```

Total work is bounded (vector length × each sub-run's own budget); one item comes out.

## Map — worked, then coded

Take `f(x) = 2x + 1`, built by substituting one leaf of a crux with `.input0`:
`f = ( .input0 .int2 .intMultiply .int1 .intAdd )`, parameter `.input0`. Over `v = [10, 20, 30]`:

```
e=10 → .input0=10 → 21 ;  e=20 → 41 ;  e=30 → 61   ⇒  push VecIntItem([21,41,61]) to .vecInt
```

```swift
// takes: [.vecInt, .code]  (vector, function)
BehaviorWithSideEffects(.vecIntMap, takes: [.vecInt, .code]) { interp, args in
    let (vec, f) = (args[0] as! VecIntItem, args[1] as! CodeItem)
    var out = [Int]()
    for e in vec.value {
        if let r = applyFunction(f, binding: [.input0: IntItem(e)], over: interp, resultStack: .int)
             as? IntItem { out.append(r.value) }          // no-result policy: skip (see below)
    }
    return [Router(.vecInt, VecIntItem(out, call: [vec, f, InstructionItem(.vecIntMap)]))]
}
```

## Reduce — the sibling

A fold wants a two-parameter function: `.input0` = accumulator, `.input1` = element. `g(acc,e) = acc + e`
is `( .input0 .input1 .intAdd )`. `takes: [.vecInt, .code, .int]` (vector, function, init). Over
`[10,20,30]` with init `0`: `0→10→30→60` ⇒ push `IntItem(60)`.

```swift
BehaviorWithSideEffects(.vecIntReduce, takes: [.vecInt, .code, .int]) { interp, args in
    let (vec, g, seed) = (args[0] as! VecIntItem, args[1] as! CodeItem, args[2] as! IntItem)
    var acc = seed.value
    for e in vec.value {
        if let r = applyFunction(g, binding: [.input0: IntItem(acc), .input1: IntItem(e)],
                                 over: interp, resultStack: .int) as? IntItem { acc = r.value }
    }
    return [Router(.int, IntItem(acc, call: [vec, g, seed, InstructionItem(.vecIntReduce)]))]
}
```

Note reduce **already half-exists** by another route (diagnostic D4): drop a binary-op body and a primed
accumulator into `vecXIterate` and the fold falls out with no new machinery — but *only* for a body written
to read the stack. The value of the input-fed reduce here is that it consumes a **harvested/substituted
crux directly**, `.inputN` holes and all. Two mechanisms for two function shapes:

- **Stack-fed (D4, already works):** the element sits on the stack, a *stack-reading* body (`( .intAdd )`)
  consumes it under `vecXIterate`. Zero new machinery — but the body must read the stack.
- **Input-fed (this plan):** the function keeps its `.inputN` holes and the Behavior rebinds them per
  element. This is what makes a harvested crux usable directly — the payoff of the crux-to-function work.

## Design decisions (recommended; revisit at implementation)

- **No iterator; one Behavior action.** §4; `.codeFromIterator` is the precedent. The earlier
  "step-budget across passes / evades the runaway guard" framing was the category error being corrected.
- **Fixed parameter slots.** Map feeds `.input0`; reduce feeds `.input0` (accumulator) + `.input1`
  (element). Simplest, needs no extra argument, and it matches construction — you substitute the chosen
  leaf with `.input0`. *Deferred alternative:* an explicit `.int` argument naming the slot.
- **Result type fixed per instruction to start** (`vecIntMap` → `.vecInt`; the function must return `.int`,
  read off `.int`). *Powerful follow-on, deferred:* make it **polymorphic** — the result vector's type is
  whichever stack the sub-run left its result on, exactly as `.vecFromIterator`'s "result type is its
  argument's." One polymorphic map would close the N² element-wise/cross-type conversion grid
  (`vecInt→vecDouble`, predicate→`vecBool`, …). Deferred only because it needs a rule for *which* stack the
  function returned on, and what to do with zero or multiple results.
- **No-result policy.** A sub-run that leaves nothing on the result stack (the function errored or starved
  for that element): map **skips** it (output shorter than input) for a first cut — flag for review against
  a sentinel-substitution alternative; reduce keeps the prior accumulator.
- **Provenance is simple.** Map/reduce record `[vec, function, (init,) .vecXMap/Reduce]`; re-running the
  instruction with the same arguments reproduces the result, under the same-environment assumption that
  `constants`/`inputs` already rely on. No per-element crux threading — the function *is* an argument.
- **One generic factory per operation, instantiated per vector type**, following the existing
  `iterateBehavior<V: VectorItem>` / `pushAllBehavior<V: VectorItem>` pattern (`Vector Behaviors.swift`).
  Build `vecIntMap`/`vecIntReduce` first as the concrete proof; the factory then yields the bool / double /
  string siblings for free.

## Where it touches down

- `Instruction Infrastructure.swift` — new enum cases (`vecIntMap`, `vecIntReduce`, then the per-type
  siblings once the factory is in).
- `Behaviors/Vector Behaviors.swift` — the `applyFunction` helper and the `mapBehavior<V>` /
  `reduceBehavior<V>` generic factories + registry entries, beside `iterateBehavior`.
- `Behavior Infrastructure.swift` — reuse `BehaviorWithSideEffects`, no change.
- Reuse: `Interpreter.load` + `run()` for the sub-eval; `VecIntItem(_:call:)` for the result; the
  constant/input environment-inheritance idiom.

## How to know it works

- Unit tests: the two worked examples (map `[10,20,30]` with `2x+1` → `[21,41,61]`; reduce sum from `0` →
  `60`), plus empty vector (map → empty; reduce → init unchanged), a function that starves on some elements
  (exercise the no-result policy), and a reduce whose function ignores the accumulator (degrades to "last
  element").
- Provenance: `result.crux()` round-trips — rebuild `vec` and `f`, re-run the instruction, same result —
  under a fixed `constants`/`inputs` environment. Enroll in the crux round-trip sweep.
- **The §4 check:** confirm **no `IteratorItem`** is constructed anywhere in the path and `.iterator` stays
  empty across a map/reduce. This is the proof that it is a single-item computation, not a metered loop.

## Relation to the rest of the roadmap

This is the concrete design for `Roadmap.md` §A.2 ("map / filter — the pseudofunction work"). It leans on
the crux-to-function payoff tracked as §E.23 (`codeFuncFrom_Crux`) and inherits that line's dependency on
§E.21 (vector elements have no provenance of their own) only for the *harvest-from-a-vector-element* case —
map/reduce themselves take an already-built function as an argument and do not need to crack a vector
element open, so they are not blocked by §21. When built, strike §A.2 and fold the verdict back here.
