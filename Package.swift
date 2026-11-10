// swift-tools-version: 6.2
import PackageDescription

// Plunge — an interpreter for Plunge, a dialect of the Push language,
// independent of any search, so it can serve a desktop app, a server-side run
// service or a script alike. Kept dependency-light (only DequeModule) and
// Linux-buildable.
//
// Note: a SwiftPM target defaults to *nonisolated* actor isolation, while an app
// target may default to MainActor (SWIFT_DEFAULT_ACTOR_ISOLATION). The explicit
// `nonisolated` annotations in the sources are therefore redundant here but
// harmless, and keep the code correct if the library is ever built under a
// MainActor default.
let package = Package(
    name: "Plunge",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "Plunge", targets: ["Plunge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.5.0"),
        // Documentation only: `swift package generate-documentation` builds the
        // DocC site. A build plugin; nothing from it is linked into the library.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "Plunge",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "PlungeTests",
            dependencies: [
                "Plunge",
                .product(name: "DequeModule", package: "swift-collections"),
            ]
        ),
    ]
)
