//
//  DocumentProcessing.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation
import CoreGraphics

// MARK: - Page Range Specification

/// Represents a page range for document processing
public enum PageRange: Equatable, Codable {
    /// Process a single page
    case single(Int)
    
    /// Process multiple specific pages
    case multiple([Int])
    
    /// Process a range of pages (inclusive)
    case range(start: Int, end: Int)
    
    /// Process all pages
    case all
    
    /// Process pages from a specific page to the end
    case from(Int)
    
    /// Process pages from the beginning to a specific page
    case to(Int)
    
    /// Parse a string representation of page range
    /// Supports formats: "5", "5,7", "5-7", "all", "5+", "-7"
    public static func parse(_ string: String, totalPages: Int) throws -> PageRange {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        
        if trimmed.lowercased() == "all" {
            return .all
        }
        
        if trimmed.hasSuffix("+") {
            let startStr = String(trimmed.dropLast())
            guard let start = Int(startStr), start >= 1, start <= totalPages else {
                throw DocumentProcessingError.invalidPageRange("Invalid 'from' page range: \(trimmed)")
            }
            return .from(start)
        }
        
        if trimmed.hasPrefix("-") {
            let endStr = String(trimmed.dropFirst())
            guard let end = Int(endStr), end >= 1, end <= totalPages else {
                throw DocumentProcessingError.invalidPageRange("Invalid 'to' page range: \(trimmed)")
            }
            return .to(end)
        }
        
        if trimmed.contains("-") {
            let components = trimmed.components(separatedBy: "-")
            guard components.count == 2,
                  let start = Int(components[0].trimmingCharacters(in: .whitespaces)),
                  let end = Int(components[1].trimmingCharacters(in: .whitespaces)) else {
                throw DocumentProcessingError.invalidPageRange("Invalid range format: \(trimmed)")
            }
            
            guard start >= 1 && end <= totalPages && start <= end else {
                throw DocumentProcessingError.invalidPageRange("Page range \(start)-\(end) is invalid for document with \(totalPages) pages")
            }
            
            return .range(start: start, end: end)
        }
        
        if trimmed.contains(",") {
            let components = trimmed.components(separatedBy: ",")
            var pages: [Int] = []
            
            for component in components {
                let pageStr = component.trimmingCharacters(in: .whitespaces)
                guard let page = Int(pageStr), page >= 1, page <= totalPages else {
                    throw DocumentProcessingError.invalidPageRange("Invalid page number: \(pageStr)")
                }
                pages.append(page)
            }
            
            return .multiple(pages.sorted())
        }
        
        // Single page
        guard let page = Int(trimmed), page >= 1, page <= totalPages else {
            throw DocumentProcessingError.invalidPageRange("Invalid page number: \(trimmed)")
        }
        
        return .single(page)
    }
    
    /// Get all page numbers that should be processed
    public func getPageNumbers(totalPages: Int) -> [Int] {
        switch self {
        case .single(let page):
            return [page]
        case .multiple(let pages):
            return pages.sorted()
        case .range(let start, let end):
            return Array(start...end)
        case .all:
            return Array(1...totalPages)
        case .from(let start):
            return Array(start...totalPages)
        case .to(let end):
            return Array(1...end)
        }
    }
    
    /// Get a human-readable description of the page range
    public var description: String {
        switch self {
        case .single(let page):
            return "page \(page)"
        case .multiple(let pages):
            return "pages \(pages.sorted().map(String.init).joined(separator: ", "))"
        case .range(let start, let end):
            return "pages \(start)-\(end)"
        case .all:
            return "all pages"
        case .from(let start):
            return "pages \(start)+"
        case .to(let end):
            return "pages -\(end)"
        }
    }
}

// MARK: - Document Processing Protocol

/// Protocol defining the interface for document processing operations
public protocol DocumentProcessing {
    
    // MARK: - Core Document Processing
    
    /// Processes a document and extracts its elements
    /// - Parameter documentPath: The path to the document to process
    /// - Parameter pageRange: Optional page range specification (e.g., "5", "5,7", "5-7", "all", "5+", "-7")
    /// - Returns: An array of document elements
    /// - Throws: An error if processing fails
    func processDocument(at documentPath: String, pageRange: PageRange?) async throws -> [DocumentElement]
    
    /// Processes a document with default page range (all pages)
    /// - Parameter documentPath: The path to the document to process
    /// - Returns: An array of document elements
    /// - Throws: An error if processing fails
    func processDocument(at documentPath: String) async throws -> [DocumentElement]
    
