//
//  PromptTemplates.swift
//  mdkit
//
// Created by alan zhang on 2025/8/27.
//

import Foundation
import Logging

// MARK: - Prompt Templates Protocol

public protocol PromptTemplating {
    func getSystemPrompt(for language: String) -> String
    func getMarkdownOptimizationPrompt(
        for language: String,
        documentTitle: String,
        pageCount: Int,
        elementCount: Int,
        documentContext: String,
        detectedLanguage: String,
        languageConfidence: Double,
        markdown: String
    ) -> String
    func getStructureAnalysisPrompt(
        for language: String,
        documentType: String,
        elementCount: Int,
        detectedLanguage: String,
        elementDescriptions: String
    ) -> String
    func getTableOptimizationPrompt(
        for language: String,
        tableContent: String
    ) -> String
    func getListOptimizationPrompt(
        for language: String,
        listContent: String
    ) -> String
    func getHeaderOptimizationPrompt(
        for language: String,
        headerContent: String
    ) -> String
    func getTechnicalStandardPrompt(
        for language: String
    ) -> String
}

// MARK: - Prompt Templates Implementation

/// Manages and provides prompt templates for different languages and use cases
public class PromptTemplates: PromptTemplating {
    
    // MARK: - Properties
    
    private let config: PromptTemplates
    private let logger: Logger
    
    // MARK: - Initialization
    
    public init(config: PromptTemplates) {
        self.config = config
        self.logger = Logger(label: "mdkit.prompttemplates")
        
        logger.info("PromptTemplates initialized with \(config.languages.count) languages")
        logger.debug("Available languages: \(config.languages.keys.sorted().joined(separator: ", "))")
    }
    
    // MARK: - Public Methods
    
    /// Gets the system prompt for the specified language
    /// - Parameter language: Language code (e.g., "en", "zh")
    /// - Returns: System prompt as a single string
    public func getSystemPrompt(for language: String) -> String {
        let prompts = getLanguagePrompts(for: language)
        let systemPrompt = prompts.systemPrompt.joined(separator: "\n")
        
        logger.debug("Retrieved system prompt for language: \(language)")
        return systemPrompt
    }
    
    /// Gets the markdown optimization prompt with all placeholders replaced
    /// - Parameters:
    ///   - language: Language code
    ///   - documentTitle: Document title
    ///   - pageCount: Number of pages
    ///   - elementCount: Number of elements
    ///   - documentContext: Document context
    ///   - detectedLanguage: Detected language
    ///   - languageConfidence: Language detection confidence
    ///   - markdown: Markdown content to optimize
    /// - Returns: Formatted optimization prompt
    public func getMarkdownOptimizationPrompt(
        for language: String,
        documentTitle: String,
        pageCount: Int,
        elementCount: Int,
        documentContext: String,
        detectedLanguage: String,
        languageConfidence: Double,
        markdown: String
    ) -> String {
        let prompts = getLanguagePrompts(for: language)
        let template = prompts.markdownOptimizationPrompt.joined(separator: "\n")
        
        let formattedPrompt = template
            .replacingOccurrences(of: "{documentTitle}", with: documentTitle)
            .replacingOccurrences(of: "{pageCount}", with: String(pageCount))
            .replacingOccurrences(of: "{elementCount}", with: String(elementCount))
            .replacingOccurrences(of: "{documentContext}", with: documentContext)
            .replacingOccurrences(of: "{detectedLanguage}", with: detectedLanguage)
            .replacingOccurrences(of: "{languageConfidence}", with: String(format: "%.2f", languageConfidence))
            .replacingOccurrences(of: "{markdown}", with: markdown)
        
        logger.debug("Generated markdown optimization prompt for language: \(language)")
        return formattedPrompt
    }
    
    /// Gets the structure analysis prompt with placeholders replaced
    /// - Parameters:
    ///   - language: Language code
    ///   - documentType: Type of document
    ///   - elementCount: Number of elements
    ///   - detectedLanguage: Detected language
    ///   - elementDescriptions: Description of document elements
    /// - Returns: Formatted structure analysis prompt
    public func getStructureAnalysisPrompt(
        for language: String,
        documentType: String,
        elementCount: Int,
        detectedLanguage: String,
        elementDescriptions: String
    ) -> String {
        let prompts = getLanguagePrompts(for: language)
        
        guard let template = prompts.structureAnalysisPrompt?.joined(separator: "\n") else {
            logger.warning("Structure analysis prompt not available for language: \(language)")
            return getFallbackStructureAnalysisPrompt(
                documentType: documentType,
                elementCount: elementCount,
                detectedLanguage: detectedLanguage,
                elementDescriptions: elementDescriptions
            )
        }
        
        let formattedPrompt = template
            .replacingOccurrences(of: "{documentType}", with: documentType)
            .replacingOccurrences(of: "{elementCount}", with: String(elementCount))
            .replacingOccurrences(of: "{detectedLanguage}", with: detectedLanguage)
            .replacingOccurrences(of: "{elementDescriptions}", with: elementDescriptions)
        
        logger.debug("Generated structure analysis prompt for language: \(language)")
        return formattedPrompt
    }
    
