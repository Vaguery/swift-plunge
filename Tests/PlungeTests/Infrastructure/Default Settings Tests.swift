//
//  Default Settings Tests.swift
//  PlungeTests
//
//  The documented defaults, pinned. 0.7.0 shipped a step limit of 1,000 while its
//  notes and the setting's own comment said 10,000 (#29), and nothing noticed.
//

@testable import Plunge
import Testing

struct DefaultSettingsTests {

    @Test func `the default step limit is 10,000`() {
        #expect(InterpreterSettings().stepLimit == 10_000)
        #expect(Interpreter.defaultSettings.stepLimit == 10_000)
        #expect(Interpreter().config.stepLimit == 10_000)
    }

    /// The relation the settings' comment says nothing enforces: a walk over the
    /// largest collection the interpreter accepts must fit in one run.
    @Test func `the default step limit can walk the largest collection`() {
        let settings = InterpreterSettings()
        #expect(settings.stepLimit > settings.maxVectorLength)
        #expect(settings.stepLimit > settings.maxStringLength)
    }
}
