//
//  OutputGenerator.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/29.
//

import Foundation
import Logging
import mdkitFileManagement
import mdkitConfiguration
import mdkitProtocols

// MARK: - Output Generator Protocol

public protocol OutputGenerating: Sendable {
    func generateOutput(from elements: [DocumentElement], outputType: OutputType) throws -> String
    func generateImageOutput(from elements: [DocumentElement], imageData: Data?) throws -> Data?
}

// MARK: - Output Generator Implementation

public final class OutputGenerator: OutputGenerating {
    private let logger: Logger
    private let config: MDKitConfig
    
    public init(config: MDKitConfig) {
        self.config = config
        self.logger = Logger(label: "mdkit.outputgenerator")
    }
    
    public func generateOutput(from elements: [DocumentElement], outputType: OutputType) throws -> String {
        logger.info("Generating \(outputType.description) from \(elements.count) elements")
        
        switch outputType {
        case .ocr:
            return try generateOCROutput(from: elements)
        case .markdown:
            return try generateMarkdownOutput(from: elements)
        case .prompt:
            return try generatePromptOutput(from: elements)
        case .markdownLLM:
            return try generateLLMOptimizedMarkdown(from: elements)
        case .images:
            // For images, we return a placeholder text since the actual image data
            // will be handled separately via generateImageOutput
            return "# PDF Page Images\n\nImages have been saved directly to the `images/` subdirectory during PDF processing.\n\nThis output type is for reference only - the actual images are saved as PNG files."
        }
    }
    
    // MARK: - Image Output Generation
    
    public func generateImageOutput(from elements: [DocumentElement], imageData: Data?) throws -> Data? {
        // Return the provided image data if available
        if let imageData = imageData {
            logger.info("Image output generation: returning provided image data (\(imageData.count) bytes)")
            return imageData
        } else {
            logger.warning("Image output generation: no image data provided")
            return nil
        }
    }
    
    // MARK: - OCR Output Generation
    
    private func generateOCROutput(from elements: [DocumentElement]) throws -> String {
        var output = "# OCR Text Output\n\n"
        output += "Generated on: \(Date().formatted())\n"
        output += "Total elements: \(elements.count)\n\n"
        
        // Filter out common headers and footers
        let filteredElements = filterOutCommonHeadersAndFooters(elements)
        output += "Total elements after filtering: \(filteredElements.count)\n\n"
        
        // Group elements by page
        let elementsByPage = Dictionary(grouping: filteredElements) { $0.pageNumber }
        let sortedPages = elementsByPage.keys.sorted()
        
        for pageNumber in sortedPages {
            let pageElements = elementsByPage[pageNumber] ?? []
            
            // Sort elements by position (top to bottom, left to right)
            // Note: PDF coordinates have origin at bottom-left, so smaller Y = top of page
            let sortedElements = pageElements.sorted { (element1: DocumentElement, element2: DocumentElement) in
                if abs(element1.boundingBox.minY - element2.boundingBox.minY) < 0.01 {
                    // If y positions are very close, sort by x position
                    return element1.boundingBox.minX < element2.boundingBox.minX
                }
                return element1.boundingBox.minY > element2.boundingBox.minY  // Inverted for correct top-to-bottom order
            }
            
            for element in sortedElements {
                if let text = element.text, !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    output += "\(text)\n\n"
                }
            }
        }
        
