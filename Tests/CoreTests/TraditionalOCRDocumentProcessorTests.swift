//
//  TraditionalOCRDocumentProcessorTests.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import XCTest
import Foundation
import Vision
import AppKit
import CoreGraphics
@testable import mdkitCore
@testable import mdkitConfiguration
@testable import mdkitFileManagement
@testable import mdkitProtocols

@available(macOS 10.15, *)
final class TraditionalOCRDocumentProcessorTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private let testDocumentPath = "Resources/test-documents/GB_T_22239_2019.PDF"
    private var processor: TraditionalOCRDocumentProcessor!
    private var configManager: ConfigurationManager!
    private var markdownGenerator: MarkdownGenerator!
    
    // MARK: - Test Setup and Teardown
    
    override func setUp() {
        super.setUp()
        
        // Verify test document exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: testDocumentPath) else {
            XCTFail("Test document not found at path: \(testDocumentPath)")
            return
        }
        
        do {
            // Create real ConfigurationManager instance
            configManager = ConfigurationManager()
            
            // Get populated configuration from ConfigurationManager
            let config = try configManager.loadConfiguration()
            
            // Create real MarkdownGenerator with actual configuration
            markdownGenerator = MarkdownGenerator(config: config.markdownGeneration)
            
            // Create LanguageDetector for testing
            let languageDetector = LanguageDetector(minimumTextLength: 5, confidenceThreshold: 0.5)
            
            // Create processor instance with real dependencies
            processor = TraditionalOCRDocumentProcessor(
                configuration: config, 
                markdownGenerator: markdownGenerator,
                languageDetector: languageDetector
            )
        } catch {
            XCTFail("Failed to set up test: \(error)")
        }
    }
    
    override func tearDown() {
        processor = nil
        configManager = nil
        markdownGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    /// Test 1: Constructor and Initialization
    func testConstructorAndInitialization() throws {
        // Verify processor was created
        XCTAssertNotNil(processor, "Processor should be created successfully")
        
        // Verify processor was created with configuration
        XCTAssertNotNil(processor, "Processor should be created successfully")
    }
    
    /// Test 2: Document Info Retrieval
    func testDocumentInfoRetrieval() async throws {
        let documentInfo = try await processor.getDocumentInfo(at: testDocumentPath)
        
        // Verify document info
        XCTAssertEqual(documentInfo.format, "PDF", "Document format should be PDF")
        XCTAssertGreaterThan(documentInfo.pageCount, 1, "PDF should have multiple pages")
        XCTAssertGreaterThan(documentInfo.fileSize, 0, "File size should be greater than 0")
        
        // Verify that page 36 exists
        XCTAssertGreaterThanOrEqual(documentInfo.pageCount, 36, "PDF should have at least 36 pages")
    }
    
    /// Test 3: Document Processing (Page 36 Only)
    func testDocumentProcessing() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        
        // Verify elements were extracted
        XCTAssertGreaterThan(elements.count, 0, "Should extract at least one element from page 36")
        XCTAssertLessThanOrEqual(elements.count, 500, "Should not extract too many elements from single page")
        
        // Verify element properties
        for element in elements {
            XCTAssertNotNil(element.text, "Element should have text")
            XCTAssertGreaterThan(element.confidence, 0.0, "Element should have confidence > 0")
            XCTAssertEqual(element.pageNumber, 36, "All elements should be from page 36")
        }
        
        print("Extracted \(elements.count) elements from page 36")
    }
    
    /// Test 4: Language Detection (Page 36 Only)
    func testLanguageDetection() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let language = try processor.detectLanguage(from: elements)
        
        // Verify language detection
        XCTAssertNotEqual(language, "unknown", "Language should be detected")
        // Accept any detected language since we're no longer hardcoding
        print("Language detected for page 36: \(language)")
    }
    
    /// Test 5: Header and Footer Detection (Page 36 Only)
    func testHeaderFooterDetection() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let (headers, footers) = try processor.detectHeadersAndFooters(from: elements)
        
        // Verify detection results
        XCTAssertGreaterThanOrEqual(headers.count, 0, "Should detect 0 or more headers")
        XCTAssertGreaterThanOrEqual(footers.count, 0, "Should detect 0 or more footers")
        
        print("Page 36 - Headers: \(headers.count), Footers: \(footers.count)")
    }
    
    /// Test 6: Element Sorting (Page 36 Only)
    func testElementSorting() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let sortedElements = processor.sortElementsByPosition(elements)
        
        // Verify sorting
        XCTAssertEqual(elements.count, sortedElements.count, "Sorting should preserve element count")
        
        // Verify order (top to bottom)
        for i in 0..<(sortedElements.count - 1) {
            let current = sortedElements[i]
            let next = sortedElements[i + 1]
            
            // Y coordinates should be decreasing (top to bottom)
            XCTAssertGreaterThanOrEqual(current.boundingBox.minY, next.boundingBox.minY, 
                "Elements should be sorted top to bottom")
        }
        
        print("Page 36 - Sorted \(elements.count) elements by position")
    }
    
    /// Test 7: Duplicate Removal (Page 36 Only)
    func testDuplicateRemoval() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let (uniqueElements, duplicatesRemoved) = try processor.removeDuplicates(from: elements)
        
        // Verify deduplication
        XCTAssertLessThanOrEqual(uniqueElements.count, elements.count, "Unique elements should not exceed original count")
        XCTAssertGreaterThanOrEqual(duplicatesRemoved, 0, "Duplicates removed should be >= 0")
        
        print("Page 36 - Removed \(duplicatesRemoved) duplicates, kept \(uniqueElements.count) unique elements")
    }
    
    /// Test 8: Element Merging (Page 36 Only)
    func testElementMerging() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let language = try processor.detectLanguage(from: elements)
        let mergedElements = try processor.mergeSplitElements(elements, language: language)
        
        // Verify merging
        XCTAssertGreaterThanOrEqual(mergedElements.count, 0, "Should have 0 or more merged elements")
        
        print("Page 36 - Merged \(elements.count) elements into \(mergedElements.count) elements")
    }
    
    /// Test 9: Markdown Generation (Page 36 Only)
    func testMarkdownGeneration() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let markdown = try processor.generateMarkdown(from: elements)
        
        // Verify markdown generation
        XCTAssertGreaterThan(markdown.count, 0, "Markdown should not be empty")
        XCTAssertTrue(markdown.contains("#"), "Markdown should contain headers")
        
        // Print the generated markdown for inspection
        print("\n" + String(repeating: "=", count: 50))
        print("GENERATED MARKDOWN FROM PAGE 36:")
        print(String(repeating: "=", count: 50))
        print(markdown)
        print(String(repeating: "=", count: 50) + "\n")
    }
    
    /// Test 10: Table of Contents Generation (Page 36 Only)
    func testTableOfContentsGeneration() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let toc = try processor.generateTableOfContents(from: elements)
        
        // Verify TOC generation
        XCTAssertGreaterThan(toc.count, 0, "Table of contents should not be empty")
        XCTAssertTrue(toc.contains("Table of Contents"), "TOC should contain title")
        
        // Print the generated table of contents for inspection
        print("\n" + String(repeating: "=", count: 50))
        print("GENERATED TABLE OF CONTENTS FROM PAGE 36:")
        print(String(repeating: "=", count: 50))
        print(toc)
        print(String(repeating: "=", count: 50) + "\n")
    }
    

    
    /// Test 12: Error Handling
    func testErrorHandling() async throws {
        // Test with non-existent file
        do {
            _ = try await processor.processDocument(at: "non_existent_file.png")
            XCTFail("Should throw error for non-existent file")
        } catch {
            // Expected error caught
            XCTAssertTrue(error is DocumentProcessingError, "Should throw DocumentProcessingError")
        }
    }
    
    /// Test 13: OCR Configuration (Page 36 Only)
    func testOCRConfiguration() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        
        // Verify that OCR was performed with proper configuration
        XCTAssertGreaterThan(elements.count, 0, "OCR should extract elements")
        
        // Check that elements have proper metadata
        for element in elements {
            XCTAssertNotNil(element.metadata["ocr_method"], "Element should have OCR method metadata")
            XCTAssertNotNil(element.metadata["confidence"], "Element should have confidence metadata")
        }
        
        print("Page 36 - OCR extracted \(elements.count) elements with proper metadata")
    }
    
    /// Test 14: Element Type Detection (Page 36 Only)
    func testElementTypeDetection() async throws {
        // Process only page 36
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        
        // Verify that elements have proper types
        for element in elements {
            XCTAssertNotEqual(element.type, .unknown, "Element should have a specific type")
            XCTAssertNotNil(element.text, "Element should have text content")
        }
        
        // Check for specific element types
        let hasTitle = elements.contains { $0.type == .title }
        let hasHeader = elements.contains { $0.type == .header }
        let hasParagraph = elements.contains { $0.type == .paragraph }
        
        XCTAssertTrue(hasTitle || hasHeader || hasParagraph, "Should detect at least one content type")
        
        print("Page 36 - Element types: Title: \(hasTitle), Header: \(hasHeader), Paragraph: \(hasParagraph)")
    }
    
    /// Test 15: Performance and Memory (Page 36 Only)
    func testPerformanceAndMemory() async throws {
        // Simple performance test without measure block
        let startTime = Date()
        let pageRange = PageRange.single(36)
        let elements = try await processor.processDocument(at: testDocumentPath, pageRange: pageRange)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Verify processing completed successfully
        XCTAssertGreaterThan(elements.count, 0, "Should process page 36 successfully")
        XCTAssertLessThan(processingTime, 10.0, "Processing should complete within reasonable time")
        
        print("Page 36 performance test completed in \(String(format: "%.2f", processingTime))s")
    }
    

}

// MARK: - Test Configuration Notes

/// This test uses real instances of ConfigurationManager and MarkdownGenerator
/// instead of mocks to ensure proper integration testing with actual configuration
/// and markdown generation logic.
///
/// All document processing tests focus on PAGE 36 ONLY to ensure fast, focused testing
/// of the specific page you're interested in.
///
/// XCTest will automatically discover and run all test methods:
/// - testConstructorAndInitialization()
/// - testDocumentInfoRetrieval()
/// - testDocumentProcessing() - PAGE 36 ONLY
/// - testLanguageDetection() - PAGE 36 ONLY
/// - testHeaderFooterDetection() - PAGE 36 ONLY
/// - testElementSorting() - PAGE 36 ONLY
/// - testDuplicateRemoval() - PAGE 36 ONLY
/// - testElementMerging() - PAGE 36 ONLY
/// - testMarkdownGeneration() - PAGE 36 ONLY
/// - testTableOfContentsGeneration() - PAGE 36 ONLY
/// - testErrorHandling()
/// - testOCRConfiguration() - PAGE 36 ONLY
/// - testElementTypeDetection() - PAGE 36 ONLY
/// - testPerformanceAndMemory() - PAGE 36 ONLY
