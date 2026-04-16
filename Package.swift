// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CorrectMe",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.0.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "CorrectMe",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                // Tell dyld where to find Sparkle.framework at runtime
                // when the binary is inside an .app bundle.
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "CorrectMeTests",
            dependencies: ["CorrectMe"],
            path: "Tests"
        )
    ]
)
