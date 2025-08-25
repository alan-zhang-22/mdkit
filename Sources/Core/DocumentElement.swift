//
//  DocumentElement.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation
import CoreGraphics

/// Represents a single element extracted from a document using Apple's Vision framework
public struct DocumentElement: Identifiable, Codable, Equatable {
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
public enum ElementType: String, CaseIterable, Codable {
    /// Document title or main heading
    case title = "title"
    
    /// Text block or paragraph
    case textBlock = "textBlock"
    
    /// Individual paragraph
    case paragraph = "paragraph"
    
    /// Section header or subheading
    case header = "header"
    
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
        case .title, .textBlock, .paragraph, .header, .listItem, .footnote, .pageNumber:
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
        case .title, .header, .table, .list, .barcode, .image, .footnote, .pageNumber, .unknown:
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
    public func canMerge(with other: DocumentElement) -> Bool {
        guard type == other.type && type.isMergeable else { return false }
        guard pageNumber == other.pageNumber else { return false }
        return mergeDistance(to: other) <= 50.0 // 50 points threshold
    }
}

// MARK: - Comparable Conformance

extension DocumentElement: Comparable {
    /// Compare elements by position (top to bottom, left to right)
    public static func < (lhs: DocumentElement, rhs: DocumentElement) -> Bool {
        // First by page number
        if lhs.pageNumber != rhs.pageNumber {
            return lhs.pageNumber < rhs.pageNumber
        }
        
        // Then by Y position (top to bottom)
        if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 5.0 {
            return lhs.boundingBox.minY < rhs.boundingBox.minY
        }
        
        // Finally by X position (left to right)
        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }
}
