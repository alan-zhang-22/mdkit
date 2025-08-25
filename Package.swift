// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mdkitLibraries",
    platforms: [
        .macOS(.v14) // Compatible with Swift Package Manager 6.0
    ],
    products: [
        // Library targets only - no executable conflicts
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
        )
    ],
    dependencies: [
        // LocalLLMClient is only used by the mdkitLLM module
        .package(path: "third-party/LocalLLMClient")
    ],
    targets: [
        // MARK: - Logging (no dependencies)
        .target(
            name: "mdkitLogging",
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
        
        // MARK: - Core (depends on Configuration and Logging)
        .target(
            name: "mdkitCore",
            dependencies: [
                "mdkitConfiguration",
                "mdkitLogging"
            ],
            path: "Sources/Core"
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
        
        // MARK: - LLM (depends on Configuration, Logging, and LocalLLMClient)
        .target(
            name: "mdkitLLM",
            dependencies: [
                "mdkitConfiguration",
                "mdkitLogging",
                .product(name: "LocalLLMClient", package: "LocalLLMClient"),
                .product(name: "LocalLLMClientLlama", package: "LocalLLMClient")
            ],
            path: "Sources/LLM",
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "mdkitCoreTests",
            dependencies: ["mdkitCore"],
            path: "Tests/CoreTests"
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
            name: "mdkitLoggingTests",
            dependencies: ["mdkitLogging"],
            path: "Tests/LoggingTests"
        ),
        .testTarget(
            name: "mdkitLLMTests",
            dependencies: ["mdkitLLM"],
            path: "Tests/LLMTests"
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
            path: "Tests/IntegrationTests"
        )
    ]
)
