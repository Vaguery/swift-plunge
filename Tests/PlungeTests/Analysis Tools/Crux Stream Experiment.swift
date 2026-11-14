//
//  Crux Stream Experiment.swift
//  PlungeTests
//
//  A stream of code through one interpreter, harvesting cruxes as it goes.
//
//  One interpreter, recording provenance, is fed random code a segment at a
//  time; each segment runs to the end before the next is added, so the stacks
//  carry over and later code builds on what earlier code left. Between segments
//  each stack keeps only its top items (a bounded working memory: without it the
//  runaway guard stops every stream within a few segments). After each segment,
//  every history node pushed during it is written out as a crux and keyed by its
//  text. The questions:
//
//  - Do new cruxes keep appearing, or does the stream start repeating itself?
//  - Do the cruxes grow more complicated over time?
//  - How much would a cache keyed by crux save?
//
//  Off unless `PUSH_STREAM` is set to the number of streams.
//  `PUSH_STREAM_SEGMENTS` (default 400) and `PUSH_STREAM_KEEP` (default 50 items
//  a stack) shape each stream. Run:
//
//      PUSH_STREAM=3 swift test -c release -Xswiftc -enable-testing --filter CruxStreamExperiment
//
//  The report is written to `PUSH_ATTRIBUTION_DIR` (default: the temporary
//  directory) as `crux-stream.txt`.
//

import Foundation
@testable import Plunge
import Testing

@Suite
struct CruxStreamExperiment {

    nonisolated static let streams: Int? = ProcessInfo.processInfo.environment["PUSH_STREAM"].flatMap(Int.init)

    @Test(.enabled(if: CruxStreamExperiment.streams != nil))
    func `a stream of code harvested for new cruxes`() throws {
        let environment = ProcessInfo.processInfo.environment
        let dir = environment["PUSH_ATTRIBUTION_DIR"].map { URL(fileURLWithPath: $0) } ?? URL.temporaryDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let segments = environment["PUSH_STREAM_SEGMENTS"].flatMap(Int.init) ?? 400
        let keep = environment["PUSH_STREAM_KEEP"].flatMap(Int.init) ?? 50

        var lines: [String] = []
        var everSeen = Set<String>(), everSeenAbstract = Set<String>()
        for number in 0..<(Self.streams ?? 0) {
            var stream = CruxStream(number: number, keep: keep)
            for segment in 0..<segments { stream.feed(segment) }
            lines += stream.report(segments: segments)
            everSeen.formUnion(stream.seen)
            everSeenAbstract.formUnion(stream.seenAbstract)
        }
        lines.append("Across all streams: \(everSeen.count) distinct cruxes, \(everSeenAbstract.count) distinct "
                     + "abstract cruxes reading an input.")
        let report = lines.joined(separator: "\n")
        try report.write(to: dir.appending(path: "crux-stream.txt"), atomically: true, encoding: .utf8)
        print(report)
    }
}

