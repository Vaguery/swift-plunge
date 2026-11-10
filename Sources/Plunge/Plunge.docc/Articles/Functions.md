# Functions: Map, Filter and Reduce

Apply a block to every element of a vector or string, keep the elements a block
approves of, or fold them into one value.

## Overview

A **function** here is a block whose holes are the input instructions: `input0`,
and for a reduction `input1` as well. Applying it to an element runs the block on
a fresh interpreter with `input0` bound to that element, and its **result** is the
last value it pushed, on whatever stack that was.

```
[1 2 3] ( .input0 2 .intMultiply ) .vecIntMap     →  .vecInt holds [2, 4, 6]
```

The function sees the program's other inputs and constants too, so
`( .input0 .input1 .intAdd )` mapped over a vector adds the program's own
`input1` to each element.

## Map

`vecIntMap`, `vecDoubleMap`, `vecBoolMap`, `vecStringMap` and `stringMap` take a
collection and a function from `.code`, and collect the function's results. The
result's type follows the data: map an int vector through a function that pushes
doubles and you get a vector of doubles, and a string mapped through a function
that pushes chars gives a string. An element whose function pushes nothing passes
through unchanged. Results of mixed types are refused.

## Filter

`vecIntFilter` and its siblings keep the elements for which the function's result
is `true`. A function that pushes no bool counts as `false`.

```
[1 2 3 4] ( .input0 2 .intMod 0 .intEq ) .vecIntFilter     →  [2, 4]
```

## Reduce

`vecIntReduce` and its siblings fold from the first element: `input0` is the
running result and `input1` the next element. An empty collection is refused.

```
[1 2 3 4] ( .input0 .input1 .intAdd ) .vecIntReduce     →  .int holds 10
```

## Cost

Every step a function takes counts against the program's own step limit. A map
that would run past it is refused, so a function can't be used to escape the
limit.

## Another way to map

An iterator with a body maps too, in the same program rather than a fresh one:
`vecFromIterator` collects what the body leaves for each element. The
`iteratorOver…` instructions build such an iterator in one step from a collection
and a block.
