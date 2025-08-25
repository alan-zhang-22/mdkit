//
//  MockDocumentProcessor.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation
import CoreGraphics

// MARK: - Mock Document Processor

/// Mock implementation of DocumentProcessing for testing purposes
public class MockDocumentProcessor: DocumentProcessing {
    
    // MARK: - Properties
    
    /// Mock document elements to return
    public var mockElements: [DocumentElement] = []
    
    /// Whether to simulate errors
    public var shouldSimulateError: Bool = false
    
    /// The error to throw when simulating errors
    public var mockError: Error = DocumentProcessingError.processingFailed("Mock error")
    
    /// Tracks processing operations
    public private(set) var processingHistory: [ProcessingOperation] = []
    
    /// Custom processing results for specific document paths
    public var customResults: [String: [DocumentElement]] = [:]
    
    /// Custom markdown outputs for specific element sets
    public var customMarkdownOutputs: [String: String] = [:]
    
    // MARK: - Processing Operation Tracking
    
    public struct ProcessingOperation {
        let type: String
        let documentPath: String?
        let elementCount: Int
        let timestamp: Date
        
        init(type: String, documentPath: String? = nil, elementCount: Int = 0) {
            self.type = type
            self.documentPath = documentPath
            self.elementCount = elementCount
            self.timestamp = Date()
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(mockElements: [DocumentElement]) {
        self.mockElements = mockElements
    }
    
    // MARK: - DocumentProcessing Implementation
    
    public func processDocument(at documentPath: String) async throws -> [DocumentElement] {
        if shouldSimulateError {
            throw mockError
        }
        
        let elements = customResults[documentPath] ?? mockElements
        processingHistory.append(ProcessingOperation(
            type: "processDocument",
            documentPath: documentPath,
            elementCount: elements.count
        ))
        
        return elements
    }
    
    public func detectHeadersAndFooters(from elements: [DocumentElement]) throws -> (headers: [DocumentElement], footers: [DocumentElement]) {
        if shouldSimulateError {
            throw mockError
        }
        
        let headers = elements.filter { $0.type == .header }
        let footers = elements.filter { $0.type == .footnote }
        
        processingHistory.append(ProcessingOperation(
            type: "detectHeadersAndFooters",
            elementCount: elements.count
        ))
        
        return (headers: headers, footers: footers)
    }
    
    public func mergeSplitElements(_ elements: [DocumentElement]) throws -> [DocumentElement] {
        if shouldSimulateError {
            throw mockError
        }
        
        // Simple mock implementation - just return the elements as-is
        let mergedElements = elements
        
        processingHistory.append(ProcessingOperation(
            type: "mergeSplitElements",
            elementCount: elements.count
        ))
        
        return mergedElements
    }
    
    public func removeDuplicates(from elements: [DocumentElement]) throws -> [DocumentElement] {
        if shouldSimulateError {
            throw mockError
        }
        
        // Simple mock implementation - remove exact duplicates
        let uniqueElements = Array(Set(elements))
        
        processingHistory.append(ProcessingOperation(
            type: "removeDuplicates",
            elementCount: elements.count
        ))
        
        return uniqueElements
    }
    
    public func sortElementsByPosition(_ elements: [DocumentElement]) -> [DocumentElement] {
        // Sort by page number first, then by Y position
        let sortedElements = elements.sorted { element1, element2 in
            if element1.pageNumber != element2.pageNumber {
                return element1.pageNumber < element2.pageNumber
            }
            return element1.boundingBox.minY < element2.boundingBox.minY
        }
        
        processingHistory.append(ProcessingOperation(
            type: "sortElementsByPosition",
            elementCount: elements.count
        ))
        
        return sortedElements
    }
    
    public func generateMarkdown(from elements: [DocumentElement]) throws -> String {
        if shouldSimulateError {
            throw mockError
        }
        
        // Create a hash of the elements for custom output lookup
        let elementsHash = String(elements.hashValue)
        
        // Return custom markdown if available, otherwise generate simple mock
        let markdown = customMarkdownOutputs[elementsHash] ?? generateSimpleMarkdown(from: elements)
        
        processingHistory.append(ProcessingOperation(
            type: "generateMarkdown",
            elementCount: elements.count
        ))
        
        return markdown
    }
    
    // MARK: - Private Methods
    
    private func generateSimpleMarkdown(from elements: [DocumentElement]) -> String {
        var markdown = ""
        
        for element in elements {
            switch element.type {
            case .title:
                markdown += "# \(element.content)\n\n"
            case .header:
                markdown += "## \(element.content)\n\n"
            case .paragraph:
                markdown += "\(element.content)\n\n"
            case .listItem:
                markdown += "- \(element.content)\n"
            case .list:
                markdown += "\n"
            case .table:
                markdown += "| \(element.content) |\n| --- |\n\n"
            case .image:
                markdown += "![\(element.content)]\n\n"
            case .barcode:
                markdown += "`\(element.content)`\n\n"
            case .footnote:
                markdown += "^[\(element.content)]\n\n"
            case .caption:
                markdown += "*\(element.content)*\n\n"
            case .textBlock:
                markdown += "\(element.content)\n\n"
            }
        }
        
        return markdown
    }
    
    // MARK: - Mock Configuration Methods
    
    /// Sets custom elements for a specific document path
    public func setCustomElements(_ elements: [DocumentElement], for documentPath: String) {
        customResults[documentPath] = elements
    }
    
    /// Sets custom markdown output for a specific set of elements
    public func setCustomMarkdown(_ markdown: String, for elements: [DocumentElement]) {
        let elementsHash = String(elements.hashValue)
        customMarkdownOutputs[elementsHash] = markdown
    }
    
    /// Clears all custom results and outputs
    public func clearCustomResults() {
        customResults.removeAll()
        customMarkdownOutputs.removeAll()
    }
    
    /// Resets the mock to its initial state
    public func reset() {
        mockElements.removeAll()
        processingHistory.removeAll()
        customResults.removeAll()
        customMarkdownOutputs.removeAll()
        shouldSimulateError = false
    }
    
    /// Gets all processing operations of a specific type
    public func getOperations(for type: String) -> [ProcessingOperation] {
        return processingHistory.filter { $0.type == type }
    }
    
    /// Gets the count of operations for a specific type
    public func operationCount(for type: String) -> Int {
        return getOperations(for: type).count
    }
    
    /// Verifies that a specific operation was performed
    public func performedOperation(_ type: String, on documentPath: String? = nil) -> Bool {
        return processingHistory.contains { operation in
            operation.type == type && (documentPath == nil || operation.documentPath == documentPath)
        }
    }
    
    /// Gets the last processing operation
    public func getLastOperation() -> ProcessingOperation? {
        return processingHistory.last
    }
}

// MARK: - DocumentElement Hashable Extension

extension DocumentElement: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(content)
        hasher.combine(pageNumber)
        hasher.combine(confidence)
    }
    
    public static func == (lhs: DocumentElement, rhs: DocumentElement) -> Bool {
        return lhs.type == rhs.type &&
               lhs.content == rhs.content &&
               lhs.pageNumber == rhs.pageNumber &&
               lhs.confidence == rhs.confidence
    }
}
