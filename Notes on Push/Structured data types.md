# Structured data types

**Status: TO THINK ABOUT.** A placeholder for a design conversation, not a design. Recorded 2026-11-05,
prompted by the deep-nesting findings of the Phase 2 stress run and the `.codeNest` idea in *Compressing
huge values*.

## Why

The language has scalars, homogeneous vectors, strings, and one heterogeneous tree: `CodeItem`. That is
enough for symbolic regression and string synthesis. It is thin for what comes next:

- **Graph algorithms** (search, shortest paths, flows, colorings), whether evolved or used as building
  blocks, need a graph to operate on. Today a program could only encode one inside code or vectors.
- **Recursive processes** naturally build and consume N-nested structure. An N-nested item handled as a
  value, rather than run, is a kind of **code quoting**: the `.code` stack already treats a block as data
  (*CodeItem goes to code*), and `.codeNest` / "x nested N" would be a compact quoted recursion. A tree
  type could make that explicit rather than incidental.
- **Matrix** work (linear maps, grids, cellular automata, image-like data) does not fit a vector of
  vectors well. Shape, row and column access, and elementwise versus algebraic operations want a type of
  their own.

Each of these wants **diverse, helpful instructions**, not just constructors: traversal, insertion and
deletion, rebalancing, neighborhood queries, shape changes. The point is to give evolution useful
primitives at the right level, as the vector and code families do now.

## Candidates

- **Matrix** (numeric first, maybe boolean): shape, get/set, row/column/diagonal extraction, transpose,
  elementwise maps, multiply, neighborhoods for grid processes.
- **Trees**: a plain n-ary tree distinct from `CodeItem` (labelled nodes, no execution meaning); binary
  trees; **balanced search trees** (red/black, AVL) as ordered maps/sets with O(log n) operations;
  **heaps / priority queues**.
- **Spatial trees**: **quadtrees / octrees**, k-d trees, for geometric and image-like problems.
  Related to the existing roadmap mention of structured geometric types (`point`, `circle`, `line`).
- **Graphs**: directed and undirected, possibly weighted; adjacency queries, edge and node edits,
  traversal orders, and graph algorithms as instructions or as iterator kinds.
- **Sets and maps** in general, which several of the above specialize.

## What the existing design already says about it

- **Adding a type is expensive today:** about 28 edits across about 20 files, four of which fail
  silently (*Macros for behavior definitions*, "The case"). The Stage 2 type registry and Stage 3
  `@PushItem` / family macros exist mainly to bring that down to one descriptor per type. That work is
  probably a prerequisite, or at least should be decided first.
- **Stacks are homogeneous** except `.exec`, so each type gets its own stack, its own combinator family
  (168 combinators today come from one `for` loop over stacks), and its place in the constant, quote,
  encode and random-code families.
- **Iterators are the traversal story.** `.points` already walks a code tree in pre-order; tree and
  graph traversals (BFS, DFS, in-order) are natural new `IteratorKind`s, and they make loops over a
  structure O(1) in provenance, which is what made `IteratorItem` worth having.

## What the Phase 2 work adds as constraints

- **Depth safety is not optional.** Anything nested must cache its size and depth at construction (as
  `CodeItem.flatSize`/`nestingDepth` and `CallMeasure` now do), walk iteratively, and have a depth bound
  enforced at push; a recursive walk or release past ~2,500 levels kills a worker thread
  (*Deep Structure Safety Tests*).
- **Walks must not expand shared structure.** Value semantics with copy-on-write means copies share
  storage, so a naive walk of a structure built from self-copies is exponential. Persistent (immutable,
  structurally shared) data structures fit value semantics well (persistent red/black trees are the
  classic example), but every walk, weight and equality check has to be written with sharing in mind.
- **Weight and limits:** each type needs an honest content `weight` so `maxItemWeight`/`maxLiveWeight`
  keep bounding memory, plus whatever per-dimension caps make sense (matrix dimensions, node counts).
- **Provenance:** each type's operations obey the provenance laws, and its values need a crux, ideally
  via a constructor or representative instruction that rebuilds them compactly (*Compressing huge
  values*). Both recording modes must compute the same thing, so each new family joins the parity
  sweeps and the dual-mode stress run automatically by being registered.

## Open questions

- **Separate types, or richer `CodeItem`?** Code is already a universal tree. Is a tree type worth a
  stack of its own, or are labelled nodes plus tree instructions over `.code` enough?
- **Which first?** Matrix is the most self-contained and has the clearest instruction set; graphs have
  the most new applications; trees connect most directly to the nesting and quoting ideas.
- **Search-space cost.** Every family adds dozens of instructions. Tagging families (`.cruxOnly`,
  per-domain presets in PlungeGP's Language tab) keeps them out of the way of problems that do not need
  them.
- **Benchmarks.** A type is worth adding when there are problems that need it. Graph and matrix
  benchmarks (PSB-style or otherwise) should arrive with the types.
