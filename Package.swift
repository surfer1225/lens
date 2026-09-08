// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lens",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Lens", targets: ["Lens"]),
        .library(name: "LensCore", targets: ["LensCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "1.10.0"),
    ],
    targets: [
        // Pure geometry and settings. No AppKit, no Accessibility, no I/O — unit-testable
        // without any system permissions.
        .target(name: "LensCore"),

        // The Accessibility / NSScreen boundary. Everything that talks to other apps' windows.
        .target(name: "LensAX", dependencies: ["LensCore"]),

        // The app itself: menu bar item, settings UI, global hotkeys.
        .executableTarget(
            name: "Lens",
            dependencies: [
                "LensCore",
                "LensAX",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]
        ),

        .testTarget(name: "LensCoreTests", dependencies: ["LensCore"]),
    ]
)
