// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CorrectMe",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CorrectMe",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "CorrectMeTests",
            dependencies: ["CorrectMe"],
            path: "Tests"
        )
    ]
)
