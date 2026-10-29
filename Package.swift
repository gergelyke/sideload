// swift-tools-version:6.4
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "sideload",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SideloadSDK", targets: ["SwiftUI"]),
        .executable(name: "sideload", targets: ["CLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0"),
    ],
    targets: [
        // MARK: System library shims

        .systemLibrary(
            name: "CCairo",
            path: "Sources/System/CCairo",
            pkgConfig: "cairo",
            providers: [.apt(["libcairo2-dev"])]
        ),
        .systemLibrary(
            name: "CSDL2",
            path: "Sources/System/CSDL2",
            pkgConfig: "sdl2",
            providers: [.apt(["libsdl2-dev"])]
        ),
        .systemLibrary(
            name: "CHarfBuzz",
            path: "Sources/System/CHarfBuzz",
            pkgConfig: "harfbuzz",
            providers: [.apt(["libharfbuzz-dev"])]
        ),
        .systemLibrary(
            name: "CFreeType",
            path: "Sources/System/CFreeType",
            pkgConfig: "freetype2",
            providers: [.apt(["libfreetype-dev"])]
        ),

        // MARK: Internal Sideload modules

        .target(
            name: "SideloadRender",
            dependencies: ["CCairo", "CHarfBuzz", "CFreeType"],
            path: "Sources/Sideload/SideloadRender",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SideloadShell",
            dependencies: ["SideloadRender", "CSDL2"],
            path: "Sources/Sideload/SideloadShell",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SideloadRuntime",
            dependencies: ["SideloadShell", "SideloadRender"],
            path: "Sources/Sideload/SideloadRuntime",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SideloadBuild",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Sources/Sideload/SideloadBuild",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: SDK (public, Apple-named API surface)

        .macro(
            name: "SwiftUIMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/SDK/SwiftUIMacros",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SwiftUI",
            dependencies: ["SideloadRuntime", "SideloadRender", "SideloadShell", "SwiftUIMacros"],
            path: "Sources/SDK/SwiftUI",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: CLI

        .executableTarget(
            name: "CLI",
            dependencies: [
                "SideloadBuild",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: Tests

        .testTarget(
            name: "SideloadRenderTests",
            dependencies: ["SideloadRender"]
        ),
        .testTarget(
            name: "SideloadShellTests",
            dependencies: ["SideloadShell"]
        ),
        .testTarget(
            name: "SideloadRuntimeTests",
            dependencies: ["SideloadRuntime"]
        ),
        .testTarget(
            name: "SideloadBuildTests",
            dependencies: ["SideloadBuild"],
            exclude: ["Fixtures"]
        ),
        .testTarget(
            name: "SwiftUITests",
            dependencies: ["SwiftUI", "SideloadRender", "SideloadRuntime"]
        ),
        .testTarget(
            name: "SwiftUIMacrosTests",
            dependencies: [
                "SwiftUIMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "EndToEndTests",
            dependencies: ["SwiftUI"]
        ),
    ]
)
