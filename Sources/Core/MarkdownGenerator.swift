import Foundation
import CoreGraphics
import Logging

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

public struct MarkdownGenerationConfig {
    /// Markdown flavor/style to generate
    public let markdownFlavor: MarkdownFlavor
    
    /// Number of spaces for indentation
    public let indentationSpaces: Int
    
    /// Whether to add horizontal rules between sections
    public let addHorizontalRules: Bool
    
    /// Whether to preserve original element order strictly
    public let preserveOriginalOrder: Bool
    
    /// Maximum header level to generate (1-6)
    public let maxHeaderLevel: Int
    
    /// Whether to add table of contents
    public let addTableOfContents: Bool
    
    public init(
        markdownFlavor: MarkdownFlavor = .standard,
        indentationSpaces: Int = 2,
        addHorizontalRules: Bool = true,
        preserveOriginalOrder: Bool = true,
        maxHeaderLevel: Int = 6,
        addTableOfContents: Bool = false
    ) {
        self.markdownFlavor = markdownFlavor
        self.indentationSpaces = indentationSpaces
        self.addHorizontalRules = addHorizontalRules
        self.preserveOriginalOrder = preserveOriginalOrder
        self.maxHeaderLevel = max(1, min(6, maxHeaderLevel))
        self.addTableOfContents = addTableOfContents
    }
}

// MARK: - Markdown Flavor

public enum MarkdownFlavor: String, CaseIterable {
    case standard = "standard"
    case github = "github"
    case gitlab = "gitlab"
    case commonmark = "commonmark"
    
    public var description: String {
        switch self {
        case .standard:
            return "Standard Markdown"
        case .github:
            return "GitHub Flavored Markdown"
        case .gitlab:
            return "GitLab Flavored Markdown"
        case .commonmark:
            return "CommonMark"
        }
    }
}

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
        
        // Add table of contents if enabled
        if config.addTableOfContents {
            markdownLines.append(contentsOf: generateTableOfContents(from: elements))
            markdownLines.append("") // Empty line after TOC
        }
        
        // Process each element
        for (index, element) in elements.enumerated() {
            let elementMarkdown = try generateMarkdownForElement(element, at: index, in: elements)
            
            if !elementMarkdown.isEmpty {
                markdownLines.append(elementMarkdown)
                
                // Add horizontal rules between major sections if enabled
                if config.addHorizontalRules && shouldAddHorizontalRule(after: element, at: index, in: elements) {
                    markdownLines.append("---")
                }
                
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
    
    /// Determine if a horizontal rule should be added after an element
    private func shouldAddHorizontalRule(after element: DocumentElement, at index: Int, in elements: [DocumentElement]) -> Bool {
        // Add rules after major section breaks
        switch element.type {
        case .title, .header:
            return true
        case .table:
            return true
        default:
            return false
        }
    }
    
    /// Generate table of contents from document elements
    private func generateTableOfContents(from elements: [DocumentElement]) -> [String] {
        var tocLines = ["## Table of Contents", ""]
        
        for element in elements {
            switch element.type {
            case .title:
                tocLines.append("- [\(element.text ?? "Untitled")](#\(element.text?.lowercased().replacingOccurrences(of: " ", with: "-") ?? "untitled"))")
            case .header:
                let level = calculateHeaderLevel(for: element, in: elements)
                let indent = String(repeating: "  ", count: level - 1)
                tocLines.append("\(indent)- [\(element.text ?? "Header")](#\(element.text?.lowercased().replacingOccurrences(of: " ", with: "-") ?? "header"))")
            default:
                break
            }
        }
        
        return tocLines
    }
}


