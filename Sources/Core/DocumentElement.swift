//
//  DocumentElement.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation
import CoreGraphics
import Logging
import mdkitConfiguration
import mdkitLogging

/// Represents a single element extracted from a document using Apple's Vision framework
public struct DocumentElement: Identifiable, Codable, Equatable, Sendable {
    /// Unique identifier for this element
    public let id: UUID
    
    /// Type of document element
    public let type: ElementType
    
    /// Bounding box in document coordinates
    public let boundingBox: CGRect
    
    /// Raw content from Vision framework (encoded as Data for Codable conformance)
    public let contentData: Data
    
    /// Confidence score from Vision framework (0.0 to 1.0)
    public let confidence: Float
    
    /// Page number where this element appears (1-indexed)
    public let pageNumber: Int
    
    /// Text content if this is a text-based element
    public let text: String?
    
    /// Additional metadata for the element
    public let metadata: [String: String]
    
    /// Timestamp when this element was processed
    public let processedAt: Date
    
    public init(
        id: UUID = UUID(),
        type: ElementType,
        boundingBox: CGRect,
        contentData: Data,
        confidence: Float,
        pageNumber: Int,
        text: String? = nil,
        metadata: [String: String] = [:],
        processedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.boundingBox = boundingBox
        self.contentData = contentData
        self.confidence = confidence
        self.pageNumber = pageNumber
        self.text = text
        self.metadata = metadata
        self.processedAt = processedAt
    }
}

// MARK: - ElementType Enum

/// Types of document elements that can be detected
public enum ElementType: String, CaseIterable, Codable, Sendable {
    /// Document title or main heading
    case title = "title"
    
    /// Text block or paragraph
    case textBlock = "textBlock"
    
    /// Individual paragraph
    case paragraph = "paragraph"
    
    /// Section header or subheading
    case header = "header"
    
    /// Footer content
    case footer = "footer"
    
    /// Table structure
    case table = "table"
    
    /// List container
    case list = "list"
    
    /// Individual list item
    case listItem = "listItem"
    
    /// Barcode or QR code
    case barcode = "barcode"
    
    /// Image or figure
    case image = "image"
    
    /// Footnote or annotation
    case footnote = "footnote"
    
    /// Page number
    case pageNumber = "pageNumber"
    
    /// Unknown or unclassified element
    case unknown = "unknown"
    
    /// Human-readable description of the element type
    public var description: String {
        switch self {
        case .title: return "Title"
        case .textBlock: return "Text Block"
        case .paragraph: return "Paragraph"
        case .header: return "Header"
        case .footer: return "Footer"
        case .table: return "Table"
        case .list: return "List"
        case .listItem: return "List Item"
        case .barcode: return "Barcode"
        case .image: return "Image"
        case .footnote: return "Footnote"
        case .pageNumber: return "Page Number"
        case .unknown: return "Unknown"
        }
    }
    
    /// Whether this element type contains text content
    public var isTextBased: Bool {
        switch self {
        case .title, .textBlock, .paragraph, .header, .footer, .listItem, .footnote, .pageNumber:
            return true
        case .table, .list, .barcode, .image, .unknown:
            return false
        }
    }
    
    /// Whether this element type can be merged with others of the same type
    public var isMergeable: Bool {
        switch self {
        case .textBlock, .paragraph, .listItem:
            return true
        case .title, .header, .footer, .table, .list, .barcode, .image, .footnote, .pageNumber, .unknown:
            return false
        }
    }
}

// MARK: - DocumentElement Extensions

extension DocumentElement {
    /// Creates a new element with updated properties
    public func updating(
        type: ElementType? = nil,
        boundingBox: CGRect? = nil,
        contentData: Data? = nil,
        confidence: Float? = nil,
        pageNumber: Int? = nil,
        text: String? = nil,
        metadata: [String: String]? = nil
    ) -> DocumentElement {
        return DocumentElement(
            id: self.id,
            type: type ?? self.type,
            boundingBox: boundingBox ?? self.boundingBox,
            contentData: contentData ?? self.contentData,
            confidence: confidence ?? self.confidence,
            pageNumber: pageNumber ?? self.pageNumber,
            text: text ?? self.text,
            metadata: metadata ?? self.metadata,
            processedAt: self.processedAt
        )
    }
    
    /// Whether this element overlaps with another element
    public func overlaps(with other: DocumentElement, threshold: Float = 0.1) -> Bool {
        return boundingBox.overlaps(with: other.boundingBox, threshold: threshold)
    }
    
    /// Distance to another element for merging purposes
    public func mergeDistance(to other: DocumentElement) -> Float {
        return boundingBox.mergeDistance(to: other.boundingBox)
    }
    
