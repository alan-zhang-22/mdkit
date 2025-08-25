//
//  DocumentElementTests.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import XCTest
@testable import mdkitCore

final class DocumentElementTests: XCTestCase {
    
    func testDocumentElementCreation() {
        let element = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 10, y: 20, width: 100, height: 30),
            content: "Test content",
            confidence: 0.95,
            pageIndex: 0
        )
        
        XCTAssertEqual(element.type, .textBlock)
        XCTAssertEqual(element.content, "Test content")
        XCTAssertEqual(element.confidence, 0.95)
        XCTAssertEqual(element.pageIndex, 0)
    }
    
    func testElementTypeEnum() {
        XCTAssertTrue(ElementType.allCases.contains(.title))
        XCTAssertTrue(ElementType.allCases.contains(.textBlock))
        XCTAssertTrue(ElementType.allCases.contains(.paragraph))
        XCTAssertTrue(ElementType.allCases.contains(.header))
        XCTAssertTrue(ElementType.allCases.contains(.table))
        XCTAssertTrue(ElementType.allCases.contains(.list))
        XCTAssertTrue(ElementType.allCases.contains(.barcode))
        XCTAssertTrue(ElementType.allCases.contains(.listItem))
        XCTAssertTrue(ElementType.allCases.contains(.unknown))
    }
    
    func testCGRectOverlapDetection() {
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 50, y: 50, width: 100, height: 100)
        let rect3 = CGRect(x: 200, y: 200, width: 100, height: 100)
        
        // Test overlap area
        let overlapArea = rect1.overlapArea(with: rect2)
        XCTAssertEqual(overlapArea, 2500) // 50x50 overlap
        
        // Test overlap percentage
        let overlapPercentage = rect1.overlapPercentage(with: rect2)
        XCTAssertEqual(overlapPercentage, 0.25) // 2500/10000
        
        // Test significant overlap
        XCTAssertTrue(rect1.overlapsSignificantly(with: rect2, threshold: 0.2))
        XCTAssertFalse(rect1.overlapsSignificantly(with: rect3, threshold: 0.1))
    }
    
    func testDocumentElementOverlap() {
        let element1 = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            content: "First element",
            confidence: 0.9,
            pageIndex: 0
        )
        
        let element2 = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 50, y: 50, width: 100, height: 100),
            content: "Second element",
            confidence: 0.9,
            pageIndex: 0
        )
        
        let element3 = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 200, y: 200, width: 100, height: 100),
            content: "Third element",
            confidence: 0.9,
            pageIndex: 0
        )
        
        // Test overlap detection
        XCTAssertTrue(element1.overlaps(with: element2))
        XCTAssertFalse(element1.overlaps(with: element3))
        
        // Test overlap percentage
        let overlapPercentage = element1.overlapPercentage(with: element2)
        XCTAssertEqual(overlapPercentage, 0.25)
    }
    
    func testReadingOrderSorting() {
        let elements = [
            DocumentElement(
                type: .textBlock,
                boundingBox: CGRect(x: 100, y: 200, width: 100, height: 30),
                content: "Bottom right",
                confidence: 0.9,
                pageIndex: 0
            ),
            DocumentElement(
                type: .textBlock,
                boundingBox: CGRect(x: 0, y: 0, width: 100, height: 30),
                content: "Top left",
                confidence: 0.9,
                pageIndex: 0
            ),
            DocumentElement(
                type: .textBlock,
                boundingBox: CGRect(x: 100, y: 0, width: 100, height: 30),
                content: "Top right",
                confidence: 0.9,
                pageIndex: 0
            )
        ]
        
        let sortedElements = DocumentElement.sortByReadingOrder(elements)
        
        // Should be sorted by Y first (top to bottom), then by X (left to right)
        XCTAssertEqual(sortedElements[0].content, "Top left")
        XCTAssertEqual(sortedElements[1].content, "Top right")
        XCTAssertEqual(sortedElements[2].content, "Bottom right")
    }
    
    func testElementPositioning() {
        let topElement = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 30),
            content: "Top",
            confidence: 0.9,
            pageIndex: 0
        )
        
        let bottomElement = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 0, y: 100, width: 100, height: 30),
            content: "Bottom",
            confidence: 0.9,
            pageIndex: 0
        )
        
        let leftElement = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 0, y: 50, width: 100, height: 30),
            content: "Left",
            confidence: 0.9,
            pageIndex: 0
        )
        
        let rightElement = DocumentElement(
            type: .textBlock,
            boundingBox: CGRect(x: 200, y: 50, width: 100, height: 30),
            content: "Right",
            confidence: 0.9,
            pageIndex: 0
        )
        
        // Test positioning methods
        XCTAssertTrue(topElement.isAbove(bottomElement))
        XCTAssertFalse(bottomElement.isAbove(topElement))
        
        XCTAssertTrue(leftElement.isLeftOf(rightElement))
        XCTAssertFalse(rightElement.isLeftOf(leftElement))
    }
}
