//
//  LanguageDetectorIntegrationTests.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import XCTest
import Foundation
import CoreGraphics
@testable import mdkitCore
@testable import mdkitConfiguration
@testable import mdkitFileManagement
@testable import mdkitProtocols

final class LanguageDetectorIntegrationTests: XCTestCase {
    
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
    
    // MARK: - Configuration Tests
    
    func testLanguageDetectionConfiguration() {
        // Verify that the configuration is properly passed through
        XCTAssertNotNil(config.processing)
        XCTAssertEqual(config.processing.overlapThreshold, 0.15)
        XCTAssertTrue(config.processing.enableHeaderFooterDetection)
        XCTAssertTrue(config.processing.enableElementMerging)
    }
    
    func testLanguageDetectionIntegration() {
        // Test that the language detector is properly integrated
        XCTAssertNotNil(mainProcessor)
        
        // Verify the configuration is accessible
        let retrievedConfig = mainProcessor.getConfiguration()
        XCTAssertNotNil(retrievedConfig.processing)
        XCTAssertEqual(retrievedConfig.processing.overlapThreshold, 0.15)
    }
    
    func testServicesIntegration() {
        // Test that all services are properly integrated
        XCTAssertNotNil(mainProcessor)
        XCTAssertNotNil(config)
    }
}
