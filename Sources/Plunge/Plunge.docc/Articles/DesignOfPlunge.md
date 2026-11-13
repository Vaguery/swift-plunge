# Why Plunge Works the Way It Does

The decisions that make Plunge a dialect of its own, and the reason for each.

## Overview

Plunge keeps what defines Push: one stack for each type, programs that are
lists of items, code that is also data, an `.exec` stack that holds the rest of
the program, and the rule that every program runs. It also keeps the familiar
instructions for copying and reordering a stack's items, and most of the diverse
Push suite of instructions that manipulate code and data.

It adds a good deal more, though. This page collects those decisions in one place,
each with its reason, for readers who know another Push interpreter and for
anyone wondering why an instruction behaves as it does. The dialect is still
being developed, and details may change before version 1.0.

## The interpreter knows nothing about search

The library runs programs and reports what it was asked to observe. It doesn't
generate programs, score them, or choose which to keep, and it has no idea of a
population or a generation. Expected outputs never enter it: a
``TrainingCase`` holds inputs only, and comparing an answer with the right one
is the caller's work.

The reason is reuse. The same interpreter can serve a desktop application, a
server that evaluates programs for searches running elsewhere, or a script, and
none of them has to accept another's idea of how a search should go. For the
same reason, everything that crosses the boundary is a plain value that can be
encoded and sent. See <doc:EvaluatingPrograms>.

## Every failure is recorded

Where other Push interpreters treat an instruction that can't run as a no-op,
Plunge leaves an item on `.error` that says what happened, and gives it a kind
that can be counted.

The running program itself can see and read values from that record.
Error messages distinguish a program that reached a wrong
answer cleanly, from one that got there by dividing by zero, from one that failed
to find an argument or match a pattern. A silent failure
can also mislead the program itself: an index lookup that answered −1 for "not
found" would hand the next instruction that very "message" number, and it
might accept it as an index.
In Plunge, a lookup that finds nothing pushes no answer. See
<doc:ErrorsAndRefusals>.

## A starved instruction becomes a function

An instruction without enough arguments is the most common event in a randomly
assembled program, both in older and this new Push dialect. In earlier versions,
the instruction is simply discarded, without consuming arguments. In Plunge,
instead of being discarded it's put on the `.function` stack as a first-class function,
where map, filter, reduce and other functional programming instructions can apply
it later. Thus, most programs get their first functions without having to construct any.
See <doc:Functions>.

## Code is data until an instruction runs it

In earlier interpreters, a code block processed from the `.exec` stack is
unpacked and run, and instructions such as `exec_if` (in Clojush and Propeller)
take their branches from the unfiltered code that remains below them on the
`.exec` stack. In Plunge, a code block met on `.exec` is immediately moved to
the `.code` stack, untouched, and every instruction that consumes a code block
as an argument takes it from `.code`. Plunge's `.execIf` takes both its branches
from `.code`.

Two things follow from this. A code block that is about to be run is an ordinary
item first, which the program can build, copy, measure, edit, or bind to a
variable before deciding to run it. And a program reads the same way throughout:
the body of a loop is written before the loop instruction, exactly as the
operands of an addition are written before `.intAdd`. The `.exec` stack holds
what is about to run, and is not also a place to keep arguments. The only
instructions that reach ahead into the program are the few whose subject is
`.exec` itself, such as `.execQuote` and `.execDup`. See <doc:CodeAndControl>.

## Questions leave their arguments

A comparison, a measurement or any other query _reads_ its arguments and leaves
them in place on the stacks. Asking whether one `int` is greater than another
doesn't cost the program either value. A program that wants them gone after checking
can actively `pop` them. When a consuming instruction has a twin that only looks,
the twin's name contains `Peek`. For example, `.vecIntNth` consumes both a `vecInt`
and an `int` index, and produces only the element at the indicated index,
while `.vecIntPeekNth`
produces the indexed element without consuming the `vecInt` item.

## An index is clamped; only emptiness refuses

