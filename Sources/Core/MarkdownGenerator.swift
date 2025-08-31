import Foundation
import CoreGraphics
import Logging
import mdkitConfiguration
import mdkitProtocols

// MARK: - Markdown Generation Error

public enum MarkdownGenerationError: LocalizedError {
    case noElementsToProcess
    case invalidElementType
    case unsupportedElementType
    case generationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noElementsToProcess:
            return "No document elements to convert to markdown"
        case .invalidElementType:
            return "Invalid element type encountered during markdown generation"
        case .unsupportedElementType:
            return "Element type not yet supported for markdown generation"
        case .generationFailed(let reason):
            return "Markdown generation failed: \(reason)"
        }
    }
}

// MARK: - Markdown Generation Configuration

// Using the unified MarkdownGenerationConfig from mdkitConfiguration
public typealias MarkdownGenerationConfig = mdkitConfiguration.MarkdownGenerationConfig

// MARK: - Markdown Flavor (Deprecated)
// This enum is no longer used with the unified configuration system

// MARK: - Markdown Generator

public final class MarkdownGenerator: Sendable {
    
    // MARK: - Properties
    
    private let config: MarkdownGenerationConfig
    private let logger: Logger
    
    // Make config accessible for testing
    internal var testConfig: MarkdownGenerationConfig { config }
    
    // MARK: - Initialization
    
    public init(config: MarkdownGenerationConfig = MarkdownGenerationConfig()) {
        self.config = config
        self.logger = Logger(label: "MarkdownGenerator")
    }
    
    // MARK: - Public Interface
    
    /// Generate markdown from an array of document elements
    /// - Parameter elements: Array of processed document elements
    /// - Returns: Generated markdown string
    /// - Throws: MarkdownGenerationError if generation fails
    public func generateMarkdown(from elements: [DocumentElement]) throws -> String {
        guard !elements.isEmpty else {
            throw MarkdownGenerationError.noElementsToProcess
        }
        
        logger.info("Starting markdown generation for \(elements.count) elements")
        
        // Add document header
        var markdownLines: [String] = []
        markdownLines.append("# Document Processing Results")
        markdownLines.append("")
        markdownLines.append("Generated on: \(Date().formatted())")
        markdownLines.append("Total elements: \(elements.count)")
        markdownLines.append("")
        
        // Sort elements by page and position (top to bottom, left to right)
        let sortedElements = sortElementsByPosition(elements)
        
        // Process each element
        for (index, element) in sortedElements.enumerated() {
            let elementMarkdown = try generateMarkdownForElement(element, at: index, in: sortedElements)
            
            if !elementMarkdown.isEmpty {
                markdownLines.append(elementMarkdown)
                
                // Add spacing between elements
                if index < sortedElements.count - 1 {
                    markdownLines.append("")
                }
            }
        }
        
        // Add table of contents if enabled
        if config.addTableOfContents {
            let toc = generateTableOfContents(from: sortedElements)
            markdownLines.append("")
            markdownLines.append(toc)
        }
        
        let markdown = markdownLines.joined(separator: "\n")
        logger.info("Markdown generation completed successfully")
        
        return markdown
    }
    
    // MARK: - Private Methods
    
