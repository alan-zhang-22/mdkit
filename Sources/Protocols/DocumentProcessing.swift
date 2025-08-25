//
//  DocumentProcessing.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation
import CoreGraphics

// MARK: - Document Processing Protocol

/// Protocol defining the interface for document processing operations
public protocol DocumentProcessing {
    /// Processes a document and extracts its elements
    /// - Parameter documentPath: The path to the document to process
    /// - Returns: An array of document elements
    /// - Throws: An error if processing fails
    func processDocument(at documentPath: String) async throws -> [DocumentElement]
    
    /// Detects headers and footers in the document
    /// - Parameter elements: The document elements to analyze
    /// - Returns: A tuple containing headers and footers
    /// - Throws: An error if detection fails
    func detectHeadersAndFooters(from elements: [DocumentElement]) throws -> (headers: [DocumentElement], footers: [DocumentElement])
    
    /// Merges split elements (headers, list items, etc.)
    /// - Parameter elements: The document elements to merge
    /// - Returns: An array of merged elements
    /// - Throws: An error if merging fails
    func mergeSplitElements(_ elements: [DocumentElement]) throws -> [DocumentElement]
    
    /// Detects and removes duplicate elements
    /// - Parameter elements: The document elements to deduplicate
    /// - Returns: An array of deduplicated elements
    /// - Throws: An error if deduplication fails
    func removeDuplicates(from elements: [DocumentElement]) throws -> [DocumentElement]
    
    /// Sorts elements by their position in the document
    /// - Parameter elements: The document elements to sort
    /// - Returns: An array of sorted elements
    func sortElementsByPosition(_ elements: [DocumentElement]) -> [DocumentElement]
    
    /// Generates markdown from processed elements
    /// - Parameter elements: The processed document elements
    /// - Returns: The generated markdown string
    /// - Throws: An error if markdown generation fails
    func generateMarkdown(from elements: [DocumentElement]) throws -> String
}

// MARK: - Document Element

/// Represents a single element in a document
public struct DocumentElement: Codable, Equatable {
    /// The type of the element
    public let type: ElementType
    
    /// The bounding box of the element on the page
    public let boundingBox: CGRect
    
    /// The content of the element
    public let content: String
    
    /// The confidence score for this element (0.0 to 1.0)
    public let confidence: Double
    
    /// The page number where this element appears
    public let pageNumber: Int
    
    /// Additional metadata for the element
    public let metadata: [String: String]
    
    public init(
        type: ElementType,
        boundingBox: CGRect,
        content: String,
        confidence: Double,
        pageNumber: Int,
        metadata: [String: String] = [:]
    ) {
        self.type = type
        self.boundingBox = boundingBox
        self.content = content
        self.confidence = confidence
        self.pageNumber = pageNumber
        self.metadata = metadata
    }
}

// MARK: - Element Type

public enum ElementType: String, Codable, CaseIterable {
    case title = "title"
    case textBlock = "textBlock"
    case paragraph = "paragraph"
    case header = "header"
    case table = "table"
    case list = "list"
    case listItem = "listItem"
    case image = "image"
    case barcode = "barcode"
    case footnote = "footnote"
    case caption = "caption"
    
    public var displayName: String {
        switch self {
        case .title: return "Title"
        case .textBlock: return "Text Block"
        case .paragraph: return "Paragraph"
        case .header: return "Header"
        case .table: return "Table"
        case .list: return "List"
        case .listItem: return "List Item"
        case .image: return "Image"
        case .barcode: return "Barcode"
        case .footnote: return "Footnote"
        case .caption: return "Caption"
        }
    }
}

// MARK: - Document Processing Errors

public enum DocumentProcessingError: Error, LocalizedError {
    case documentNotFound
    case unsupportedFormat
    case processingFailed(String)
    case invalidElementData
    case mergeFailed(String)
    case deduplicationFailed(String)
    case markdownGenerationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found at the specified path"
        case .unsupportedFormat:
            return "Document format is not supported"
        case .processingFailed(let reason):
            return "Document processing failed: \(reason)"
        case .invalidElementData:
            return "Invalid element data encountered"
        case .mergeFailed(let reason):
            return "Element merging failed: \(reason)"
        case .deduplicationFailed(let reason):
            return "Element deduplication failed: \(reason)"
        case .markdownGenerationFailed(let reason):
            return "Markdown generation failed: \(reason)"
        }
    }
}
