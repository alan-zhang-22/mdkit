//
//  MDKitConfig.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation
import Logging

// MARK: - Main Configuration

public struct MDKitConfig: Codable {
    // MARK: - Document Processing
    public let processing: ProcessingConfig
    public let output: OutputConfig
    public let llm: LLMConfig
    public let logging: LoggingConfig
    
    public init(
        processing: ProcessingConfig = ProcessingConfig(),
        output: OutputConfig = OutputConfig(),
        llm: LLMConfig = LLMConfig(),
        logging: LoggingConfig = LoggingConfig()
    ) {
        self.processing = processing
        self.output = output
        self.llm = llm
        self.logging = logging
    }
}

// MARK: - Processing Configuration

public struct ProcessingConfig: Codable {
    /// Overlap threshold for duplicate detection (0.0 to 1.0)
    public let overlapThreshold: Double
    
    /// Whether to enable header/footer detection
    public let enableHeaderFooterDetection: Bool
    
    /// Header/footer detection regions (percentage of page height)
    public let headerRegion: ClosedRange<Double>
    public let footerRegion: ClosedRange<Double>
    
    /// Whether to merge split headers and list items
    public let enableElementMerging: Bool
    
    /// Maximum distance for merging elements (in points)
    public let maxMergeDistance: Double
    
    /// Whether to use LLM for content optimization
    public let enableLLMOptimization: Bool
    
    public init(
        overlapThreshold: Double = 0.1,
        enableHeaderFooterDetection: Bool = true,
        headerRegion: ClosedRange<Double> = 0.0...0.15,
        footerRegion: ClosedRange<Double> = 0.85...1.0,
        enableElementMerging: Bool = true,
        maxMergeDistance: Double = 50.0,
        enableLLMOptimization: Bool = true
    ) {
        self.overlapThreshold = overlapThreshold
        self.enableHeaderFooterDetection = enableHeaderFooterDetection
        self.headerRegion = headerRegion
        self.footerRegion = footerRegion
        self.enableElementMerging = enableElementMerging
        self.maxMergeDistance = maxMergeDistance
        self.enableLLMOptimization = enableLLMOptimization
    }
}

// MARK: - Output Configuration

public struct OutputConfig: Codable {
    /// Output directory for generated files
    public let outputDirectory: String
    
    /// Output filename pattern
    public let filenamePattern: String
    
    /// Whether to create log files
    public let createLogFiles: Bool
    
    /// Whether to overwrite existing files
    public let overwriteExisting: Bool
    
    /// Markdown formatting options
    public let markdown: MarkdownConfig
    
    public init(
        outputDirectory: String = "./output",
        filenamePattern: String = "{filename}.md",
        createLogFiles: Bool = true,
        overwriteExisting: Bool = false,
        markdown: MarkdownConfig = MarkdownConfig()
    ) {
        self.outputDirectory = outputDirectory
        self.filenamePattern = filenamePattern
        self.createLogFiles = createLogFiles
        self.overwriteExisting = overwriteExisting
        self.markdown = markdown
    }
}

// MARK: - Markdown Configuration

public struct MarkdownConfig: Codable {
    /// Header level offset (adds to all header levels)
    public let headerLevelOffset: Int
    
    /// Whether to use ATX headers (# ## ###)
    public let useATXHeaders: Bool
    
    /// Whether to add table of contents
    public let addTableOfContents: Bool
    
    /// Whether to preserve original formatting
    public let preserveFormatting: Bool
    
    /// List marker style
    public let listMarkerStyle: ListMarkerStyle
    
    public init(
        headerLevelOffset: Int = 0,
        useATXHeaders: Bool = true,
        addTableOfContents: Bool = false,
        preserveFormatting: Bool = true,
        listMarkerStyle: ListMarkerStyle = .dash
    ) {
        self.headerLevelOffset = headerLevelOffset
        self.useATXHeaders = useATXHeaders
        self.addTableOfContents = addTableOfContents
        self.preserveFormatting = preserveFormatting
        self.listMarkerStyle = listMarkerStyle
    }
}

// MARK: - List Marker Style

public enum ListMarkerStyle: String, CaseIterable, Codable {
    case dash = "-"
    case asterisk = "*"
    case plus = "+"
    case number = "1."
}

// MARK: - LLM Configuration

public struct LLMConfig: Codable {
    /// Whether to enable LLM processing
    public let enabled: Bool
    
    /// LLM model configuration
    public let model: ModelConfig
    
    /// Processing parameters
    public let parameters: ProcessingParameters
    
