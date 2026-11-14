# ``Plunge``

An interpreter for Plunge, a dialect of the Push programming language, built to
run the programs that genetic programming and other kinds of search produce.

## Overview

Push is a stack-based language designed to be written by evolution instead of
by people. Every program runs, however it was assembled: an instruction that
can't do its job leaves an error behind and the program carries on. That makes
Push a good target for genetic programming, and for any other search that
generates, varies and selects programs.

Plunge is a dialect of Push. It keeps Push's central ideas (one stack for each
type, code that is also data, no program that fails to run) and adds
first-class loops, keyed variables, functions, and a record of how every result
was made. <doc:DesignOfPlunge> lists where it departs from other Push
interpreters, and why.

This package is the interpreter alone, and contains no search. You give it
programs and inputs; it runs them, concurrently and within strict limits, and
reports what you asked it to observe. The language has 1,066 instructions over
14 typed stacks: bools, numbers, text, vectors, code, loops, variables and
functions. Two more stacks collect what a program emits: its errors, and
whatever it prints.

### Where to start

- To run a first program, read <doc:GettingStarted>.
- To learn the language, read <doc:ThePushLanguage>, then the articles under
  *The language* below. <doc:Vocabulary> defines the terms they use.
- To connect a search to the library, read <doc:WritingPrograms>,
  <doc:InputsAndConstants>, <doc:EvaluatingPrograms> and <doc:ObservingARun>.
- To understand what a run can and can't do, read <doc:HowTheInterpreterRuns>,
  <doc:ErrorsAndRefusals> and <doc:LimitsAndGuards>.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ThePushLanguage>
- <doc:HowTheInterpreterRuns>
- <doc:DesignOfPlunge>
- <doc:Vocabulary>

### Using the library

- <doc:WritingPrograms>
- <doc:InputsAndConstants>
- <doc:EvaluatingPrograms>
- <doc:ObservingARun>
- <doc:ErrorsAndRefusals>
- <doc:LimitsAndGuards>

### The language

- <doc:CodeAndControl>
- <doc:Iterators>
- <doc:Variables>
- <doc:SearchingTheStacks>
- <doc:Collections>
- <doc:Functions>
- <doc:Provenance>
- <doc:TaggingInstructions>
- <doc:InstructionReference>

### Running programs

- ``Runner``
- ``RunnerConfiguration``
- ``Individual``
- ``TrainingCase``
- ``Pairing``
- ``CaseResult``
- ``EvaluationRequest``
- ``evaluate(request:)``
- ``evaluate(streaming:)``
- ``InterpreterSettings``

### Observing a run

- ``RecorderSpec``
- ``RecorderTarget``
- ``RecordingPolicy``
- ``RecordedTrace``

### Writing programs

- ``PushProgram``
- ``pushItem(_:)``
- ``bindings(_:)``
- ``merged(_:)``

### Items

- ``Item``
- ``IntItem``
- ``DoubleItem``
- ``BoolItem``
- ``CharItem``
- ``StringItem``
- ``VecIntItem``
- ``VecDoubleItem``
- ``VecBoolItem``
- ``VecStringItem``
- ``CodeItem``
- ``InstructionItem``
- ``IteratorItem``
- ``BindingItem``
- ``FunctionItem``
- ``ErrorItem``
- ``ErrorKind``
- ``Pretty``

### The language's vocabulary

- ``PushInstruction``
- ``PushStack``
- ``InstructionSignature``
- ``Produces``
- ``BehaviorClass``
- ``InstructionRole``
- ``InstructionTag``
- ``InstructionTagging``
- ``TagFacet``
- ``TagProvenance``
- ``IteratorKind``
- ``PointsEmission``

### Recording provenance

- ``StandInItem``
- ``ProvenanceRecording``
- ``CallMeasure``
- ``CruxCompression``

### Saving and sending items

- ``AnyItem``
- ``ItemArchive``
- ``ArchiveError``
- ``ItemBindingCoding``

### Testing

- ``RandomCode``
