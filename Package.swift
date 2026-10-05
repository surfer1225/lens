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
        // Pinned to the exact commit Scripts/package.sh verifies and the Homebrew formula
        // builds, so every build path compiles the same dependency code.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", revision: "70caa8dea43e2d273cd5ab78885d7eff01df550c"),
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
