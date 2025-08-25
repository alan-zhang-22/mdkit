//
//  LanguageDetecting.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation

// MARK: - Language Detection Protocol

/// Protocol defining the interface for language detection
public protocol LanguageDetecting {
    /// Detects the language of the given text
    /// - Parameter text: The text to analyze for language detection
    /// - Returns: The detected language code (e.g., "en", "es", "fr")
    func detectLanguage(from text: String) -> String
    
    /// Detects the language with confidence score
    /// - Parameter text: The text to analyze for language detection
    /// - Returns: A tuple containing the language code and confidence score
    func detectLanguageWithConfidence(from text: String) -> (language: String, confidence: Double)
    
    /// Checks if the given language code is supported
    /// - Parameter languageCode: The language code to check
    /// - Returns: True if the language is supported, false otherwise
    func isLanguageSupported(_ languageCode: String) -> Bool
}

// MARK: - Language Detection Errors

public enum LanguageDetectionError: Error, LocalizedError {
    case textTooShort
    case unsupportedLanguage
    case detectionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .textTooShort:
            return "Text is too short for reliable language detection"
        case .unsupportedLanguage:
            return "Language is not supported by the detection system"
        case .detectionFailed(let reason):
            return "Language detection failed: \(reason)"
        }
    }
}

// MARK: - Supported Languages

public enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        }
    }
}
