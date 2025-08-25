//
//  LLMClient.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation

// MARK: - LLM Client Protocol

/// Protocol defining the interface for LLM clients
public protocol LLMClient {
    /// Generates text from a given input prompt
    /// - Parameter input: The input prompt to send to the LLM
    /// - Returns: The generated text response
    /// - Throws: An error if the LLM request fails
    func generateText(from input: String) async throws -> String
    
    /// Generates a streaming text response from a given input prompt
    /// - Parameter input: The input prompt to send to the LLM
    /// - Returns: An async stream of text chunks
    /// - Throws: An error if the LLM request fails
    func textStream(from input: String) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - LLM Client Errors

public enum LLMClientError: Error, LocalizedError {
    case connectionFailed
    case modelNotLoaded
    case invalidInput
    case generationFailed(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to LLM backend"
        case .modelNotLoaded:
            return "LLM model is not loaded or available"
        case .invalidInput:
            return "Invalid input provided to LLM"
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .timeout:
            return "LLM request timed out"
        }
    }
}
