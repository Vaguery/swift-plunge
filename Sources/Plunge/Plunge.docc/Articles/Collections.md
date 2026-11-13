# Collections

Work with vectors and strings as wholes: combine two element by element, sort,
count, cut into pieces, and convert.

## Overview

The four vector types (`.vecBool`, `.vecInt`, `.vecDouble`, `.vecString`) and
strings share most of their instructions: the name says the container first
(`.vecIntSort`, `.stringSort`), and close analogues differ only by type. This
article covers the operations on a collection as a whole. Taking elements out
and putting them in is on each type's reference page; applying a function to
each element is in <doc:Functions>.

A name written here with an X, as in `.vecXSort`, stands for one instruction for
each vector type (`.vecIntSort`, `.vecStringSort` and so on). A bare ending such
as `Rotate` stands for every instruction that ends that way.

## Element by element

`.vecIntAdd`, `.vecIntSubtract`, `.vecIntMultiply`, `.vecIntQuot` and
`.vecIntMod` combine two vectors of ints element by element, as the scalar
instructions combine two ints; `.vecDoubleAdd` and its siblings do the same for
doubles, with `.vecDoubleDivide`. `.vecIntDot` and `.vecDoubleDot` give the dot
product. `.vecXEqEach`, and `LTEach` and `GTEach` for ints, doubles and strings,
compare element by element into a vector of bools; `.vecBoolAnd`, `.vecBoolOr`
and `.vecBoolNot` combine vectors of bools.

**The second vector is found, not just taken.** Written `a b .vecIntAdd`, `b`
is the top vector and `a` is the **first vector below it with the same length**.
A vector of another length in between is passed over and left where it is:

```
[100, 200] [7] [1, 2] .vecIntAdd     →  .vecInt holds [101, 202] [7]
```

So two vectors of the same length can be combined even when a vector of
another length has landed between them.

If no vector below has the same length, the instruction misses: it refuses
with ``ErrorKind/notFound``, and the arithmetic still takes `b` (comparisons and
dot products read their vectors and leave them). A lone vector starves the
instruction. Arithmetic refuses as the scalar instruction does, on overflow or
division by zero, and its error names the index.

Comparisons follow the vector rules: every NaN is one value, greater than every
number. Bools order false before true, here and everywhere else (`.boolLT`,
`.vecBoolSort`).

## Order and position

- **Sort:** `.vecXSort` and `.stringSort` sort ascending, stably; NaN sorts
  last, false before true. For descending order, reverse afterward.
- **Where the extremes are:** `.vecIntIndexOfMax`, `.vecIntIndexOfMin` and their
  double and string siblings give the index of the first greatest or least
  element, leaving the vector.
- **The last occurrence:** `.vecXLastIndexOf` and `.stringLastIndexOf`, beside
  the first-occurrence `IndexOf`.
- **Rearrange:** `Rotate` (left by n, any sign), `Interleave` (a[0] b[0] a[1] …),
  and `Repeat` (the whole vector n times).

Rearranging keeps each element's history, so an element taken out of a sorted
vector replays as the element that went in.

## Counting and summing

- `.vecIntProduct` and `.vecDoubleProduct` (empty gives 1), beside the sums;
  `.vecIntMean` and `.vecDoubleMean` give a double and refuse an empty vector.
- `.vecIntPrefixSums` and `.vecDoublePrefixSums` give running totals.
- `.vecXFrequencies` and `.stringFrequencies` give two results: the distinct
  elements in ascending order, then a vector of ints with how many times each
  occurs. Two strings are anagrams when their frequencies are equal.

## Ranges, digits and conversions

- `a b .vecIntRange` counts from a toward b, leaving b out: `2 5` gives
  `[2, 3, 4]`, and `3 0` gives `[3, 2, 1]`. `a b s .vecIntRangeBy` steps by s,
  and refuses a step of 0 or one that goes the wrong way.
- `.vecIntFromInt` gives an int's decimal digits, most significant first
  (`-305` gives `[3, 0, 5]`); `.intFromVecInt` reads them back.
- `.vecDoubleFromVecInt`, `.vecIntFromVecDouble` (truncating) and
  `.vecIntFromVecBool` (true is 1) convert whole vectors.

## Pieces

`v n .vecIntChunks` cuts a vector into consecutive pieces of n elements, the
last possibly shorter, and `v n .vecIntWindows` gives every run of n consecutive
elements, sliding by one. The pieces come as **one code block** on `.code`, to
walk with `.iteratorOverCodeRoot` or take apart with `.codeNthRoot`:

```
[1, 2, 3, 4, 5] 2 .vecIntChunks     →  .code holds ( [1, 2] [3, 4] [5] )
```

`.stringChunks` and `.stringWindows` give a vector of strings instead.

Code blocks gain the root-level operations the vectors have: `.codeReverseRoot`,
`.codeFirstRoot`, `.codeLastRoot`, `.codeTakeRoot` and `.codeDropRoot`.

## Size

Every instruction that builds something large (`Range`, `Repeat`, `Windows`)
checks the size first and refuses, with ``ErrorKind/sizeRefusal``, before
building anything over the limit. See <doc:LimitsAndGuards>.

## See Also

- <doc:Functions>
- <doc:Iterators>
- <doc:SearchingTheStacks>
- <doc:VecIntInstructions>
- <doc:StringInstructions>