/// One stream: an interpreter, what it has harvested, and a window of counts.
nonisolated struct CruxStream {
    /// What one window of segments harvested.
    struct Window {
        var pushed = 0, new = 0, newAbstract = 0, readingInputs = 0, newReadingInputs = 0
        var lengthOfNew = 0, longestNew = 0, deepestNew = 0, steps = 0
    }

    static let windowSize = 50
    static let segmentLength = 50

    let number: Int
    let keep: Int
    let interpreter = Interpreter()
    let instructions = Runner().definedInstructions
    let loopers = Array(Interpreter.reEntrantInstructions).sorted { $0.rawValue < $1.rawValue }
    var seen = Set<String>(), seenAbstract = Set<String>()
    var windows = [Window()]
    var guardStops = 0

    var seedBase: UInt64 { UInt64(10_000 + number * 1_000) }

    /// A stream whose inputs and constants come from one generated case; its code
    /// comes from a fresh case each segment.
    init(number: Int, keep: Int) {
        self.number = number
        self.keep = keep
        let base = DualModeStress.makeCase(seed: UInt64(10_000 + number * 1_000), instructions: instructions,
                                           loopers: loopers)
        var settings = InterpreterSettings()
        settings.recordsProvenance = true
        settings.maxLiveWeight = 2_000_000
        interpreter.config = settings
        interpreter.load(inputs: base.inputs, constants: base.constants, program: [])
        interpreter.pushLog = []
    }

    /// Runs one segment of code, harvests what it pushed, and trims the stacks.
    mutating func feed(_ segment: Int) {
        let code = DualModeStress.makeCase(seed: seedBase + UInt64(segment + 1), instructions: instructions,
                                           loopers: loopers).program.prefix(Self.segmentLength)
        let inty = interpreter
        inty.pushLog!.removeAll(keepingCapacity: true)
        inty.place(contentsOf: Array(code), on: .exec)
        let before = inty.counter
        inty.run(stepLimit: inty.counter + 2_000)
        if !inty.stacks[.exec]!.isEmpty { inty.clear(.exec) }   // a loop that ran past its share
        windows[windows.count - 1].steps += inty.counter - before
        harvest()
        if (segment + 1) % Self.windowSize == 0 { windows.append(Window()) }
        if inty.stacks[.error]!.contains(where: { ($0 as? ErrorItem)?.kind == .guardStop }) { guardStops += 1 }
        trim()
    }

    /// Every distinct history node the segment pushed, written out and keyed.
    mutating func harvest() {
        var window = windows.removeLast()
        defer { windows.append(window) }
        var keys = Set<CruxSharing.Key>()
        for (_, item) in interpreter.pushLog! {
            guard let key = CruxSharing.key(item), keys.insert(key).inserted,
                  item.callWeight < 2_000, item.weight < 10_000 else { continue }
            window.pushed += 1
            let crux = item.crux()
            let text = crux.map { $0.pretty() }.joined(separator: " ")
            let abstract = CruxAttribution.abstractShape(crux)
            if abstract != nil { window.readingInputs += 1 }
            if seen.insert(text).inserted {
                window.new += 1
                window.lengthOfNew += crux.count
                window.longestNew = max(window.longestNew, crux.count)
                window.deepestNew = max(window.deepestNew, item.callDepth)
                if abstract != nil { window.newReadingInputs += 1 }
            }
            if let shape = abstract?.shape, seenAbstract.insert(shape).inserted { window.newAbstract += 1 }
        }
    }

    /// Each stack keeps its top `keep` items.
    func trim() {
        for stack in PushStack.allStacks where stack != .exec {
            let items = interpreter.stacks[stack]!
            guard items.count > keep else { continue }
            interpreter.clear(stack)
            interpreter.place(contentsOf: Array(items.prefix(keep)), on: stack)
        }
        interpreter.recomputeLiveWeight()
    }

    func report(segments: Int) -> [String] {
        var lines = [
            "── stream \(number): \(segments) segments of \(Self.segmentLength) tokens, \(interpreter.counter) steps; "
                + "\(seen.count) distinct cruxes, \(seenAbstract.count) distinct abstract cruxes reading an input; "
                + "\(guardStops) segments ended by a guard",
            "   window   steps  pushed    new  new%  reading inputs (new)  new abstract  mean new len  longest  deepest"
        ]
        for (i, w) in windows.enumerated() where w.pushed > 0 {
            lines.append(String(format: "   %6d %7d %7d %6d %4.0f%%  %8d (%5d) %13d %13.1f %8d %8d",
                                i * Self.windowSize, w.steps, w.pushed, w.new, 100 * Double(w.new) / Double(w.pushed),
                                w.readingInputs, w.newReadingInputs, w.newAbstract,
                                Double(w.lengthOfNew) / Double(max(w.new, 1)), w.longestNew, w.deepestNew))
        }
        return lines
    }
}
