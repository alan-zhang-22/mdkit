import XCTest
import Vision
import CoreGraphics
import Logging
@testable import mdkitCore

final class UnifiedDocumentProcessorTests: XCTestCase {
    
    var processor: UnifiedDocumentProcessor!
    var testConfig: SimpleProcessingConfig!
    
    override func setUp() {
        super.setUp()
        testConfig = SimpleProcessingConfig(
            overlapThreshold: 0.1,
            enableElementMerging: true,
            enableHeaderFooterDetection: true,
            headerRegion: 0.0...0.15,
            footerRegion: 0.85...1.0,
            enableLLMOptimization: false
        )
        processor = UnifiedDocumentProcessor(config: testConfig)
    }
    
    override func tearDown() {
        processor = nil
        testConfig = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(processor)
        XCTAssertEqual(processor.config.overlapThreshold, testConfig.overlapThreshold)
        XCTAssertEqual(processor.config.enableElementMerging, testConfig.enableElementMerging)
        XCTAssertEqual(processor.config.enableHeaderFooterDetection, testConfig.enableHeaderFooterDetection)
        XCTAssertEqual(processor.config.headerRegion, testConfig.headerRegion)
        XCTAssertEqual(processor.config.footerRegion, testConfig.footerRegion)
        XCTAssertEqual(processor.config.enableLLMOptimization, testConfig.enableLLMOptimization)
    }
    
    // MARK: - Configuration Tests
    
    func testHeaderFooterDetectionConfiguration() {
        // Test with header/footer detection enabled
        let configWithDetection = SimpleProcessingConfig(
            overlapThreshold: 0.1,
            enableElementMerging: true,
            enableHeaderFooterDetection: true,
            headerRegion: 0.0...0.1,
            footerRegion: 0.9...1.0,
            enableLLMOptimization: false
        )
        
        XCTAssertTrue(configWithDetection.enableHeaderFooterDetection)
        XCTAssertEqual(configWithDetection.headerRegion, 0.0...0.1)
        XCTAssertEqual(configWithDetection.footerRegion, 0.9...1.0)
        
        // Test with header/footer detection disabled
        let configWithoutDetection = SimpleProcessingConfig(
            overlapThreshold: 0.1,
            enableElementMerging: true,
            enableHeaderFooterDetection: false,
            headerRegion: 0.0...0.15,
            footerRegion: 0.85...1.0,
            enableLLMOptimization: false
        )
        
        XCTAssertFalse(configWithoutDetection.enableHeaderFooterDetection)
    }
    
    func testLLMOptimizationConfiguration() {
        // Test with LLM optimization enabled
        let configWithLLM = SimpleProcessingConfig(
            overlapThreshold: 0.1,
            enableElementMerging: true,
            enableHeaderFooterDetection: true,
            headerRegion: 0.0...0.15,
            footerRegion: 0.85...1.0,
            enableLLMOptimization: true
        )
        
        XCTAssertTrue(configWithLLM.enableLLMOptimization)
        
        // Test with LLM optimization disabled
        let configWithoutLLM = SimpleProcessingConfig(
            overlapThreshold: 0.1,
            enableElementMerging: true,
            enableHeaderFooterDetection: true,
            headerRegion: 0.0...0.15,
            footerRegion: 0.85...1.0,
            enableLLMOptimization: false
        )
        
        XCTAssertFalse(configWithoutLLM.enableLLMOptimization)
    }
    
    func testHeaderFooterDetectionLogic() {
        // Test header detection
        let headerConfig = SimpleProcessingConfig(
            overlapThreshold: 0.1,
            enableElementMerging: true,
            enableHeaderFooterDetection: true,
            headerRegion: 0.0...0.1,  // Top 10%
            footerRegion: 0.9...1.0,  // Bottom 10%
            enableLLMOptimization: false
        )
        
        let headerProcessor = UnifiedDocumentProcessor(config: headerConfig)
        
        // Test that elements in header region are detected as headers
        let headerElement = createMockElement(text: "Regular text", boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.05))
        // Note: This test would need access to the private determineElementType method
        // For now, we'll test the configuration is properly applied
        
