// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkidmarkApp",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "SkidmarkApp",
            targets: ["SkidmarkApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "SkidmarkApp",
            dependencies: [],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "SETUP.md",
                "Package.swift",
                "test_output.log"
            ],
            sources: [
                "Models",
                "ViewModels",
                "Views",
                "Services",
                "Utilities",
                "SkidmarkApp.swift"
            ],
            resources: [
                .process("SupportingFiles/Assets.xcassets")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SkidmarkAppTests",
            dependencies: [
                "SkidmarkApp",
                .product(name: "SwiftCheck", package: "SwiftCheck")
            ],
            path: "Tests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
