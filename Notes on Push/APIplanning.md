#  Planning document for Interpreter use

## Overview

There are several eventual targets for using the `Interpreter` type in applications. In each case, the application is genetic programming, controlled by a separate process locally or remotely. That process will be responsible for search proper, and will manage training case selection, search operators, assignment of constant values, and so on. 

This interpreter is intended to live inside a `Runner` or `Evaluator` process, which is local in some cases and remote in others. That will receive informational requests, config instructions, but most importantly will be sent `Individuals` to evaluate. 

A request to evaluate an `Individual` will have to carry along at least these features:

- an `Individual`, at least including
    - a `genome`, a `Plushy` or other encoded textual representation of `[Item]`
- a `constants` collection, which assigns some bound `Item` values to specific `PushInstruction` tokens like `.int8` and `.vecBool0`
- zero or more `inputs`, which are `any Item`, and which are bound to `PushInstruction` tokens like `.input0`
- configuration info for how to set up the `Interpreter` before running, and how many steps to run it
- configuration spelling out which of the defined Push Behaviors should be disabled, if any
- details needed to produce one or more `Recorder` instances
- details needed to select the statistics to return or assign with the results (TBD)

Since each `Individual` will be run several times, it is an open question whether it's more efficient to have it manage `error` reporting for all training cases inside the structure, and ask the `Runner` to return the results section only when complete, or to spawn requests for each combination of a program and training case with all the redundant information that may entail.

Since almost certainly all the `Individual`s in a population-based algorithm will be evaluated at once, it may also be useful for the configuration shared across the instances to be sent to the `Runner` at once, and the necessary parts doled out to the `Interpreter`s spawned as needed

Several modes of interaction will be useful for all the target architectures, some overlapping: 

1. Request a list of all `PushInstruction` names defined in the language.
2. Request a list of active `Behaviors` in an extant Runner
3. Send a configuration shared for multiple evaluations
4. Request current configuration state
5. Send one or more `Individual` records for evaluation
6. Send one or more `Training Case` records to be used in evaluation
7. queue status check
8. other state info?

## Use cases for the library

1. A MacOS app which will run locally on a Mac, using concurrency to evaluate programs against training data selected from a dataset also stored locally. This single app will define and manage the search algorithm locally, with a UI. Multiple Interpreter threads will be spawned which will use local resources to evaluate a suite of programs against a suite of training cases.
2. A server-side Runner app, which will respond to RESTful (authenticated) requests to evaluate Individuals en masse. This will spawn multiple `Interpreter` processes as resources permit. It may demand some local storage for intermediate results.
3. A serverless lambda or other FaaS architecture, where a client will spawn a queue of evaluation tasks, and these will be handled (with whatever queued storage might be required)

## Plans

1. the current interpreter package should be reviewed and prepped to present a better API
2. the current `Interpreter.run()` and `.load()` and related interface is ragged and needs a lot of improvement for usability
3. specifying `constants` and `inputs` is cumbersome
4. No capacity exists yet for easily building and applying a `Recorder` to an existing `Interpreter`, or to retrieve and process the results
5. in all cases, the changes should leave the library suitable for work on a Mac or a Linux server
6. some attention should be paid to reusing `constants` across multiple `Individuals`, since there may be ways of optimizing them separate from architecture search in GP
7. As the use case described below starts being developed, there will be some changes to the Push language (possibly some new types), but no large-scale architectural shifts; no plans for a new kind of `Behavior`, for example

## Use case: the MacOS MVP

The first app will be a desktop MacOS app, with a modest UI and local runner. This will need to be able to run mutliple threads, as possible, and report results promptly for the UI to be updated. It's a good place to knock the rough parts off the current API

