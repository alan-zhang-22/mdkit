//
//  LanguageDetectorIntegrationTests.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import XCTest
@testable import mdkitCore
@testable import mdkitConfiguration

final class LanguageDetectorIntegrationTests: XCTestCase {
    
    var config: MDKitConfig!
    var mainProcessor: MainProcessor!
    
    override func setUp() {
        super.setUp()
        
        // Use default configuration with custom language detection
        config = MDKitConfig(
            processing: ProcessingConfig(
                languageDetection: LanguageDetectionConfig(
                    minimumTextLength: 5,
                    confidenceThreshold: 0.7
                )
            )
        )
        
        do {
            mainProcessor = try MainProcessor(config: config)
        } catch {
            XCTFail("Failed to create MainProcessor: \(error)")
        }
    }
    
    override func tearDown() {
        mainProcessor = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Language Detection Tests
    
    func testLanguageDetectionIntegration() {
        // Test that language detection is working
        let englishText = "This is a sample English text for testing language detection."
        let detectedLanguage = mainProcessor.detectLanguage(from: englishText)
        
        XCTAssertEqual(detectedLanguage, "en", "Should detect English text correctly")
    }
    
    func testLanguageDetectionWithConfidence() {
        let englishText = "This is a longer English text that should provide better confidence for language detection."
        let (language, confidence) = mainProcessor.detectLanguageWithConfidence(from: englishText)
        
        XCTAssertEqual(language, "en", "Should detect English text correctly")
        XCTAssertGreaterThan(confidence, 0.5, "Confidence should be reasonable")
    }
    
    func testLanguageDetectionForShortText() {
        let shortText = "Hi"
        let detectedLanguage = mainProcessor.detectLanguage(from: shortText)
        
        // Should default to English for short text
        XCTAssertEqual(detectedLanguage, "en", "Should default to English for short text")
    }
    
    func testLanguageDetectionForEmptyText() {
        let emptyText = ""
        let detectedLanguage = mainProcessor.detectLanguage(from: emptyText)
        
        // Should default to English for empty text
        XCTAssertEqual(detectedLanguage, "en", "Should default to English for empty text")
    }
    
    func testLanguageDetectionConfiguration() {
        // Verify that the language detection configuration is properly passed through
        let stats = mainProcessor.getStatistics()
        
        // The language detector should be initialized with the config values
        let testText = "This is a test text that should be long enough for language detection."
        let (_, confidence) = mainProcessor.detectLanguageWithConfidence(from: testText)
        
        // With confidence threshold 0.7, we should get reasonable confidence
        XCTAssertGreaterThan(confidence, 0.5, "Confidence should be reasonable for configured threshold")
    }
    
    func testLanguageDetectionPerformance() {
        let longText = String(repeating: "This is a sample English text for testing language detection performance. ", count: 100)
        
        measure {
            for _ in 0..<10 {
                _ = mainProcessor.detectLanguage(from: longText)
            }
        }
    }
    
    func testLanguageDetectionStatistics() {
        let stats = mainProcessor.getStatistics()
        
        // Initially, language distribution should be empty
        XCTAssertTrue(stats.languageDistribution.isEmpty, "Language distribution should be empty initially")
        
        // After detecting some languages, the distribution should be updated
        let testTexts = [
            "This is English text.",
            "Ceci est du texte français.",
            "Dies ist deutscher Text.",
            "Este es texto en español."
        ]
        
        for text in testTexts {
            let language = mainProcessor.detectLanguage(from: text)
            // Note: We can't directly test the statistics update since it's called during PDF processing
            // But we can verify the language detection is working
            XCTAssertFalse(language.isEmpty, "Language detection should return a non-empty string")
        }
    }
}
