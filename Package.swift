// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-voice-recordings",
    // macOS only: the store it reads (CloudRecordings.db and its .m4a files)
    // is the Mac's own copy of the Voice Memos library.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "VoiceRecordings", targets: ["VoiceRecordings"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-subtitle-kit.git", from: "0.1.0"),
        .package(url: "https://github.com/arraypress/swift-sqlite-reader.git", from: "0.2.0"),
    ],
    targets: [
        // Synchronous and local: no transport, nothing to await, so the
        // nonisolated-nonsending feature is left off.
        .target(name: "VoiceRecordings", dependencies: [
            .product(name: "SubtitleKit", package: "swift-subtitle-kit"),
            .product(name: "SQLiteReader", package: "swift-sqlite-reader"),
        ]),
        .testTarget(name: "VoiceRecordingsTests", dependencies: ["VoiceRecordings"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