    /// Prompt templates
    public let prompts: PromptConfig
    
    public init(
        enabled: Bool = true,
        model: ModelConfig = ModelConfig(),
        parameters: ProcessingParameters = ProcessingParameters(),
        prompts: PromptConfig = PromptConfig()
    ) {
        self.enabled = enabled
        self.model = model
        self.parameters = parameters
        self.prompts = prompts
    }
}

// MARK: - Logging Configuration

public struct LoggingConfig: Codable {
    /// The minimum log level to output
    public let level: String
    
    /// Whether to enable console logging
    public let enableConsole: Bool
    
    /// Whether to enable file logging
    public let enableFile: Bool
    
    /// The log file name (without path)
    /// swift-log-file automatically creates rotated files: mdkit.log, mdkit.log.1, mdkit.log.2, etc.
    public let logFileName: String
    
    /// The directory where log files should be written
    /// Default: "./logs" - creates a logs directory in the current working directory
    public let logDirectory: String
    
    /// Maximum size of each log file in bytes
    /// When a log file reaches this size, it's rotated and a new one is created
    public let maxFileSize: Int
    
    /// Maximum number of log files to keep
    /// This includes the active log file and all rotated files
    /// Example: if maxFiles = 3, you'll have: mdkit.log, mdkit.log.1, mdkit.log.2
    public let maxFiles: Int
    
    /// Whether to include timestamps in log messages
    public let includeTimestamps: Bool
    
    /// Whether to include log levels in log messages
    public let includeLogLevels: Bool
    
    public init(
        level: String = "info",
        enableConsole: Bool = true,
        enableFile: Bool = true,
        logFileName: String = "mdkit.log",
        logDirectory: String = "./logs",
        maxFileSize: Int = 1024 * 1024, // 1MB
        maxFiles: Int = 5,
        includeTimestamps: Bool = true,
        includeLogLevels: Bool = true
    ) {
        self.level = level
        self.enableConsole = enableConsole
        self.enableFile = enableFile
        self.logFileName = logFileName
        self.logDirectory = logDirectory
        self.maxFileSize = maxFileSize
        self.maxFiles = maxFiles
        self.includeTimestamps = includeTimestamps
        self.includeLogLevels = includeLogLevels
    }
    
    /// Convert string level to Logger.Level
    public var loggerLevel: Logger.Level {
        switch level.lowercased() {
        case "debug": return .debug
        case "info": return .info
        case "warning": return .warning
        case "error": return .error
        case "critical": return .critical
        default: return .info
        }
    }
}

// MARK: - Model Configuration

public struct ModelConfig: Codable {
    /// Model identifier
    public let identifier: String
    
    /// Model file path
    public let modelPath: String?
    
    /// Model type
    public let type: ModelType
    
    public init(
        identifier: String = "llama-2-7b-chat",
        modelPath: String? = nil,
        type: ModelType = .llama
    ) {
        self.identifier = identifier
        self.modelPath = modelPath
        self.type = type
    }
}

// MARK: - Model Type

public enum ModelType: String, CaseIterable, Codable {
    case llama = "llama"
    case gemma = "gemma"
    case mistral = "mistral"
    case custom = "custom"
}

// MARK: - Processing Parameters

public struct ProcessingParameters: Codable {
    /// Temperature for text generation (0.0 to 1.0)
    public let temperature: Double
    
    /// Top-K sampling parameter
    public let topK: Int
    
    /// Top-P sampling parameter (0.0 to 1.0)
    public let topP: Double
    
    /// Maximum output tokens
    public let maxTokens: Int
    
    public init(
        temperature: Double = 0.7,
        topK: Int = 40,
        topP: Double = 0.9,
        maxTokens: Int = 2048
    ) {
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.maxTokens = maxTokens
    }
}

// MARK: - Prompt Configuration

public struct PromptConfig: Codable {
    /// System prompt for LLM
    public let systemPrompt: String
    
    /// Content optimization prompt
    public let optimizationPrompt: String
    
    /// Language detection prompt
    public let languagePrompt: String
    
    public init(
        systemPrompt: String = "You are a helpful assistant that converts PDF content to well-formatted Markdown.",
        optimizationPrompt: String = "Please optimize the following content for Markdown formatting, preserving the structure and meaning while improving readability.",
        languagePrompt: String = "Please detect the language of the following text and respond with just the language code (e.g., 'en', 'es', 'fr')."
    ) {
        self.systemPrompt = systemPrompt
        self.optimizationPrompt = optimizationPrompt
        self.languagePrompt = languagePrompt
    }
}
