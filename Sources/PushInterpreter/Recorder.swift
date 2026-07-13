//
//  Recorder.swift
//  PushInterpreter
//
//  Created by William Tozier on 6/20/26.
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
    var instrumentation: (Interpreter) -> T?
    
    init(_ name: String,
         data: [T?] = [],
         instrumentation: @escaping (Interpreter) -> T?) {
        self.name = name
        self.data = data
        self.instrumentation = instrumentation
    }
    
    mutating func record(interpreter: Interpreter) {
        data.append(instrumentation(interpreter))
    }
    
    mutating func reset() {
        data.removeAll()
    }
    
    func reportAll(steps:Int, fillWithLast:Bool = true, trim:Bool = false) -> [T?] {
        let readings = data.count
        if readings < steps {
            // `data.last` is nil only when nothing was recorded; with no last
            // reading to repeat, fall through and return whatever data exists
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
    mutating func record(interpreter: Interpreter)
    mutating func reset()
    var dataAsAnyArray: [Any?] { get }
}

// struct that holds any Recorder<T> recorder, compatible with [Recorder<T>] array
//
nonisolated struct AnyRecorder: AnyRecorderProtocol {
    private var _box: AnyRecorderBox
    
    var name: String { _box.name }
    mutating func record(interpreter: Interpreter) { _box.record(interpreter: interpreter) }
    mutating func reset() { _box.reset() }
    var dataAsAnyArray: [Any?] { _box.dataAsAnyArray }
    
    func reportAll(steps: Int, fillWithLast: Bool = true, trim: Bool = false) -> [Any?] {
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
    func record(interpreter: Interpreter) { base.record(interpreter: interpreter) }
    func reset() { base.reset() }
    var dataAsAnyArray: [Any?] { base.data.map { $0 } }
    
    func reportAll(
        steps:Int,
        fillWithLast:Bool = true,
        trim:Bool = false) -> [Any?] {
        base.reportAll(steps: steps, fillWithLast: fillWithLast, trim: trim)
    }


    init(_ base: Recorder<T>) {
        self.base = base
    }
}

