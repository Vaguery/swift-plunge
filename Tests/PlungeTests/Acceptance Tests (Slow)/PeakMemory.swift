//
//  PeakMemory.swift
//  PlungeTests
//
//  The process's peak resident set size, for the slow suites that report memory.
//  Darwin reports it through `getrusage` (`ru_maxrss`, in bytes); on Linux it is
//  `VmHWM` in `/proc/self/status`, in kB.
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

nonisolated enum PeakMemory {

    /// Peak resident memory so far, in bytes; 0 if it can't be read.
    static func residentBytes() -> Double {
        #if canImport(Darwin)
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_maxrss)
        #else
        guard let status = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8),
              let line = status.split(separator: "\n").first(where: { $0.hasPrefix("VmHWM:") }),
              let kilobytes = line.split(whereSeparator: \.isWhitespace).dropFirst().first.flatMap({ Double($0) })
        else { return 0 }
        return kilobytes * 1_024
        #endif
    }
}
