# Provenance and the Crux

Ask any item how it was made, and get back a short program that makes it again.

## Overview

A program found by search is usually long, and most of it does nothing useful.
With provenance recording on, every item the interpreter computes remembers the
arguments and the instruction that made it, so you can see which parts of a
program its answer actually depends on. That history, written out as a program,
is the item's **crux**.

```
.input0 10 .intAdd 99 .input0 .intMultiply      with input0 = 4  →  396
crux of 396:  ( 99 .input0 .intMultiply )
```

The program's first three items computed 14 and left it on the stack; the answer
never used it, so the crux leaves it out. Running a crux on a fresh interpreter,
with the same inputs and constants, puts exactly that item on its stack and
nothing anywhere else.

## Turning it on

Recording is off by default, because it costs time and memory, and nothing a
program computes depends on it. Turn it on per run:

```swift
var settings = InterpreterSettings()
settings.recordsProvenance = true
let runner = Runner(configuration: RunnerConfiguration(settings: settings, recorders: [
    RecorderSpec("answer", observing: .top(.int), keeping: .finalOnly)
]))
```

Then ask a recorded item for its crux with ``Item/crux()``. A typical use is to
run a search without recording, then re-run the best programs with it on, to see
what they do.

Setting ``RunnerConfiguration/cruxInputTokens`` also turns recording on, and has
each ``CaseResult`` report whether each recorder's final item depends on the
given inputs (``CaseResult/cruxMentionsInput``). A program whose answer ignores its
inputs is a cheap thing to detect and discard.

## What a crux records

- **Computed values** record their arguments and their instruction, so their crux
  rebuilds them from the cruxes of their arguments.
- **Copies and moves** record nothing: `intDup` pushes the same item again, so
  both copies have the original's crux. A crux that uses a value twice builds it
  once and duplicates it.
- **Elements** taken out of a collection record where they were, as
  `v 2 .vecIntNth`, unless they kept a history of their own from before they went
  in.
- **Questions** leave their arguments in place, so their crux cleans up after
  itself: the crux of `a b .intGT`'s bool removes `a` and `b` again, leaving only
  the answer.

## Stand-ins

Some values can't be rebuilt by re-running what made them. A stack's depth, the
step count and a fresh binding key depend on the state of the run, not on any
argument. For these the crux holds a **stand-in** (``StandInItem``): a literal
that runs as the value it replaces and says why it is there. It prints as, for
example, `.intStackDepth_actuallyWas_4`. A stand-in records one of three reasons:

- **observed**: read from the state of the run;
- **minted**: a value the instruction supplies itself, such as the 0 a counted
  loop starts from;
- **elided**: a history too large to keep (over
  ``InterpreterSettings/maxCallWeight`` or ``InterpreterSettings/maxCallDepth``),
  replaced by the value it produced.

A crux therefore always runs, and every literal in it that the program didn't
contain is marked.

## Long histories

A loop that adds 1 a thousand times would leave a crux a thousand steps long. The
interpreter keeps such histories compact: shared parts are built once, and
repeated steps fold into a counted loop. ``CruxCompression`` does the same to any
crux you hand it.

## Keeping histories

``AnyItem``, the `Codable` wrapper the ``Runner`` uses for results, keeps an item's
value and drops its history. To send or save items with their histories intact,
encode them as an ``ItemArchive``.