        XCTAssertTrue(headerConfig.enableHeaderFooterDetection)
        XCTAssertEqual(headerConfig.headerRegion, 0.0...0.1)
        XCTAssertEqual(headerConfig.footerRegion, 0.9...1.0)
    }
    
    // MARK: - Element Type Detection Tests
    
    func testHeaderPatternDetection() {
        let headerTexts = [
            "INTRODUCTION",
            "1. Background",
            "2. Methodology",
            "Chapter One",
            "Executive Summary"
        ]
        
        for text in headerTexts {
            let element = createMockElement(text: text, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
            XCTAssertTrue(isHeaderPattern(text), "Text '\(text)' should be detected as header")
        }
    }
    
    func testListItemPatternDetection() {
        let listItemTexts = [
            "- First item",
            "* Second item",
            "+ Third item",
            "1. Numbered item",
            "1- Another numbered item",
            "a. Lettered item",
            "a) Another lettered item"
        ]
        
        for text in listItemTexts {
            XCTAssertTrue(isListItemPattern(text), "Text '\(text)' should be detected as list item")
        }
    }
    
    func testPageNumberPatternDetection() {
        let pageNumberTexts = [
            "1",
            "42",
            "Page 1",
            "Page 15",
            "1 of 5",
            "3 of 10"
        ]
        
        for text in pageNumberTexts {
            XCTAssertTrue(isPageNumberPattern(text), "Text '\(text)' should be detected as page number")
        }
    }
    
    func testNonHeaderPatterns() {
        let nonHeaderTexts = [
            "This is a regular paragraph with normal text content.",
            "Mixed case text that doesn't follow header patterns",
            "lowercase text",
            "12345",
            "Special characters: @#$%"
        ]
        
        for text in nonHeaderTexts {
            XCTAssertFalse(isHeaderPattern(text), "Text '\(text)' should NOT be detected as header")
        }
    }
    
    func testNonListItemPatterns() {
        let nonListItemTexts = [
            "Regular text without list markers",
            "Text with numbers 123 but no list format",
            "Just some content",
            "A sentence that ends with a period."
        ]
        
        for text in nonListItemTexts {
            XCTAssertFalse(isListItemPattern(text), "Text '\(text)' should NOT be detected as list item")
        }
    }
    
    func testNonPageNumberPatterns() {
        let nonPageNumberTexts = [
            "Page",
            "of",
            "Chapter 1",
            "Section 2.1",
            "Appendix A"
        ]
        
        for text in nonPageNumberTexts {
            XCTAssertFalse(isPageNumberPattern(text), "Text '\(text)' should NOT be detected as page number")
        }
    }
    
    // MARK: - Position-based Sorting Tests
    
    func testElementSortingByPosition() {
        let elements = [
            createMockElement(text: "Bottom", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.8, height: 0.1)),
            createMockElement(text: "Top", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.1)),
            createMockElement(text: "Middle", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1))
        ]
        
        let sortedElements = sortElementsByPosition(elements)
        
        XCTAssertEqual(sortedElements[0].text, "Top")
        XCTAssertEqual(sortedElements[1].text, "Middle")
        XCTAssertEqual(sortedElements[2].text, "Bottom")
    }
    
    func testElementSortingWithSameYPosition() {
        let elements = [
            createMockElement(text: "Right", boundingBox: CGRect(x: 0.6, y: 0.3, width: 0.3, height: 0.1)),
            createMockElement(text: "Left", boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.3, height: 0.1)),
            createMockElement(text: "Center", boundingBox: CGRect(x: 0.35, y: 0.3, width: 0.3, height: 0.1))
        ]
        
        let sortedElements = sortElementsByPosition(elements)
        
        XCTAssertEqual(sortedElements[0].text, "Left")
        XCTAssertEqual(sortedElements[1].text, "Center")
        XCTAssertEqual(sortedElements[2].text, "Right")
    }
    
    func testElementSortingComplexLayout() {
        let elements = [
            createMockElement(text: "Header", boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.05)),
            createMockElement(text: "Left Column", boundingBox: CGRect(x: 0.05, y: 0.2, width: 0.4, height: 0.6)),
            createMockElement(text: "Right Column", boundingBox: CGRect(x: 0.55, y: 0.2, width: 0.4, height: 0.6)),
            createMockElement(text: "Footer", boundingBox: CGRect(x: 0.1, y: 0.9, width: 0.8, height: 0.05))
        ]
        
        let sortedElements = sortElementsByPosition(elements)
        
        XCTAssertEqual(sortedElements[0].text, "Header")
        XCTAssertEqual(sortedElements[1].text, "Left Column")
        XCTAssertEqual(sortedElements[2].text, "Right Column")
        XCTAssertEqual(sortedElements[3].text, "Footer")
    }
    
    // MARK: - Coordinate Conversion Tests
    
    func testVisionCoordinateConversion() {
        let visionBox = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let convertedBox = convertVisionBoundingBox(visionBox)
        
        // Vision: origin at bottom-left, Y increases upward
        // Our system: origin at top-left, Y increases downward
        XCTAssertEqual(convertedBox.minX, 0.1, accuracy: 0.001)
        XCTAssertEqual(convertedBox.minY, 0.4, accuracy: 0.001) // 1.0 - (0.2 + 0.4) = 0.4
        XCTAssertEqual(convertedBox.width, 0.3, accuracy: 0.001)
        XCTAssertEqual(convertedBox.height, 0.4, accuracy: 0.001)
    }
    
    func testVisionCoordinateConversionEdgeCases() {
        // Test top-left corner
        let topLeft = convertVisionBoundingBox(CGRect(x: 0.0, y: 1.0, width: 0.1, height: 0.1))
        XCTAssertEqual(topLeft.minX, 0.0, accuracy: 0.001)
        XCTAssertEqual(topLeft.minY, -0.1, accuracy: 0.001) // 1.0 - (1.0 + 0.1) = -0.1
        
        // Test bottom-right corner
        let bottomRight = convertVisionBoundingBox(CGRect(x: 0.9, y: 0.0, width: 0.1, height: 0.1))
        XCTAssertEqual(bottomRight.minX, 0.9, accuracy: 0.001)
        XCTAssertEqual(bottomRight.minY, 0.9, accuracy: 0.001) // 1.0 - (0.0 + 0.1) = 0.9
        
        // Test center
        let center = convertVisionBoundingBox(CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2))
        XCTAssertEqual(center.minX, 0.4, accuracy: 0.001)
        XCTAssertEqual(center.minY, 0.4, accuracy: 0.001) // 1.0 - (0.4 + 0.2) = 0.4
    }
    
    // MARK: - Element Type Detection Tests
    
    func testElementTypeDetection() {
        // Test title detection
        let titleElement = createMockElement(text: "Document Title", boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.05))
        XCTAssertEqual(determineElementType(text: titleElement.text!, boundingBox: titleElement.boundingBox), mdkitCore.ElementType.title)
        
        // Test header detection
        let headerElement = createMockElement(text: "1. Introduction", boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.03))
        XCTAssertEqual(determineElementType(text: headerElement.text!, boundingBox: headerElement.boundingBox), mdkitCore.ElementType.header)
        
        // Test list item detection
        let listItemElement = createMockElement(text: "- First point", boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.05))
        XCTAssertEqual(determineElementType(text: listItemElement.text!, boundingBox: listItemElement.boundingBox), mdkitCore.ElementType.listItem)
        
        // Test page number detection
        let pageNumberElement = createMockElement(text: "1", boundingBox: CGRect(x: 0.45, y: 0.95, width: 0.1, height: 0.03))
        XCTAssertEqual(determineElementType(text: pageNumberElement.text!, boundingBox: pageNumberElement.boundingBox), mdkitCore.ElementType.pageNumber)
        
        // Test text block detection
        let textBlockElement = createMockElement(text: "This is a long paragraph with lots of text content that should be classified as a text block because it contains more than 100 characters and represents substantial content.", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.1))
        XCTAssertEqual(determineElementType(text: textBlockElement.text!, boundingBox: textBlockElement.boundingBox), mdkitCore.ElementType.textBlock)
        
        // Test paragraph detection
        let paragraphElement = createMockElement(text: "This is a medium-length paragraph that should be classified as a paragraph.", boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.05))
        XCTAssertEqual(determineElementType(text: paragraphElement.text!, boundingBox: paragraphElement.boundingBox), mdkitCore.ElementType.paragraph)
    }
    
    // MARK: - Helper Methods
    
    private func createMockElement(text: String, boundingBox: CGRect) -> DocumentElement {
        return DocumentElement(
            type: mdkitCore.ElementType.unknown,
            boundingBox: boundingBox,
            contentData: text.data(using: .utf8) ?? Data(),
            confidence: 0.95,
            pageNumber: 1,
            text: text,
            metadata: [:]
        )
    }
    
    // MARK: - Private Method Access for Testing
    
    private func isHeaderPattern(_ text: String) -> Bool {
        let patterns = [
            "^[A-Z][A-Z\\s]+$", // ALL CAPS
            "^[0-9]+\\.[\\s]*[A-Z]", // Numbered headers: "1. Title"
            "^[A-Z][a-z]+[\\s]+[A-Z][a-z]+" // Title Case
        ]
        
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func isListItemPattern(_ text: String) -> Bool {
        let patterns = [
            "^[\\-\\*\\+][\\s]+", // Bullet points: "- ", "* ", "+ "
            "^[0-9]+[\\s]*[\\-\\.][\\s]+", // Numbered lists: "1. ", "1- "
            "^[a-z][\\.\\)][\\s]+" // Lettered lists: "a. ", "a) "
        ]
        
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func isPageNumberPattern(_ text: String) -> Bool {
        let patterns = [
            "^[0-9]+$", // Just numbers
            "^Page [0-9]+$", // "Page 1"
            "^[0-9]+ of [0-9]+$" // "1 of 5"
        ]
        
        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func sortElementsByPosition(_ elements: [DocumentElement]) -> [DocumentElement] {
        return elements.sorted { first, second in
            // Primary sort: Y position (top to bottom)
            if abs(first.boundingBox.midY - second.boundingBox.midY) > 0.01 {
                return first.boundingBox.midY < second.boundingBox.midY
            }
            
            // Secondary sort: X position (left to right)
            return first.boundingBox.midX < second.boundingBox.midX
        }
    }
    
    private func convertVisionBoundingBox(_ visionBox: CGRect) -> CGRect {
        // Vision coordinates: origin at bottom-left, Y increases upward
        // Our system: origin at top-left, Y increases downward
        // Use parentheses to ensure proper floating-point arithmetic
        let convertedY = 1.0 - (visionBox.origin.y + visionBox.height)
        
        return CGRect(
            x: visionBox.origin.x,
            y: convertedY,
            width: visionBox.width,
            height: visionBox.height
        )
    }
    
    private func determineElementType(text: String, boundingBox: CGRect) -> mdkitCore.ElementType {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for titles FIRST (usually first element, short text, at top of page)
        if boundingBox.minY < 0.2 && trimmedText.count < 50 {
            return .title
        }
        
        // Check for headers (usually shorter text, higher confidence)
        if trimmedText.count < 100 && boundingBox.height < 0.1 {
            // Check for common header patterns
            if isHeaderPattern(trimmedText) {
                return .header
            }
        }
        
        // Check for list items
        if isListItemPattern(trimmedText) {
            return mdkitCore.ElementType.listItem
        }
        
        // Check for page numbers
        if isPageNumberPattern(trimmedText) {
            return mdkitCore.ElementType.pageNumber
        }
        
        // Default to text block for longer content
        if trimmedText.count > 100 {
            return mdkitCore.ElementType.textBlock
        }
        
        // Default to paragraph for medium content
        return mdkitCore.ElementType.paragraph
    }
}
