//
//  LanguageDetector.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation
import NaturalLanguage
import mdkitProtocols

// MARK: - Language Detector Implementation

/// Language detector that uses Apple's Natural Language framework
public class LanguageDetector: LanguageDetecting {
    
    // MARK: - Properties
    
    /// Minimum text length required for reliable language detection
    private let minimumTextLength: Int
    
    /// Confidence threshold for language detection
    private let confidenceThreshold: Double
    
    /// Natural Language recognizer for language detection
    private let recognizer: NLLanguageRecognizer
    
    // MARK: - Initialization
    
    /// Initialize the language detector
    /// - Parameters:
    ///   - minimumTextLength: Minimum text length for reliable detection
    ///   - confidenceThreshold: Confidence threshold (0.0 to 1.0)
    public init(minimumTextLength: Int = 10, confidenceThreshold: Double = 0.6) {
        self.minimumTextLength = minimumTextLength
        self.confidenceThreshold = confidenceThreshold
        self.recognizer = NLLanguageRecognizer()
    }
    
    // MARK: - LanguageDetecting Protocol Implementation
    
    public func detectLanguage(from text: String) -> String {
        // Check minimum text length
        guard text.count >= minimumTextLength else {
            return "en" // Default to English for short text
        }
        
        // Reset recognizer for new text
        recognizer.reset()
        recognizer.processString(text)
        
        // Get the most likely language
        guard let language = recognizer.dominantLanguage else {
            return "en" // Default to English if detection fails
        }
        
        return language.rawValue
    }
    
    public func detectLanguageWithConfidence(from text: String) -> (language: String, confidence: Double) {
        // Check minimum text length
        guard text.count >= minimumTextLength else {
            return (language: "en", confidence: 0.5) // Low confidence for short text
        }
        
        // Reset recognizer for new text
        recognizer.reset()
        recognizer.processString(text)
        
        // Get language probabilities
        let languageHypotheses = recognizer.languageHypotheses(withMaximum: 5)
        
        // Find the highest confidence language above threshold
        let sortedLanguages = languageHypotheses.sorted { $0.value > $1.value }
        
        if let (language, confidence) = sortedLanguages.first, confidence >= confidenceThreshold {
            return (language: language.rawValue, confidence: confidence)
        } else if let (language, _) = sortedLanguages.first {
            // Return highest confidence even if below threshold
            return (language: language.rawValue, confidence: sortedLanguages.first?.value ?? 0.5)
        } else {
            return (language: "en", confidence: 0.5) // Default fallback
        }
    }
    
    public func isLanguageSupported(_ languageCode: String) -> Bool {
        // Check if the language code is supported by Apple's Natural Language framework
        // For now, return true for common languages - this can be enhanced later
        let commonLanguages = ["en", "es", "fr", "de", "it", "pt", "ru", "zh", "ja", "ko"]
        return commonLanguages.contains(languageCode)
    }
    
    // MARK: - Additional Utility Methods
    
    /// Get a list of all supported languages
    /// - Returns: Array of supported language codes
    public func getSupportedLanguages() -> [String] {
        // Return common supported languages - this can be enhanced later
        return ["en", "es", "fr", "de", "it", "pt", "ru", "zh", "ja", "ko"]
    }
    
    /// Get language display name for a language code
    /// - Parameter languageCode: The language code (e.g., "en", "es")
    /// - Returns: Human-readable language name
    public func getLanguageDisplayName(for languageCode: String) -> String {
        let locale = Locale(identifier: languageCode)
        return locale.localizedString(forLanguageCode: languageCode) ?? languageCode
    }
}
