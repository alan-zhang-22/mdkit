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
    
    /// Generate markdown content for a single page
    /// - Parameters:
    ///   - pageElements: Array of document elements for this page
    ///   - pageNumber: Current page number
    ///   - inputFilename: Original input filename for metadata
    ///   - isFirstPage: Whether this is the first page (to include front matter)
    ///   - totalPages: Total number of pages in the document
    /// - Returns: Generated markdown string for this page
    /// - Throws: MarkdownGenerationError if generation fails
    public func generateMarkdownForPage(
        from pageElements: [DocumentElement],
        pageNumber: Int,
        inputFilename: String?,
        isFirstPage: Bool,
        totalPages: Int
    ) throws -> String {
        
        guard !pageElements.isEmpty else {
            // Return empty string for pages with no content
            return ""
        }
        
        logger.info("Generating markdown for page \(pageNumber) with \(pageElements.count) elements")
        
        var markdownLines: [String] = []
        
        // Add front matter only for the first page
        if isFirstPage {
            // Extract meaningful title from first page elements
            let meaningfulTitle = extractDocumentTitle(from: pageElements) ?? "Document Processing Results"
            
            // Add YAML front matter
            markdownLines.append("---")
            markdownLines.append("title: \(meaningfulTitle)")
            if let inputFilename = inputFilename {
                markdownLines.append("source_file: \(inputFilename)")
            }
            markdownLines.append("generated: \(Date().formatted())")
            markdownLines.append("total_pages: \(totalPages)")
            markdownLines.append("document_type: PDF")
            markdownLines.append("processing_tool: MDKit")
            markdownLines.append("version: 1.0")
            markdownLines.append("---")
            markdownLines.append("")
        }
        
        // Sort elements by position (top to bottom, left to right)
        let sortedElements = sortElementsByPosition(pageElements)
        
        // Check if this page is a TOC page and convert headers to TOC items if needed
        let elementsWithTOCConversion = convertHeadersToTOCItemsIfNeeded(sortedElements)
        
        // Process each element
        for (index, element) in elementsWithTOCConversion.enumerated() {
            do {
                let elementMarkdown = try generateMarkdownForElement(element, at: index, in: elementsWithTOCConversion)
                if !elementMarkdown.isEmpty {
                    markdownLines.append(elementMarkdown)
                    
                    // Add spacing between elements, but not between consecutive TOC items
                    if index < elementsWithTOCConversion.count - 1 {
                        let nextElement = elementsWithTOCConversion[index + 1]
                        let isCurrentTOC = element.type == .tocItem
                        let isNextTOC = nextElement.type == .tocItem
                        
                        // Only add blank line if not between two TOC items
                        if !(isCurrentTOC && isNextTOC) {
                            markdownLines.append("")
                        }
                    }
                }
            } catch {
                logger.warning("Failed to generate markdown for element \(index): \(error.localizedDescription)")
                // Continue with other elements
            }
        }
        
        return markdownLines.joined(separator: "\n")
    }
    
    // MARK: - Private Methods
    
    /// Generate markdown for a single document element
    private func generateMarkdownForElement(_ element: DocumentElement, at index: Int, in elements: [DocumentElement]) throws -> String {
        guard let text = element.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Skipping element with no text content: \(element.type)")
            return ""
        }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add detailed logging to track element types during markdown generation
        logger.debug("🔍 MARKDOWN GENERATION - Element \(index): type=\(element.type), text='\(trimmedText.prefix(50))...'")
        
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
            
        case .tocItem:
            return generateTOCItemMarkdown(trimmedText, element: element)
            
        case .unknown:
            logger.warning("Unknown element type encountered, treating as paragraph: \(trimmedText)")
            return generateParagraphMarkdown(trimmedText, element: element)
        }
    }
    
    // MARK: - Element-Specific Markdown Generation
    
    /// Generate markdown for title elements
    private func generateTitleMarkdown(_ text: String, element: DocumentElement) -> String {
        let anchorId = generateAnchorId(from: text)
        return "# \(text) {#\(anchorId)}"
    }
    
    /// Generate markdown for header elements with level calculation
    private func generateHeaderMarkdown(_ text: String, element: DocumentElement, in elements: [DocumentElement]) -> String {
        // Always recalculate header level based on numbering pattern for proper hierarchy
        let level = calculateHeaderLevelFromNumbering(text)
        
        // Debug logging to see what's happening
        logger.debug("Calculated header level: \(level) for '\(text)'")
        
        let prefix = String(repeating: "#", count: level)
        let anchorId = generateAnchorId(from: text)
        return "\(prefix) \(text) {#\(anchorId)}"
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
    
    /// Generate markdown for TOC item elements
    private func generateTOCItemMarkdown(_ text: String, element: DocumentElement) -> String {
        // Clean up the TOC text by removing page numbers and ellipsis
        let cleanedText = text
            .replacingOccurrences(of: "⋯", with: "")
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "：", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Generate anchor ID for the TOC item
        let anchorId = generateAnchorId(from: cleanedText)
        
        // Format as TOC list item with link
        return "- [\(cleanedText)](#\(anchorId))"
    }
    
    // MARK: - Helper Methods
    
    /// Calculate header level based on numbering pattern (e.g., "6.1.1.3" = level 4)
    private func calculateHeaderLevelFromNumbering(_ text: String) -> Int {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract the header marker (numbering part)
        let marker = extractHeaderMarkerFromText(trimmedText)
        
        // Calculate level based on the number of dots in the marker
        let components = marker.components(separatedBy: ".")
        let filteredComponents = components.filter { !$0.isEmpty }
        
        // Ensure level is at least 1 and at most 6
        let calculatedLevel = max(1, min(filteredComponents.count, 6))
        
        return calculatedLevel
    }
    
    /// Extract header marker from text (e.g., "6.1.1.3 防雷击" -> "6.1.1.3")
    private func extractHeaderMarkerFromText(_ text: String) -> String {
        // Pattern to match numbered headers: digits followed by optional dots and digits
        let pattern = "^\\d+(?:\\.\\d+)*"
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                return String(text[Range(match.range, in: text)!])
            }
        }
        
        // Fallback: return text up to first space
        if let spaceIndex = text.firstIndex(of: " ") {
            return String(text[..<spaceIndex])
        }
        
        return text
    }
    
    /// Calculate header level based on position and content (legacy method)
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
    

    
    /// Generate anchor ID from header text (markdown-friendly)
    private func generateAnchorId(from text: String) -> String {
        // Remove special characters and replace spaces with hyphens
        let cleaned = text
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "⋯", with: "")
            .replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "：", with: "")
            .replacingOccurrences(of: "：", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .lowercased()
        
        return cleaned
    }
    
    /// Extract meaningful document title from the first page elements
    private func extractDocumentTitle(from elements: [DocumentElement]) -> String? {
        // Get elements from the first page
        let firstPageElements = elements.filter { $0.pageNumber == 1 }
        
        // Look for title elements first
        if let titleElement = firstPageElements.first(where: { $0.type == .title }),
           let titleText = titleElement.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !titleText.isEmpty {
            return titleText
        }
        
        // Look for header elements on the first page (likely document title)
        let headerElements = firstPageElements.filter { $0.type == .header }
        
        // Find the highest header (lowest Y position = top of page)
        if let topHeader = headerElements.min(by: { $0.boundingBox.minY < $1.boundingBox.minY }),
           let headerText = topHeader.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !headerText.isEmpty {
            return headerText
        }
        
        // Look for the first significant text element (likely document title)
        let sortedFirstPageElements = firstPageElements.sorted { $0.boundingBox.minY < $1.boundingBox.minY }
        
        for element in sortedFirstPageElements {
            if let text = element.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty,
               text.count > 5, // Avoid very short text
               text.count < 100 { // Avoid very long text
                return text
            }
        }
        
        return nil
    }
    
    /// Convert headers to TOC items if the page is detected as a TOC page
    private func convertHeadersToTOCItemsIfNeeded(_ elements: [DocumentElement]) -> [DocumentElement] {
        // Group elements by page
        let elementsByPage = Dictionary(grouping: elements) { $0.pageNumber }
        let sortedPages = elementsByPage.keys.sorted()
        
        var convertedElements: [DocumentElement] = []
        
        for pageNumber in sortedPages {
            let pageElements = elementsByPage[pageNumber] ?? []
            
            // Check if this page is a TOC page (high header ratio)
            let headerCount = pageElements.filter { $0.type == .header }.count
            let totalElements = pageElements.count
            let headerRatio = totalElements > 0 ? Float(headerCount) / Float(totalElements) : 0.0
            
            let isTOCPage = headerRatio >= 0.9 && totalElements >= 3
            
            logger.debug("🔍 TOC CONVERSION: Page \(pageNumber) - headerCount: \(headerCount), totalElements: \(totalElements), headerRatio: \(String(format: "%.1f", headerRatio * 100))%, isTOCPage: \(isTOCPage)")
            
            if isTOCPage {
                logger.info("Page \(pageNumber) detected as TOC page (header ratio: \(String(format: "%.1f", headerRatio * 100))%) - converting headers to TOC items")
                
                // First, apply missing header number fix to headers on this page
                let fixedHeaders = fixMissingHeaderNumbers(pageElements)
                
                // Convert headers to TOC items for this page
                for element in fixedHeaders {
                    if element.type == .header {
                        // Create a new element with TOC item type
                        let tocElement = DocumentElement(
                            type: .tocItem,
                            boundingBox: element.boundingBox,
                            contentData: element.contentData,
                            confidence: element.confidence,
                            pageNumber: element.pageNumber,
                            text: element.text,
                            metadata: element.metadata,
                            headerLevel: element.headerLevel
                        )
                        convertedElements.append(tocElement)
                    } else {
                        convertedElements.append(element)
                    }
                }
            } else {
                // Keep elements as they are for non-TOC pages
                convertedElements.append(contentsOf: pageElements)
            }
        }
        
        return convertedElements
    }
    
    /// Fixes missing header numbers in TOC pages by analyzing context
    private func fixMissingHeaderNumbers(_ elements: [DocumentElement]) -> [DocumentElement] {
        var fixedElements = elements
        
        for i in 0..<fixedElements.count {
            let currentElement = fixedElements[i]
            
            // Only process header elements
            guard currentElement.type == .header, let currentText = currentElement.text else { continue }
            
            // Check if current element is missing a header number (doesn't start with a number)
            if !currentText.matches(pattern: "^\\d+(\\.\\d+)*\\s") {
                // Look for the expected header number based on surrounding context
                if let expectedNumber = predictMissingHeaderNumber(at: i, in: fixedElements) {
                    let fixedText = "\(expectedNumber) \(currentText)"
                    logger.info("Fixed missing header number: '\(currentText)' → '\(fixedText)'")
                    
                    fixedElements[i] = DocumentElement(
                        id: currentElement.id,
                        type: currentElement.type,
                        boundingBox: currentElement.boundingBox,
                        contentData: currentElement.contentData,
                        confidence: currentElement.confidence,
                        pageNumber: currentElement.pageNumber,
                        text: fixedText,
                        metadata: currentElement.metadata,
                        headerLevel: currentElement.headerLevel
                    )
                }
            }
        }
        
        return fixedElements
    }
    
    /// Predicts the missing header number based on surrounding context
    private func predictMissingHeaderNumber(at index: Int, in elements: [DocumentElement]) -> String? {
        // Look at previous and next header elements to determine the pattern
        var previousNumber: String?
        var nextNumber: String?
        
        // Find the previous header with a number
        for i in (0..<index).reversed() {
            if let element = elements[safe: i], 
               element.type == .header, 
               let text = element.text,
               let number = extractHeaderNumber(from: text) {
                previousNumber = number
                break
            }
        }
        
        // Find the next header with a number
        for i in (index + 1)..<elements.count {
            if let element = elements[safe: i], 
               element.type == .header, 
               let text = element.text,
               let number = extractHeaderNumber(from: text) {
                nextNumber = number
                break
            }
        }
        
        // Predict the missing number based on context
        if let prev = previousNumber, let next = nextNumber {
            return predictNumberBetween(prev, next)
        } else if let prev = previousNumber {
            return predictNextNumber(prev)
        } else if let next = nextNumber {
            return predictPreviousNumber(next)
        }
        
        return nil
    }
    
    /// Extracts header number from text (e.g., "5.1 等级保护对象" → "5.1")
    private func extractHeaderNumber(from text: String) -> String? {
        let pattern = "^(\\d+(\\.\\d+)*)\\s"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        
        let numberRange = Range(match.range(at: 1), in: text)!
        return String(text[numberRange])
    }
    
    /// Predicts the number between two given numbers
    private func predictNumberBetween(_ prev: String, _ next: String) -> String? {
        // Handle simple increment (e.g., "5.1" → "5.2" → "5.3")
        if let prevBase = extractBaseNumber(prev),
           let nextBase = extractBaseNumber(next),
           prevBase == nextBase,
           let prevSuffix = extractSuffix(prev),
           let nextSuffix = extractSuffix(next),
           let prevSuffixInt = Int(prevSuffix),
           let nextSuffixInt = Int(nextSuffix),
           nextSuffixInt == prevSuffixInt + 1 {
            return "\(prevBase).\(prevSuffixInt + 1)"
        }
        
        return nil
    }
    
    /// Predicts the next number in sequence
    private func predictNextNumber(_ current: String) -> String? {
        if let base = extractBaseNumber(current),
           let suffix = extractSuffix(current),
           let suffixInt = Int(suffix) {
            return "\(base).\(suffixInt + 1)"
        }
        return nil
    }
    
    /// Predicts the previous number in sequence
    private func predictPreviousNumber(_ current: String) -> String? {
        if let base = extractBaseNumber(current),
           let suffix = extractSuffix(current),
           let suffixInt = Int(suffix),
           suffixInt > 1 {
            return "\(base).\(suffixInt - 1)"
        }
        return nil
    }
    
    /// Extracts base number (e.g., "5.1" → "5")
    private func extractBaseNumber(_ number: String) -> String? {
        let components = number.components(separatedBy: ".")
        return components.first
    }
    
    /// Extracts suffix number (e.g., "5.1" → "1")
    private func extractSuffix(_ number: String) -> String? {
        let components = number.components(separatedBy: ".")
        return components.count > 1 ? components.last : nil
    }
    

}


