import XCTest
import Foundation
import CoreGraphics
@testable import mdkitCore
@testable import mdkitProtocols

final class MarkdownGeneratorTests: XCTestCase {
    
    var markdownGenerator: MarkdownGenerator!
    
    override func setUp() {
        super.setUp()
        markdownGenerator = MarkdownGenerator()
    }
    
    override func tearDown() {
        markdownGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestElement(
        type: DocumentElementType,
        text: String,
        boundingBox: CGRect = CGRect(x: 0, y: 0, width: 100, height: 20)
    ) -> DocumentElement {
        return DocumentElement(
            type: type,
            boundingBox: boundingBox,
            contentData: Data(),
            confidence: 0.9,
            pageNumber: 1,
            text: text
        )
    }
    
    private func createTestElements() -> [DocumentElement] {
        return [
            createTestElement(type: .title, text: "Document Title", boundingBox: CGRect(x: 0, y: 0, width: 200, height: 30)),
            createTestElement(type: .header, text: "Section Header", boundingBox: CGRect(x: 0, y: 40, width: 150, height: 25)),
            createTestElement(type: .paragraph, text: "This is a paragraph with some content.", boundingBox: CGRect(x: 0, y: 70, width: 180, height: 20)),
            createTestElement(type: .listItem, text: "First list item", boundingBox: CGRect(x: 0, y: 100, width: 160, height: 18)),
            createTestElement(type: .listItem, text: "Second list item", boundingBox: CGRect(x: 0, y: 120, width: 160, height: 18))
        ]
    }
    
    // MARK: - Basic Generation Tests
    
    func testGenerateMarkdownWithEmptyElements() throws {
        let elements: [DocumentElement] = []
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "")
    }
    
    func testGenerateMarkdownWithSingleElement() throws {
        let elements = [createTestElement(type: .title, text: "Simple Title")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("# Simple Title"))
        XCTAssertFalse(markdown.contains("##"))
    }
    
    // MARK: - Element Type Tests
    
    func testTitleElementGeneration() throws {
        let elements = [createTestElement(type: .title, text: "Document Title")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("# Document Title"))
        XCTAssertFalse(markdown.contains("##"))
    }
    
    func testHeaderElementGeneration() throws {
        let elements = [createTestElement(type: .header, text: "Section Header")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("## Section Header"))
    }
    
    func testParagraphElementGeneration() throws {
        let elements = [createTestElement(type: .paragraph, text: "This is a paragraph.")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("This is a paragraph."))
    }
    
    func testListItemElementGeneration() throws {
        let elements = [createTestElement(type: .listItem, text: "List item text")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("- List item text"))
    }
    
    func testTableElementGeneration() throws {
        let elements = [createTestElement(type: .table, text: "Table data")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("Table data"))
    }
    
    func testFooterElementGeneration() throws {
        let elements = [createTestElement(type: .footer, text: "Footer content")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("Footer content"))
    }
    
    func testFootnoteElementGeneration() throws {
        let elements = [createTestElement(type: .footnote, text: "Footnote text")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("Footnote text"))
    }
    
    func testPageNumberElementGeneration() throws {
        let elements = [createTestElement(type: .pageNumber, text: "5")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("5"))
    }
    
    func testImageElementGeneration() throws {
        let elements = [createTestElement(type: .image, text: "Figure 1")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("Figure 1"))
    }
    
    func testBarcodeElementGeneration() throws {
        let elements = [createTestElement(type: .barcode, text: "123456789")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("123456789"))
    }
    
    func testUnknownElementGeneration() throws {
        let elements = [createTestElement(type: .unknown, text: "Unknown content")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("Unknown content"))
    }
    
    // MARK: - Header Level Tests
    
