//
//  FileManager.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation
import Logging
import mdkitConfiguration

// MARK: - Output Type Enum

public enum OutputType: String, CaseIterable, Codable {
    case ocr = "ocr"
    case markdown = "markdown"
    case prompt = "prompt"
    case markdownLLM = "markdown_llm"
    
    // File extension for each type
    public var fileExtension: String {
        switch self {
        case .ocr: return "txt"
        case .markdown: return "md"
        case .prompt: return "txt"
        case .markdownLLM: return "md"
        }
    }
    
    // Directory name for each type
    public var directoryName: String {
        switch self {
        case .ocr: return "ocr"
        case .markdown: return "markdown"
        case .prompt: return "prompts"
        case .markdownLLM: return "markdown-llm"
        }
    }
    
    // Description for logging and UI
    public var description: String {
        switch self {
        case .ocr: return "OCR Text Output"
        case .markdown: return "Markdown Output"
        case .prompt: return "LLM Prompts"
        case .markdownLLM: return "LLM-Optimized Markdown"
        }
    }
}

// MARK: - File Manager Protocol

public protocol FileManaging: Sendable {
    // Stream lifecycle management with output type
    func openOutputStream(for inputFile: String, outputType: OutputType, append: Bool) throws -> OutputStream
    func closeOutputStream(_ stream: OutputStream) throws
    func generateOutputPaths(for inputFile: String, outputType: OutputType) -> OutputPaths
    func ensureDirectoriesExist() throws
    func cleanupTempFiles() throws
    
    // Writing operations
    func writeString(_ content: String, to stream: OutputStream) throws
    func writeLine(_ content: String, to stream: OutputStream) throws
    func appendToFile(_ content: String, for inputFile: String, outputType: OutputType) throws
}

// MARK: - File Manager Implementation

public final class MDKitFileManager: FileManaging {
    // MARK: - Properties
    
    private let config: FileManagementConfig
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init(config: FileManagementConfig) {
        self.config = config
        self.logger = Logger(label: "mdkit.filemanager")
        setupDirectories()
    }
    
    // MARK: - Public Methods
    
    public func openOutputStream(for inputFile: String, outputType: OutputType, append: Bool = true) throws -> OutputStream {
        let paths = generateOutputPaths(for: inputFile, outputType: outputType)
        
        // Ensure directories exist
        try ensureDirectoriesExist()
        
        // Get output type config for this output type
        let outputTypeConfig = getOutputTypeConfig(for: outputType)
        
        // Check if file exists and handle overwrite protection
        if let outputPath = paths.outputFiles[outputType], 
           !outputTypeConfig.overwriteExisting && 
           Foundation.FileManager.default.fileExists(atPath: outputPath) {
            throw FileManagerError.fileAlreadyExists(path: outputPath)
        }
        
        // Create output stream
        guard let outputPath = paths.outputFiles[outputType] else {
            throw FileManagerError.invalidOutputPath
        }
        
        // Ensure the output directory exists
        let outputDir = (outputPath as NSString).deletingLastPathComponent
        try createDirectoryIfNeeded(outputDir)
        
        // For file operations, we need to ensure the file exists and is properly set up
        if !Foundation.FileManager.default.fileExists(atPath: outputPath) {
            // Create empty file first with some initial content to ensure proper file structure
            try "".write(toFile: outputPath, atomically: true, encoding: .utf8)
        }
        
        guard let stream = OutputStream(url: URL(fileURLWithPath: outputPath), append: append) else {
            throw FileManagerError.cannotCreateOutputStream(path: outputPath)
        }
        
        stream.open()
        logger.info("Opened output stream for \(outputType.description) at: \(outputPath)")
        
        return stream
    }
    
    public func closeOutputStream(_ stream: OutputStream) throws {
        stream.close()
        logger.debug("Closed output stream")
    }
    
    // MARK: - Convenience Methods
    
