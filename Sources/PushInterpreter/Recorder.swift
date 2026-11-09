//
//  Recorder.swift
//  PushInterpreter
//
//  Created by Bill Tozier on 6/20/26.
//

import Foundation

/// A  `Recorder` observes and reports the behavior of some aspect of an `Interpreter`
/// at runtime, keeping an array of `data` at each observed step. Intended to be used as an
/// internal attribute of a specific `Interpreter`, and loaded with a closure that copies the
/// top or second item of some particular stack in each step the interpreter makes.
///
nonisolated struct Recorder<T> {

    let name: String
    var data: [T?] = []
    let policy: RecordingPolicy
    var instrumentation: (Interpreter) -> T?

    init(_ name: String,
         data: [T?] = [],
         keeping policy: RecordingPolicy = .everyStep,
         instrumentation: @escaping (Interpreter) -> T?) {
        self.name = name
        self.data = data
        self.policy = policy
        self.instrumentation = instrumentation
    }

    mutating func record(interpreter: Interpreter) {
        let reading = instrumentation(interpreter)
        switch policy {
        case .everyStep:
            data.append(reading)
        case .finalOnly:
            // Hold a single reading, overwritten each step, so the trace never
            // grows with run length.
            if data.isEmpty { data.append(reading) } else { data[0] = reading }
        }
    }
    
    mutating func reset() {
        data.removeAll()
    }
    
    func reportAll(steps:Int, fillWithLast:Bool = false, trim:Bool = false) -> [T?] {
        let readings = data.count
        if readings < steps {
            // A run that stops early simply recorded fewer readings; the truncated
            // collection *is* the record, and consumers infer no change occurs after
            // the program halts. Opt into `fillWithLast` only if a caller genuinely
            // needs the last reading repeated out to `steps`. (`data.last` is nil
            // when nothing was recorded, so there is nothing to repeat.)
            if fillWithLast, let last = data.last {
                let padding = Array(repeating: last, count: steps - readings)
                return data + padding
            }
        }
        if readings > steps && trim {
            return Array(data.prefix(upTo: steps))
        }
        return data
    }
}


// generated code:

// wrapper Protocol to enable construction of [Recorder<Any>] arrays
//
nonisolated protocol AnyRecorderProtocol {
    var name: String { get }
    func record(interpreter: Interpreter)
    func reset()
    var dataAsAnyArray: [Any?] { get }
    var policy: RecordingPolicy { get }
}

// struct that holds any Recorder<T> recorder, compatible with [Recorder<T>] array
//
// `record`/`reset` are NOT `mutating`: the recorder's mutable state lives in `_box`, a
// class, so recording mutates through the reference without changing this struct. That
// matters in the step loop's hot path — a `mutating` call through
// `recorders[key]?.record(...)` would mark the `recorders` dictionary as mutated and
// COW-copy its entire storage *every step*, which profiling showed as gigabytes of
// churn. Non-mutating, the dictionary is only read, so no copy is made.
nonisolated struct AnyRecorder: AnyRecorderProtocol {
    private let _box: AnyRecorderBox

    var name: String { _box.name }
    var policy: RecordingPolicy { _box.policy }
    func record(interpreter: Interpreter) { _box.record(interpreter: interpreter) }
    func reset() { _box.reset() }
    var dataAsAnyArray: [Any?] { _box.dataAsAnyArray }
    
    func reportAll(steps: Int, fillWithLast: Bool = false, trim: Bool = false) -> [Any?] {
        _box.reportAll(steps: steps, fillWithLast: fillWithLast, trim: trim)
    }
        
    init<T>(_ concrete: Recorder<T>) {
        self._box = RecorderBox(concrete)
    }
}

// wrapper Protocol for individual Recorder items
//
nonisolated private protocol AnyRecorderBox: AnyObject {
    var name: String { get }
    var policy: RecordingPolicy { get }
    func record(interpreter: Interpreter)
    func reset()
    var dataAsAnyArray: [Any?] { get }
    func reportAll(steps:Int, fillWithLast:Bool, trim:Bool) -> [Any?]
}

// Box around a Recorder, permitting interaction indirectly
//
nonisolated private final class RecorderBox<T>: AnyRecorderBox {
    var base: Recorder<T>
    var name: String { base.name }
    var policy: RecordingPolicy { base.policy }
    func record(interpreter: Interpreter) { base.record(interpreter: interpreter) }
    func reset() { base.reset() }
    var dataAsAnyArray: [Any?] { base.data.map { $0 } }
    
    func reportAll(
        steps:Int,
        fillWithLast:Bool = false,
        trim:Bool = false) -> [Any?] {
        base.reportAll(steps: steps, fillWithLast: fillWithLast, trim: trim)
    }


    init(_ base: Recorder<T>) {
        self.base = base
    }
}

