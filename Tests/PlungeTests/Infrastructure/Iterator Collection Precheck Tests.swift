//
//  Iterator Collection Precheck Tests.swift
//  PlungeTests
//
//  `collected()` refuses an iterator that emits more than `collectionLimit`
//  items. It used to find that out by walking to the limit, which cost about
//  20 ms per refusal, and a stress-run program that retried `.codeFromIterator`
//  in a loop spent 44 minutes doing so. It now refuses up front when the O(1)
//  `certainlyEmitsMore(than:)` can prove the answer. These pin that the precheck
//  never changes a result: with it and without it, collection agrees exactly.
//

@testable import Plunge
import Testing

@Suite
struct IteratorCollectionPrecheckTests {

    /// splitmix64, so the sweep is the same every run.
    struct Mix: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Ends and strides that exercise the arithmetic: small values, and the
    /// extremes where spans and offsets overflow.
    static let ends: [Int] = [0, 1, -1, 2, 5, -5, 9, 12, -12, 40,
                              .max, .max - 1, .max - 3, .min, .min + 1, .min + 3]
    static let strides: [Int] = [0, 1, -1, 2, -2, 3, -3, 7, -7, .max, .min, .min + 1]
        + (1...12).flatMap { [Int.max / $0, -(Int.max / $0)] }

    func randomIterator(_ rng: inout Mix) -> IteratorItem {
        let cursor = Int.random(in: 0...6, using: &rng)
        switch Int.random(in: 0..<3, using: &rng) {
        case 0:
            return IteratorItem(kind: .counting(stride: Self.strides.randomElement(using: &rng)!),
                                origin: IntItem(Self.ends.randomElement(using: &rng)!),
                                destination: IntItem(Self.ends.randomElement(using: &rng)!),
                                emits: true, cursor: cursor)
        case 1:
            return IteratorItem(kind: .repeating(into: nil), origin: IntItem(7),
                                destination: IntItem(Int.random(in: -2...20, using: &rng)),
                                emits: true, cursor: cursor)
        default:
            let length = Int.random(in: 0...6, using: &rng)
            return IteratorItem(kind: .elements(into: nil), origin: VecIntItem(Array(0..<length)),
                                emits: true, cursor: cursor, laps: Int.random(in: 1...5, using: &rng))
        }
    }

    func rendered(_ items: [any Item]?) -> [String]? { items?.map { $0.pretty() } }

    @Test func `the precheck never changes what collection returns`() {
        var rng = Mix(state: 2026_11_05)
        var refusedUpFront = 0, checked = 0
        for _ in 0..<20_000 {
            let iterator = randomIterator(&rng)
            // A spent iterator never rests on a stack, so it is never collected.
            guard !iterator.isSpent else { continue }
            let limit = Int.random(in: 0...12, using: &rng)
            let walked = iterator.collectedByWalking(recording: .off, limit: limit)
            if iterator.certainlyEmitsMore(than: limit) {
                refusedUpFront += 1
                #expect(walked == nil, "precheck refused \(iterator.pretty()) at limit \(limit), but the walk did not")
            }
            #expect(rendered(iterator.collected(recording: .off, limit: limit)) == rendered(walked),
                    "\(iterator.pretty()) at limit \(limit)")
            checked += 1
        }
        #expect(checked > 10_000)
        #expect(refusedUpFront > 1_000, "the sweep reaches the refusals it is about")
    }

    /// The shapes behind the slow program: refused without walking at the real limit.
    @Test func `endless and over-long iterators are refused without walking`() {
        let limit = IteratorItem.collectionLimit
        let stalled = IteratorItem(kind: .counting(stride: 0), origin: IntItem(3), destination: IntItem(0),
                                   emits: true)
        let long = IteratorItem(kind: .counting(stride: 1), origin: IntItem(0), destination: IntItem(.max),
                                emits: true)
        let repeating = IteratorItem(kind: .repeating(into: nil), origin: IntItem(1),
                                     destination: IntItem(limit + 1), emits: true)
        let cycling = IteratorItem(kind: .elements(into: nil), origin: VecIntItem([1, 2, 3]),
                                   emits: true, laps: limit)
        for iterator in [stalled, long, repeating, cycling] {
            #expect(!iterator.isSpent)
            #expect(iterator.certainlyEmitsMore(than: limit), "\(iterator.pretty())")
        }
        let exactlyAtLimit = IteratorItem(kind: .repeating(into: nil), origin: IntItem(1),
                                          destination: IntItem(limit), emits: true)
        #expect(!exactlyAtLimit.certainlyEmitsMore(than: limit))
        #expect(exactlyAtLimit.collected(recording: .off)?.count == limit)
    }
}
