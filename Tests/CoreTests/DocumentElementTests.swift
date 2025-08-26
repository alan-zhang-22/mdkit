//
//  DocumentElementTests.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import XCTest
import CoreGraphics
@testable import mdkitCore

final class DocumentElementTests: XCTestCase {
    
    // MARK: - Test Data
    
    let sampleBoundingBox = CGRect(x: 100, y: 200, width: 300, height: 50)
    let sampleContentData = "Sample text content".data(using: .utf8)!
    
    // MARK: - ElementType Tests
    
    func testElementTypeCases() {
        // Test that all cases are accessible
        XCTAssertEqual(ElementType.allCases.count, 13)
        XCTAssertTrue(ElementType.allCases.contains(.title))
        XCTAssertTrue(ElementType.allCases.contains(.textBlock))
        XCTAssertTrue(ElementType.allCases.contains(.paragraph))
        XCTAssertTrue(ElementType.allCases.contains(.header))
        XCTAssertTrue(ElementType.allCases.contains(.footer))
        XCTAssertTrue(ElementType.allCases.contains(.table))
        XCTAssertTrue(ElementType.allCases.contains(.list))
        XCTAssertTrue(ElementType.allCases.contains(.listItem))
        XCTAssertTrue(ElementType.allCases.contains(.barcode))
        XCTAssertTrue(ElementType.allCases.contains(.image))
        XCTAssertTrue(ElementType.allCases.contains(.footnote))
        XCTAssertTrue(ElementType.allCases.contains(.pageNumber))
        XCTAssertTrue(ElementType.allCases.contains(.unknown))
    }
    
    func testElementTypeDescriptions() {
        XCTAssertEqual(ElementType.title.description, "Title")
        XCTAssertEqual(ElementType.textBlock.description, "Text Block")
        XCTAssertEqual(ElementType.paragraph.description, "Paragraph")
        XCTAssertEqual(ElementType.header.description, "Header")
        XCTAssertEqual(ElementType.footer.description, "Footer")
        XCTAssertEqual(ElementType.table.description, "Table")
        XCTAssertEqual(ElementType.list.description, "List")
        XCTAssertEqual(ElementType.listItem.description, "List Item")
        XCTAssertEqual(ElementType.barcode.description, "Barcode")
        XCTAssertEqual(ElementType.image.description, "Image")
        XCTAssertEqual(ElementType.footnote.description, "Footnote")
        XCTAssertEqual(ElementType.pageNumber.description, "Page Number")
        XCTAssertEqual(ElementType.unknown.description, "Unknown")
    }
    
    func testElementTypeTextBased() {
        // Text-based elements
        XCTAssertTrue(ElementType.title.isTextBased)
        XCTAssertTrue(ElementType.textBlock.isTextBased)
        XCTAssertTrue(ElementType.paragraph.isTextBased)
        XCTAssertTrue(ElementType.header.isTextBased)
        XCTAssertTrue(ElementType.footer.isTextBased)
        XCTAssertTrue(ElementType.listItem.isTextBased)
        XCTAssertTrue(ElementType.footnote.isTextBased)
        XCTAssertTrue(ElementType.pageNumber.isTextBased)
        
        // Non-text-based elements
        XCTAssertFalse(ElementType.table.isTextBased)
        XCTAssertFalse(ElementType.list.isTextBased)
        XCTAssertFalse(ElementType.barcode.isTextBased)
        XCTAssertFalse(ElementType.image.isTextBased)
        XCTAssertFalse(ElementType.unknown.isTextBased)
    }
    
    func testElementTypeMergeable() {
        // Mergeable elements
        XCTAssertTrue(ElementType.textBlock.isMergeable)
        XCTAssertTrue(ElementType.paragraph.isMergeable)
        XCTAssertTrue(ElementType.listItem.isMergeable)
        
        // Non-mergeable elements
        XCTAssertFalse(ElementType.title.isMergeable)
        XCTAssertFalse(ElementType.header.isMergeable)
        XCTAssertFalse(ElementType.footer.isMergeable)
        XCTAssertFalse(ElementType.table.isMergeable)
        XCTAssertFalse(ElementType.list.isMergeable)
        XCTAssertFalse(ElementType.barcode.isMergeable)
        XCTAssertFalse(ElementType.image.isMergeable)
        XCTAssertFalse(ElementType.footnote.isMergeable)
        XCTAssertFalse(ElementType.pageNumber.isMergeable)
        XCTAssertFalse(ElementType.unknown.isMergeable)
    }
    
    // MARK: - DocumentElement Initialization Tests
    
    func testDocumentElementInitialization() {
        let element = DocumentElement(
            type: .paragraph,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.95,
            pageNumber: 1,
            text: "Sample text",
            metadata: ["key": "value"],
            processedAt: Date()
        )
        
        XCTAssertEqual(element.type, .paragraph)
        XCTAssertEqual(element.boundingBox, sampleBoundingBox)
        XCTAssertEqual(element.contentData, sampleContentData)
        XCTAssertEqual(element.confidence, 0.95)
        XCTAssertEqual(element.pageNumber, 1)
        XCTAssertEqual(element.text, "Sample text")
        XCTAssertEqual(element.metadata["key"], "value")
        XCTAssertNotNil(element.processedAt)
        XCTAssertNotNil(element.id)
    }
    
    func testDocumentElementDefaultValues() {
        let element = DocumentElement(
            type: .title,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.8,
            pageNumber: 2
        )
        
        XCTAssertEqual(element.type, .title)
        XCTAssertEqual(element.boundingBox, sampleBoundingBox)
        XCTAssertEqual(element.contentData, sampleContentData)
        XCTAssertEqual(element.confidence, 0.8)
        XCTAssertEqual(element.pageNumber, 2)
        XCTAssertNil(element.text)
        XCTAssertTrue(element.metadata.isEmpty)
        XCTAssertNotNil(element.processedAt)
        XCTAssertNotNil(element.id)
    }
    
