import XCTest
import Foundation
import CoreGraphics
@testable import mdkitCore
@testable import mdkitConfiguration
@testable import mdkitFileManagement
@testable import mdkitProtocols

final class MainProcessorTests: XCTestCase {
    
    var mainProcessor: MainProcessor!
    var config: MDKitConfig!
    
    override func setUp() {
        super.setUp()
        
        // Create a minimal test configuration
        config = MDKitConfig(
            processing: ProcessingConfig(
                overlapThreshold: 0.15,
                enableHeaderFooterDetection: true,
                pageHeaderRegion: [0.0, 0.12],
                pageFooterRegion: [0.88, 1.0],
                enableElementMerging: true,
                mergeDistanceThreshold: 0.02,
                isMergeDistanceNormalized: true,
                horizontalMergeThreshold: 0.15,
                isHorizontalMergeThresholdNormalized: true,
                enableLLMOptimization: true,
                pdfImageScaleFactor: 2.0,
                enableImageEnhancement: true
            ),
            output: OutputConfig(
                outputDirectory: "./test-output",
                filenamePattern: "{filename}_test.md",
                createLogFiles: true,
                overwriteExisting: true
            ),
            logging: LoggingConfig(
                level: "info",
                outputFolder: "./test-logs",
                enableConsoleOutput: true
            )
        )
        
        // Create services directly for testing
        let markdownGenerator = MarkdownGenerator()
        let languageDetector = LanguageDetector()
        let fileManager = MDKitFileManager(config: FileManagementConfig())
        let outputGenerator = OutputGenerator(config: config)
        let documentProcessor = TraditionalOCRDocumentProcessor(
            configuration: config,
            markdownGenerator: markdownGenerator,
            languageDetector: languageDetector
        )
        
        // Create main processor
        mainProcessor = try! MainProcessor(
            config: config,
            documentProcessor: documentProcessor,
            languageDetector: languageDetector,
            markdownGenerator: markdownGenerator,
            fileManager: fileManager,
            outputGenerator: outputGenerator
        )
    }
    
    override func tearDown() {
        mainProcessor = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(mainProcessor)
        XCTAssertNotNil(config)
    }
    
    func testConfigurationAccess() {
        let retrievedConfig = mainProcessor.getConfiguration()
        XCTAssertEqual(retrievedConfig.processing.overlapThreshold, config.processing.overlapThreshold)
        XCTAssertTrue(retrievedConfig.processing.enableHeaderFooterDetection)
        XCTAssertTrue(retrievedConfig.processing.enableElementMerging)
    }
    
    func testLLMConfiguration() {
        // Test that LLM configuration is accessible if enabled
        let retrievedConfig = mainProcessor.getConfiguration()
        XCTAssertNotNil(retrievedConfig.llm)
        // Note: LLM might be disabled in test config, which is fine
    }
    
    func testServicesIntegration() {
        // Test that all services are properly integrated
        XCTAssertNotNil(mainProcessor)
        XCTAssertNotNil(config)
    }
}
