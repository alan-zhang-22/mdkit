//
//  LanguageDetector.swift
//  mdkit
//
// Created by alan zhang on 2025/8/27.
//

import Foundation
import NaturalLanguage
import Logging

// MARK: - Language Detector Implementation

/// Implementation of language detection using Apple's Natural Language framework
public class LanguageDetector: LanguageDetecting {
    
    // MARK: - Properties
    
    private let logger: Logger
    private let minimumTextLength: Int
    private let confidenceThreshold: Double
    
    // MARK: - Initialization
    
    public init(
        minimumTextLength: Int = 10,
        confidenceThreshold: Double = 0.6
    ) {
        self.minimumTextLength = minimumTextLength
        self.confidenceThreshold = confidenceThreshold
        self.logger = Logger(label: "mdkit.languagedetector")
        
        logger.info("LanguageDetector initialized with minLength: \(minimumTextLength), confidenceThreshold: \(confidenceThreshold)")
    }
    
    // MARK: - Public Methods
    
    /// Detects the language of the given text
    /// - Parameter text: The text to analyze for language detection
    /// - Returns: The detected language code (e.g., "en", "es", "fr")
    public func detectLanguage(from text: String) -> String {
        logger.debug("Detecting language for text of length: \(text.count)")
        
        // Check minimum text length
        guard text.count >= minimumTextLength else {
            logger.warning("Text too short for reliable language detection: \(text.count) characters")
            return "en" // Default to English for short texts
        }
        
        // Use Natural Language framework for language detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let language = recognizer.dominantLanguage else {
            logger.warning("Could not determine dominant language, defaulting to English")
            return "en"
        }
        
        let languageCode = language.rawValue
        logger.info("Detected language: \(languageCode) for text")
        
        return languageCode
    }
    
    /// Detects the language with confidence score
    /// - Parameter text: The text to analyze for language detection
    /// - Returns: A tuple containing the language code and confidence score
    public func detectLanguageWithConfidence(from text: String) -> (language: String, confidence: Double) {
        logger.debug("Detecting language with confidence for text of length: \(text.count)")
        
        // Check minimum text length
        guard text.count >= minimumTextLength else {
            logger.warning("Text too short for reliable language detection: \(text.count) characters")
            return (language: "en", confidence: 0.0)
        }
        
        // Use Natural Language framework for language detection with confidence
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let language = recognizer.dominantLanguage else {
            logger.warning("Could not determine dominant language")
            return (language: "en", confidence: 0.0)
        }
        
        let languageCode = language.rawValue
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[language] ?? 0.0
        
        logger.info("Detected language: \(languageCode) with confidence: \(String(format: "%.2f", confidence))")
        
        return (language: languageCode, confidence: confidence)
    }
    
    /// Checks if the given language code is supported
    /// - Parameter languageCode: The language code to check
    /// - Returns: True if the language is supported, false otherwise
    public func isLanguageSupported(_ languageCode: String) -> Bool {
        // Check if the language code exists in our supported languages
        let isSupported = SupportedLanguage.allCases.contains { $0.rawValue == languageCode }
        logger.debug("Language \(languageCode) supported: \(isSupported)")
        return isSupported
    }
    
    // MARK: - Enhanced Language Detection
    
    /// Detects multiple possible languages with confidence scores
    /// - Parameter text: The text to analyze
    /// - Parameter maxLanguages: Maximum number of languages to return
    /// - Returns: Array of language codes with confidence scores, sorted by confidence
    public func detectMultipleLanguages(
        from text: String,
        maxLanguages: Int = 3
    ) -> [(language: String, confidence: Double)] {
        logger.debug("Detecting multiple languages for text of length: \(text.count)")
        
        guard text.count >= minimumTextLength else {
            logger.warning("Text too short for reliable language detection: \(text.count) characters")
            return []
        }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        let hypotheses = recognizer.languageHypotheses(withMaximum: maxLanguages)
        
        // Convert to array and sort by confidence
        let sortedLanguages = hypotheses.sorted { $0.value > $1.value }
            .map { (language: $0.key.rawValue, confidence: $0.value) }
        
        logger.info("Detected \(sortedLanguages.count) languages: \(sortedLanguages.map { "\($0.language)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", "))")
        
        return sortedLanguages
    }
    
    /// Detects if text contains multiple languages (mixed content)
    /// - Parameter text: The text to analyze
    /// - Returns: True if multiple languages detected, false otherwise
    public func isMultilingual(from text: String) -> Bool {
        let languages = detectMultipleLanguages(from: text, maxLanguages: 2)
        let isMultilingual = languages.count > 1 && languages[1].confidence > confidenceThreshold
        
        logger.debug("Text multilingual detection: \(isMultilingual)")
        return isMultilingual
    }
    
    /// Gets the primary language with fallback logic
    /// - Parameter text: The text to analyze
    /// - Returns: The primary language code with fallback to English
    public func getPrimaryLanguage(from text: String) -> String {
        let (language, confidence) = detectLanguageWithConfidence(from: text)
        
        // If confidence is too low, fall back to English
        if confidence < confidenceThreshold {
            logger.warning("Low confidence (\(String(format: "%.2f", confidence))) for language \(language), falling back to English")
            return "en"
        }
        
        return language
    }
}

// MARK: - Language Detection Utilities

extension LanguageDetector {
    
    /// Detects language from document elements
    /// - Parameter elements: Array of document elements
    /// - Returns: The detected language code
    public func detectLanguageFromElements(_ elements: [String]) -> String {
        logger.debug("Detecting language from \(elements.count) document elements")
        
        // Combine all element text for better language detection
        let combinedText = elements.joined(separator: " ")
        
        // Use the primary language detection with fallback
        return getPrimaryLanguage(from: combinedText)
    }
    
    /// Detects language with context from previous pages
    /// - Parameter currentText: Current page text
    /// - Parameter previousLanguages: Previously detected languages
    /// - Returns: The detected language code
    public func detectLanguageWithContext(
        currentText: String,
        previousLanguages: [String]
    ) -> String {
        logger.debug("Detecting language with context from \(previousLanguages.count) previous pages")
        
        // If we have previous language detection, use it as a hint
        if let mostCommonLanguage = previousLanguages.mostFrequent() {
            logger.debug("Using previous language context: \(mostCommonLanguage)")
            
            // Check if current text supports the previous language
            let (detectedLanguage, confidence) = detectLanguageWithConfidence(from: currentText)
            
            if detectedLanguage == mostCommonLanguage && confidence >= confidenceThreshold {
                return detectedLanguage
            }
        }
        
        // Fall back to standard detection
        return getPrimaryLanguage(from: currentText)
    }
}

// MARK: - Array Extension for Most Frequent Element

private extension Array where Element == String {
    func mostFrequent() -> String? {
        let counts = self.reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
