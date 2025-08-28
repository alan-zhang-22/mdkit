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
    func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String) async throws -> String
    func analyzeDocumentStructure(_ elements: String) async throws -> String
    func optimizeTable(_ tableContent: String) async throws -> String
    func optimizeList(_ listContent: String) async throws -> String
    func optimizeHeaders(_ headerContent: String) async throws -> String
    func getTechnicalStandardPrompt(for content: String) -> String
}

// MARK: - LLM Processor Implementation

public class LLMProcessor: LLMProcessing {
    // MARK: - Properties
    
    private let config: MDKitConfig
    private let client: LLMClient
    private let languageDetector: LanguageDetecting
    private let promptManager: PromptTemplating
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init(
        config: MDKitConfig,
        client: LLMClient,
        languageDetector: LanguageDetecting
    ) {
        self.config = config
        self.client = client
        self.languageDetector = languageDetector
        self.promptManager = PromptManager.create(from: config)
        self.logger = Logger(label: "mdkit.llmprocessor")
    }
    
    // MARK: - Public Methods
    
    public func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String) async throws -> String {
        logger.info("Starting markdown optimization")
        
        // Detect language from the markdown content
        let detectedLanguage = languageDetector.detectLanguage(from: markdown)
        // TODO: Fix protocol method resolution issue
        let languageConfidence: Double = 0.8 // Temporary fallback
        
        logger.info("Detected language: \(detectedLanguage) with confidence: \(String(format: "%.2f", languageConfidence))")
        
        // Get language-specific prompt template
        let prompt = promptManager.getMarkdownOptimizationPrompt(
            for: detectedLanguage,
            documentTitle: "Document", // TODO: Extract from context
            pageCount: 1, // TODO: Extract from context
            elementCount: elements.components(separatedBy: "\n").count,
            documentContext: documentContext,
            detectedLanguage: detectedLanguage,
            languageConfidence: languageConfidence,
            markdown: markdown
        )
        
        logger.debug("Using prompt template for language: \(detectedLanguage)")
        logger.debug("Sending optimization prompt to LLM")
        
        let result = try await client.generateText(from: prompt)
        logger.info("Markdown optimization completed successfully")
        
        return result
    }
    
    public func analyzeDocumentStructure(_ elements: String) async throws -> String {
        logger.info("Starting document structure analysis")
        
        // Detect language from the elements
        let detectedLanguage = languageDetector.detectLanguage(from: elements)
        logger.info("Detected language for structure analysis: \(detectedLanguage)")
        
        // Get language-specific prompt template
        let prompt = promptManager.getStructureAnalysisPrompt(
            for: detectedLanguage,
            documentType: "Technical Document", // TODO: Extract from content analysis
            elementCount: elements.components(separatedBy: "\n").count,
            detectedLanguage: detectedLanguage,
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
    public func optimizeTable(_ tableContent: String) async throws -> String {
        logger.info("Starting table optimization")
        
        let detectedLanguage = languageDetector.detectLanguage(from: tableContent)
        let prompt = promptManager.getTableOptimizationPrompt(
            for: detectedLanguage,
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
    public func optimizeList(_ listContent: String) async throws -> String {
        logger.info("Starting list optimization")
        
        let detectedLanguage = languageDetector.detectLanguage(from: listContent)
        let prompt = promptManager.getListOptimizationPrompt(
            for: detectedLanguage,
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
    public func optimizeHeaders(_ headerContent: String) async throws -> String {
        logger.info("Starting header optimization")
        
        let detectedLanguage = languageDetector.detectLanguage(from: headerContent)
        let prompt = promptManager.getHeaderOptimizationPrompt(
            for: detectedLanguage,
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
    public func getTechnicalStandardPrompt(for content: String) -> String {
        let detectedLanguage = languageDetector.detectLanguage(from: content)
        return promptManager.getTechnicalStandardPrompt(for: detectedLanguage)
    }
    
    // MARK: - Factory Method
    
    public static func create(config: MDKitConfig) throws -> LLMProcessor {
        let logger = Logger(label: "mdkit.llmprocessor.factory")
        logger.info("Creating LLMProcessor with configuration")
        
        // Create LLM client with configuration
        let client = try createLLMClient(config: config)
        let languageDetector = createLanguageDetector(config: config)
        
        logger.info("LLMProcessor created successfully")
        return LLMProcessor(
            config: config,
            client: client,
            languageDetector: languageDetector
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
    
    private static func createLanguageDetector(config: MDKitConfig) -> LanguageDetecting {
        let logger = Logger(label: "mdkit.llmprocessor.language")
        logger.debug("Creating language detector")
        
        // Create real language detector with configuration
        let minimumTextLength = config.processing.languageDetection?.minimumTextLength ?? 10
        let confidenceThreshold = config.processing.languageDetection?.confidenceThreshold ?? 0.6
        
        logger.info("Creating real language detector with minLength: \(minimumTextLength), confidenceThreshold: \(confidenceThreshold)")
        return LanguageDetector(
            minimumTextLength: minimumTextLength,
            confidenceThreshold: confidenceThreshold
        )
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

private class MockLanguageDetector: LanguageDetecting {
    func detectLanguage(from elements: String) -> String {
        return "en"
    }
}