An evolved program computes indices to collections using arithmetic that was
never "designed", and there have been several ways that Push interpreters have
avoided "out of range" errors, including modulo arithmetic or failing out of range.
As a rule, Plunge brings an out-of-range index or count value into the required range
by saturating at the lowest or highest values of the context,
so that any `int` read as an index can land on a real position. The
exception for this is an empty collection, where no position exists: asking one for
any element (indexed or not) is a refusal.

## Nothing is random (yet)

An instruction's result depends only on its arguments and on the state of the
run. There is no random-number instruction, and nothing that leaks an arbitrary
order such as a runtime hash. Fresh variable keys and other generated values are
the same in every run of the same program, given the same input assignments.

The design decision here is that randomness "belongs" to the search, at least
until truly stochastic variables or functions are added for simulation applications.
Keeping it out of the language means that a program's result can be reproduced
exactly, on any machine and in any order of
evaluation, and that an item's crux, run again, produces the same result.

## Everything is bounded

Steps, stack depths, item sizes and total memory all have limits, and numbers
can't overflow or become infinite. Any program synthesis search can try to write
an endless loop sooner or later, and our interpreter has to survive it. See
<doc:LimitsAndGuards>, which also explains where each limit's number came from.

## Equality is about values

Two items are equal when their values are equal. A 5 computed as `2 3 .intAdd`
equals a 5 written as a literal. How an item was made (its provenance and `crux`)
never affects what a program computes, which is why turning provenance recording
on or off can't change a result.

## One order for everything

Wherever items are compared or sorted, the order is the same: false comes before
true (despite that having no meaning in logical settings), and in vectors, every
not-a-number counts as one value, greater than every number. So every sort has
one well-defined result, even at the edges, and sorts are also stable: items
that compare equal keep their order.

## Loops, variables and functions are items

A loop in progress is represented in Plunge by an `iterator` on the `.iterator`
stack. A variable is (one or more) items on `.binding` with a specific key.
A function is an item on `.function`. Each can be copied, reordered, stored and
examined by the same family of instructions that work on `int` items and other basic types.
Thus, in Plunge
a program can pause a loop and change where it will stop, shadow a
variable and restore it, or compose two functions, without the language needing
additional syntax (outside of new imperative instructions) for any of that.
See <doc:Iterators>, <doc:Variables> and <doc:Functions>.

## Names explain how an instruction works

An instruction's name starts with the stack it works on: `.intAdd`, `.codeDo`,
`.bindingDeref`. When it makes something for another stack out of an item, the
verb follows the stack the item came from: `.intQuote` makes a code block from an
`int`, and `.intRef` makes a binding from one. Suffixes carry the same meaning
everywhere: `Peek` reads without taking, and `From` starts a lookup or a find at
a given position. The instructions that every stack has (`Dup`, `Swap`, `Yank` and the
rest) are named alike on each. Knowing one stack's instructions tells you most
of another's.

## A large language, narrowed softly

Plunge has over a thousand instructions, on purpose. Most small jobs can be
done by more than one short sequence of them, which gives a search more than
one way to find each. The instructions that turn one kind of data into another
are especially worth having, because an unexpected solution often works by
changing how the problem or its data structures are represented.

Unlike many earlier Push implementations, Plunge is intended to have the
_entire core language_ (aside from domain-specific extensions) always available.
The interpreter is here to run programs. Responsibility for composing them, or
searching for improved programs, is where types and instructions should
be managed—and preferably dynamically.

For more on the many types and styles of instructions, see <doc:TaggingInstructions>.

## Results explain themselves

A program built by evolutionary search can grow quite long, and much of that code
tends to be "bloat" that doesn't contribute to calculating the desired answer.
With the Plunge interpreter's provenance recording on, every item on every stack
remembers the process that created it, and can write that out as a *crux*:
a short runnable Push program that produces that item and nothing else.
A program's crux shows what a program _actually_ does, and for example tells you
immediately whether an observed value depends on the inputs, or only matched a
target by accident. But more importantly, the crux of an item available at runtime
is actual Push data itself, and a runnable, trustable, _editable_ piece of evidence
linking inputs to behavior. See <doc:Provenance>.

## See Also

- <doc:ThePushLanguage>
- <doc:HowTheInterpreterRuns>
