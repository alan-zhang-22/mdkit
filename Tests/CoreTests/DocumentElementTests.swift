//
//  DocumentElementTests.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import XCTest
import CoreGraphics
@testable import mdkitCore
@testable import mdkitConfiguration
@testable import mdkitProtocols

final class DocumentElementTests: XCTestCase {
    
    // MARK: - Test Data
    
    let sampleBoundingBox = CGRect(x: 100, y: 200, width: 300, height: 50)
    let sampleContentData = "Sample text content".data(using: .utf8)!
    
    // MARK: - ElementType Tests
    
    func testElementTypeCases() {
        // Test that all cases are accessible
        XCTAssertEqual(DocumentElementType.allCases.count, 13)
        XCTAssertTrue(DocumentElementType.allCases.contains(.title))
        XCTAssertTrue(DocumentElementType.allCases.contains(.textBlock))
        XCTAssertTrue(DocumentElementType.allCases.contains(.paragraph))
        XCTAssertTrue(DocumentElementType.allCases.contains(.header))
        XCTAssertTrue(DocumentElementType.allCases.contains(.footer))
        XCTAssertTrue(DocumentElementType.allCases.contains(.table))
        XCTAssertTrue(DocumentElementType.allCases.contains(.list))
        XCTAssertTrue(DocumentElementType.allCases.contains(.listItem))
        XCTAssertTrue(DocumentElementType.allCases.contains(.barcode))
        XCTAssertTrue(DocumentElementType.allCases.contains(.image))
        XCTAssertTrue(DocumentElementType.allCases.contains(.footnote))
        XCTAssertTrue(DocumentElementType.allCases.contains(.pageNumber))
        XCTAssertTrue(DocumentElementType.allCases.contains(.unknown))
    }
    
    func testElementTypeDescriptions() {
        XCTAssertEqual(DocumentElementType.title.description, "Title")
        XCTAssertEqual(DocumentElementType.textBlock.description, "Text Block")
        XCTAssertEqual(DocumentElementType.paragraph.description, "Paragraph")
        XCTAssertEqual(DocumentElementType.header.description, "Header")
        XCTAssertEqual(DocumentElementType.footer.description, "Footer")
        XCTAssertEqual(DocumentElementType.table.description, "Table")
        XCTAssertEqual(DocumentElementType.list.description, "List")
        XCTAssertEqual(DocumentElementType.listItem.description, "List Item")
        XCTAssertEqual(DocumentElementType.barcode.description, "Barcode")
        XCTAssertEqual(DocumentElementType.image.description, "Image")
        XCTAssertEqual(DocumentElementType.footnote.description, "Footnote")
        XCTAssertEqual(DocumentElementType.pageNumber.description, "Page Number")
        XCTAssertEqual(DocumentElementType.unknown.description, "Unknown")
    }
    
    func testElementTypeTextBased() {
        // Text-based elements
        XCTAssertTrue(DocumentElementType.title.isTextBased)
        XCTAssertTrue(DocumentElementType.textBlock.isTextBased)
        XCTAssertTrue(DocumentElementType.paragraph.isTextBased)
        XCTAssertTrue(DocumentElementType.header.isTextBased)
        XCTAssertTrue(DocumentElementType.footer.isTextBased)
        XCTAssertTrue(DocumentElementType.listItem.isTextBased)
        XCTAssertTrue(DocumentElementType.footnote.isTextBased)
        XCTAssertTrue(DocumentElementType.pageNumber.isTextBased)
        
        // Non-text-based elements
        XCTAssertFalse(DocumentElementType.table.isTextBased)
        XCTAssertFalse(DocumentElementType.list.isTextBased)
        XCTAssertFalse(DocumentElementType.barcode.isTextBased)
        XCTAssertFalse(DocumentElementType.image.isTextBased)
        XCTAssertFalse(DocumentElementType.unknown.isTextBased)
    }
    
    func testElementTypeMergeable() {
        // Mergeable elements
        XCTAssertTrue(DocumentElementType.textBlock.isMergeable)
        XCTAssertTrue(DocumentElementType.paragraph.isMergeable)
        XCTAssertTrue(DocumentElementType.listItem.isMergeable)
        
        // Non-mergeable elements
        XCTAssertFalse(DocumentElementType.title.isMergeable)
        XCTAssertFalse(DocumentElementType.header.isMergeable)
        XCTAssertFalse(DocumentElementType.footer.isMergeable)
        XCTAssertFalse(DocumentElementType.table.isMergeable)
        XCTAssertFalse(DocumentElementType.list.isMergeable)
        XCTAssertFalse(DocumentElementType.barcode.isMergeable)
        XCTAssertFalse(DocumentElementType.image.isMergeable)
        XCTAssertFalse(DocumentElementType.footnote.isMergeable)
        XCTAssertFalse(DocumentElementType.pageNumber.isMergeable)
        XCTAssertFalse(DocumentElementType.unknown.isMergeable)
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
        let config = MDKitConfig(
            processing: ProcessingConfig(
                mergeDistanceThreshold: 0.15, // 0.15 normalized threshold
                isMergeDistanceNormalized: true,
                horizontalMergeThreshold: 0.20, // 0.20 normalized threshold for horizontal
                isHorizontalMergeThresholdNormalized: true
            )
        )
        
        // Same type, same page, within merge distance
        XCTAssertTrue(element1.canMerge(with: element2, config: config.processing))
        
        // Different types cannot merge
        XCTAssertFalse(element1.canMerge(with: element3, config: config.processing))
        
        // Different page numbers cannot merge
        let element4 = DocumentElement(
            type: .paragraph,
            boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.05),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 2
        )
        XCTAssertFalse(element1.canMerge(with: element4, config: config.processing))
    }
    
    // MARK: - Horizontal vs Vertical Merging Tests
    
    func testHorizontalMergingWithDirectionalThresholds() {
        // Create elements that are on the same line
        let element1 = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.05),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "5.1.2"
        )
        
        let element2 = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 0.4, y: 0.2, width: 0.4, height: 0.05),
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "Access Control"
        )
        
        // Create a configuration with different horizontal vs vertical thresholds
        let config = MDKitConfig(
            processing: ProcessingConfig(
                mergeDistanceThreshold: 0.02, // 2% for vertical
                isMergeDistanceNormalized: true,
                horizontalMergeThreshold: 0.15, // 15% for horizontal
                isHorizontalMergeThresholdNormalized: true
            )
        )
        
        // Elements should be on the same line (tolerance 0.05 = 5% of document height)
        XCTAssertTrue(element1.boundingBox.isVerticallyAligned(with: element2.boundingBox, tolerance: 0.05))
        
        // Elements should be mergeable due to same line threshold being more permissive
        XCTAssertTrue(element1.canMerge(with: element2, config: config.processing))
        
        // Test with elements on different lines
        let element3 = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.05), // Much further down
            contentData: sampleContentData,
            confidence: 0.9,
            pageNumber: 1,
            text: "Different line"
        )
        
        // Elements should NOT be on the same line with realistic tolerance (0.05 = 5%)
        XCTAssertFalse(element1.boundingBox.isVerticallyAligned(with: element3.boundingBox, tolerance: 0.05))
        
        // Elements should NOT be mergeable due to different line threshold being more restrictive
        XCTAssertFalse(element1.canMerge(with: element3, config: config.processing))
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