    // MARK: - DocumentElement Updating Tests
    
    func testDocumentElementUpdating() {
        let original = DocumentElement(
            type: .paragraph,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "Original text"
        )
        
        let updated = original.updating(
            type: .header,
            confidence: 0.95,
            text: "Updated text"
        )
        
        XCTAssertEqual(updated.type, .header)
        XCTAssertEqual(updated.boundingBox, original.boundingBox)
        XCTAssertEqual(updated.contentData, original.contentData)
        XCTAssertEqual(updated.confidence, 0.95)
        XCTAssertEqual(updated.pageNumber, original.pageNumber)
        XCTAssertEqual(updated.text, "Updated text")
        XCTAssertEqual(updated.metadata, original.metadata)
        XCTAssertEqual(updated.processedAt, original.processedAt)
        XCTAssertEqual(updated.id, original.id)
    }
    
    func testDocumentElementUpdatingPartial() {
        let original = DocumentElement(
            type: .paragraph,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let updated = original.updating(confidence: 0.95)
        
        XCTAssertEqual(updated.type, original.type)
        XCTAssertEqual(updated.boundingBox, original.boundingBox)
        XCTAssertEqual(updated.contentData, original.contentData)
        XCTAssertEqual(updated.confidence, 0.95)
        XCTAssertEqual(updated.pageNumber, original.pageNumber)
        XCTAssertEqual(updated.text, original.text)
        XCTAssertEqual(updated.metadata, original.metadata)
        XCTAssertEqual(updated.processedAt, original.processedAt)
        XCTAssertEqual(updated.id, original.id)
    }
    
    // MARK: - DocumentElement Overlap Tests
    
    func testDocumentElementOverlaps() {
        let element1 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element2 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 150, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element3 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 300, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        // element1 and element2 overlap
        XCTAssertTrue(element1.overlaps(with: element2, threshold: 0.1))
        
        // element1 and element3 don't overlap
        XCTAssertFalse(element1.overlaps(with: element3, threshold: 0.1))
    }
    
    func testDocumentElementMergeDistance() {
        let element1 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element2 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 220, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        // 20 points gap between elements (220 - 200 = 20, horizontal gap)
        XCTAssertEqual(element1.mergeDistance(to: element2), 20.0)
    }
    
    func testDocumentElementCanMerge() {
        let element1 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.05),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element2 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 0.22, y: 0.1, width: 0.1, height: 0.05),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element3 = DocumentElement(
            type: .title,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.1, height: 0.05),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        // Create a configuration that works with normalized coordinates
        let config = SimpleProcessingConfig(
            mergeDistanceThreshold: 0.15, // 0.15 normalized threshold
            isMergeDistanceNormalized: true
        )
        
        // Same type, same page, within merge distance
        XCTAssertTrue(element1.canMerge(with: element2, config: config))
        
        // Different types cannot merge
        XCTAssertFalse(element1.canMerge(with: element3, config: config))
        
        // Different page numbers cannot merge
        let element4 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.05),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 2
        )
        XCTAssertFalse(element1.canMerge(with: element4, config: config))
    }
    
    // MARK: - DocumentElement Comparable Tests
    
    func testDocumentElementSorting() {
        let element1 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element2 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 100, y: 200, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element3 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 200, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1
        )
        
        let element4 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 50),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 2
        )
        
        // Test sorting by page number first
        XCTAssertTrue(element1 < element4)
        
        // Test sorting by Y position (top to bottom)
        XCTAssertTrue(element1 < element2)
        
        // Test sorting by X position (left to right) when Y is similar
        XCTAssertTrue(element1 < element3)
        
        // Test that sorting is consistent
        let elements = [element2, element4, element1, element3]
        let sorted = elements.sorted()
        
        XCTAssertEqual(sorted[0], element1)  // page 1, y=100, x=100
        XCTAssertEqual(sorted[1], element3)  // page 1, y=100, x=200
        XCTAssertEqual(sorted[2], element2)  // page 1, y=200, x=100
        XCTAssertEqual(sorted[3], element4)  // page 2, y=100, x=100
    }
    
    // MARK: - Codable Tests
    
    func testDocumentElementCodable() throws {
        let original = DocumentElement(
            type: .paragraph,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "Test text",
            metadata: ["key": "value"]
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DocumentElement.self, from: data)
        
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.boundingBox, original.boundingBox)
        XCTAssertEqual(decoded.contentData, original.contentData)
        XCTAssertEqual(decoded.confidence, original.confidence)
        XCTAssertEqual(decoded.pageNumber, original.pageNumber)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.metadata, original.metadata)
        XCTAssertEqual(decoded.id, original.id)
    }
    
    // MARK: - Equatable Tests
    
    func testDocumentElementEquatable() {
        let element1 = DocumentElement(
            type: .paragraph,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "Test text"
        )
        
        let element2 = DocumentElement(
            type: .paragraph,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "Test text"
        )
        
        let element3 = DocumentElement(
            type: .header,
            boundingBox: sampleBoundingBox,
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "Test text"
        )
        
        // Elements with same content but different IDs should not be equal
        // (since ID is part of the identity)
        XCTAssertNotEqual(element1, element2)
        
        // Different content should not be equal
        XCTAssertNotEqual(element1, element3)
        
        // Same element should equal itself
        XCTAssertEqual(element1, element1)
    }
}
