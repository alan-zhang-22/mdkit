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
        // Async executable target for enhanced command-line usage
        .executable(
            name: "mdkit-async",
            targets: ["mdkitAsyncExecutable"]
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
            name: "MDKitLogging",
            targets: ["mdkitLogging"]
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
        // Apple's official logging package
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
        // File logging backend for swift-log
        .package(url: "https://github.com/crspybits/swift-log-file", from: "0.1.0"),
        // Command-line argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0")
    ],
    targets: [
        // MARK: - Executable Target (CLI application)
        .executableTarget(
            name: "mdkitExecutable",
            dependencies: [
                "mdkitCore",
                "mdkitConfiguration",
                "mdkitFileManagement",
                "mdkitLogging",
                "mdkitLLM",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "mdkit",
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .define("SWIFT_PACKAGE")
            ]
        ),
        
        // MARK: - Async Executable Target (Enhanced CLI with async processing)
        .executableTarget(
            name: "mdkitAsyncExecutable",
            dependencies: [
                "mdkitCore",
                "mdkitLogging",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "mdkit-async",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        
        // MARK: - Logging Configuration (depends on swift-log and swift-log-file)
        .target(
            name: "mdkitLogging",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "FileLogging", package: "swift-log-file")
            ],
            path: "Sources/Logging"
        ),
        
        // MARK: - Configuration (depends on Logging)
        .target(
            name: "mdkitConfiguration",
            dependencies: [
                "mdkitLogging"
            ],
            path: "Sources/Configuration"
        ),
        
        // MARK: - Core (depends on Configuration, Logging, Protocols, and FileManagement)
        .target(
            name: "mdkitCore",
            dependencies: [
                "mdkitConfiguration",
                "mdkitLogging",
                "mdkitProtocols",
                "mdkitFileManagement"
            ],
            path: "Sources/Core",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        
        // MARK: - File Management (depends on Configuration and Logging)
        .target(
            name: "mdkitFileManagement",
            dependencies: [
                "mdkitConfiguration",
                "mdkitLogging"
            ],
            path: "Sources/FileManagement"
        ),
        
        // MARK: - LLM (depends on Configuration, Logging, Protocols, and LocalLLMClient)
        .target(
            name: "mdkitLLM",
            dependencies: [
                "mdkitConfiguration",
                "mdkitLogging",
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
            path: "Sources/Protocols"
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "mdkitCoreTests",
            dependencies: ["mdkitCore"],
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
                "mdkitLogging",
                "mdkitLLM"
            ],
            path: "Tests/IntegrationTests",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        )
    ]
)