    /// Write a string directly to an output stream
    /// - Parameters:
    ///   - content: The string content to write
    ///   - stream: The output stream to write to
    /// - Throws: Error if writing fails
    public func writeString(_ content: String, to stream: OutputStream) throws {
        let data = content.data(using: .utf8)!
        
        // Check if stream is open and ready
        guard stream.streamStatus == .open else {
            throw FileManagerError.writeFailed(expected: data.count, actual: -1)
        }
        
        // Debug: log what we're writing
        logger.debug("Writing string: '\(content)' (length: \(content.count))")
        
        // Use the same approach as the working sample code
        let bytesWritten = data.withUnsafeBytes {
            stream.write($0.baseAddress!, maxLength: data.count)
        }
        
        if bytesWritten < 0 {
            // Get the stream error
            if stream.streamError != nil {
                throw FileManagerError.writeFailed(expected: data.count, actual: bytesWritten)
            } else {
                throw FileManagerError.writeFailed(expected: data.count, actual: bytesWritten)
            }
        } else if bytesWritten != data.count {
            throw FileManagerError.writeFailed(expected: data.count, actual: bytesWritten)
        }
        
        // Debug: log what was written
        logger.debug("Successfully wrote \(bytesWritten) bytes")
    }
    
    /// Write a string with a newline to an output stream
    /// - Parameters:
    ///   - content: The string content to write
    ///   - stream: The output stream to write to
    /// - Throws: Error if writing fails
    public func writeLine(_ content: String, to stream: OutputStream) throws {
        try writeString(content + "\n", to: stream)
    }
    
    /// Append content to an existing file by reopening the stream
    /// This method is useful for page-by-page processing where multiple writes to the same stream don't work reliably
    /// - Parameters:
    ///   - content: The string content to append
    ///   - inputFile: The input file name
    ///   - outputType: The output type
    /// - Throws: Error if writing fails
    public func appendToFile(_ content: String, for inputFile: String, outputType: OutputType) throws {
        let paths = generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        // Ensure parent directories exist
        let outputDir = (outputPath as NSString).deletingLastPathComponent
        try createDirectoryIfNeeded(outputDir)
        
        // Open stream in append mode
        guard let stream = OutputStream(url: URL(fileURLWithPath: outputPath), append: true) else {
            throw FileManagerError.cannotCreateOutputStream(path: outputPath)
        }
        
        stream.open()
        defer {
            stream.close()
        }
        
        // Write the content
        try writeString(content, to: stream)
    }
    
    public func generateOutputPaths(for inputFile: String, outputType: OutputType) -> OutputPaths {
        let baseDir = config.outputDirectory
        let outputDir = "\(baseDir)/\(getOutputDirectoryName(for: inputFile, outputType: outputType))"
        let fileName = generateFileName(for: inputFile, outputType: outputType)
        
        var outputFiles: [OutputType: String] = [:]
        outputFiles[outputType] = "\(outputDir)/\(fileName)"
        
        return OutputPaths(
            baseDirectory: baseDir,
            outputFiles: outputFiles,
            tempDirectory: "\(config.tempDirectory)/\(getTempDirectoryName(for: inputFile))"
        )
    }
    
    public func ensureDirectoriesExist() throws {
        if config.createDirectories {
            try createDirectoryIfNeeded(config.outputDirectory)
            try createDirectoryIfNeeded(config.tempDirectory)
            try createDirectoryIfNeeded(config.markdownDirectory)
            try createDirectoryIfNeeded(config.logDirectory)
        }
    }
    
    public func cleanupTempFiles() throws {
        let tempDir = config.tempDirectory
        
        guard Foundation.FileManager.default.fileExists(atPath: tempDir) else {
            logger.debug("Temp directory does not exist: \(tempDir)")
            return
        }
        
        let contents = try Foundation.FileManager.default.contentsOfDirectory(atPath: tempDir)
        for item in contents {
            let itemPath = "\(tempDir)/\(item)"
            try Foundation.FileManager.default.removeItem(atPath: itemPath)
            logger.debug("Removed temp item: \(itemPath)")
        }
        
        logger.info("Cleaned up temp directory: \(tempDir)")
    }
    
    // MARK: - Private Methods
    
    private func setupDirectories() {
        do {
            try ensureDirectoriesExist()
        } catch {
            logger.error("Failed to setup directories: \(error)")
        }
    }
    
    private func getOutputTypeConfig(for outputType: OutputType) -> OutputTypeConfig {
        // Get specific config for this output type, or use defaults
        return config.outputTypeConfigs[outputType] ?? OutputTypeConfig(
            enabled: true,
            directory: nil,
            fileNamingStrategy: config.fileNamingStrategy,
            overwriteExisting: config.overwriteExisting
        )
    }
    
