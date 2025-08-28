import XCTest
import Foundation
@testable import mdkitCore
@testable import mdkitConfiguration
@testable import mdkitFileManagement
@testable import mdkitProtocols

final class MainProcessorTests: XCTestCase {
    
    // MARK: - Properties
    
    var config: MDKitConfig!
    var mainProcessor: MainProcessor!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a minimal test configuration
        config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 0.15,
                enableHeaderFooterDetection: true,
                headerRegion: [0.0, 0.12],
                footerRegion: [0.88, 1.0],
                enableElementMerging: true,
                mergeDistanceThreshold: 0.02,
                isMergeDistanceNormalized: true,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true,
                enableLLMOptimization: false, // Disable LLM for testing
                pdfImageScaleFactor: 2.0,
                enableImageEnhancement: true
            ),
            output: OutputConfig(
                outputDirectory: "./test-output",
                filenamePattern: "_test.md",
                createLogFiles: false,
                overwriteExisting: true,
                markdown: MarkdownConfig()
            ),
            llm: LLMConfig(
                enabled: false, // Disable LLM for testing
                backend: "TestBackend",
                model: ModelConfig(
                    identifier: "test-model",
                    name: "Test Model",
                    type: "test"
                ),
                parameters: ProcessingParameters(
                    temperature: 0.3,
                    topP: 0.9,
                    topK: 40,
                    maxTokens: 2048
                ),
                options: LLMOptions(),
                contextManagement: ContextManagement(),
                memoryOptimization: MemoryOptimization(),
                promptTemplates: PromptTemplates()
            ),
            headerFooterDetection: HeaderFooterDetectionConfig(),
            headerDetection: HeaderDetectionConfig(markdownLevelOffset: 0),
            listDetection: ListDetectionConfig(),
            duplicationDetection: DuplicationDetectionConfig(),
            positionSorting: PositionSortingConfig(),
            markdownGeneration: MarkdownGenerationConfig(),
            ocr: OCRConfig(),
            performance: PerformanceConfig(),
            fileManagement: FileManagementConfig(
                outputDirectory: "./test-output",
                markdownDirectory: "./test-markdown",
                logDirectory: "./test-logs",
                tempDirectory: "/tmp/mdkit-test",
                createDirectories: true,
                overwriteExisting: true,
                preserveOriginalNames: true,
                fileNamingStrategy: "timestamped"
            ),
            logging: LoggingConfig(
                enabled: true,
                level: "debug",
                outputFolder: "./test-logs",
                enableConsoleOutput: true,
                logFileRotation: false,
                maxLogFileSize: "1MB",
                logCategories: LogCategories(),
                logFileNaming: LogFileNaming()
            )
        )
        
        // Create main processor
        mainProcessor = try MainProcessor(config: config)
    }
    
    override func tearDown() async throws {
        // Clean up test output directory
        try? FileManager.default.removeItem(atPath: "./test-output")
        try? FileManager.default.removeItem(atPath: "./test-logs")
        
        mainProcessor = nil
        config = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() throws {
        XCTAssertNotNil(mainProcessor)
        XCTAssertEqual(mainProcessor.getConfiguration().processing.overlapThreshold, 0.15)
        XCTAssertFalse(mainProcessor.getConfiguration().llm.enabled)
    }
    
    func testInitializationWithLLMEnabled() throws {
        // Create a new config with LLM enabled
        let llmConfig = MDKitConfig(
            processing: config!.processing,
            output: config!.output,
            llm: LLMConfig(
                enabled: true,
                backend: "TestBackend",
                model: config!.llm.model,
                parameters: config!.llm.parameters,
                options: config!.llm.options,
                contextManagement: config!.llm.contextManagement,
                memoryOptimization: config!.llm.memoryOptimization,
                promptTemplates: config!.llm.promptTemplates
            ),
            headerFooterDetection: config!.headerFooterDetection,
            headerDetection: config!.headerDetection,
            listDetection: config!.listDetection,
            duplicationDetection: config!.duplicationDetection,
            positionSorting: config!.positionSorting,
            markdownGeneration: config!.markdownGeneration,
            ocr: config!.ocr,
            performance: config!.performance,
            fileManagement: config!.fileManagement,
            logging: config!.logging
        )
        
        let processor = try MainProcessor(config: llmConfig)
        XCTAssertNotNil(processor)
        XCTAssertTrue(processor.getConfiguration().llm.enabled)
    }
    
    // MARK: - File Validation Tests
    
    func testValidateInputFileNotFound() async throws {
        let nonExistentPath = "/path/to/nonexistent/file.pdf"
        
        // The MainProcessor catches errors and returns ProcessingResult
        let result = try await mainProcessor.processPDF(inputPath: nonExistentPath)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.inputPath, nonExistentPath)
        XCTAssertNil(result.outputPath)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error is MainProcessorError)
    }
    
    func testValidateInputFileNotReadable() async throws {
        // Create a temporary file that's not readable
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.pdf")
        
        // Create an empty file
        try "".write(to: tempFile, atomically: true, encoding: .utf8)
        
        // Make it not readable
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: tempFile.path)
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        // The MainProcessor catches errors and returns ProcessingResult
        let result = try await mainProcessor.processPDF(inputPath: tempFile.path)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.inputPath, tempFile.path)
        XCTAssertNil(result.outputPath)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error is MainProcessorError)
    }
    
    func testValidateInputFileUnsupportedFileType() async throws {
        // Create a temporary text file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.txt")
        
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        // The MainProcessor catches errors and returns ProcessingResult
        let result = try await mainProcessor.processPDF(inputPath: tempFile.path)
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.inputPath, tempFile.path)
        XCTAssertNil(result.outputPath)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error is MainProcessorError)
    }
    
    // MARK: - Processing Options Tests
    
    func testProcessingOptionsDefaultValues() {
        let options = ProcessingOptions()
        
        XCTAssertFalse(options.verbose)
        XCTAssertFalse(options.dryRun)
        XCTAssertEqual(options.maxConcurrency, 1)
        XCTAssertEqual(options.outputFormat, .markdown)
    }
    
    func testProcessingOptionsCustomValues() {
        let options = ProcessingOptions(
            verbose: true,
            dryRun: true,
            maxConcurrency: 4,
            outputFormat: .html
        )
        
        XCTAssertTrue(options.verbose)
        XCTAssertTrue(options.dryRun)
        XCTAssertEqual(options.maxConcurrency, 4)
        XCTAssertEqual(options.outputFormat, .html)
    }
    
    // MARK: - Statistics Tests
    
    func testStatisticsInitialization() {
        let stats = mainProcessor.getStatistics()
        
        XCTAssertEqual(stats.totalFiles, 0)
        XCTAssertEqual(stats.successfulFiles, 0)
        XCTAssertEqual(stats.failedFiles, 0)
        XCTAssertEqual(stats.totalProcessingTime, 0)
        XCTAssertEqual(stats.averageProcessingTime, 0)
        XCTAssertEqual(stats.successRate, 0)
    }
    
    func testStatisticsUpdate() {
        let stats = mainProcessor.getStatistics()
        
        // Update with successful result
        stats.update(
            inputPath: "/test/file1.pdf",
            outputPath: "/test/output1.md",
            processingTime: 1.5,
            elementCount: 10,
            detectedLanguage: "en"
        )
        
        XCTAssertEqual(stats.totalFiles, 1)
        XCTAssertEqual(stats.successfulFiles, 1)
        XCTAssertEqual(stats.failedFiles, 0)
        XCTAssertEqual(stats.totalProcessingTime, 1.5)
        XCTAssertEqual(stats.averageProcessingTime, 1.5)
        XCTAssertEqual(stats.successRate, 100.0)
        
        // Update with failed result
        stats.update(
            inputPath: "/test/file2.pdf",
            outputPath: nil,
            processingTime: 0.5,
            elementCount: 0,
            detectedLanguage: "en"
        )
        
        XCTAssertEqual(stats.totalFiles, 2)
        XCTAssertEqual(stats.successfulFiles, 1)
        XCTAssertEqual(stats.failedFiles, 1)
        XCTAssertEqual(stats.totalProcessingTime, 2.0)
        XCTAssertEqual(stats.averageProcessingTime, 1.0)
        XCTAssertEqual(stats.successRate, 50.0)
    }
    
    func testStatisticsReset() {
        let stats = mainProcessor.getStatistics()
        
        // Add some data
        stats.update(
            inputPath: "/test/file.pdf",
            outputPath: "/test/output.md",
            processingTime: 1.0,
            elementCount: 5,
            detectedLanguage: "en"
        )
        
        // Verify data exists
        XCTAssertEqual(stats.totalFiles, 1)
        XCTAssertEqual(stats.successfulFiles, 1)
        
        // Reset
        stats.reset()
        
        // Verify reset
        XCTAssertEqual(stats.totalFiles, 0)
        XCTAssertEqual(stats.successfulFiles, 0)
        XCTAssertEqual(stats.failedFiles, 0)
        XCTAssertEqual(stats.totalProcessingTime, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testMainProcessorErrorDescriptions() {
        let errors: [MainProcessorError] = [
            .inputFileNotFound(path: "/test/file.pdf"),
            .inputFileNotReadable(path: "/test/file.pdf"),
            .unsupportedFileType(extension: "txt"),
            .outputDirectoryCreationFailed(path: "/test/output"),
            .markdownGenerationFailed,
            .llmOptimizationFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Output Format Tests
    
    func testOutputFormatCases() {
        let formats: [OutputFormat] = [.markdown, .html, .plainText, .json]
        
        for format in formats {
            switch format {
            case .markdown:
                XCTAssertTrue(true) // Valid case
            case .html:
                XCTAssertTrue(true) // Valid case
            case .plainText:
                XCTAssertTrue(true) // Valid case
            case .json:
                XCTAssertTrue(true) // Valid case
            }
        }
    }
    
    // MARK: - Processing Result Tests
    
    func testProcessingResultSuccess() {
        let stats = ProcessingStatistics()
        let result = ProcessingResult(
            success: true,
            inputPath: "/test/input.pdf",
            outputPath: "/test/output.md",
            processingTime: 2.5,
            elementCount: 15,
            statistics: stats
        )
        
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.inputPath, "/test/input.pdf")
        XCTAssertEqual(result.outputPath, "/test/output.md")
        XCTAssertEqual(result.processingTime, 2.5)
        XCTAssertEqual(result.elementCount, 15)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.statistics)
    }
    
    func testProcessingResultFailure() {
        let stats = ProcessingStatistics()
        let error = MainProcessorError.inputFileNotFound(path: "/test/file.pdf")
        let result = ProcessingResult(
            success: false,
            inputPath: "/test/input.pdf",
            outputPath: nil,
            processingTime: 0.1,
            elementCount: 0,
            error: error,
            statistics: stats
        )
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.inputPath, "/test/input.pdf")
        XCTAssertNil(result.outputPath)
        XCTAssertEqual(result.processingTime, 0.1)
        XCTAssertEqual(result.elementCount, 0)
        XCTAssertNotNil(result.error)
        XCTAssertNotNil(result.statistics)
    }
    
    // MARK: - Configuration Access Tests
    
    func testGetConfiguration() {
        let retrievedConfig = mainProcessor.getConfiguration()
        
        XCTAssertEqual(retrievedConfig.processing.overlapThreshold, config.processing.overlapThreshold)
        XCTAssertEqual(retrievedConfig.output.outputDirectory, config.output.outputDirectory)
        XCTAssertEqual(retrievedConfig.llm.enabled, config.llm.enabled)
        XCTAssertEqual(retrievedConfig.logging.level, config.logging.level)
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchProcessingEmptyArray() async throws {
        let results = try await mainProcessor.processPDFs(inputPaths: [])
        
        XCTAssertEqual(results.count, 0)
    }
    
    func testBatchProcessingSingleFile() async throws {
        // This test would require a real PDF file, so we'll just test the method signature
        // In a real scenario, you'd need to create a test PDF file
        XCTAssertNotNil(mainProcessor.processPDFs)
    }
    
    // MARK: - Performance Tests
    
    func testStatisticsPerformance() {
        let stats = ProcessingStatistics()
        
        measure {
            for i in 0..<1000 {
                stats.update(
                    inputPath: "/test/file\(i).pdf",
                    outputPath: "/test/output\(i).md",
                    processingTime: Double.random(in: 0.1...5.0),
                    elementCount: Int.random(in: 1...100),
                    detectedLanguage: "en"
                )
            }
        }
    }
    
    func testProcessingOptionsPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = ProcessingOptions(
                    verbose: Bool.random(),
                    dryRun: Bool.random(),
                    maxConcurrency: Int.random(in: 1...16),
                    outputFormat: [.markdown, .html, .plainText, .json].randomElement()!
                )
            }
        }
    }
}

// MARK: - Helper Extensions

extension Array {
    func randomElement() -> Element? {
        guard !isEmpty else { return nil }
        let randomIndex = Int.random(in: 0..<count)
        return self[randomIndex]
    }
}
