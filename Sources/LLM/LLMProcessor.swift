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
import mdkitLogging

// MARK: - LLM Processor Protocol

public protocol LLMProcessing {
    func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String) async throws -> String
    func analyzeDocumentStructure(_ elements: String) async throws -> String
}

// MARK: - LLM Processor Implementation

public class LLMProcessor: LLMProcessing {
    // MARK: - Properties
    
    private let config: MDKitConfig
    private let client: LLMClient
    private let languageDetector: LanguageDetecting
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init(
        config: MDKitConfig,
        client: LLMClient,
        languageDetector: LanguageDetecting,
        logger: Logger
    ) {
        self.config = config
        self.client = client
        self.languageDetector = languageDetector
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    public func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String) async throws -> String {
        logger.info("Starting markdown optimization")
        
        let prompt = """
        You are an expert at optimizing Markdown documents. Please analyze and improve the following markdown:
        
        MARKDOWN TO OPTIMIZE:
        \(markdown)
        
        DOCUMENT CONTEXT:
        \(documentContext)
        
        DOCUMENT ELEMENTS:
        \(elements)
        
        Please provide an optimized version that:
        1. Maintains the original structure and meaning
        2. Improves formatting and readability
        3. Fixes any markdown syntax issues
        4. Enhances the overall document quality
        
        Return only the optimized markdown, no explanations.
        """
        
        logger.debug("Sending optimization prompt to LLM")
        let result = try await client.generateText(from: prompt)
        logger.info("Markdown optimization completed successfully")
        
        return result
    }
    
    public func analyzeDocumentStructure(_ elements: String) async throws -> String {
        logger.info("Starting document structure analysis")
        
        let prompt = """
        Analyze the following document elements and provide a structural analysis:
        
        ELEMENTS:
        \(elements)
        
        Please provide:
        1. Document type identification
        2. Main sections and subsections
        3. Content organization patterns
        4. Recommendations for markdown structure
        
        Return a structured analysis in markdown format.
        """
        
        logger.debug("Sending structure analysis prompt to LLM")
        let result = try await client.generateText(from: prompt)
        logger.info("Document structure analysis completed successfully")
        
        return result
    }
    
    // MARK: - Factory Method
    
    public static func create(config: MDKitConfig, logger: Logger) throws -> LLMProcessor {
        logger.info("Creating LLMProcessor with configuration")
        
        // Create LLM client with configuration
        let client = try createLLMClient(config: config, logger: logger)
        let languageDetector = createLanguageDetector(config: config, logger: logger)
        
        logger.info("LLMProcessor created successfully")
        return LLMProcessor(
            config: config,
            client: client,
            languageDetector: languageDetector,
            logger: logger
        )
    }
    
    // MARK: - Private Helper Methods
    
    private static func createLLMClient(config: MDKitConfig, logger: Logger) throws -> LLMClient {
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
    
    private static func createLanguageDetector(config: MDKitConfig, logger: Logger) -> LanguageDetecting {
        logger.debug("Creating language detector")
        
        // Implementation will use Natural Language framework
        // For now, return a mock detector - this will be enhanced later
        logger.info("Using mock language detector (real implementation pending)")
        return MockLanguageDetector()
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