    private func getOutputDirectoryName(for inputFile: String, outputType: OutputType) -> String {
        let baseName = (inputFile as NSString).deletingPathExtension
        return "\(baseName)/\(outputType.directoryName)"
    }
    
    private func generateFileName(for inputFile: String, outputType: OutputType) -> String {
        let baseName = (inputFile as NSString).deletingPathExtension
        
        switch config.fileNamingStrategy {
        case "timestamped":
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = formatter.string(from: Date())
            return "\(baseName)_\(timestamp).\(outputType.fileExtension)"
            
        case "original":
            return "\(baseName).\(outputType.fileExtension)"
            
        case "custom":
            // Could support custom patterns from config
            return "\(baseName)_\(outputType.rawValue).\(outputType.fileExtension)"
            
        default:
            return "\(baseName).\(outputType.fileExtension)"
        }
    }
    
    private func getTempDirectoryName(for inputFile: String) -> String {
        let baseName = (inputFile as NSString).deletingPathExtension
        return "\(baseName)_temp"
    }
    
    private func createDirectoryIfNeeded(_ path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        if !Foundation.FileManager.default.fileExists(atPath: expandedPath) {
            try Foundation.FileManager.default.createDirectory(
                atPath: expandedPath,
                withIntermediateDirectories: true,
                attributes: [FileAttributeKey: Any]()
            )
            logger.debug("Created directory: \(expandedPath)")
        }
    }
}

// MARK: - Supporting Types

// Using the unified FileManagementConfig from mdkitConfiguration
public typealias FileManagementConfig = mdkitConfiguration.FileManagementConfig

public struct OutputPaths {
    public let baseDirectory: String
    public let outputFiles: [OutputType: String]
    public let tempDirectory: String
    
    public init(baseDirectory: String, outputFiles: [OutputType: String], tempDirectory: String) {
        self.baseDirectory = baseDirectory
        self.outputFiles = outputFiles
        self.tempDirectory = tempDirectory
    }
    
    // Convenience accessor for specific output type
    public func path(for outputType: OutputType) -> String? {
        return outputFiles[outputType]
    }
}

// MARK: - Error Types

public enum FileManagerError: Error, LocalizedError {
    case fileAlreadyExists(path: String)
    case cannotCreateOutputStream(path: String)
    case invalidOutputPath
    case directoryCreationFailed(path: String)
    case cleanupFailed
    case writeFailed(expected: Int, actual: Int)
    
    public var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let path):
            return "File already exists at path: \(path)"
        case .cannotCreateOutputStream(let path):
            return "Cannot create output stream at path: \(path)"
        case .invalidOutputPath:
            return "Invalid output path generated"
        case .directoryCreationFailed(let path):
            return "Failed to create directory at path: \(path)"
        case .cleanupFailed:
            return "Failed to cleanup temporary files"
        case .writeFailed(let expected, let actual):
            return "Failed to write data. Expected \(expected) bytes, wrote \(actual) bytes."
        }
    }
}

// MARK: - Configuration Extensions

// Extend FileManagementConfig to support per-output-type configurations
extension FileManagementConfig {
    public var outputTypeConfigs: [OutputType: OutputTypeConfig] {
        // For now, return default configs for all types
        // This can be enhanced later with actual per-type configuration
        var configs: [OutputType: OutputTypeConfig] = [:]
        for outputType in OutputType.allCases {
            configs[outputType] = OutputTypeConfig(
                enabled: true,
                directory: nil, // Use default directory structure
                fileNamingStrategy: self.fileNamingStrategy,
                overwriteExisting: self.overwriteExisting
            )
        }
        return configs
    }
}

public struct OutputTypeConfig {
    public let enabled: Bool
    public let directory: String?
    public let fileNamingStrategy: String
    public let overwriteExisting: Bool
    
    public init(
        enabled: Bool = true,
        directory: String? = nil,
        fileNamingStrategy: String = "timestamped",
        overwriteExisting: Bool = true
    ) {
        self.enabled = enabled
        self.directory = directory
        self.fileNamingStrategy = fileNamingStrategy
        self.overwriteExisting = overwriteExisting
    }
}
