# Iterators and Loops

Loops that are items: a program can build one, play it, pause it, inspect it,
change it and resume it.

## What an iterator is

An item on `.iterator` describes a loop:

- a **source**: a range of ints, a string, a vector, a block, or an item to
  repeat;
- a **cursor**: how many passes it has taken;
- a **body**: an optional block to run on each pass;
- whether it **emits**: pushes each element (a number of the range, an element
  of the vector, a char of the string) onto its stack before the body runs.

Iterators print as `«start→end @cursor body»`.

## Building and playing one

The quickest way to walk a collection is an `iteratorOver…` instruction, which
takes the collection and a body and builds an iterator that emits each element.
`iteratorPlay` then runs the loop to the end:

```
[1 2 3] ( 10 .intMultiply ) .iteratorOverVecInt .iteratorPlay
    →  .int holds 10 20 30; the body returns to .code
```

The `iteratorFrom…` instructions build the same kinds of iterator with every
setting spelled out: where to start, how deep in `.exec` to queue each pass, and
whether to emit. A counting iterator, `iteratorFromIntRange`, counts from one int
toward another and stops short of it.

## Collecting

`vecFromIterator` runs an iterator to the end and collects what it produced into a
vector, or a string if the results are chars. With a body, it collects what the
body leaves on each pass, which makes it a map:

```
[1 2 3] ( 10 .intMultiply ) .iteratorOverVecInt .vecFromIterator
    →  .vecInt holds [10, 20, 30]
```

`codeFromIterator` collects into a block instead, which takes items of any type.

## Controlling a loop

Because a loop is an item, a program can work on it between passes:

- `iteratorStep` takes a single pass;
- `iteratorPopState` skips a pass;
- the `iteratorPeek…` instructions read its start, end, stride, body and laps
  without disturbing it;
- the `iteratorSet…` instructions change its start, end, cursor, depth and laps;
- `iteratorRestart` rewinds it.

A change that leaves nothing more to emit ends the loop, and its body returns to
`.code`.

## Limits

An iterator is bounded like everything else: it can't outrun the step limit, and
a collector refuses a loop that would produce more than one item may hold.

## See Also

- <doc:IteratorInstructions>
- <doc:Functions>
