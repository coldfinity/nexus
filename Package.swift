// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nexus",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Vendored fork (Vendor/SwiftTerm) patched to expose a line-height
        // multiplier; upstream SwiftTerm has no public knob for it.
        .package(path: "Vendor/SwiftTerm")
    ],
    targets: [
        // Vendored Lua 5.4 runtime (Vendor/Lua) for the Lua config file.
        .target(
            name: "CLua",
            path: "Vendor/Lua",
            exclude: [
                "all", "makefile", "manual", "README.md", "testes",
                "lua.c", "ltests.c", "onelua.c"
            ],
            publicHeadersPath: "include",
            cSettings: [.define("LUA_USE_MACOSX")]
        ),
        .executableTarget(
            name: "Nexus",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                "CLua"
            ],
            path: "Sources/Nexus"
        ),
        .testTarget(
            name: "NexusTests",
            dependencies: ["Nexus"],
            path: "Tests/NexusTests"
        )
    ],
    // Bridging AppKit delegates (SwiftTerm) is far smoother under the Swift 5
    // language mode; strict Swift 6 concurrency across those boundaries is not
    // worth the friction for this app.
    swiftLanguageModes: [.v5]
)
