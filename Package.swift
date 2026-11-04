// swift-tools-version: 6.2
import PackageDescription

// PushInterpreter — the self-contained Push-language interpreter core, extracted
// from the PropellerWithStructs app so it can be reused here, in a server-side
// run service, and in a federated mesh. Kept dependency-light (only DequeModule)
// and Linux-buildable on the way to becoming a standalone public library.
//
// Note: a SwiftPM target defaults to *nonisolated* actor isolation, unlike the
// app target (which sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor). The explicit
// `nonisolated` annotations in the sources are therefore redundant here but
// harmless, and keep the code robust if a default is ever imposed.
let package = Package(
    name: "PushInterpreter",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "PushInterpreter", targets: ["PushInterpreter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "PushInterpreter",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "PushInterpreterTests",
            dependencies: [
                "PushInterpreter",
                .product(name: "DequeModule", package: "swift-collections"),
            ]
        ),
    ]
)
