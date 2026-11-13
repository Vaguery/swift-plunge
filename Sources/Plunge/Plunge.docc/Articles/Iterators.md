# Iterators and Loops

Loops that are items: a program can build one, play it, pause it, inspect it,
change it and resume it.

## Overview

The loop instructions in <doc:CodeAndControl> start a loop and let it run. An
**iterator** is a loop held as an item on the `.iterator` stack, so everything a
program can do with an item it can do with a loop: copy it, set it aside, look
at how far it has got, change where it will stop, and start it again later.
Iterators are also how a program walks a collection, since an iterator can hand
over the elements of a vector, a string or a code block one at a time.

## What an iterator is

An item on `.iterator` describes a loop:

- a **source**: a range of ints, a string, a vector, a code block, or an item to
  repeat;
- a **cursor**: how many passes it has taken;
- a **body**: an optional code block to run on each pass;
- whether it **emits**: pushes each element (a number of the range, an element
  of the vector, a char of the string) onto its stack before the body runs.

An iterator prints in words: `«iter 3 to 40 by 1 at 3: ( true )»` counts
from 3 toward 40 by ones, has taken three passes, and runs `( true )` on each.
The source names the kind of loop, so two iterators never print alike:
`over [1, 2, 3]` walks a collection's elements, `letters of "ab"` and
`words of "a b"` walk a string two other ways, and `7 repeated 4 times` repeats
one item.

## Building and playing one

The quickest way to walk a collection is an `.iteratorOver…` instruction, which
takes the collection and a body and builds an iterator that emits each element.
`.iteratorPlay` then runs the loop to the end:

```
[1, 2, 3] ( 10 .intMultiply ) .iteratorOverVecInt .iteratorPlay
    →  .int holds 30 20 10; the body returns to .code
```

Each pass pushed one element and ran the body on it, so the results were
pushed in the order 10, 20, 30, and 30 is on top.

The `.iteratorFrom…` instructions build the same kinds of iterator with every
setting spelled out: where to start, how deep in `.exec` to queue each pass, and
whether to emit. A counting iterator, `.iteratorFromIntRange`, counts from one
int toward another and stops short of it.

## Collecting

`.vecFromIterator` runs an iterator to the end and collects what it produced
into a vector, or a string if the results are chars. With a body, it collects
what the body leaves on each pass, which makes it a map:

```
[1, 2, 3] ( 10 .intMultiply ) .iteratorOverVecInt .vecFromIterator
    →  .vecInt holds [10, 20, 30]
```

`.codeFromIterator` collects into a code block instead, which takes items of any
type.

`.vecFromIterator` runs each pass apart from the program's own stacks, in a
sandbox, so the body sees only its own element. <doc:Functions> compares this
way of mapping with the function instructions.

## Controlling a loop

Because a loop is an item, a program can work on it between passes:

- `.iteratorStep` takes a single pass;
- `.iteratorPopState` skips a pass;
- the `.iteratorPeek…` instructions read its start, end, stride, body and laps
  without disturbing it;
- the `.iteratorSet…` instructions change its start, end, cursor, depth and
  laps;
- `.iteratorRestart` rewinds it.

A change that leaves nothing more to emit ends the loop, and its body returns to
`.code`.

## Limits

An iterator is bounded like everything else: it can't outrun the step limit, and
a collector refuses a loop that would produce more than one item may hold. See
<doc:LimitsAndGuards>.

## See Also

- <doc:IteratorInstructions>
- <doc:CodeAndControl>
- <doc:Functions>
