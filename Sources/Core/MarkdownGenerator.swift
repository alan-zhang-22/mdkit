import Foundation
import CoreGraphics
import Logging
import mdkitConfiguration

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

public class MarkdownGenerator {
    
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
        
        var markdownLines: [String] = []
        
        // Process each element
        for (index, element) in elements.enumerated() {
            let elementMarkdown = try generateMarkdownForElement(element, at: index, in: elements)
            
            if !elementMarkdown.isEmpty {
                markdownLines.append(elementMarkdown)
                
                // Add spacing between elements
                if index < elements.count - 1 {
                    markdownLines.append("")
                }
            }
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
        let level = calculateHeaderLevel(for: element, in: elements)
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
    

}


