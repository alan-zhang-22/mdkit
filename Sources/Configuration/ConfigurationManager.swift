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
    
    /// Loads configuration from a JSON file in the resources directory
    /// - Parameter fileName: Name of the JSON file (e.g., "dev-config.json")
    /// - Returns: Loaded MDKitConfig
    /// - Throws: ConfigurationError if loading fails
    public func loadConfigurationFromResources(fileName: String) throws -> MDKitConfig {
        logger.info("Loading configuration from resources: \(fileName)")
        
        // Try to find the file in common resource locations
        let searchPaths = [
            "./Resources/configs/\(fileName)",
            "./configs/\(fileName)",
            "./\(fileName)",
            Bundle.main.path(forResource: fileName.replacingOccurrences(of: ".json", with: ""), ofType: "json")
        ].compactMap { $0 }
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                logger.info("Found configuration file at: \(path)")
                return try loadConfiguration(from: path)
            }
        }
        
        logger.error("Could not find \(fileName) in any of the search paths")
        throw ConfigurationError.loadFailed(path: "resources/\(fileName)", underlying: ConfigurationError.fileNotFound("Could not find \(fileName) in any of the search paths"))
    }
    
    /// Loads configuration from a JSON file in the resources directory with fallback
    /// - Parameter fileName: Name of the JSON file (e.g., "dev-config.json")
    /// - Returns: Loaded MDKitConfig or default configuration if loading fails
    public func loadConfigurationFromResourcesWithFallback(fileName: String) -> MDKitConfig {
        do {
            return try loadConfigurationFromResources(fileName: fileName)
        } catch {
            logger.warning("Failed to load configuration from resources \(fileName), using default configuration: \(error)")
            return MDKitConfig()
        }
    }
    
    /// Creates a default configuration with values from dev-config.json if available
    /// - Returns: MDKitConfig with either loaded values or sensible defaults
    public func createDefaultConfiguration() -> MDKitConfig {
        // Try to load from dev-config.json first
        do {
            return try loadConfigurationFromResources(fileName: "dev-config.json")
        } catch {
            logger.info("Could not load dev-config.json, creating minimal default configuration")
            return createMinimalDefaultConfiguration()
        }
    }
    
    /// Creates a minimal default configuration with essential settings
    /// - Returns: MDKitConfig with minimal but functional defaults
    private func createMinimalDefaultConfiguration() -> MDKitConfig {
        return MDKitConfig(
            processing: ProcessingConfig(),
            output: OutputConfig(),
            llm: LLMConfig(),
            headerFooterDetection: HeaderFooterDetectionConfig(),
            headerDetection: HeaderDetectionConfig(markdownLevelOffset: 0),
            listDetection: ListDetectionConfig(),
            duplicationDetection: DuplicationDetectionConfig(),
            positionSorting: PositionSortingConfig(),
            markdownGeneration: MarkdownGenerationConfig(),
            ocr: OCRConfig(),
            performance: PerformanceConfig(),
            fileManagement: FileManagementConfig(),
            logging: LoggingConfig()
        )
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
                pageHeaderRegion: [0.90, 1.0],
                pageFooterRegion: [0.0, 0.1],
                enableElementMerging: true,
                mergeDistanceThreshold: 0.02,
                isMergeDistanceNormalized: true,
                enableLLMOptimization: true
            ),
            output: OutputConfig(
                outputDirectory: "./dev-output",
                filenamePattern: "{filename}_dev.md",
                createLogFiles: true,
                overwriteExisting: true,
                markdown: MarkdownConfig(
                    headerLevelOffset: 0,
                    useATXHeaders: true,
                    addTableOfContents: true,
                    preserveFormatting: true,
                    listMarkerStyle: "-"
                )
            ),
            llm: LLMConfig(
                enabled: true,
                backend: "LocalLLMClientLlama",
                modelPath: "",
                model: ModelConfig(
                    identifier: "ggml-org/Meta-Llama-3.1-8B-Instruct-Q4_0-GGUF",
                    name: "Meta Llama 3.1 8B Instruct Q4_0",
                    type: "llama",
                    downloadUrl: "",
                    localPath: "~/.localllmclient/huggingface/models/meta-llama-3.1-8b-instruct-q4_0.gguf"
                ),
                parameters: ProcessingParameters(
                    temperature: 0.3,
                    topP: 0.9,
                    topK: 40,
                    penaltyRepeat: 1.1,
                    penaltyFrequency: 0.8,
                    maxTokens: 2048,
                    batch: 256,
                    threads: 4,
                    gpuLayers: 0
                ),
                options: LLMOptions(
                    responseFormat: "markdown",
                    verbose: true,
                    streaming: true,
                    jsonMode: false
                ),
                contextManagement: ContextManagement(
                    maxContextLength: 2048,
                    overlapLength: 100,
                    chunkSize: 500,
                    enableSlidingWindow: true,
                    enableHierarchicalProcessing: true
                ),
                memoryOptimization: MemoryOptimization(
                    maxMemoryUsage: "2GB",
                    enableStreaming: true,
                    cleanupAfterBatch: true,
                    enableMemoryMapping: false
                ),
                promptTemplates: PromptTemplates(
                    languages: [
                        "zh": LanguagePrompts(
                            systemPrompt: [
                                "您是一位专业的文档处理专家，专门负责将中文PDF文档转换为结构良好的markdown格式。",
                                "您的专业领域包括：",
                                "- 中文技术文档和标准规范",
                                "- 中文工程文档和合规要求",
                                "- 中文学术论文和研究文档",
                                "- 中文商业报告和程序手册"
                            ],
                            markdownOptimizationPrompt: [
                                "开发环境 - 文档信息：",
                                "标题：{documentTitle}",
                                "页数：{pageCount}",
                                "元素数量：{elementCount}",
                                "上下文：{documentContext}",
                                "检测语言：{detectedLanguage}（置信度：{languageConfidence}）",
                                "",
                                "请优化此markdown以实现：",
                                "1. 更好的结构和组织",
                                "2. 改进的可读性和清晰度",
                                "3. 一致的格式和层次结构",
                                "4. 技术准确性保持",
                                "5. 中文文档的本地化优化",
                                "6. 开发友好的格式"
                            ]
                        ),
                        "en": LanguagePrompts(
                            systemPrompt: [
                                "You are an expert document processor specializing in converting technical documents to well-structured markdown.",
                                "Your expertise includes:",
                                "- ISO standards and technical specifications",
                                "- Engineering documentation and compliance requirements",
                                "- Academic papers and research documents",
                                "- Business reports and procedural manuals"
                            ],
                            markdownOptimizationPrompt: [
                                "Development Environment - Document: {documentTitle}",
                                "Pages: {pageCount}",
                                "Elements: {elementCount}",
                                "Context: {documentContext}",
                                "Detected Language: {detectedLanguage} (Confidence: {languageConfidence})",
                                "",
                                "Please optimize this markdown for:",
                                "1. Better structure and organization",
                                "2. Improved readability and clarity",
                                "3. Consistent formatting and hierarchy",
                                "4. Technical accuracy preservation",
                                "5. Development-friendly formatting"
                            ]
                        )
                    ],
                    defaultLanguage: "zh",
                    fallbackLanguage: "en"
                )
            ),
            headerFooterDetection: HeaderFooterDetectionConfig(
                enabled: true,
                headerFrequencyThreshold: 0.6,
                footerFrequencyThreshold: 0.6,
                regionBasedDetection: RegionBasedDetectionConfig(
                    enabled: true,
                    headerRegionY: 72.0,
                    footerRegionY: 720.0,
                    regionTolerance: 10.0
                ),
                percentageBasedDetection: PercentageBasedDetectionConfig(
                    enabled: true,
                    headerRegionHeight: 0.12,
                    footerRegionHeight: 0.12
                ),
                smartDetection: SmartDetectionConfig(
                    enabled: true,
                    excludePageNumbers: true,
                    excludeCommonHeaders: ["Page", "Chapter", "Section", "页", "章", "节"],
                    excludeCommonFooters: ["Confidential", "Copyright", "All rights reserved", "机密", "版权", "版权所有"],
                    enableContentAnalysis: true,
                    minHeaderFooterLength: 2,
                    maxHeaderFooterLength: 150
                ),
                multiRegionDetection: MultiRegionDetectionConfig(
                    enabled: false,
                    maxRegions: 2
                )
            ),
            headerDetection: HeaderDetectionConfig(
                enabled: true,
                sameLineTolerance: 8.0,
                enableHeaderMerging: true,
                enableLevelCalculation: true,
                markdownLevelOffset: 1,
                patterns: HeaderPatternsConfig(
                    numberedHeaders: [
                        "^\\d+(?:\\.\\d+)*\\s*$",
                        "^\\d+[A-Z](?:\\.\\d+)*\\s*$",
                        "^第\\d+[章节]\\s*$",
                        "^\\d+[、.．]\\s*$"
                    ],
                    letteredHeaders: [
                        "^[A-Z](?:\\.\\d+)*\\s*$",
                        "^[A-Z]\\d+(?:\\.\\d+)*\\s*$",
                        "^[甲乙丙丁戊己庚辛壬癸]\\s*$"
                    ],
                    romanHeaders: [
                        "^[IVX]+(?:\\.\\d+)*\\s*$",
                        "^[一二三四五六七八九十]+\\s*$"
                    ],
                    namedHeaders: [
                        "^(Chapter|Section|Part|章节|部分)\\s+\\d+(?:\\.\\d+)*\\s*$",
                        "^(Appendix|附录)\\s+[A-Z](?:\\.\\d+)*\\s*$",
                        "^第\\d+[章节]\\s*$"
                    ]
                ),
                levelCalculation: HeaderLevelCalculationConfig(
                    autoCalculate: true,
                    maxLevel: 6,
                    customLevels: [
                        "Part": 1,
                        "Chapter": 2,
                        "Section": 3,
                        "部分": 1,
                        "章": 2,
                        "节": 3
                    ]
                )
            ),
            listDetection: ListDetectionConfig(
                enabled: true,
                sameLineTolerance: 8.0,
                enableListItemMerging: true,
                enableLevelCalculation: true,
                enableNestedLists: true,
                patterns: ListPatternsConfig(
                    numberedMarkers: [
                        "^\\d+\\)\\s*$",
                        "^\\d+\\.\\s*$",
                        "^\\d+-\\s*$",
                        "^\\d+[、.．]\\s*$"
                    ],
                    letteredMarkers: [
                        "^[a-z]\\)\\s*$",
                        "^[a-z]\\.\\s*$",
                        "^[a-z]-\\s*$",
                        "^[甲乙丙丁戊己庚辛壬癸]\\s*$"
                    ],
                    bulletMarkers: [
                        "^[•\\-\\*]\\s*$",
                        "^[\\u2022\\u2023\\u25E6]\\s*$",
                        "^[·\\u2022]\\s*$"
                    ],
                    romanMarkers: [
                        "^[ivx]+\\)\\s*$",
                        "^[ivx]+\\.\\s*$",
                        "^[一二三四五六七八九十]+\\s*$"
                    ],
                    customMarkers: [
                        "^[\\u25A0\\u25A1\\u25A2]\\s*$",
                        "^[\\u25CB\\u25CF]\\s*$"
                    ]
                ),
                indentation: ListIndentationConfig(
                    baseIndentation: 60.0,
                    levelThreshold: 25.0,
                    enableXCoordinateAnalysis: true
                )
            ),
            duplicationDetection: DuplicationDetectionConfig(
                enabled: true,
                overlapThreshold: 0.25,
                enableLogging: true,
                logOverlaps: true,
                strictMode: false
            ),
            positionSorting: PositionSortingConfig(
                sortBy: "verticalPosition",
                tolerance: 8.0,
                enableHorizontalSorting: false,
                confidenceWeighting: 0.3
            ),
            markdownGeneration: MarkdownGenerationConfig(
                preservePageBreaks: false,
                extractImages: true,
                headerFormat: "atx",
                listFormat: "unordered",
                tableFormat: "standard",
                codeBlockFormat: "fenced"
            ),
            imageExtraction: ImageExtractionConfig(
                enabled: true,
                savePDFPagesAsImages: true,
                imageFormat: "png",
                imageQuality: 300,
                saveToOutputFolder: true,
                namingPattern: "page_{pageNumber}.png"
            ),
            ocr: OCRConfig(
                recognitionLevel: "accurate",
                languages: ["zh-CN", "en-US"],
                useLanguageCorrection: true,
                minimumTextHeight: 0.008,
                customWords: ["技术规范", "质量标准", "合规要求", "工程文档"],
                enableDocumentAnalysis: true,
                preserveLayout: true,
                tableDetection: true,
                listDetection: true,
                barcodeDetection: false
            ),
            performance: PerformanceConfig(
                maxMemoryUsage: "1GB",
                enableStreaming: true,
                batchSize: 5,
                cleanupAfterBatch: true,
                enableMultiThreading: true,
                maxThreads: 4
            ),
            fileManagement: FileManagementConfig(
                outputDirectory: "./dev-output",
                markdownDirectory: "./dev-markdown",
                logDirectory: "./dev-logs",
                tempDirectory: "./dev-temp",
                createDirectories: true,
                overwriteExisting: true,
                preserveOriginalNames: true,
                fileNamingStrategy: "timestamped"
            ),
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "dev-logs",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "5MB",
                logCategories: LogCategories(
                    ocrElements: LogCategory(
                        enabled: true,
                        format: "json",
                        includeBoundingBoxes: true,
                        includeConfidence: true
                    ),
                    documentObservation: LogCategory(
                        enabled: true,
                        format: "json",
                        includePositionData: true,
                        includeElementTypes: true
                    ),
                    markdownGeneration: LogCategory(
                        enabled: true,
                        format: "markdown",
                        includeSourceMapping: true,
                        includeProcessingTime: true
                    ),
                    llmPrompts: LogCategory(
                        enabled: true,
                        format: "json",
                        includeProcessingTime: true,
                        includeSystemPrompt: true,
                        includeUserPrompt: true,
                        includeLLMResponse: true,
                        includeTokenCounts: true
                    ),
                    llmOptimizedMarkdown: LogCategory(
                        enabled: true,
                        format: "markdown",
                        includeOptimizationDetails: true,
                        includeBeforeAfterComparison: true
                    )
                ),
                logFileNaming: LogFileNaming(
                    pattern: "dev_{timestamp}_{document}_{category}.{extension}",
                    timestampFormat: "yyyyMMdd_HHmmss",
                    includeDocumentHash: true,
                    maxFileNameLength: 100
                )
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
        
        if config.processing.mergeDistanceThreshold < 0.0 {
            errors.append("Processing merge distance threshold must be non-negative")
        }
        
        if config.processing.pageHeaderRegion.count == 2 {
            if config.processing.pageHeaderRegion[0] < 0.0 || config.processing.pageHeaderRegion[1] > 1.0 {
                errors.append("Processing page header region must be between 0.0 and 1.0")
            }
        }
        
        if config.processing.pageFooterRegion.count == 2 {
            if config.processing.pageFooterRegion[0] < 0.0 || config.processing.pageFooterRegion[1] > 1.0 {
                errors.append("Processing page footer region must be between 0.0 and 1.0")
            }
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
            
            if config.llm.parameters.batch <= 0 {
                errors.append("LLM batch size must be positive")
            }
            
            if config.llm.parameters.threads <= 0 {
                errors.append("LLM threads must be positive")
            }
            
            if config.llm.parameters.gpuLayers < 0 {
                errors.append("LLM GPU layers must be non-negative")
            }
            
            if config.llm.contextManagement.maxContextLength <= 0 {
                errors.append("LLM max context length must be positive")
            }
            
            if config.llm.contextManagement.chunkSize <= 0 {
                errors.append("LLM chunk size must be positive")
            }
        }
        
        // Validate header footer detection configuration
        if config.headerFooterDetection.enabled {
            if config.headerFooterDetection.headerFrequencyThreshold < 0.0 || config.headerFooterDetection.headerFrequencyThreshold > 1.0 {
                errors.append("Header frequency threshold must be between 0.0 and 1.0")
            }
            
            if config.headerFooterDetection.footerFrequencyThreshold < 0.0 || config.headerFooterDetection.footerFrequencyThreshold > 1.0 {
                errors.append("Footer frequency threshold must be between 0.0 and 1.0")
            }
            
            if config.headerFooterDetection.regionBasedDetection.enabled {
                if config.headerFooterDetection.regionBasedDetection.regionTolerance < 0.0 {
                    errors.append("Region tolerance must be non-negative")
                }
            }
            
            if config.headerFooterDetection.percentageBasedDetection.enabled {
                if config.headerFooterDetection.percentageBasedDetection.headerRegionHeight < 0.0 || config.headerFooterDetection.percentageBasedDetection.headerRegionHeight > 1.0 {
                    errors.append("Header region height must be between 0.0 and 1.0")
                }
                
                if config.headerFooterDetection.percentageBasedDetection.footerRegionHeight < 0.0 || config.headerFooterDetection.percentageBasedDetection.footerRegionHeight > 1.0 {
                    errors.append("Footer region height must be between 0.0 and 1.0")
                }
            }
            
            if config.headerFooterDetection.smartDetection.minHeaderFooterLength < 0 {
                errors.append("Minimum header/footer length must be non-negative")
            }
            
            if config.headerFooterDetection.smartDetection.maxHeaderFooterLength < config.headerFooterDetection.smartDetection.minHeaderFooterLength {
                errors.append("Maximum header/footer length must be greater than or equal to minimum length")
            }
        }
        
        // Validate header detection configuration
        if config.headerDetection.enabled {
            if config.headerDetection.sameLineTolerance < 0.0 {
                errors.append("Header same line tolerance must be non-negative")
            }
            
            if config.headerDetection.markdownLevelOffset < 0 {
                errors.append("Header markdown level offset must be non-negative")
            }
            
            if config.headerDetection.levelCalculation.maxLevel < 1 || config.headerDetection.levelCalculation.maxLevel > 6 {
                errors.append("Header max level must be between 1 and 6")
            }
        }
        
        // Validate list detection configuration
        if config.listDetection.enabled {
            if config.listDetection.sameLineTolerance < 0.0 {
                errors.append("List same line tolerance must be non-negative")
            }
            
            if config.listDetection.indentation.baseIndentation < 0.0 {
                errors.append("List base indentation must be non-negative")
            }
            
            if config.listDetection.indentation.levelThreshold < 0.0 {
                errors.append("List level threshold must be non-negative")
            }
        }
        
        // Validate duplication detection configuration
        if config.duplicationDetection.enabled {
            if config.duplicationDetection.overlapThreshold < 0.0 || config.duplicationDetection.overlapThreshold > 1.0 {
                errors.append("Duplication overlap threshold must be between 0.0 and 1.0")
            }
        }
        
        // Validate position sorting configuration
        if config.positionSorting.tolerance < 0.0 {
            errors.append("Position sorting tolerance must be non-negative")
        }
        
        if config.positionSorting.confidenceWeighting < 0.0 || config.positionSorting.confidenceWeighting > 1.0 {
            errors.append("Position sorting confidence weighting must be between 0.0 and 1.0")
        }
        
        // Validate OCR configuration
        if config.ocr.minimumTextHeight < 0.0 || config.ocr.minimumTextHeight > 1.0 {
            errors.append("OCR minimum text height must be between 0.0 and 1.0")
        }
        
        // Allow empty languages when auto-detection is enabled
        if config.ocr.languages.isEmpty && !config.ocr.autoDetectLanguages {
            errors.append("OCR languages cannot be empty unless auto-detection is enabled")
        }
        
        // Validate performance configuration
        if config.performance.batchSize <= 0 {
            errors.append("Performance batch size must be positive")
        }
        
        if config.performance.maxThreads <= 0 {
            errors.append("Performance max threads must be positive")
        }
        
        // Validate file management configuration
        if config.fileManagement.outputDirectory.isEmpty {
            errors.append("File management output directory cannot be empty")
        }
        
        if config.fileManagement.markdownDirectory.isEmpty {
            errors.append("File management markdown directory cannot be empty")
        }
        
        if config.fileManagement.logDirectory.isEmpty {
            errors.append("File management log directory cannot be empty")
        }
        
        if config.fileManagement.tempDirectory.isEmpty {
            errors.append("File management temp directory cannot be empty")
        }
        
        // Validate logging configuration
        if config.logging.enabled {
            if config.logging.outputFolder.isEmpty {
                errors.append("Log output folder cannot be empty when logging is enabled")
            }
            
            if config.logging.maxLogFileSize.isEmpty {
                errors.append("Log max file size cannot be empty when logging is enabled")
            }
            
            if config.logging.logFileNaming.maxFileNameLength <= 0 {
                errors.append("Log max file name length must be positive")
            }
            
            if config.logging.logFileNaming.pattern.isEmpty {
                errors.append("Log file naming pattern cannot be empty")
            }
            
            if config.logging.logFileNaming.timestampFormat.isEmpty {
                errors.append("Log timestamp format cannot be empty")
            }
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
    case fileNotFound(String)
    
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
        case .fileNotFound(let message):
            return "File not found: \(message)"
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
        case .fileNotFound(let message):
            return "File not found: \(message)"
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
        case .fileNotFound:
            return "Ensure the file exists in the expected resource path"
        }
    }
}
