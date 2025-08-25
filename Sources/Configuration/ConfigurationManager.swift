//
//  ConfigurationManager.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation
import Logging

// MARK: - Configuration Manager Protocol

public protocol ConfigurationManaging {
    func loadConfiguration(from path: String?) throws -> MDKitConfig
    func saveConfiguration(_ config: MDKitConfig, to path: String) throws
    func createSampleConfiguration(at path: String) throws
    func validateConfiguration(_ config: MDKitConfig) throws
}

// MARK: - Configuration Manager Implementation

public class ConfigurationManager: ConfigurationManaging {
    // MARK: - Properties
    
    private let defaultConfigPath = "~/.mdkit/config.json"
    private let sampleConfigPath = "~/.mdkit/config-sample.json"
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init() {
        // Create our own logger for this manager
        self.logger = Logger(label: "mdkit.configuration")
    }
    
    // MARK: - Public Methods
    
    public func loadConfiguration(from path: String? = nil) throws -> MDKitConfig {
        let configPath = path ?? defaultConfigPath
        let expandedPath = (configPath as NSString).expandingTildeInPath
        
        logger.info("Loading configuration from: \(expandedPath)")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            logger.info("Configuration file not found, using default configuration")
            return MDKitConfig()
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            let config = try JSONDecoder().decode(MDKitConfig.self, from: data)
            
            // Validate configuration
            try validateConfiguration(config)
            
            logger.info("Configuration loaded successfully from: \(expandedPath)")
            return config
            
        } catch let error as DecodingError {
            logger.error("Failed to decode configuration: \(error)")
            throw ConfigurationError.invalidFormat(error)
        } catch {
            logger.error("Failed to load configuration: \(error)")
            throw ConfigurationError.loadFailed(path: expandedPath, underlying: error)
        }
    }
    
    public func saveConfiguration(_ config: MDKitConfig, to path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        let directory = (expandedPath as NSString).deletingLastPathComponent
        
        logger.info("Saving configuration to: \(expandedPath)")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory) {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: URL(fileURLWithPath: expandedPath))
            logger.info("Configuration saved successfully to: \(expandedPath)")
        } catch {
            logger.error("Failed to save configuration: \(error)")
            throw ConfigurationError.saveFailed(path: expandedPath, underlying: error)
        }
    }
    
    public func createSampleConfiguration(at path: String) throws {
        logger.info("Creating sample configuration at: \(path)")
        
        let sampleConfig = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 0.15,
                enableHeaderFooterDetection: true,
                headerRegion: 0.0...0.12,
                footerRegion: 0.88...1.0,
                enableElementMerging: true,
                maxMergeDistance: 75.0,
                enableLLMOptimization: true
            ),
            output: OutputConfig(
                outputDirectory: "./output",
                filenamePattern: "{filename}_converted.md",
                createLogFiles: true,
                overwriteExisting: false,
                markdown: MarkdownConfig(
                    headerLevelOffset: 0,
                    useATXHeaders: true,
                    addTableOfContents: true,
                    preserveFormatting: true,
                    listMarkerStyle: .dash
                )
            ),
            llm: LLMConfig(
                enabled: true,
                model: ModelConfig(
                    identifier: "llama-2-7b-chat",
                    modelPath: nil,
                    type: .llama
                ),
                parameters: ProcessingParameters(
                    temperature: 0.6,
                    topK: 50,
                    topP: 0.85,
                    maxTokens: 4096
                ),
                prompts: PromptConfig()
            ),
            logging: LoggingConfig(
                level: "info",
                enableConsole: true,
                enableFile: true,
                logFileName: "mdkit.log",
                logDirectory: "./logs",
                maxFileSize: 1024 * 1024, // 1MB
                maxFiles: 5,
                includeTimestamps: true,
                includeLogLevels: true
            )
        )
        
        try saveConfiguration(sampleConfig, to: path)
    }
    
    public func validateConfiguration(_ config: MDKitConfig) throws {
        var errors: [String] = []
        
        // Validate processing configuration
        if config.processing.overlapThreshold < 0.0 || config.processing.overlapThreshold > 1.0 {
            errors.append("Processing overlap threshold must be between 0.0 and 1.0")
        }
        
        if config.processing.maxMergeDistance < 0.0 {
            errors.append("Processing max merge distance must be non-negative")
        }
        
        if config.processing.headerRegion.lowerBound < 0.0 || config.processing.headerRegion.upperBound > 1.0 {
            errors.append("Processing header region must be between 0.0 and 1.0")
        }
        
        if config.processing.footerRegion.lowerBound < 0.0 || config.processing.footerRegion.upperBound > 1.0 {
            errors.append("Processing footer region must be between 0.0 and 1.0")
        }
        
        // Validate output configuration
        if config.output.outputDirectory.isEmpty {
            errors.append("Output directory cannot be empty")
        }
        
        if config.output.filenamePattern.isEmpty {
            errors.append("Output filename pattern cannot be empty")
        }
        
        // Validate LLM configuration
        if config.llm.enabled {
            if config.llm.model.identifier.isEmpty {
                errors.append("LLM model identifier cannot be empty when LLM is enabled")
            }
            
            if config.llm.parameters.temperature < 0.0 || config.llm.parameters.temperature > 1.0 {
                errors.append("LLM temperature must be between 0.0 and 1.0")
            }
            
            if config.llm.parameters.topP < 0.0 || config.llm.parameters.topP > 1.0 {
                errors.append("LLM top-p must be between 0.0 and 1.0")
            }
            
            if config.llm.parameters.maxTokens <= 0 {
                errors.append("LLM max tokens must be positive")
            }
        }
        
        // Validate logging configuration
        if config.logging.enableFile && config.logging.logDirectory.isEmpty {
            errors.append("Log directory must be specified when file logging is enabled")
        }
        
        // If there are validation errors, throw them
        if !errors.isEmpty {
            logger.warning("Configuration validation found \(errors.count) issues")
            throw ConfigurationError.validationFailed(errors)
        }
        
        logger.info("Configuration validation passed successfully")
    }
}

// MARK: - Configuration Errors

public enum ConfigurationError: LocalizedError {
    case loadFailed(path: String, underlying: Error)
    case saveFailed(path: String, underlying: Error)
    case validationFailed([String])
    case invalidFormat(Error)
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let path, let underlying):
            return "Failed to load configuration from \(path): \(underlying.localizedDescription)"
        case .saveFailed(let path, let underlying):
            return "Failed to save configuration to \(path): \(underlying.localizedDescription)"
        case .validationFailed(let errors):
            return "Configuration validation failed:\n" + errors.joined(separator: "\n")
        case .invalidFormat(let underlying):
            return "Invalid configuration format: \(underlying.localizedDescription)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .loadFailed(let path, _):
            return "Could not read configuration file at \(path)"
        case .saveFailed(let path, _):
            return "Could not write configuration file to \(path)"
        case .validationFailed:
            return "Configuration values are invalid"
        case .invalidFormat:
            return "Configuration file format is invalid"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .loadFailed:
            return "Check that the file exists and is readable, or use default configuration"
        case .saveFailed:
            return "Check that the directory exists and is writable"
        case .validationFailed:
            return "Review the configuration values and ensure they are within valid ranges"
        case .invalidFormat:
            return "Ensure the configuration file is valid JSON"
        }
    }
}