    /// Gets the table optimization prompt
    /// - Parameters:
    ///   - language: Language code
    ///   - tableContent: Table content to optimize
    /// - Returns: Formatted table optimization prompt
    public func getTableOptimizationPrompt(
        for language: String,
        tableContent: String
    ) -> String {
        let prompts = getLanguagePrompts(for: language)
        
        guard let template = prompts.tableOptimizationPrompt?.joined(separator: "\n") else {
            logger.warning("Table optimization prompt not available for language: \(language)")
            return getFallbackTableOptimizationPrompt(tableContent: tableContent)
        }
        
        let formattedPrompt = template
            .replacingOccurrences(of: "{tableContent}", with: tableContent)
        
        logger.debug("Generated table optimization prompt for language: \(language)")
        return formattedPrompt
    }
    
    /// Gets the list optimization prompt
    /// - Parameters:
    ///   - language: Language code
    ///   - listContent: List content to optimize
    /// - Returns: Formatted list optimization prompt
    public func getListOptimizationPrompt(
        for language: String,
        listContent: String
    ) -> String {
        let prompts = getLanguagePrompts(for: language)
        
        guard let template = prompts.listOptimizationPrompt?.joined(separator: "\n") else {
            logger.warning("List optimization prompt not available for language: \(language)")
            return getFallbackListOptimizationPrompt(listContent: listContent)
        }
        
        let formattedPrompt = template
            .replacingOccurrences(of: "{listContent}", with: listContent)
        
        logger.debug("Generated list optimization prompt for language: \(language)")
        return formattedPrompt
    }
    
    /// Gets the header optimization prompt
    /// - Parameters:
    ///   - language: Language code
    ///   - headerContent: Header content to optimize
    /// - Returns: Formatted header optimization prompt
    public func getHeaderOptimizationPrompt(
        for language: String,
        headerContent: String
    ) -> String {
        let prompts = getLanguagePrompts(for: language)
        
        guard let template = prompts.headerOptimizationPrompt?.joined(separator: "\n") else {
            logger.warning("Header optimization prompt not available for language: \(language)")
            return getFallbackHeaderOptimizationPrompt(headerContent: headerContent)
        }
        
        let formattedPrompt = template
            .replacingOccurrences(of: "{headerContent}", with: headerContent)
        
        logger.debug("Generated header optimization prompt for language: \(language)")
        return formattedPrompt
    }
    
    /// Gets the technical standard prompt
    /// - Parameter language: Language code
    /// - Returns: Technical standard prompt
    public func getTechnicalStandardPrompt(
        for language: String
    ) -> String {
        let prompts = getLanguagePrompts(for: language)
        
        guard let template = prompts.technicalStandardPrompt?.joined(separator: "\n") else {
            logger.warning("Technical standard prompt not available for language: \(language)")
            return getFallbackTechnicalStandardPrompt()
        }
        
        logger.debug("Retrieved technical standard prompt for language: \(language)")
        return template
    }
    

    
    // MARK: - Private Helper Methods
    
    /// Gets language-specific prompts with fallback logic
    /// - Parameter language: Language code
    /// - Returns: LanguagePrompts for the specified language
    private func getLanguagePrompts(for language: String) -> LanguagePrompts {
        // First try the requested language
        if let prompts = config.languages[language] {
            return prompts
        }
        
        // Then try the default language
        if let prompts = config.languages[config.defaultLanguage] {
            logger.info("Language '\(language)' not found, using default language '\(config.defaultLanguage)'")
            return prompts
        }
        
        // Finally fall back to fallback language
        if let prompts = config.languages[config.fallbackLanguage] {
            logger.warning("Default language '\(config.defaultLanguage)' not found, using fallback '\(config.fallbackLanguage)'")
            return prompts
        }
        
        // Last resort: return empty prompts
        logger.error("No language prompts found for any language")
        return LanguagePrompts()
    }
    
    // MARK: - Fallback Prompts
    
    private func getFallbackStructureAnalysisPrompt(
        documentType: String,
        elementCount: Int,
        detectedLanguage: String,
        elementDescriptions: String
    ) -> String {
        return """
        Please analyze the following document structure:
        
        Document Type: \(documentType)
        Total Elements: \(elementCount)
        Detected Language: \(detectedLanguage)
        
        Elements:
        \(elementDescriptions)
        
        Please provide:
        - Document type identification
        - Main sections and subsections
        - Content organization patterns
        - Recommendations for markdown structure
        
        Return a structured analysis in markdown format.
        """
    }
    
    private func getFallbackTableOptimizationPrompt(tableContent: String) -> String {
        return """
        Please optimize the following table structure for better markdown formatting:
        
        \(tableContent)
        
        Ensure proper alignment, spacing, and markdown table syntax.
        """
    }
    
    private func getFallbackListOptimizationPrompt(listContent: String) -> String {
        return """
        Please optimize the following list structure for better markdown formatting:
        
        \(listContent)
        
        Ensure proper indentation, list markers, and hierarchy.
        """
    }
    
    private func getFallbackHeaderOptimizationPrompt(headerContent: String) -> String {
        return """
        Please optimize the following header structure for better markdown hierarchy:
        
        \(headerContent)
        
        Ensure proper header levels and consistent formatting.
        """
    }
    
    private func getFallbackTechnicalStandardPrompt() -> String {
        return """
        This is a technical standard document.
        Please ensure all technical terms, specifications, and references are preserved exactly as written,
        while improving overall structure and readability.
        """
    }
}



// MARK: - Prompt Template Factory

extension PromptTemplates {
    
    /// Creates a PromptTemplates instance from configuration
    /// - Parameter config: MDKitConfig containing prompt template settings
    /// - Returns: Configured PromptTemplates instance
    public static func create(from config: MDKitConfig) -> PromptTemplates {
        return PromptTemplates(config: config.llm.promptTemplates)
    }
}