        logger.info("Generated OCR output with \(filteredElements.count) elements")
        return output
    }
    
    // MARK: - Markdown Output Generation
    
    private func generateMarkdownOutput(from elements: [DocumentElement]) throws -> String {
        var output = "# Document Processing Results\n\n"
        output += "Generated on: \(Date().formatted())\n"
        output += "Total elements: \(elements.count)\n\n"
        
        // Filter out common headers and footers
        let filteredElements = filterOutCommonHeadersAndFooters(elements)
        output += "Total elements after filtering: \(filteredElements.count)\n\n"
        
        // Group elements by page
        let elementsByPage = Dictionary(grouping: filteredElements) { $0.pageNumber }
        let sortedPages = elementsByPage.keys.sorted()
        
        for pageNumber in sortedPages {
            let pageElements = elementsByPage[pageNumber] ?? []
            
            // Sort elements by position (top to bottom, left to right)
            // Note: PDF coordinates have origin at bottom-left, so smaller Y = top of page
            let sortedElements = pageElements.sorted { (element1: DocumentElement, element2: DocumentElement) in
                if abs(element1.boundingBox.minY - element2.boundingBox.minY) < 0.01 {
                    return element1.boundingBox.minX < element2.boundingBox.minX
                }
                return element1.boundingBox.minY > element2.boundingBox.minY  // Inverted for correct top-to-bottom order
            }
            
            for element in sortedElements {
                if let text = element.text, !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    switch element.type {
                    case .title:
                        output += "### \(text)\n\n"
                    case .header:
                        output += "#### \(text)\n\n"
                    case .textBlock, .paragraph:
                        output += "\(text)\n\n"
                    case .listItem:
                        output += "- \(text)\n"
                    case .table:
                        output += "**Table:** \(text)\n\n"
                    case .image:
                        output += "![Image](\(text))\n\n"
                    case .footnote:
                        output += "> Footnote: \(text)\n\n"
                    default:
                        output += "\(text)\n\n"
                    }
                }
            }
        }
        
        // Add table of contents
        if config.fileManagement.addTableOfContents {
            output += generateTableOfContents(from: filteredElements)
        }
        
        logger.info("Generated markdown output with \(filteredElements.count) elements")
        return output
    }
    
    // MARK: - Prompt Output Generation
    
    private func generatePromptOutput(from elements: [DocumentElement]) throws -> String {
        var output = "# LLM Prompt Generation\n\n"
        output += "Generated on: \(Date().formatted())\n"
        output += "Total elements: \(elements.count)\n\n"
        
        // Filter out common headers and footers
        let filteredElements = filterOutCommonHeadersAndFooters(elements)
        output += "Total elements after filtering: \(filteredElements.count)\n\n"
        
        // Group elements by page
        let elementsByPage = Dictionary(grouping: filteredElements) { $0.pageNumber }
        let sortedPages = elementsByPage.keys.sorted()
        
        for pageNumber in sortedPages {
            let pageElements = elementsByPage[pageNumber] ?? []
            output += "## Page \(pageNumber) - Content Summary\n\n"
            
            // Extract key content for prompt generation
            let textElements = pageElements.compactMap { $0.text }.filter { !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty }
            
            if !textElements.isEmpty {
                output += "### Content:\n"
                for text in textElements {
                    output += "\(text)\n"
                }
                output += "\n"
                
                // Generate prompt suggestions
                output += "### Suggested Prompts:\n"
                output += "1. **Summarize**: Please provide a concise summary of the content on page \(pageNumber).\n"
                output += "2. **Extract Key Points**: What are the main points and key information from this page?\n"
                output += "3. **Analyze**: Analyze the technical content and provide insights.\n"
                output += "4. **Translate**: Translate the content to English if it's in another language.\n"
                output += "5. **Structure**: Organize the information into a structured format.\n\n"
            }
        }
        
        // Add general prompt templates
        output += "## General Prompt Templates\n\n"
        output += "### For Document Analysis:\n"
        output += "```\nAnalyze the following document content and provide:\n"
        output += "1. A comprehensive summary\n"
        output += "2. Key technical concepts\n"
        output += "3. Important findings or conclusions\n"
        output += "4. Recommendations for further analysis\n```\n\n"
        
        output += "### For Content Extraction:\n"
        output += "```\nExtract and organize the following information:\n"
        output += "1. Main topics and subtopics\n"
        output += "2. Technical specifications\n"
        output += "3. Key data points\n"
        output += "4. Action items or requirements\n```\n\n"
        
        logger.info("Generated prompt output with \(elements.count) elements")
        return output
    }
    

    
    // MARK: - LLM-Optimized Markdown Generation
    
    private func generateLLMOptimizedMarkdown(from elements: [DocumentElement]) throws -> String {
        var output = "# LLM-Optimized Document Analysis\n\n"
        output += "Generated on: \(Date().formatted())\n"
        output += "Total elements: \(elements.count)\n"
        output += "Optimized for LLM processing\n\n"
        
        // Filter out common headers and footers
        let filteredElements = filterOutCommonHeadersAndFooters(elements)
        output += "Total elements after filtering: \(filteredElements.count)\n\n"
        
        // Group elements by page
        let elementsByPage = Dictionary(grouping: filteredElements) { $0.pageNumber }
        let sortedPages = elementsByPage.keys.sorted()
        
        for pageNumber in sortedPages {
            let pageElements = elementsByPage[pageNumber] ?? []
            
            // Sort elements by position (top to bottom, left to right)
            // Note: PDF coordinates have origin at bottom-left, so smaller Y = top of page
            let sortedElements = pageElements.sorted { (element1: DocumentElement, element2: DocumentElement) in
                if abs(element1.boundingBox.minY - element2.boundingBox.minY) < 0.01 {
                    return element1.boundingBox.minX < element2.boundingBox.minX
                }
                return element1.boundingBox.minY > element2.boundingBox.minY  // Inverted for correct top-to-bottom order
            }
            
            // Process elements with LLM optimization
            for element in sortedElements {
                if let text = element.text, !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    let optimizedText = optimizeTextForLLM(text, elementType: element.type)
                    
                    switch element.type {
                    case .title:
                        output += "### \(optimizedText)\n\n"
                    case .header:
                        output += "#### \(optimizedText)\n\n"
                    case .textBlock, .paragraph:
                        output += "\(optimizedText)\n\n"
                    case .listItem:
                        output += "- \(optimizedText)\n"
                    case .table:
                        output += "**Table Data:** \(optimizedText)\n\n"
                    case .image:
                        output += "![Image Content](\(optimizedText))\n\n"
                    case .footnote:
                        output += "> Footnote: \(optimizedText)\n\n"
                    default:
                        output += "\(optimizedText)\n\n"
                    }
                }
            }
        }
        
        // Add LLM-specific metadata and instructions
        output += "## LLM Processing Instructions\n\n"
        output += "This document has been optimized for LLM processing with the following considerations:\n"
        output += "- Text has been cleaned and normalized\n"
        output += "- Structure has been enhanced for better comprehension\n"
        output += "- Metadata has been preserved for context\n"
        output += "- Content is organized for optimal token efficiency\n\n"
        
        // Add table of contents
        if config.fileManagement.addTableOfContents {
            output += generateTableOfContents(from: filteredElements)
        }
        
        logger.info("Generated LLM-optimized markdown output with \(filteredElements.count) elements")
        return output
    }
    
    // MARK: - Helper Methods
    
    /// Filter out common headers and footers based on configuration
    private func filterOutCommonHeadersAndFooters(_ elements: [DocumentElement]) -> [DocumentElement] {
        // Header/footer filtering is now handled by TraditionalOCRDocumentProcessor during processing
        // This method is kept for backward compatibility but simply returns the elements as-is
        logger.debug("Header/footer filtering skipped - already processed by TraditionalOCRDocumentProcessor")
        return elements
    }
    
    /// Filter out elements based on their position in header and footer regions
    private func filterOutElementsByRegion(_ elements: [DocumentElement]) -> [DocumentElement] {
        // Region-based filtering is now handled by TraditionalOCRDocumentProcessor during processing
        // This method is kept for backward compatibility but simply returns the elements as-is
        logger.debug("Region-based filtering skipped - already processed by TraditionalOCRDocumentProcessor")
        return elements
    }
    

    
    private func optimizeTextForLLM(_ text: String, elementType: DocumentElementType) -> String {
        var optimized = text
        
        // Clean up common OCR artifacts
        optimized = optimized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        optimized = optimized.replacingOccurrences(of: "\\|", with: "I", options: .regularExpression) // Common OCR mistake
        optimized = optimized.replacingOccurrences(of: "0", with: "O", options: .regularExpression) // Common OCR mistake
        
        // Add context based on element type
        switch elementType {
        case .title:
            optimized = "TITLE: \(optimized)"
        case .header:
            optimized = "HEADING: \(optimized)"
        case .textBlock, .paragraph:
            optimized = "TEXT: \(optimized)"
        case .listItem:
            optimized = "LIST_ITEM: \(optimized)"
        case .table:
            optimized = "TABLE_DATA: \(optimized)"
        case .image:
            optimized = "IMAGE_DESCRIPTION: \(optimized)"
        case .footnote:
            optimized = "FOOTNOTE: \(optimized)"
        default:
            optimized = "CONTENT: \(optimized)"
        }
        
        return optimized
    }
    
    private func generateTableOfContents(from elements: [DocumentElement]) -> String {
        var toc = "## Table of Contents\n\n"
        
        let elementsByPage = Dictionary(grouping: elements) { $0.pageNumber }
        let sortedPages = elementsByPage.keys.sorted()
        
        for pageNumber in sortedPages {
            let pageElements = elementsByPage[pageNumber] ?? []
            let titles = pageElements.compactMap { element -> String? in
                guard element.type == .title || element.type == .header,
                      let text = element.text else { return nil }
                return text
            }
            
            if !titles.isEmpty {
                for (index, title) in titles.enumerated() {
                    toc += "\(index + 1). \(title)\n"
                }
                toc += "\n"
            }
        }
        
        return toc
    }
}
