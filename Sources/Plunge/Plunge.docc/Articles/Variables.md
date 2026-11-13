# Variables and Bindings

Name a value with an int key, look it up later, shadow it, and bind it for the
length of a code block.

## Overview

On a stack, a value is reachable only while it is near the top. A variable lets
a program put a value aside under a name and get it back from anywhere, however
the stacks have changed in between.

The `.binding` stack holds **bindings**: pairs of an int key and any item,
written `«bind: 3 -> "x"»`. A variable is every binding with one key. The topmost is
its current value; older ones below it are shadowed, not lost, so each variable
is a stack of its own values.

Instructions that work on the stack are named for it, as everywhere in the
language: `.bindingDeref`, `.bindingPopKey`. The one exception is the verb
**ref**, which makes a binding *from* another stack's item, just as `.intQuote`
makes a code block from an int: `.intRef`, `.stringRef`, and so on.

## Keys

Keys are ints, and any int can be a key, negative ones included. Because keys
are ints, a program can compute them: arithmetic can turn one key into another,
which no fixed set of names would allow.

At the start of every run the inputs are bound under their slot numbers: input
0 is key 0, input 1 is key 1, and so on, for every input the training case
binds. So a program can reach input 3 with `.input3` or as key 3. Rebinding key
3 changes what key 3 gives, but `.input3` still gives the input.

New keys come from a counter that starts just after the input slots (at 10,
while there are ten slots) and counts up. They are the same in every run of the
same program: nothing about a key is random.

## Binding and looking up

`.intRef` (and `.boolRef`, `.stringRef`, `.codeRef`, one for each type of value)
binds a copy of the top item of its stack to a fresh key, leaves the item where
it was, and pushes the key onto `.int`:

```
7 .intRef                        →  .binding holds «bind: 10 -> 7»; .int holds 10 7
```

Lookups read a key from the top of `.int` and leave it there:

- `.bindingDeref` runs what the key holds. A code block's contents run, and any
  other item lands on its stack.
- `.bindingDerefToCode` delivers it to `.code` as data, a code block as it is
  and anything else wrapped in a one-item code block.
- `.bindingDerefFrom` and `.bindingDerefToCodeFrom` take a depth from `.int` and
  look from there down, which reaches the older, shadowed bindings of the same
  key.

A key with no binding is a miss: the lookup refuses with a *not found* error and
pushes nothing.

## Assignment

`.intRefAs` (one for each type) is assignment: it takes a value and a key and
binds the one to the other, shadowing whatever that key held before. The key is
on top, so for ints the value is just below it:

```
7 3 .intRefAs                    →  key 3 now holds 7
"x" 3 .stringRefAs               →  key 3 now holds "x", and 7 is shadowed
```

A key isn't tied to a type: key 3 held an int and now holds a string.

`.bindingRekey` gives the top binding a new key, whatever its type. So `7
.intRef .intPop 3 .bindingRekey` also binds 7 to key 3, but leaves the 7 where
it was (the pop clears the fresh key that `.intRef` pushed).

## Scoped bindings

`.intWith` (one for each type) binds the top item of its stack for the length of
a code block taken from `.code`, then removes the binding. Inside the code
block, the binding's key is on top of `.int`:

```
5 ( .bindingDerefToCode ) .intWith     →  .code holds ( 5 ); the binding is gone
```

`.bindingScope` does the same for a key that is already bound:
`k ( body ) .bindingScope` runs the body, then pops k's binding.

## Removing bindings

Each removal pops a key's topmost binding, so its previous value comes back:

- `.bindingPopKey` discards it.
- `.bindingDo` runs its value as it pops it, as `.codeDo` runs the code block it
  takes: `.bindingDeref` is the reading form, `.bindingDo` the consuming one.
- `.bindingUnpack` takes the top binding apart, its value onto its own stack (a
  code block as data) and its key onto `.int` above it. `.bindingUnpack
  .intRefAs` puts an int binding back as it was.

## Asking about keys

These read a key from `.int` and leave it. An unbound key is an answer here, not
a refusal:

- `.bindingContainsKey` gives whether the key is bound.
- `.bindingOccurrencesOfKey` gives how many bindings it has, the shadowed ones
  included.

## Finding keys

Each of these refuses when there is nothing to find:

- `.bindingKeyDepth` gives how deep a key's topmost binding is.
- `.bindingNearestKey` gives the bound key nearest a given int.
- `.bindingFloorKey` gives the largest bound key at or below it, and
  `.bindingCeilingKey` the smallest at or above it.
- `.bindingKeyOf` gives the key bound to a value, the value given as a code
  block on `.code`.

They are useful because keys are ints: arithmetic can walk from one variable to
the next, and these find the bound keys near wherever it lands.

`.bindingFreshKey` pushes a fresh key without binding anything.

## Bindings as data

`.bindingQuote` turns a binding into the code block `( k value )`, and
`.bindingFromCode` turns such a code block back into a binding. A binding
written in a program lands on `.binding`, as a code block lands on `.code`.

## See Also

- <doc:BindingInstructions>
- <doc:InputsAndConstants>
- <doc:SearchingTheStacks>
