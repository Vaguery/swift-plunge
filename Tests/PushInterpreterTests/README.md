# Tests moved

The interpreter and behavior unit tests now live in the `PushInterpreter`
Swift package, at `PushInterpreter/Tests/PushInterpreterTests/`, and run via
`swift test` (Linux-capable). This empty target is vestigial and can be
removed from the Xcode project.