    /// Whether this element can be merged with another
    public func canMerge(with other: DocumentElement, config: mdkitConfiguration.ProcessingConfig? = nil) -> Bool {
        // Both elements must be mergeable types
        guard type.isMergeable && other.type.isMergeable else { 
            Logger(label: "DocumentElement").info("🔍 CANMERGE: ❌ Type mismatch - \(type) vs \(other.type)")
            return false 
        }
        
        // Elements must be on the same page
        guard pageNumber == other.pageNumber else { 
            Logger(label: "DocumentElement").info("🔍 CANMERGE: ❌ Different pages - \(pageNumber) vs \(other.pageNumber)")
            return false 
        }
        
        let logger = Logger(label: "DocumentElement")
        logger.info("🔍 CANMERGE: Checking merge between:")
        logger.info("   📝 Element 1: '\(text ?? "nil")' (Type: \(type))")
        logger.info("   📝 Element 2: '\(other.text ?? "nil")' (Type: \(other.type))")
        
        // RULE 1: Same line merging - ALWAYS merge regardless of distance
        // Use a tighter tolerance to prevent incorrect same-line detection
        let isSameLine = boundingBox.isVerticallyAligned(with: other.boundingBox, tolerance: 0.005) // Same line (0.5% tolerance)
        
        if isSameLine {
            logger.info("🔍 CANMERGE: ✅ RULE 1 - Same line elements, ALWAYS merge")
            return true
        }
        
        logger.info("🔍 CANMERGE: ❌ Not same line, checking RULE 2...")
        
        // RULE 2: Cross-line merging - only for incomplete paragraphs + non-headers
        // Check if current element is a paragraph that doesn't end with full stop
        let isIncompleteParagraph = isIncompleteParagraph()
        let nextElementIsNotHeader = !other.isHeaderElement()
        
        logger.info("🔍 CANMERGE: RULE 2 checks:")
        logger.info("   📝 Is incomplete paragraph: \(isIncompleteParagraph)")
        logger.info("   📝 Next element is not header: \(nextElementIsNotHeader)")
        
        if isIncompleteParagraph && nextElementIsNotHeader {
            // Calculate vertical distance for cross-line merging
            let verticalDistance = abs(boundingBox.maxY - other.boundingBox.minY)
            let documentHeight = 792.0 // Standard PDF page height
            let normalizedVerticalDistance = Float(verticalDistance / documentHeight)
            
            logger.info("🔍 CANMERGE: RULE 2 - Cross-line merging:")
            logger.info("   📏 Vertical distance: \(verticalDistance)px")
            logger.info("   📏 Normalized distance: \(normalizedVerticalDistance)")
            logger.info("   📏 Threshold: 0.05")
            
            // Allow cross-line merging if elements are reasonably close
            let canMergeCrossLine = normalizedVerticalDistance <= 0.05
            logger.info("🔍 CANMERGE: RULE 2 result: \(canMergeCrossLine ? "✅ ALLOW" : "❌ DENY")")
            return canMergeCrossLine
        }
        
        logger.info("🔍 CANMERGE: ❌ No rules satisfied, cannot merge")
        // No other merging scenarios allowed
        return false
    }
    
    /// Checks if this element is an incomplete paragraph (doesn't end with full stop)
    private func isIncompleteParagraph() -> Bool {
        guard let text = self.text, !text.isEmpty else { return false }
        
        // Check if text ends with Chinese or English full stop symbols
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Chinese full stops: 。，；：！？
        // English full stops: .,;:!?
        let fullStopSymbols = ["。", "，", "；", "：", "！", "？", ".", ",", ";", ":", "!", "?"]
        
        return !fullStopSymbols.contains { trimmedText.hasSuffix($0) }
    }
    
    /// Checks if this element is a header element
    private func isHeaderElement() -> Bool {
        // Check if element type is header
        if type == .title || type == .header { // Changed from .heading to .header
            return true
        }
        
        // Check if text content looks like a header
        guard let text = self.text, !text.isEmpty else { return false }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern for Chinese section headers: "8.1.4.2 访问控制"
        let headerPattern = #"^\d+\.?\d*\.?\d*\s+[^\s]+$"#
        if trimmedText.range(of: headerPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Pattern for numbered lists: "a)", "b)", "1)", "2)", etc.
        let listPattern = #"^[a-zA-Z0-9]+\)"#
        if trimmedText.range(of: listPattern, options: .regularExpression) != nil {
            return true
        }
        
        return false
    }
    
    /// Checks if this element starts a list item
    private func isListStart() -> Bool {
        guard let text = self.text, !text.isEmpty else { return false }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern for standalone list items: "a)", "b)", "c)", "1)", "2)", "3)", etc.
        // These should be at the beginning of the text with minimal content
        let standaloneListPattern = #"^[a-zA-Z0-9]+\)\s*$"#
        if trimmedText.range(of: standaloneListPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Pattern for Chinese standalone list items: "a）", "b）", "1）", "2）", etc.
        let chineseStandaloneListPattern = #"^[a-zA-Z0-9]+）\s*$"#
        if trimmedText.range(of: chineseStandaloneListPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Pattern for list items with minimal content: "a) text", "b) text", "1) text", etc.
        // But only if the text after the marker is very short (less than 10 characters)
        let shortListPattern = #"^[a-zA-Z0-9]+\)\s*[^\s]{1,10}$"#
        if trimmedText.range(of: shortListPattern, options: .regularExpression) != nil {
            return true
        }
        
        // Pattern for Chinese list items with minimal content: "a）text", "b）text", "1）text", etc.
        // But only if the text after the marker is very short (less than 10 characters)
        let chineseShortListPattern = #"^[a-zA-Z0-9]+）\s*[^\s]{1,10}$"#
        if trimmedText.range(of: chineseShortListPattern, options: .regularExpression) != nil {
            return true
        }
        
        // If the text is longer and contains substantial content after the marker,
        // it's likely not a list item but regular text that happens to start with a marker
        return false
    }
}

// MARK: - Comparable Conformance

extension DocumentElement: Comparable {
    /// Compare elements by position (top to bottom, left to right) - CORRECT for merge order
    public static func < (lhs: DocumentElement, rhs: DocumentElement) -> Bool {
        // First by page number
        if lhs.pageNumber != rhs.pageNumber {
            return lhs.pageNumber < rhs.pageNumber
        }
        
        // Then by Y position (top to bottom) - REVERSED for correct processing order
        if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 5.0 {
            return lhs.boundingBox.minY > rhs.boundingBox.minY
        }
        
        // Finally by X position (left to right)
        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}
