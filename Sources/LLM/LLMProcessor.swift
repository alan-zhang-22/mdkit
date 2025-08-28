//
//  LLMProcessor.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation
import LocalLLMClient
import LocalLLMClientLlama
import mdkitConfiguration
import Logging
import mdkitProtocols

// MARK: - LLM Processor Protocol

public protocol LLMProcessing {
    func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String, detectedLanguage: String) async throws -> String
    func analyzeDocumentStructure(_ elements: String, detectedLanguage: String) async throws -> String
    func optimizeTable(_ tableContent: String, detectedLanguage: String) async throws -> String
    func optimizeList(_ listContent: String, detectedLanguage: String) async throws -> String
    func optimizeHeaders(_ headerContent: String, detectedLanguage: String) async throws -> String
    func getTechnicalStandardPrompt(for content: String, detectedLanguage: String) -> String
}

// MARK: - LLM Processor Implementation

public class LLMProcessor: LLMProcessing {
    // MARK: - Properties
    
    private let config: MDKitConfig
    private let client: LLMClient
    private let promptManager: PromptTemplating
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init(
        config: MDKitConfig,
        client: LLMClient
    ) {
        self.config = config
        self.client = client
        self.promptManager = PromptManager.create(from: config)
        self.logger = Logger(label: "mdkit.llmprocessor")
    }
    
    // MARK: - Public Methods
    
    public func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String, detectedLanguage: String = "en") async throws -> String {
        logger.info("Starting markdown optimization for language: \(detectedLanguage)")
        
        // Use provided language or default to English
        let language = detectedLanguage.isEmpty ? "en" : detectedLanguage
        let languageConfidence: Double = 0.8 // Default confidence
        
        logger.info("Using language: \(language) with confidence: \(String(format: "%.2f", languageConfidence))")
        
        // Get language-specific prompt template
        let prompt = promptManager.getMarkdownOptimizationPrompt(
            for: language,
            documentTitle: "Document", // TODO: Extract from context
            pageCount: 1, // TODO: Extract from context
            elementCount: elements.components(separatedBy: "\n").count,
            documentContext: documentContext,
            detectedLanguage: language,
            languageConfidence: languageConfidence,
            markdown: markdown
        )
        
        logger.debug("Using prompt template for language: \(detectedLanguage)")
        logger.debug("Sending optimization prompt to LLM")
        
        let result = try await client.generateText(from: prompt)
        logger.info("Markdown optimization completed successfully")
        
        return result
    }
    
    public func analyzeDocumentStructure(_ elements: String, detectedLanguage: String = "en") async throws -> String {
        logger.info("Starting document structure analysis for language: \(detectedLanguage)")
        
        // Use provided language or default to English
        let language = detectedLanguage.isEmpty ? "en" : detectedLanguage
        logger.info("Using language for structure analysis: \(language)")
        
        // Get language-specific prompt template
        let prompt = promptManager.getStructureAnalysisPrompt(
            for: language,
            documentType: "Technical Document", // TODO: Extract from content analysis
            elementCount: elements.components(separatedBy: "\n").count,
            detectedLanguage: language,
            elementDescriptions: elements
        )
        
        logger.debug("Using structure analysis prompt template for language: \(detectedLanguage)")
        logger.debug("Sending structure analysis prompt to LLM")
        
        let result = try await client.generateText(from: prompt)
        logger.info("Document structure analysis completed successfully")
        
        return result
    }
    
    // MARK: - Additional Optimization Methods
    
    /// Optimizes table structure using language-specific prompts
    /// - Parameter tableContent: Table content to optimize
    /// - Returns: Optimized table structure
    public func optimizeTable(_ tableContent: String, detectedLanguage: String = "en") async throws -> String {
        logger.info("Starting table optimization for language: \(detectedLanguage)")
        
        let language = detectedLanguage.isEmpty ? "en" : detectedLanguage
        let prompt = promptManager.getTableOptimizationPrompt(
            for: language,
            tableContent: tableContent
        )
        
        logger.debug("Using table optimization prompt for language: \(detectedLanguage)")
        let result = try await client.generateText(from: prompt)
        logger.info("Table optimization completed successfully")
        
        return result
    }
    
    /// Optimizes list structure using language-specific prompts
    /// - Parameter listContent: List content to optimize
    /// - Returns: Optimized list structure
    public func optimizeList(_ listContent: String, detectedLanguage: String = "en") async throws -> String {
        logger.info("Starting list optimization for language: \(detectedLanguage)")
        
        let language = detectedLanguage.isEmpty ? "en" : detectedLanguage
        let prompt = promptManager.getListOptimizationPrompt(
            for: language,
            listContent: listContent
        )
        
        logger.debug("Using list optimization prompt for language: \(detectedLanguage)")
        let result = try await client.generateText(from: prompt)
        logger.info("List optimization completed successfully")
        
        return result
    }
    
    /// Optimizes header structure using language-specific prompts
    /// - Parameter headerContent: Header content to optimize
    /// - Returns: Optimized header structure
    public func optimizeHeaders(_ headerContent: String, detectedLanguage: String = "en") async throws -> String {
        logger.info("Starting header optimization for language: \(detectedLanguage)")
        
        let language = detectedLanguage.isEmpty ? "en" : detectedLanguage
        let prompt = promptManager.getHeaderOptimizationPrompt(
            for: language,
            headerContent: headerContent
        )
        
        logger.debug("Using header optimization prompt for language: \(detectedLanguage)")
        let result = try await client.generateText(from: prompt)
        logger.info("Header optimization completed successfully")
        
        return result
    }
    
    /// Gets technical standard prompt for the specified language
    /// - Parameter content: Content to determine language from
    /// - Returns: Technical standard prompt
    public func getTechnicalStandardPrompt(for content: String, detectedLanguage: String = "en") -> String {
        let language = detectedLanguage.isEmpty ? "en" : detectedLanguage
        return promptManager.getTechnicalStandardPrompt(for: language)
    }
    
    // MARK: - Factory Method
    
    public static func create(config: MDKitConfig) throws -> LLMProcessor {
        let logger = Logger(label: "mdkit.llmprocessor.factory")
        logger.info("Creating LLMProcessor with configuration")
        
        // Create LLM client with configuration
        let client = try createLLMClient(config: config)
        
        logger.info("LLMProcessor created successfully")
        return LLMProcessor(
            config: config,
            client: client
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func createLLMClient(config: MDKitConfig) throws -> LLMClient {
        let logger = Logger(label: "mdkit.llmprocessor.client")
        logger.debug("Creating LLM client")
        
        // Check if LLM optimization is enabled
        guard config.processing.enableLLMOptimization else {
            logger.info("LLM optimization disabled, using mock client")
            return MockLLMClient()
        }
        
        // Implementation will depend on the specific LLM backend configuration
        // For now, return a mock client - this will be enhanced later with real LocalLLMClient
        logger.info("Using mock LLM client (real implementation pending)")
        return MockLLMClient()
    }
    

}

// MARK: - Supporting Types

public protocol LLMClient {
    func textStream(from input: String) async throws -> AsyncThrowingStream<String, Error>
    func generateText(from input: String) async throws -> String
}

public protocol LanguageDetecting {
    func detectLanguage(from elements: String) -> String
}

// MARK: - Mock Implementations (Temporary)

private class MockLLMClient: LLMClient {
    func textStream(from input: String) async throws -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield("Mock response")
            continuation.finish()
        }
    }
    
    func generateText(from input: String) async throws -> String {
        return "Mock generated text"
    }
}