    /// Generate markdown for a single document element
    private func generateMarkdownForElement(_ element: DocumentElement, at index: Int, in elements: [DocumentElement]) throws -> String {
        guard let text = element.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Skipping element with no text content: \(element.type)")
            return ""
        }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch element.type {
        case .title:
            return generateTitleMarkdown(trimmedText, element: element)
            
        case .header:
            return generateHeaderMarkdown(trimmedText, element: element, in: elements)
            
        case .paragraph, .textBlock:
            return generateParagraphMarkdown(trimmedText, element: element)
            
        case .list:
            return generateListMarkdown(trimmedText, element: element)
            
        case .listItem:
            return generateListItemMarkdown(trimmedText, element: element)
            
        case .table:
            return generateTableMarkdown(trimmedText, element: element)
            
        case .footer:
            return generateFooterMarkdown(trimmedText, element: element)
            
        case .footnote:
            return generateFootnoteMarkdown(trimmedText, element: element)
            
        case .pageNumber:
            return generatePageNumberMarkdown(trimmedText, element: element)
            
        case .image:
            return generateImageMarkdown(trimmedText, element: element)
            
        case .barcode:
            return generateBarcodeMarkdown(trimmedText, element: element)
            
        case .unknown:
            logger.warning("Unknown element type encountered, treating as paragraph: \(trimmedText)")
            return generateParagraphMarkdown(trimmedText, element: element)
        }
    }
    
    // MARK: - Element-Specific Markdown Generation
    
    /// Generate markdown for title elements
    private func generateTitleMarkdown(_ text: String, element: DocumentElement) -> String {
        return "# \(text)"
    }
    
    /// Generate markdown for header elements with level calculation
    private func generateHeaderMarkdown(_ text: String, element: DocumentElement, in elements: [DocumentElement]) -> String {
        // Use the header level calculated by HeaderAndListDetector if available
        let level = element.headerLevel ?? calculateHeaderLevel(for: element, in: elements)
        
        // Debug logging to see what's happening
        if element.headerLevel != nil {
            logger.debug("Using stored header level: \(element.headerLevel!) for '\(text)'")
        } else {
            logger.debug("No stored header level, using position-based calculation: \(level) for '\(text)'")
        }
        
        let prefix = String(repeating: "#", count: level)
        return "\(prefix) \(text)"
    }
    
    /// Generate markdown for paragraph and text block elements
    private func generateParagraphMarkdown(_ text: String, element: DocumentElement) -> String {
        return text
    }
    
    /// Generate markdown for list elements
    private func generateListMarkdown(_ text: String, element: DocumentElement) -> String {
        // For now, treat lists as paragraphs
        // TODO: Implement proper list structure detection
        return text
    }
    
    /// Generate markdown for list item elements
    private func generateListItemMarkdown(_ text: String, element: DocumentElement) -> String {
        return "- \(text)"
    }
    
    /// Generate markdown for table elements
    private func generateTableMarkdown(_ text: String, element: DocumentElement) -> String {
        // For now, treat tables as code blocks
        // TODO: Implement proper table structure from Vision framework data
        return "```\n\(text)\n```"
    }
    
    /// Generate markdown for footer elements
    private func generateFooterMarkdown(_ text: String, element: DocumentElement) -> String {
        return "*\(text)*"
    }
    
    /// Generate markdown for footnote elements
    private func generateFootnoteMarkdown(_ text: String, element: DocumentElement) -> String {
        return "^[\(text)]"
    }
    
    /// Generate markdown for page number elements
    private func generatePageNumberMarkdown(_ text: String, element: DocumentElement) -> String {
        return "**Page \(text)**"
    }
    
    /// Generate markdown for image elements
    private func generateImageMarkdown(_ text: String, element: DocumentElement) -> String {
        return "![\(text)](image_\(element.id.uuidString.prefix(8)).png)"
    }
    
    /// Generate markdown for barcode elements
    private func generateBarcodeMarkdown(_ text: String, element: DocumentElement) -> String {
        return "`[Barcode: \(text)]`"
    }
    
    // MARK: - Helper Methods
    
    /// Calculate header level based on position and content
    private func calculateHeaderLevel(for element: DocumentElement, in elements: [DocumentElement]) -> Int {
        // Simple heuristic: use Y position to determine header level
        let normalizedY = element.boundingBox.minY
        
        if normalizedY < 0.1 {
            return 1 // Top of page = H1
        } else if normalizedY < 0.2 {
            return 2 // Upper section = H2
        } else if normalizedY < 0.3 {
            return 3 // Middle section = H3
        } else if normalizedY < 0.4 {
            return 4 // Lower section = H4
        } else if normalizedY < 0.5 {
            return 5 // Bottom section = H5
        } else {
            return 6 // Very bottom = H6
        }
    }
    
    /// Sort elements by page and position (top to bottom, left to right)
    private func sortElementsByPosition(_ elements: [DocumentElement]) -> [DocumentElement] {
        // Group elements by page
        let elementsByPage = Dictionary(grouping: elements) { $0.pageNumber }
        let sortedPages = elementsByPage.keys.sorted()
        
        var sortedElements: [DocumentElement] = []
        
        for pageNumber in sortedPages {
            let pageElements = elementsByPage[pageNumber] ?? []
            
            // Sort elements by position (top to bottom, left to right)
            // Note: PDF coordinates have origin at bottom-left, so smaller Y = top of page
            let sortedPageElements = pageElements.sorted { (element1: DocumentElement, element2: DocumentElement) in
                if abs(element1.boundingBox.minY - element2.boundingBox.minY) < 0.01 {
                    // If y positions are very close, sort by x position
                    return element1.boundingBox.minX < element2.boundingBox.minX
                }
                return element1.boundingBox.minY > element2.boundingBox.minY  // Inverted for correct top-to-bottom order
            }
            
            sortedElements.append(contentsOf: sortedPageElements)
        }
        
        return sortedElements
    }
    
    /// Generate table of contents from elements
    private func generateTableOfContents(from elements: [DocumentElement]) -> String {
        var toc = "## Table of Contents\n\n"
        
        let headers = elements.compactMap { element -> String? in
            guard element.type == .title || element.type == .header,
                  let text = element.text else { return nil }
            return text
        }
        
        for (index, header) in headers.enumerated() {
            toc += "\(index + 1). \(header)\n"
        }
        
        return toc
    }
}


