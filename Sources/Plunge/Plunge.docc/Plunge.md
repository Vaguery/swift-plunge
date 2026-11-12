# ``Plunge``

An interpreter for Plunge, a dialect of the Push programming language, built to
run the programs a genetic-programming search produces.

## Overview

Push is a stack-based language designed to be written by evolution. Every
program runs, however it was assembled: an instruction that can't do its job
leaves an error behind and the program carries on. That makes Push a good target
for searches that generate, vary and select programs instead of writing them.

This package is the interpreter alone, independent of any search. You give it
programs and inputs; it runs them, concurrently and within strict limits, and
reports what you asked to observe. Its language has 1,060 instructions over 14
typed stacks: numbers, text, vectors, code, first-class loops, keyed variables
and functions. Every item it computes can explain how it was made.

Start with <doc:GettingStarted>, then read <doc:ThePushLanguage> for the ideas
and <doc:HowTheInterpreterRuns> for the machinery.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ThePushLanguage>
- <doc:HowTheInterpreterRuns>

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
- ``RandomCode``

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