    func testHeaderLevelCalculation() throws {
        let elements = [
            createTestElement(type: .header, text: "Top Header", boundingBox: CGRect(x: 0, y: 0.05, width: 100, height: 20)),
            createTestElement(type: .header, text: "Upper Header", boundingBox: CGRect(x: 0, y: 0.15, width: 100, height: 20)),
            createTestElement(type: .header, text: "Middle Header", boundingBox: CGRect(x: 0, y: 0.25, width: 100, height: 20)),
            createTestElement(type: .header, text: "Lower Header", boundingBox: CGRect(x: 0, y: 0.35, width: 100, height: 20)),
            createTestElement(type: .header, text: "Bottom Header", boundingBox: CGRect(x: 0, y: 0.45, width: 100, height: 20)),
            createTestElement(type: .header, text: "Very Bottom Header", boundingBox: CGRect(x: 0, y: 0.55, width: 100, height: 20))
        ]
        
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        // Check that headers are generated with appropriate levels
        XCTAssertTrue(markdown.contains("## Top Header"))
        XCTAssertTrue(markdown.contains("### Upper Header"))
        XCTAssertTrue(markdown.contains("#### Middle Header"))
        XCTAssertTrue(markdown.contains("##### Lower Header"))
        XCTAssertTrue(markdown.contains("###### Bottom Header"))
        XCTAssertTrue(markdown.contains("###### Very Bottom Header"))
    }
    
    // MARK: - Complex Content Tests
    
    func testGenerateMarkdownWithMultipleElements() throws {
        let elements = createTestElements()
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("# Document Title"))
        XCTAssertTrue(markdown.contains("## Section Header"))
        XCTAssertTrue(markdown.contains("This is a paragraph with some content."))
        XCTAssertTrue(markdown.contains("- First list item"))
        XCTAssertTrue(markdown.contains("- Second list item"))
    }
    
    func testGenerateMarkdownWithNestedStructure() throws {
        let elements = [
            createTestElement(type: .title, text: "Main Title", boundingBox: CGRect(x: 0, y: 0, width: 200, height: 30)),
            createTestElement(type: .header, text: "Chapter 1", boundingBox: CGRect(x: 0, y: 0.1, width: 150, height: 25)),
            createTestElement(type: .paragraph, text: "Chapter 1 content", boundingBox: CGRect(x: 0, y: 0.2, width: 180, height: 20)),
            createTestElement(type: .header, text: "Chapter 2", boundingBox: CGRect(x: 0, y: 0.4, width: 150, height: 25)),
            createTestElement(type: .paragraph, text: "Chapter 2 content", boundingBox: CGRect(x: 0, y: 0.5, width: 180, height: 20))
        ]
        
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("# Main Title"))
        XCTAssertTrue(markdown.contains("## Chapter 1"))
        XCTAssertTrue(markdown.contains("Chapter 1 content"))
        XCTAssertTrue(markdown.contains("## Chapter 2"))
        XCTAssertTrue(markdown.contains("Chapter 2 content"))
    }
    
    // MARK: - Edge Cases
    
    func testElementsWithEmptyText() throws {
        let elements = [
            createTestElement(type: .title, text: "Valid Title"),
            createTestElement(type: .paragraph, text: ""),
            createTestElement(type: .header, text: "   "),
            createTestElement(type: .listItem, text: "Valid Item")
        ]
        
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("# Valid Title"))
        XCTAssertFalse(markdown.contains("##"))
        XCTAssertTrue(markdown.contains("- Valid Item"))
    }
    
    func testElementsWithSpecialCharacters() throws {
        let elements = [
            createTestElement(type: .title, text: "Title with \"quotes\" & symbols"),
            createTestElement(type: .header, text: "Header with <tags> and [brackets]"),
            createTestElement(type: .paragraph, text: "Text with *asterisks* and _underscores_")
        ]
        
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.contains("Title with \"quotes\" & symbols"))
        XCTAssertTrue(markdown.contains("Header with <tags> and [brackets]"))
        XCTAssertTrue(markdown.contains("Text with *asterisks* and _underscores_"))
    }
    
    func testInvalidElementType() throws {
        // Create an element with an invalid type (this shouldn't happen in practice)
        let invalidElement = DocumentElement(
            type: DocumentElementType(rawValue: "invalid") ?? .unknown,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
            contentData: Data(),
            confidence: 0.9,
            pageNumber: 1,
            text: "Invalid content"
        )
        
        let markdown = try markdownGenerator.generateMarkdown(from: [invalidElement])
        
        XCTAssertTrue(markdown.contains("Invalid content"))
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithLargeNumberOfElements() throws {
        let elements = (0..<1000).map { index in
            createTestElement(
                type: index % 2 == 0 ? .header : .paragraph,
                text: "Element \(index)",
                boundingBox: CGRect(x: 0, y: Double(index) * 0.1, width: 100, height: 20)
            )
        }
        
        measure {
            do {
                _ = try markdownGenerator.generateMarkdown(from: elements)
            } catch {
                XCTFail("Failed to generate markdown: \(error)")
            }
        }
    }
}


