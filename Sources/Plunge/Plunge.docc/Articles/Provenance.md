# Provenance and the Crux

Ask any item how it was made, and get back a short program that makes it again.

## Overview

A program found by search is usually long, and most of it does nothing useful.
With provenance recording on, every item the interpreter computes remembers the
arguments and the instruction that made it, so you can see which parts of a
program its answer actually depends on. That history, written out as a program,
is the item's **crux**.

```
.input0 10 .intAdd 99 .input0 .intMultiply      with input0 = 4  →  .int holds 396 14
crux of 396:  ( 99 .input0 .intMultiply )
```

The program's first three items computed 14 and left it on the stack; the answer
never used it, so the crux leaves it out. Running a crux on a new interpreter,
with the same inputs and constants, puts exactly that item on its stack and
nothing anywhere else.

A crux is not a trace of what ran. It records only what is needed to rebuild
one item, which is why it is short, and why it can be run again as an ordinary
program.

## What a crux is for

- **Explaining a result.** The crux of an answer is the part of the program
  that produced it, with everything irrelevant removed.
- **Checking that an answer used its inputs.** A program can score well on a
  few training cases by pushing a constant. If the crux of its answer never
  mentions an input, the answer can't depend on one.
- **Reusing what worked.** A crux is working code for one value, which a search
  can keep and build on.

## Turning it on

Recording is off by default, because it costs time and memory, and nothing a
program computes depends on it. Turn it on for an evaluation:

```swift
var settings = InterpreterSettings()
settings.recordsProvenance = true
let runner = Runner(configuration: RunnerConfiguration(settings: settings, recorders: [
    RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
]))
```

Then ask a recorded item for its crux with ``Item/crux()``, which returns the
program as an array of items:

```swift
if case .items(let answers)? = result.traces["answer"], let answer = answers.last ?? nil {
    print(CodeItem(answer.item.crux()).pretty())   // ( 99 .input0 .intMultiply )
}
```

A typical use is to run a search without recording, then evaluate the best
programs again with it on, to see what they do. Recording never changes what a
program computes, so the second evaluation gives the same answers as the first.

Setting ``RunnerConfiguration/cruxInputTokens`` also turns recording on, and has
each ``CaseResult`` report whether each recorder's final item depends on the
given inputs (``CaseResult/cruxMentionsInput``). The check is made where the
run happens, so you get the yes or no without keeping the items. A program
whose answer ignores its inputs is a cheap thing to detect and discard.

## What a crux records

- **Computed values** record their arguments and their instruction, so their
  crux rebuilds them from the cruxes of their arguments.
- **Copies and moves** record nothing: `.intDup` pushes the same item again, so
  both copies have the original's crux. A crux that uses a value twice builds it
  once and duplicates it.
- **Elements** taken out of a collection record where they were, as `v 2
  .vecIntNth`, unless they kept a history of their own from before they went in.
- **Queries** leave their arguments in place, so their crux cleans up after
  itself: the crux of the bool from `a b .intGT` removes `a` and `b` again,
  leaving only the answer.
- **Inputs and constants** are recorded by name. They come from outside the run
  and are the same whenever the same pairing is evaluated, so naming them is
  enough to get them back.

## Stand-ins

Some values can't be rebuilt by running again what made them. A stack's depth,
the step count and a fresh binding key depend on the state of the run, not on
any argument. For these the crux holds a **stand-in** (``StandInItem``): a
literal that runs as the value it replaces and says why it is there. It prints
as, for example, `.intStackDepth_actuallyWas_4`. A stand-in records one of three
reasons:

- **observed**: read from the state of the run;
- **minted**: a value the instruction supplies itself, such as the 0 a counted
  loop starts from;
- **elided**: a history too large to keep (over
  ``InterpreterSettings/maxCallWeight`` or
  ``InterpreterSettings/maxCallDepth``), replaced by the value it produced.

A crux therefore always runs, and every literal in it that the program didn't
contain is marked. The marks matter: without them, a number the run happened to
observe would look the same as a number the program was written with, and
nobody could tell how much of a result was really derived.

## Long histories

A loop that adds 1 a thousand times would leave a crux a thousand steps long.
The interpreter keeps such histories compact: shared parts are built once, and
repeated steps fold into a counted loop. ``CruxCompression`` does the same to
any crux you hand it.

## Running a crux

A crux is a program, so run it as one: make it the program of an
``Individual`` and evaluate it against the same training case, with the same
constants. Two settings need thought. Use
``InterpreterSettings/reconstructing``, which relaxes the size limits for this
job, and give the run enough steps: ``CruxCompression/replaySteps(_:)``
estimates how many a crux needs. See <doc:LimitsAndGuards>.

## Keeping histories

``AnyItem``, the `Codable` wrapper the ``Runner`` uses for results, keeps an
item's value and drops its history. To send or save items with their histories
intact, encode them as an ``ItemArchive``:

```swift
let data = try JSONEncoder().encode(ItemArchive([answer.item]))
let restored = try JSONDecoder().decode(ItemArchive.self, from: data).items
// restored[0].crux() is the crux the original had
```

## See Also

- <doc:ObservingARun>
- <doc:LimitsAndGuards>
- ``StandInItem``
- ``CruxCompression``
- ``ItemArchive``
