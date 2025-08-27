import XCTest
@testable import mdkitConfiguration

final class ConfigurationValidatorTests: XCTestCase {
    
    var validator: ConfigurationValidator!
    
    override func setUp() {
        super.setUp()
        validator = ConfigurationValidator()
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }
    
    // MARK: - Valid Configuration Tests
    
    func testValidDefaultConfiguration() throws {
        let config = MDKitConfig()
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    func testValidCustomConfiguration() throws {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 0.5,
                enableHeaderFooterDetection: true,
                headerRegion: [0.0, 0.1],
                footerRegion: [0.9, 1.0],
                enableElementMerging: true,
                mergeDistanceThreshold: 25.0,
                isMergeDistanceNormalized: false,
                horizontalMergeThreshold: 50.0,
                isHorizontalMergeThresholdNormalized: false,
                enableLLMOptimization: true
            ),
            output: OutputConfig(
                outputDirectory: "./custom-output",
                filenamePattern: "{filename}_{timestamp}.md",
                createLogFiles: true,
                overwriteExisting: false,
                markdown: MarkdownConfig(
                    headerLevelOffset: 1,
                    useATXHeaders: true,
                    addTableOfContents: true,
                    preserveFormatting: true,
                    listMarkerStyle: "*"
                )
            ),
            llm: LLMConfig(
                enabled: true,
                backend: "LocalLLMClientLlama",
                modelPath: "",
                model: ModelConfig(
                    identifier: "custom-model",
                    name: "Custom Model",
                    type: "llama",
                    downloadUrl: "",
                    localPath: ""
                ),
                parameters: ProcessingParameters(
                    temperature: 0.8,
                    topP: 0.95,
                    topK: 50,
                    penaltyRepeat: 1.1,
                    penaltyFrequency: 0.8,
                    maxTokens: 4096,
                    batch: 256,
                    threads: 4,
                    gpuLayers: 0
                ),
                options: LLMOptions(),
                contextManagement: ContextManagement(),
                memoryOptimization: MemoryOptimization(),
                promptTemplates: PromptTemplates(
                    languages: [
                        "en": LanguagePrompts(
                            systemPrompt: ["Custom system prompt"],
                            markdownOptimizationPrompt: ["Custom optimization prompt"]
                        )
                    ],
                    defaultLanguage: "en",
                    fallbackLanguage: "en"
                )
            ),
            headerFooterDetection: HeaderFooterDetectionConfig(),
            headerDetection: HeaderDetectionConfig(),
            listDetection: ListDetectionConfig(),
            duplicationDetection: DuplicationDetectionConfig(),
            positionSorting: PositionSortingConfig(),
            markdownGeneration: MarkdownGenerationConfig(),
            ocr: OCRConfig(),
            performance: PerformanceConfig(),
            fileManagement: FileManagementConfig(),
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "./custom-logs",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "2MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming()
            )
        )
        
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    // MARK: - Processing Configuration Validation Tests
    
    func testInvalidOverlapThreshold() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 1.5,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config)) { error in
            XCTAssertTrue(error is ConfigurationValidationError)
            if case .conflictingConfigurations(let messages) = error as? ConfigurationValidationError {
                XCTAssertTrue(messages.contains { $0.contains("Processing config:") })
            }
        }
    }
    
    func testInvalidHeaderRegion() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                headerRegion: [-0.1, 0.2],
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidFooterRegion() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                footerRegion: [0.8, 1.1],
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidMaxMergeDistance() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                mergeDistanceThreshold: -10.0,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testOverlappingHeaderFooterRegions() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                headerRegion: [0.0, 0.2],
                footerRegion: [0.15, 1.0],
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    // MARK: - Output Configuration Validation Tests
    
    func testInvalidOutputDirectory() {
        let config = MDKitConfig(
            output: OutputConfig(outputDirectory: "")
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidFilenamePattern() {
        let config = MDKitConfig(
            output: OutputConfig(filenamePattern: "")
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testFilenamePatternWithoutPlaceholders() {
        let config = MDKitConfig(
            output: OutputConfig(filenamePattern: "output.md")
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testValidFilenamePattern() {
        let config = MDKitConfig(
            output: OutputConfig(filenamePattern: "{filename}.md")
        )
        
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    // MARK: - LLM Configuration Validation Tests
    
    func testLLMDisabledWithOptimizationEnabled() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true,
                enableLLMOptimization: true
            ),
            llm: LLMConfig(enabled: false)
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testLLMEnabledWithValidConfig() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                backend: "LocalLLMClientLlama",
                modelPath: "",
                model: ModelConfig(
                    identifier: "test-model",
                    name: "Test Model",
                    type: "llama",
                    downloadUrl: "",
                    localPath: ""
                ),
                parameters: ProcessingParameters(
                    temperature: 0.5,
                    topP: 0.9,
                    topK: 40,
                    penaltyRepeat: 1.1,
                    penaltyFrequency: 0.8,
                    maxTokens: 2048,
                    batch: 256,
                    threads: 4,
                    gpuLayers: 0
                ),
                options: LLMOptions(),
                contextManagement: ContextManagement(),
                memoryOptimization: MemoryOptimization(),
                promptTemplates: PromptTemplates(
                    languages: [
                        "en": LanguagePrompts(
                            systemPrompt: ["Test prompt"],
                            markdownOptimizationPrompt: ["Test optimization"]
                        )
                    ],
                    defaultLanguage: "en",
                    fallbackLanguage: "en"
                )
            )
        )
        
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    func testInvalidTemperature() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                parameters: ProcessingParameters(temperature: 1.5)
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidTopP() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                parameters: ProcessingParameters(topP: -0.1)
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidMaxTokens() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                parameters: ProcessingParameters(maxTokens: 0)
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testEmptyModelIdentifier() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                model: ModelConfig(identifier: "")
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testEmptyPrompts() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                backend: "LocalLLMClientLlama",
                modelPath: "",
                model: ModelConfig(),
                parameters: ProcessingParameters(),
                options: LLMOptions(),
                contextManagement: ContextManagement(),
                memoryOptimization: MemoryOptimization(),
                promptTemplates: PromptTemplates(
                    languages: [
                        "en": LanguagePrompts(
                            systemPrompt: [],
                            markdownOptimizationPrompt: ["Valid"]
                        )
                    ],
                    defaultLanguage: "en",
                    fallbackLanguage: "en"
                )
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    // MARK: - Logging Configuration Validation Tests
    
    func testInvalidLogLevel() {
        let config = MDKitConfig(
            logging: LoggingConfig(level: "invalid-level")
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testValidLogLevels() throws {
        let validLevels = ["debug", "info", "warning", "error", "critical"]
        
        for level in validLevels {
            let config = MDKitConfig(
                logging: LoggingConfig(level: level)
            )
                    XCTAssertNoThrow(try validator.validate(config))
    }
    
    // MARK: - Real Configuration File Tests
    
    func testDevConfigFileLoading() throws {
        // Test loading the actual dev-config.json file
        let configManager = ConfigurationManager()
        let config = try configManager.loadConfigurationFromResources(fileName: "dev-config.json")
        
        // Verify the configuration loaded successfully
        XCTAssertNotNil(config)
        
        // Validate the loaded configuration
        XCTAssertNoThrow(try validator.validate(config))
        
        // Verify key configuration sections are present and have expected values
        XCTAssertEqual(config.processing.overlapThreshold, 0.15)
        XCTAssertTrue(config.processing.enableHeaderFooterDetection)
        XCTAssertEqual(config.processing.headerRegion, [0.0, 0.12])
        XCTAssertEqual(config.processing.footerRegion, [0.88, 1.0])
        XCTAssertTrue(config.processing.enableElementMerging)
        XCTAssertEqual(config.processing.mergeDistanceThreshold, 0.02)
        XCTAssertTrue(config.processing.isMergeDistanceNormalized)
        XCTAssertTrue(config.processing.enableLLMOptimization)
        
        // Verify LLM configuration
        XCTAssertTrue(config.llm.enabled)
        XCTAssertEqual(config.llm.backend, "LocalLLMClientLlama")
        XCTAssertEqual(config.llm.model.identifier, "ggml-org/Meta-Llama-3.1-8B-Instruct-Q4_0-GGUF")
        XCTAssertEqual(config.llm.model.name, "Meta Llama 3.1 8B Instruct Q4_0")
        XCTAssertEqual(config.llm.model.type, "llama")
        XCTAssertEqual(config.llm.parameters.temperature, 0.3)
        XCTAssertEqual(config.llm.parameters.topP, 0.9)
        XCTAssertEqual(config.llm.parameters.topK, 40)
        XCTAssertEqual(config.llm.parameters.maxTokens, 2048)
        
        // Verify prompt templates are configured
        XCTAssertFalse(config.llm.promptTemplates.languages.isEmpty)
        XCTAssertTrue(config.llm.promptTemplates.languages.keys.contains("zh"))
        XCTAssertTrue(config.llm.promptTemplates.languages.keys.contains("en"))
        XCTAssertEqual(config.llm.promptTemplates.defaultLanguage, "zh")
        XCTAssertEqual(config.llm.promptTemplates.fallbackLanguage, "en")
        
        // Verify header footer detection configuration
        XCTAssertTrue(config.headerFooterDetection.enabled)
        XCTAssertEqual(config.headerFooterDetection.headerFrequencyThreshold, 0.6)
        XCTAssertEqual(config.headerFooterDetection.footerFrequencyThreshold, 0.6)
        XCTAssertTrue(config.headerFooterDetection.regionBasedDetection.enabled)
        XCTAssertEqual(config.headerFooterDetection.regionBasedDetection.headerRegionY, 72.0)
        XCTAssertEqual(config.headerFooterDetection.regionBasedDetection.footerRegionY, 720.0)
        XCTAssertEqual(config.headerFooterDetection.regionBasedDetection.regionTolerance, 10.0)
        
        // Verify header detection configuration
        XCTAssertTrue(config.headerDetection.enabled)
        XCTAssertEqual(config.headerDetection.sameLineTolerance, 8.0)
        XCTAssertTrue(config.headerDetection.enableHeaderMerging)
        XCTAssertTrue(config.headerDetection.enableLevelCalculation)
        XCTAssertEqual(config.headerDetection.markdownLevelOffset, 1)
        XCTAssertFalse(config.headerDetection.patterns.numberedHeaders.isEmpty)
        XCTAssertFalse(config.headerDetection.patterns.letteredHeaders.isEmpty)
        XCTAssertFalse(config.headerDetection.patterns.romanHeaders.isEmpty)
        XCTAssertFalse(config.headerDetection.patterns.namedHeaders.isEmpty)
        
        // Verify list detection configuration
        XCTAssertTrue(config.listDetection.enabled)
        XCTAssertEqual(config.listDetection.sameLineTolerance, 8.0)
        XCTAssertTrue(config.listDetection.enableListItemMerging)
        XCTAssertTrue(config.listDetection.enableLevelCalculation)
        XCTAssertTrue(config.listDetection.enableNestedLists)
        XCTAssertFalse(config.listDetection.patterns.numberedMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.letteredMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.bulletMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.romanMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.customMarkers.isEmpty)
        
        // Verify logging configuration
        XCTAssertTrue(config.logging.enabled)
        XCTAssertEqual(config.logging.level, "debug")
        XCTAssertEqual(config.logging.outputFolder, "dev-logs")
        XCTAssertTrue(config.logging.enableConsoleOutput)
        XCTAssertTrue(config.logging.logFileRotation)
        XCTAssertEqual(config.logging.maxLogFileSize, "5MB")
        XCTAssertTrue(config.logging.logCategories.ocrElements.enabled)
        XCTAssertTrue(config.logging.logCategories.documentObservation.enabled)
        XCTAssertTrue(config.logging.logCategories.markdownGeneration.enabled)
        XCTAssertTrue(config.logging.logCategories.llmPrompts.enabled)
        XCTAssertTrue(config.logging.logCategories.llmOptimizedMarkdown.enabled)
    }
    
    func testDevConfigFileValidation() throws {
        // Test that the dev-config.json file passes all validation rules
        let configManager = ConfigurationManager()
        let config = try configManager.loadConfigurationFromResources(fileName: "dev-config.json")
        
        // This should not throw any validation errors
        XCTAssertNoThrow(try validator.validate(config))
        
        // Verify cross-configuration constraints are satisfied
        // Note: validateCrossConfigurationConstraints is private, so we can't test it directly
        // The main validation should catch any cross-configuration issues
    }
    
    func testDevConfigFileRoundTrip() throws {
        // Test saving and reloading the dev-config.json configuration
        let configManager = ConfigurationManager()
        let originalConfig = try configManager.loadConfigurationFromResources(fileName: "dev-config.json")
        
        // Save to a temporary file
        let tempPath = "/tmp/test-dev-config.json"
        try configManager.saveConfiguration(originalConfig, to: tempPath)
        
        // Reload from the temporary file
        let reloadedConfig = try configManager.loadConfiguration(from: tempPath)
        
        // Verify the configuration is identical
        XCTAssertEqual(originalConfig.processing.overlapThreshold, reloadedConfig.processing.overlapThreshold)
        XCTAssertEqual(originalConfig.processing.enableHeaderFooterDetection, reloadedConfig.processing.enableHeaderFooterDetection)
        XCTAssertEqual(originalConfig.processing.headerRegion, reloadedConfig.processing.headerRegion)
        XCTAssertEqual(originalConfig.processing.footerRegion, reloadedConfig.processing.footerRegion)
        XCTAssertEqual(originalConfig.llm.enabled, reloadedConfig.llm.enabled)
        XCTAssertEqual(originalConfig.llm.backend, reloadedConfig.llm.backend)
        XCTAssertEqual(originalConfig.llm.model.identifier, reloadedConfig.llm.model.identifier)
        XCTAssertEqual(originalConfig.logging.level, reloadedConfig.logging.level)
        
        // Clean up
        try FileManager.default.removeItem(atPath: tempPath)
    }
}
    
    func testInvalidMaxFileSize() {
        let config = MDKitConfig(
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "./logs",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming()
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidMaxFiles() {
        let config = MDKitConfig(
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "./logs",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "1MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming(maxFileNameLength: -1)
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testEmptyLogDirectory() {
        let config = MDKitConfig(
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "1MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming()
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testEmptyLogFileName() {
        let config = MDKitConfig(
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "./logs",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "1MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming(pattern: "")
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    // MARK: - Cross-Configuration Validation Tests
    
    func testConflictingOutputAndLogDirectories() {
        let config = MDKitConfig(
            output: OutputConfig(outputDirectory: "./same-dir"),
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "./same-dir",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "1MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming()
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testFileLoggingEnabledButLogFilesDisabled() {
        let config = MDKitConfig(
            output: OutputConfig(createLogFiles: false),
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "./logs",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "1MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming()
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    // MARK: - Convenience Method Tests
    
    func testCreateDefaultValidatedConfig() throws {
        let config = try validator.createDefaultValidatedConfig()
        XCTAssertNotNil(config)
        
        // Verify it's actually valid
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    func testValidateData() throws {
        let config = MDKitConfig()
        let data = try JSONEncoder().encode(config)
        
        let validatedConfig = try validator.validateData(data)
        XCTAssertNotNil(validatedConfig)
        XCTAssertEqual(validatedConfig.processing.overlapThreshold, config.processing.overlapThreshold)
    }
    
    // MARK: - Edge Case Tests
    
    func testZeroOverlapThreshold() throws {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 0.0,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    func testOneOverlapThreshold() throws {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 1.0,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    func testZeroMaxMergeDistance() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                mergeDistanceThreshold: 0.0,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            )
        )
        XCTAssertNoThrow(try validator.validate(config)) // 0.0 is valid (no merging)
    }
    
    func testNegativeHeaderLevelOffset() {
        let config = MDKitConfig(
            output: OutputConfig(
                markdown: MarkdownConfig(headerLevelOffset: -1)
            )
        )
        XCTAssertNoThrow(try validator.validate(config)) // This should be valid
    }
    
    func testZeroTopK() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                backend: "LocalLLMClientLlama",
                modelPath: "",
                model: ModelConfig(),
                parameters: ProcessingParameters(topK: 0),
                options: LLMOptions(),
                contextManagement: ContextManagement(),
                memoryOptimization: MemoryOptimization(),
                promptTemplates: PromptTemplates()
            )
        )
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    // MARK: - Complex Validation Scenarios
    
    func testMultipleValidationErrors() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 1.5,
                mergeDistanceThreshold: -10.0,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true
            ),
            output: OutputConfig(
                outputDirectory: "",
                filenamePattern: "invalid"
            )
        )
        
        XCTAssertThrowsError(try validator.validate(config)) { error in
            if case .conflictingConfigurations(let messages) = error as? ConfigurationValidationError {
                XCTAssertGreaterThan(messages.count, 1)
                XCTAssertTrue(messages.contains { $0.contains("Processing config:") })
                XCTAssertTrue(messages.contains { $0.contains("Output config:") })
            }
        }
    }
    
    func testValidConfigurationWithAllFeaturesEnabled() throws {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 0.3,
                enableHeaderFooterDetection: true,
                headerRegion: [0.0, 0.12],
                footerRegion: [0.88, 1.0],
                enableElementMerging: true,
                mergeDistanceThreshold: 30.0,
                isMergeDistanceNormalized: false,
                horizontalMergeThreshold: 60.0,
                isHorizontalMergeThresholdNormalized: false,
                enableLLMOptimization: true
            ),
            output: OutputConfig(
                outputDirectory: "./output",
                filenamePattern: "{filename}_{timestamp}_{hash}.md",
                createLogFiles: true,
                overwriteExisting: false,
                markdown: MarkdownConfig(
                    headerLevelOffset: 0,
                    useATXHeaders: true,
                    addTableOfContents: true,
                    preserveFormatting: true,
                    listMarkerStyle: "1"
                )
            ),
            llm: LLMConfig(
                enabled: true,
                backend: "LocalLLMClientLlama",
                modelPath: "",
                model: ModelConfig(
                    identifier: "llama-2-13b-chat",
                    name: "Llama 2 13B Chat",
                    type: "llama",
                    downloadUrl: "",
                    localPath: ""
                ),
                parameters: ProcessingParameters(
                    temperature: 0.6,
                    topP: 0.92,
                    topK: 50,
                    penaltyRepeat: 1.1,
                    penaltyFrequency: 0.8,
                    maxTokens: 3072,
                    batch: 256,
                    threads: 4,
                    gpuLayers: 0
                ),
                options: LLMOptions(),
                contextManagement: ContextManagement(),
                memoryOptimization: MemoryOptimization(),
                promptTemplates: PromptTemplates(
                    languages: [
                        "en": LanguagePrompts(
                            systemPrompt: ["You are an expert at converting PDF content to well-structured Markdown."],
                            markdownOptimizationPrompt: ["Please optimize this content for Markdown formatting while preserving structure."]
                        )
                    ],
                    defaultLanguage: "en",
                    fallbackLanguage: "en"
                )
            ),
            headerFooterDetection: HeaderFooterDetectionConfig(),
            headerDetection: HeaderDetectionConfig(),
            listDetection: ListDetectionConfig(),
            duplicationDetection: DuplicationDetectionConfig(),
            positionSorting: PositionSortingConfig(),
            markdownGeneration: MarkdownGenerationConfig(),
            ocr: OCRConfig(),
            performance: PerformanceConfig(),
            fileManagement: FileManagementConfig(),
            logging: LoggingConfig(
                enabled: true,
                level: "info",
                outputFolder: "./logs",
                enableConsoleOutput: true,
                logFileRotation: true,
                maxLogFileSize: "2MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming()
            )
        )
        
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    // MARK: - Real Configuration File Tests
    
    func testDevConfigFileLoading() throws {
        // Test loading the actual dev-config.json file
        let configManager = ConfigurationManager()
        let config = try configManager.loadConfigurationFromResources(fileName: "dev-config.json")
        
        // Verify the configuration loaded successfully
        XCTAssertNotNil(config)
        
        // Validate the loaded configuration
        XCTAssertNoThrow(try validator.validate(config))
        
        // Verify key configuration sections are present and have expected values
        XCTAssertEqual(config.processing.overlapThreshold, 0.15)
        XCTAssertTrue(config.processing.enableHeaderFooterDetection)
        XCTAssertEqual(config.processing.headerRegion, [0.0, 0.12])
        XCTAssertEqual(config.processing.footerRegion, [0.88, 1.0])
        XCTAssertTrue(config.processing.enableElementMerging)
        XCTAssertEqual(config.processing.mergeDistanceThreshold, 0.02)
        XCTAssertTrue(config.processing.isMergeDistanceNormalized)
        XCTAssertTrue(config.processing.enableLLMOptimization)
        
        // Verify LLM configuration
        XCTAssertTrue(config.llm.enabled)
        XCTAssertEqual(config.llm.backend, "LocalLLMClientLlama")
        XCTAssertEqual(config.llm.model.identifier, "ggml-org/Meta-Llama-3.1-8B-Instruct-Q4_0-GGUF")
        XCTAssertEqual(config.llm.model.name, "Meta Llama 3.1 8B Instruct Q4_0")
        XCTAssertEqual(config.llm.model.type, "llama")
        XCTAssertEqual(config.llm.parameters.temperature, 0.3)
        XCTAssertEqual(config.llm.parameters.topP, 0.9)
        XCTAssertEqual(config.llm.parameters.topK, 40)
        XCTAssertEqual(config.llm.parameters.maxTokens, 2048)
        
        // Verify prompt templates are configured
        XCTAssertFalse(config.llm.promptTemplates.languages.isEmpty)
        XCTAssertTrue(config.llm.promptTemplates.languages.keys.contains("zh"))
        XCTAssertTrue(config.llm.promptTemplates.languages.keys.contains("en"))
        XCTAssertEqual(config.llm.promptTemplates.defaultLanguage, "zh")
        XCTAssertEqual(config.llm.promptTemplates.fallbackLanguage, "en")
        
        // Verify header footer detection configuration
        XCTAssertTrue(config.headerFooterDetection.enabled)
        XCTAssertEqual(config.headerFooterDetection.headerFrequencyThreshold, 0.6)
        XCTAssertEqual(config.headerFooterDetection.footerFrequencyThreshold, 0.6)
        XCTAssertTrue(config.headerFooterDetection.regionBasedDetection.enabled)
        XCTAssertEqual(config.headerFooterDetection.regionBasedDetection.headerRegionY, 72.0)
        XCTAssertEqual(config.headerFooterDetection.regionBasedDetection.footerRegionY, 720.0)
        XCTAssertEqual(config.headerFooterDetection.regionBasedDetection.regionTolerance, 10.0)
        
        // Verify header detection configuration
        XCTAssertTrue(config.headerDetection.enabled)
        XCTAssertEqual(config.headerDetection.sameLineTolerance, 8.0)
        XCTAssertTrue(config.headerDetection.enableHeaderMerging)
        XCTAssertTrue(config.headerDetection.enableLevelCalculation)
        XCTAssertEqual(config.headerDetection.markdownLevelOffset, 1)
        XCTAssertFalse(config.headerDetection.patterns.numberedHeaders.isEmpty)
        XCTAssertFalse(config.headerDetection.patterns.letteredHeaders.isEmpty)
        XCTAssertFalse(config.headerDetection.patterns.romanHeaders.isEmpty)
        XCTAssertFalse(config.headerDetection.patterns.namedHeaders.isEmpty)
        
        // Verify list detection configuration
        XCTAssertTrue(config.listDetection.enabled)
        XCTAssertEqual(config.listDetection.sameLineTolerance, 8.0)
        XCTAssertTrue(config.listDetection.enableListItemMerging)
        XCTAssertTrue(config.listDetection.enableLevelCalculation)
        XCTAssertTrue(config.listDetection.enableNestedLists)
        XCTAssertFalse(config.listDetection.patterns.numberedMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.letteredMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.bulletMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.romanMarkers.isEmpty)
        XCTAssertFalse(config.listDetection.patterns.customMarkers.isEmpty)
        
        // Verify logging configuration
        XCTAssertTrue(config.logging.enabled)
        XCTAssertEqual(config.logging.level, "debug")
        XCTAssertEqual(config.logging.outputFolder, "dev-logs")
        XCTAssertTrue(config.logging.enableConsoleOutput)
        XCTAssertTrue(config.logging.logFileRotation)
        XCTAssertEqual(config.logging.maxLogFileSize, "5MB")
        XCTAssertTrue(config.logging.logCategories.ocrElements.enabled)
        XCTAssertTrue(config.logging.logCategories.documentObservation.enabled)
        XCTAssertTrue(config.logging.logCategories.markdownGeneration.enabled)
        XCTAssertTrue(config.logging.logCategories.llmPrompts.enabled)
        XCTAssertTrue(config.logging.logCategories.llmOptimizedMarkdown.enabled)
    }
    
    func testDevConfigFileValidation() throws {
        // Test that the dev-config.json file passes all validation rules
        let configManager = ConfigurationManager()
        let config = try configManager.loadConfigurationFromResources(fileName: "dev-config.json")
        
        // This should not throw any validation errors
        XCTAssertNoThrow(try validator.validate(config))
        
        // Verify cross-configuration constraints are satisfied
        // Note: validateCrossConfigurationConstraints is private, so we can't test it directly
        // The main validation should catch any cross-configuration issues
    }
    
    func testDevConfigFileRoundTrip() throws {
        // Test saving and reloading the dev-config.json configuration
        let configManager = ConfigurationManager()
        let originalConfig = try configManager.loadConfigurationFromResources(fileName: "dev-config.json")
        
        // Save to a temporary file
        let tempPath = "/tmp/test-dev-config.json"
        try configManager.saveConfiguration(originalConfig, to: tempPath)
        
        // Reload from the temporary file
        let reloadedConfig = try configManager.loadConfiguration(from: tempPath)
        
        // Verify the configuration is identical
        XCTAssertEqual(originalConfig.processing.overlapThreshold, reloadedConfig.processing.overlapThreshold)
        XCTAssertEqual(originalConfig.processing.enableHeaderFooterDetection, reloadedConfig.processing.enableHeaderFooterDetection)
        XCTAssertEqual(originalConfig.processing.headerRegion, reloadedConfig.processing.headerRegion)
        XCTAssertEqual(originalConfig.processing.footerRegion, reloadedConfig.processing.footerRegion)
        XCTAssertEqual(originalConfig.llm.enabled, reloadedConfig.llm.enabled)
        XCTAssertEqual(originalConfig.llm.backend, reloadedConfig.llm.backend)
        XCTAssertEqual(originalConfig.llm.model.identifier, reloadedConfig.llm.model.identifier)
        XCTAssertEqual(originalConfig.logging.level, reloadedConfig.logging.level)
        
        // Clean up
        try FileManager.default.removeItem(atPath: tempPath)
    }
}
