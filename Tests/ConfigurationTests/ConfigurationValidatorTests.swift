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
                headerRegion: 0.0...0.1,
                footerRegion: 0.9...1.0,
                enableElementMerging: true,
                mergeDistanceThreshold: 25.0,
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
                    listMarkerStyle: .asterisk
                )
            ),
            llm: LLMConfig(
                enabled: true,
                model: ModelConfig(
                    identifier: "custom-model",
                    modelPath: nil,
                    type: .llama
                ),
                parameters: ProcessingParameters(
                    temperature: 0.8,
                    topK: 50,
                    topP: 0.95,
                    maxTokens: 4096
                ),
                prompts: PromptConfig(
                    systemPrompt: "Custom system prompt",
                    optimizationPrompt: "Custom optimization prompt",
                    languagePrompt: "Custom language prompt"
                )
            ),
            logging: LoggingConfig(
                level: "debug",
                enableConsole: true,
                enableFile: true,
                logFileName: "custom.log",
                logDirectory: "./custom-logs",
                maxFileSize: 2048 * 1024,
                maxFiles: 10,
                includeTimestamps: true,
                includeLogLevels: true
            )
        )
        
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    // MARK: - Processing Configuration Validation Tests
    
    func testInvalidOverlapThreshold() {
        let config = MDKitConfig(
            processing: ProcessingConfig(overlapThreshold: 1.5)
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
            processing: ProcessingConfig(headerRegion: -0.1...0.2)
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidFooterRegion() {
        let config = MDKitConfig(
            processing: ProcessingConfig(footerRegion: 0.8...1.1)
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidMaxMergeDistance() {
        let config = MDKitConfig(
            processing: ProcessingConfig(mergeDistanceThreshold: -10.0)
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testOverlappingHeaderFooterRegions() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                headerRegion: 0.0...0.2,
                footerRegion: 0.15...1.0
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
            processing: ProcessingConfig(enableLLMOptimization: true),
            llm: LLMConfig(enabled: false)
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testLLMEnabledWithValidConfig() {
        let config = MDKitConfig(
            llm: LLMConfig(
                enabled: true,
                model: ModelConfig(identifier: "test-model"),
                parameters: ProcessingParameters(
                    temperature: 0.5,
                    topK: 40,
                    topP: 0.9,
                    maxTokens: 2048
                ),
                prompts: PromptConfig(
                    systemPrompt: "Test prompt",
                    optimizationPrompt: "Test optimization",
                    languagePrompt: "Test language"
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
                prompts: PromptConfig(
                    systemPrompt: "",
                    optimizationPrompt: "Valid",
                    languagePrompt: "Valid"
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
    }
    
    func testInvalidMaxFileSize() {
        let config = MDKitConfig(
            logging: LoggingConfig(maxFileSize: 0)
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testInvalidMaxFiles() {
        let config = MDKitConfig(
            logging: LoggingConfig(maxFiles: -1)
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testEmptyLogDirectory() {
        let config = MDKitConfig(
            logging: LoggingConfig(logDirectory: "")
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testEmptyLogFileName() {
        let config = MDKitConfig(
            logging: LoggingConfig(logFileName: "")
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    // MARK: - Cross-Configuration Validation Tests
    
    func testConflictingOutputAndLogDirectories() {
        let config = MDKitConfig(
            output: OutputConfig(outputDirectory: "./same-dir"),
            logging: LoggingConfig(logDirectory: "./same-dir")
        )
        
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    func testFileLoggingEnabledButLogFilesDisabled() {
        let config = MDKitConfig(
            output: OutputConfig(createLogFiles: false),
            logging: LoggingConfig(enableFile: true)
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
            processing: ProcessingConfig(overlapThreshold: 0.0)
        )
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    func testOneOverlapThreshold() throws {
        let config = MDKitConfig(
            processing: ProcessingConfig(overlapThreshold: 1.0)
        )
        XCTAssertNoThrow(try validator.validate(config))
    }
    
    func testZeroMaxMergeDistance() {
        let config = MDKitConfig(
            processing: ProcessingConfig(mergeDistanceThreshold: 0.0)
        )
        XCTAssertThrowsError(try validator.validate(config))
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
                parameters: ProcessingParameters(topK: 0)
            )
        )
        XCTAssertThrowsError(try validator.validate(config))
    }
    
    // MARK: - Complex Validation Scenarios
    
    func testMultipleValidationErrors() {
        let config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 1.5,
                mergeDistanceThreshold: -10.0
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
                headerRegion: 0.0...0.12,
                footerRegion: 0.88...1.0,
                enableElementMerging: true,
                mergeDistanceThreshold: 30.0,
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
                    listMarkerStyle: .number
                )
            ),
            llm: LLMConfig(
                enabled: true,
                model: ModelConfig(
                    identifier: "llama-2-13b-chat",
                    modelPath: nil,
                    type: .llama
                ),
                parameters: ProcessingParameters(
                    temperature: 0.6,
                    topK: 50,
                    topP: 0.92,
                    maxTokens: 3072
                ),
                prompts: PromptConfig(
                    systemPrompt: "You are an expert at converting PDF content to well-structured Markdown.",
                    optimizationPrompt: "Please optimize this content for Markdown formatting while preserving structure.",
                    languagePrompt: "Detect the language of this text and respond with the language code."
                )
            ),
            logging: LoggingConfig(
                level: "info",
                enableConsole: true,
                enableFile: true,
                logFileName: "mdkit.log",
                logDirectory: "./logs",
                maxFileSize: 2 * 1024 * 1024,
                maxFiles: 7,
                includeTimestamps: true,
                includeLogLevels: true
            )
        )
        
        XCTAssertNoThrow(try validator.validate(config))
    }
}