    /// Processes a document from image data with page range support
    /// - Parameter imageData: The image data to process
    /// - Parameter pageNumber: The page number for this image
    /// - Parameter pageRange: Optional page range specification
    /// - Returns: An array of document elements
    /// - Throws: An error if processing fails
    func processDocument(from imageData: Data, pageNumber: Int, pageRange: PageRange?) async throws -> [DocumentElement]
    
    // MARK: - Document Analysis
    
    /// Gets information about the document (page count, format, etc.)
    /// - Parameter documentPath: The path to the document
    /// - Returns: Document information
    /// - Throws: An error if information cannot be retrieved
    func getDocumentInfo(at documentPath: String) async throws -> DocumentInfo
    
    /// Detects headers and footers in the document
    /// - Parameter elements: The document elements to analyze
    /// - Returns: A tuple containing headers and footers
    /// - Throws: An error if detection fails
    func detectHeadersAndFooters(from elements: [DocumentElement]) throws -> (headers: [DocumentElement], footers: [DocumentElement])
    
    /// Detects the primary language of the document
    /// - Parameter elements: The document elements to analyze
    /// - Returns: The detected language code (e.g., "en", "zh", "ja")
    /// - Throws: An error if language detection fails
    func detectLanguage(from elements: [DocumentElement]) throws -> String
    
    // MARK: - Element Processing
    
    /// Merges split elements (headers, list items, etc.)
    /// - Parameter elements: The document elements to merge
    /// - Parameter language: The detected document language for better merging
    /// - Returns: An array of merged elements
    /// - Throws: An error if merging fails
    func mergeSplitElements(_ elements: [DocumentElement], language: String) async throws -> [DocumentElement]
    
    /// Detects and removes duplicate elements
    /// - Parameter elements: The document elements to deduplicate
    /// - Returns: A tuple containing deduplicated elements and count of removed duplicates
    /// - Throws: An error if deduplication fails
    func removeDuplicates(from elements: [DocumentElement]) throws -> (elements: [DocumentElement], duplicatesRemoved: Int)
    
    /// Sorts elements by their position in the document
    /// - Parameter elements: The document elements to sort
    /// - Returns: An array of sorted elements
    func sortElementsByPosition(_ elements: [DocumentElement]) -> [DocumentElement]
    
    /// Sorts elements by position within a single page
    /// - Parameter elements: The document elements to sort
    /// - Returns: An array of sorted elements
    func sortElementsByPositionWithinPage(_ elements: [DocumentElement]) -> [DocumentElement]
    
    // MARK: - Output Generation
    
    /// Generates markdown from processed elements
    /// - Parameter elements: The processed document elements
    /// - Returns: The generated markdown string
    /// - Throws: An error if markdown generation fails
    func generateMarkdown(from elements: [DocumentElement]) throws -> String
    
    /// Generates a table of contents from document elements
    /// - Parameter elements: The document elements to analyze
    /// - Returns: The generated table of contents as markdown
    /// - Throws: An error if TOC generation fails
    func generateTableOfContents(from elements: [DocumentElement]) throws -> String
    

}

// MARK: - Document Information

/// Information about a document
public struct DocumentInfo: Codable, Equatable {
    /// The total number of pages in the document
    public let pageCount: Int
    
    /// The document format (e.g., "PDF", "Image", "Text")
    public let format: String
    
    /// The file size in bytes
    public let fileSize: Int64
    
    /// The document creation date (if available)
    public let creationDate: Date?
    
    /// The document modification date (if available)
    public let modificationDate: Date?
    
    /// Additional metadata about the document
    public let metadata: [String: String]
    
    public init(
        pageCount: Int,
        format: String,
        fileSize: Int64,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.pageCount = pageCount
        self.format = format
        self.fileSize = fileSize
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.metadata = metadata
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
    case invalidPageRange(String)
    case languageDetectionFailed(String)
    case configurationError(String)
    case documentLoadFailed(String)
    case pageNotFound(String)
    case imageProcessingFailed(String)
    
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
        case .invalidPageRange(let reason):
            return "Invalid page range: \(reason)"
        case .languageDetectionFailed(let reason):
            return "Language detection failed: \(reason)"
                case .configurationError(let reason):
            return "Configuration error: \(reason)"
        case .documentLoadFailed(let reason):
            return "Document load failed: \(reason)"
        case .pageNotFound(let reason):
            return "Page not found: \(reason)"
        case .imageProcessingFailed(let reason):
            return "Image processing failed: \(reason)"
    }
    }
}
