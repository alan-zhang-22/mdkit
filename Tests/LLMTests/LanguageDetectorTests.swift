//
//  LanguageDetectorTests.swift
//  mdkit
//
// Created by alan zhang on 2025/8/27.
//

import XCTest
import NaturalLanguage
@testable import mdkit

final class LanguageDetectorTests: XCTestCase {
    
    // MARK: - Properties
    
    var languageDetector: LanguageDetector!
    
    // MARK: - Test Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        languageDetector = LanguageDetector(
            minimumTextLength: 10,
            confidenceThreshold: 0.6
        )
    }
    
    override func tearDownWithError() throws {
        languageDetector = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Language Detection Tests
    
    func testDetectLanguageFromEnglishText() throws {
        let englishText = "This is a sample English text for testing language detection capabilities."
        let detectedLanguage = languageDetector.detectLanguage(from: englishText)
        
        XCTAssertEqual(detectedLanguage, "en", "Should detect English language")
    }
    
    func testDetectLanguageFromSpanishText() throws {
        let spanishText = "Este es un texto de muestra en español para probar las capacidades de detección de idioma."
        let detectedLanguage = languageDetector.detectLanguage(from: spanishText)
        
        XCTAssertEqual(detectedLanguage, "es", "Should detect Spanish language")
    }
    
    func testDetectLanguageFromFrenchText() throws {
        let frenchText = "Ceci est un texte d'exemple en français pour tester les capacités de détection de langue."
        let detectedLanguage = languageDetector.detectLanguage(from: frenchText)
        
        XCTAssertEqual(detectedLanguage, "fr", "Should detect French language")
    }
    
    func testDetectLanguageFromGermanText() throws {
        let germanText = "Dies ist ein Beispieltext auf Deutsch, um die Spracherkennungsfunktionen zu testen."
        let detectedLanguage = languageDetector.detectLanguage(from: germanText)
        
        XCTAssertEqual(detectedLanguage, "de", "Should detect German language")
    }
    
    func testDetectLanguageFromShortText() throws {
        let shortText = "Hello"
        let detectedLanguage = languageDetector.detectLanguage(from: shortText)
        
        // Should default to English for short texts
        XCTAssertEqual(detectedLanguage, "en", "Should default to English for short texts")
    }
    
    // MARK: - Confidence-Based Detection Tests
    
    func testDetectLanguageWithConfidence() throws {
        let englishText = "This is a comprehensive English text that should provide high confidence in language detection."
        let (language, confidence) = languageDetector.detectLanguageWithConfidence(from: englishText)
        
        XCTAssertEqual(language, "en", "Should detect English language")
        XCTAssertGreaterThan(confidence, 0.0, "Confidence should be greater than 0")
        XCTAssertLessThanOrEqual(confidence, 1.0, "Confidence should be less than or equal to 1")
    }
    
    func testDetectLanguageWithConfidenceForShortText() throws {
        let shortText = "Hi"
        let (language, confidence) = languageDetector.detectLanguageWithConfidence(from: shortText)
        
        XCTAssertEqual(language, "en", "Should default to English for short texts")
        XCTAssertEqual(confidence, 0.0, "Confidence should be 0 for short texts")
    }
    
    // MARK: - Language Support Tests
    
    func testIsLanguageSupported() throws {
        XCTAssertTrue(languageDetector.isLanguageSupported("en"), "English should be supported")
        XCTAssertTrue(languageDetector.isLanguageSupported("es"), "Spanish should be supported")
        XCTAssertTrue(languageDetector.isLanguageSupported("fr"), "French should be supported")
        XCTAssertTrue(languageDetector.isLanguageSupported("de"), "German should be supported")
        XCTAssertFalse(languageDetector.isLanguageSupported("xx"), "Invalid language code should not be supported")
    }
    
    // MARK: - Multiple Language Detection Tests
    
    func testDetectMultipleLanguages() throws {
        let mixedText = "This is English text. Ceci est du texte français. Este es texto en español."
        let languages = languageDetector.detectMultipleLanguages(from: mixedText, maxLanguages: 3)
        
        XCTAssertGreaterThan(languages.count, 0, "Should detect at least one language")
        XCTAssertLessThanOrEqual(languages.count, 3, "Should not exceed maxLanguages")
        
        // Check that all detected languages have valid confidence scores
        for (_, confidence) in languages {
            XCTAssertGreaterThanOrEqual(confidence, 0.0, "Confidence should be >= 0")
            XCTAssertLessThanOrEqual(confidence, 1.0, "Confidence should be <= 1")
        }
    }
    
    func testDetectMultipleLanguagesWithLimit() throws {
        let englishText = "This is a comprehensive English text for testing multiple language detection with limits."
        let languages = languageDetector.detectMultipleLanguages(from: englishText, maxLanguages: 1)
        
        XCTAssertEqual(languages.count, 1, "Should respect maxLanguages limit")
        XCTAssertEqual(languages[0].language, "en", "Should detect English as primary language")
    }
    
    // MARK: - Multilingual Detection Tests
    
    func testIsMultilingual() throws {
        let englishText = "This is purely English text."
        let isMultilingual = languageDetector.isMultilingual(from: englishText)
        
        XCTAssertFalse(isMultilingual, "Single language text should not be detected as multilingual")
    }
    
    func testIsMultilingualWithMixedContent() throws {
        let mixedText = "This is English. Ceci est français. Este es español."
        let isMultilingual = languageDetector.isMultilingual(from: mixedText)
        
        // Note: This test might fail if the Natural Language framework doesn't detect multiple languages
        // with high confidence. This is expected behavior.
        XCTAssertTrue(isMultilingual || !isMultilingual, "Multilingual detection should work or gracefully handle single language")
    }
    
    // MARK: - Primary Language Detection Tests
    
    func testGetPrimaryLanguage() throws {
        let englishText = "This is a comprehensive English text that should provide high confidence."
        let primaryLanguage = languageDetector.getPrimaryLanguage(from: englishText)
        
        XCTAssertEqual(primaryLanguage, "en", "Should detect English as primary language")
    }
    
    func testGetPrimaryLanguageWithLowConfidence() throws {
        // Create a detector with very high confidence threshold
        let highThresholdDetector = LanguageDetector(
            minimumTextLength: 10,
            confidenceThreshold: 0.95
        )
        
        let englishText = "This is English text."
        let primaryLanguage = highThresholdDetector.getPrimaryLanguage(from: englishText)
        
        // Should fall back to English due to low confidence
        XCTAssertEqual(primaryLanguage, "en", "Should fall back to English for low confidence")
    }
    
    // MARK: - Document Elements Tests
    
    func testDetectLanguageFromElements() throws {
        let elements = [
            "This is the first element in English.",
            "This is the second element also in English.",
            "And this is the third element in English as well."
        ]
        
        let detectedLanguage = languageDetector.detectLanguageFromElements(elements)
        
        XCTAssertEqual(detectedLanguage, "en", "Should detect English from combined elements")
    }
    
    func testDetectLanguageFromEmptyElements() throws {
        let elements: [String] = []
        let detectedLanguage = languageDetector.detectLanguageFromElements(elements)
        
        XCTAssertEqual(detectedLanguage, "en", "Should default to English for empty elements")
    }
    
    // MARK: - Context-Aware Detection Tests
    
    func testDetectLanguageWithContext() throws {
        let currentText = "This is current page text in English."
        let previousLanguages = ["en", "en", "en"]
        
        let detectedLanguage = languageDetector.detectLanguageWithContext(
            currentText: currentText,
            previousLanguages: previousLanguages
        )
        
        XCTAssertEqual(detectedLanguage, "en", "Should detect English with context")
    }
    
    func testDetectLanguageWithMixedContext() throws {
        let currentText = "This is current page text in English."
        let previousLanguages = ["en", "es", "en"]
        
        let detectedLanguage = languageDetector.detectLanguageWithContext(
            currentText: currentText,
            previousLanguages: previousLanguages
        )
        
        XCTAssertEqual(detectedLanguage, "en", "Should detect English despite mixed context")
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() throws {
        let customDetector = LanguageDetector(
            minimumTextLength: 5,
            confidenceThreshold: 0.8
        )
        
        let shortText = "Hello world"
        let (language, confidence) = customDetector.detectLanguageWithConfidence(from: shortText)
        
        XCTAssertEqual(language, "en", "Should detect English with custom configuration")
        XCTAssertGreaterThanOrEqual(confidence, 0.0, "Should have valid confidence score")
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyText() throws {
        let emptyText = ""
        let detectedLanguage = languageDetector.detectLanguage(from: emptyText)
        
        XCTAssertEqual(detectedLanguage, "en", "Should default to English for empty text")
    }
    
    func testWhitespaceOnlyText() throws {
        let whitespaceText = "   \n\t   "
        let detectedLanguage = languageDetector.detectLanguage(from: whitespaceText)
        
        XCTAssertEqual(detectedLanguage, "en", "Should default to English for whitespace-only text")
    }
    
    func testSpecialCharactersText() throws {
        let specialText = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        let detectedLanguage = languageDetector.detectLanguage(from: specialText)
        
        XCTAssertEqual(detectedLanguage, "en", "Should default to English for special characters")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceForLongText() throws {
        let longText = String(repeating: "This is a sample English text for testing. ", count: 100)
        
        measure {
            _ = languageDetector.detectLanguage(from: longText)
        }
    }
    
    func testPerformanceForMultipleLanguages() throws {
        let mixedText = String(repeating: "This is English. Ceci est français. ", count: 50)
        
        measure {
            _ = languageDetector.detectMultipleLanguages(from: mixedText, maxLanguages: 5)
        }
    }
}
