# Extensibility goal: compass and straightedge

*Recorded 2026-11-08, in the user's words as far as possible. This is the reason macros and plugin
packaging keep coming back (Roadmap #43, *Macros for behavior definitions.md*, Open directions A4).*

## The goal

When the system is more complete and works for search, it should be **as simple as possible** for a
user to do an evolutionary search in a new domain. The model, held for ten years or more:

1. The user can add **types and instructions** for handling points in a plane, and abstract geometric
   circles passing through those points.
2. Those types **need not interact with the numerical types**. They can be abstract.
3. The default suite of **control structures, iteration, recursion** and so on interacts seamlessly
   with the new types.
4. So the user can **evolve plane-geometry constructions with compass and straightedge**.

The canonical example is the impossible but interesting task: *find the best compass-and-straightedge
method you can for trisecting an angle, or for squaring the circle.* Feasible constructions are also
in scope for this milestone. The point is that **plane geometry, in Geogebra-style abstract symbolic
representations, could be added and used easily.**

So:

- **The language should be easily extensible**, ideally packaged as an external module or plugin.
- **The search should run a reasonable suite of parameterized training cases** and evaluate them.
- As a result, **increasingly accurate (but never complete) solutions** can be explored.

## What it asks of the work in progress

Recorded so later decisions can be checked against it. None of this is designed yet.

- **Declaring a new instruction should be short and hard to get wrong.** The step-2 Behavior forms
  (#43) moved most of the language toward declarations: structural rules are data, context reads and
  channels cannot mutate. Typed operation constructors (parameter packs, Roadmap #44) would make an
  operation's argument and result types data too. A macro may then have only registration left to do,
  which is why the user expects macros to get simpler as the representation is refined.
- **Instructions must be addable from outside the package.** *Macros for behavior definitions.md* Q2:
  `PushInstruction` is an enum, so a loaded module cannot add instructions without it becoming an
  open, `RawRepresentable` type with a registry.
- **New types must cost one declaration, not twenty files.** The same note counts about 28 edits across
  about 20 files to add a type today, four of which fail silently.
- **Every registered instruction must keep the language's guarantees** (Open directions A4): obey the
  crux rule and be covered by the round-trip check, or provenance completeness stops being a
  whole-language guarantee.
- **Generic control must reach new types without per-type code**: dup, swap, yank and the rest for a
  new stack, loops and iterators over its items. The structural rules being declared per stack, not
  per type, is a step in that direction.
- **The Runner and search must take parameterized training cases** for a domain they know nothing about.
