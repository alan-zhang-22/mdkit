// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mdkitLibraries",
    platforms: [
        .macOS(.v26) // Required for RecognizeDocumentsRequest, DocumentObservation, and async/await support
    ],
    products: [
        // Executable target for command-line usage
        .executable(
            name: "mdkit",
            targets: ["mdkitExecutable"]
        ),

        // Library targets for use in other projects
        .library(
            name: "MDKitCore",
            targets: ["mdkitCore"]
        ),
        .library(
            name: "MDKitConfiguration",
            targets: ["mdkitConfiguration"]
        ),
        .library(
            name: "MDKitFileManagement",
            targets: ["mdkitFileManagement"]
        ),
        .library(
            name: "MDKitLLM",
            targets: ["mdkitLLM"]
        ),
        .library(
            name: "MDKitProtocols",
            targets: ["mdkitProtocols"]
        )
    ],
    dependencies: [
        // LocalLLMClient is only used by the mdkitLLM module
        .package(path: "third-party/LocalLLMClient"),
        // Command-line argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0"),
        // Logging
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0")
    ],
    targets: [
        // MARK: - Executable Target (CLI application)
        .executableTarget(
            name: "mdkitExecutable",
            dependencies: [
                "mdkitCore",
                "mdkitConfiguration",
                "mdkitFileManagement",
                "mdkitLLM",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/CLI",
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .define("SWIFT_PACKAGE")
            ]
        ),
        

        

        
        // MARK: - Configuration (no external dependencies)
        .target(
            name: "mdkitConfiguration",
            dependencies: [],
            path: "Sources/Configuration"
        ),
        
        // MARK: - Core (depends on Configuration, Protocols, and FileManagement)
        .target(
            name: "mdkitCore",
            dependencies: [
                "mdkitConfiguration",
                "mdkitProtocols",
                "mdkitFileManagement"
            ],
            path: "Sources/Core",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        
        // MARK: - File Management (depends on Configuration)
        .target(
            name: "mdkitFileManagement",
            dependencies: [
                "mdkitConfiguration"
            ],
            path: "Sources/FileManagement"
        ),
        
        // MARK: - LLM (depends on Configuration, Protocols, and LocalLLMClient)
        .target(
            name: "mdkitLLM",
            dependencies: [
                "mdkitConfiguration",
                "mdkitProtocols",
                .product(name: "LocalLLMClient", package: "LocalLLMClient"),
                .product(name: "LocalLLMClientLlama", package: "LocalLLMClient")
            ],
            path: "Sources/LLM",
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .define("SWIFT_PACKAGE")
            ]
        ),
        
        // MARK: - Protocols (no dependencies)
        .target(
            name: "mdkitProtocols",
            dependencies: [],
            path: "Sources/Protocols"
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "mdkitCoreTests",
            dependencies: [
                "mdkitCore",
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Tests/CoreTests",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .testTarget(
            name: "mdkitConfigurationTests",
            dependencies: ["mdkitConfiguration"],
            path: "Tests/ConfigurationTests"
        ),
        
        .testTarget(
            name: "mdkitFileManagementTests",
            dependencies: ["mdkitFileManagement"],
            path: "Tests/FileManagementTests"
        ),
        
        .testTarget(
            name: "mdkitLLMTests",
            dependencies: ["mdkitLLM"],
            path: "Tests/LLMTests",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),

        .testTarget(
            name: "mdkitIntegrationTests",
            dependencies: [
                "mdkitCore",
                "mdkitConfiguration",
                "mdkitFileManagement",
                "mdkitLLM"
            ],
            path: "Tests/IntegrationTests",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        )
    ]
)
