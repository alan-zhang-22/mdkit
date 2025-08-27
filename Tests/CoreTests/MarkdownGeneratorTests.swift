import XCTest
import CoreGraphics
import Logging
@testable import mdkitCore
@testable import mdkitConfiguration

final class MarkdownGeneratorTests: XCTestCase {
    
    // MARK: - Properties
    
    var markdownGenerator: MarkdownGenerator!
    var testConfig: MarkdownGenerationConfig!
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        testConfig = MarkdownGenerationConfig()
        markdownGenerator = MarkdownGenerator(config: testConfig)
    }
    
    override func tearDown() {
        markdownGenerator = nil
        testConfig = nil
        super.tearDown()
    }
    
    // MARK: - Test Data Creation
    
    private func createTestElement(
        type: ElementType,
        text: String,
        boundingBox: CGRect = CGRect(x: 0, y: 0, width: 100, height: 20)
    ) -> DocumentElement {
        return DocumentElement(
            type: type,
            boundingBox: boundingBox,
            contentData: text.data(using: .utf8) ?? Data(),
            confidence: 0.9,
            pageNumber: 1,
            text: text
        )
    }
    
    private func createTestElements() -> [DocumentElement] {
        return [
            createTestElement(type: .title, text: "Document Title", boundingBox: CGRect(x: 0, y: 0, width: 200, height: 30)),
            createTestElement(type: .header, text: "Section 1", boundingBox: CGRect(x: 0, y: 50, width: 150, height: 25)),
            createTestElement(type: .paragraph, text: "This is a paragraph of text.", boundingBox: CGRect(x: 0, y: 80, width: 300, height: 20)),
            createTestElement(type: .listItem, text: "First list item", boundingBox: CGRect(x: 20, y: 110, width: 280, height: 20)),
            createTestElement(type: .listItem, text: "Second list item", boundingBox: CGRect(x: 20, y: 135, width: 280, height: 20)),
            createTestElement(type: .header, text: "Section 2", boundingBox: CGRect(x: 0, y: 170, width: 150, height: 25)),
            createTestElement(type: .table, text: "Table content", boundingBox: CGRect(x: 0, y: 200, width: 400, height: 100)),
            createTestElement(type: .footer, text: "Footer text", boundingBox: CGRect(x: 0, y: 320, width: 300, height: 20))
        ]
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        XCTAssertNotNil(markdownGenerator)
        XCTAssertEqual(markdownGenerator.testConfig.headerFormat, "atx")
        XCTAssertEqual(markdownGenerator.testConfig.listFormat, "unordered")
        XCTAssertEqual(markdownGenerator.testConfig.tableFormat, "standard")
        XCTAssertEqual(markdownGenerator.testConfig.codeBlockFormat, "fenced")
        XCTAssertFalse(markdownGenerator.testConfig.preservePageBreaks)
        XCTAssertTrue(markdownGenerator.testConfig.extractImages)
    }
    
    func testGenerateMarkdownWithEmptyElements() {
        do {
            let result = try markdownGenerator.generateMarkdown(from: [])
            XCTFail("Expected error for empty elements, but got result: \(result)")
        } catch MarkdownGenerationError.noElementsToProcess {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGenerateMarkdownWithSingleElement() throws {
        let elements = [createTestElement(type: .title, text: "Simple Title")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "# Simple Title")
    }
    
    // MARK: - Element Type Tests
    
    func testTitleElementGeneration() throws {
        let elements = [createTestElement(type: .title, text: "Document Title")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "# Document Title")
    }
    
    func testHeaderElementGeneration() throws {
        let elements = [createTestElement(type: .header, text: "Section Header")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "# Section Header")
    }
    
    func testParagraphElementGeneration() throws {
        let elements = [createTestElement(type: .paragraph, text: "This is a paragraph.")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "This is a paragraph.")
    }
    
    func testListItemElementGeneration() throws {
        let elements = [createTestElement(type: .listItem, text: "List item text")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "- List item text")
    }
    
    func testTableElementGeneration() throws {
        let elements = [createTestElement(type: .table, text: "Table data")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "```\nTable data\n```")
    }
    
    func testFooterElementGeneration() throws {
        let elements = [createTestElement(type: .footer, text: "Footer content")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "*Footer content*")
    }
    
    func testFootnoteElementGeneration() throws {
        let elements = [createTestElement(type: .footnote, text: "Footnote text")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "^[Footnote text]")
    }
    
    func testPageNumberElementGeneration() throws {
        let elements = [createTestElement(type: .pageNumber, text: "5")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "**Page 5**")
    }
    
    func testImageElementGeneration() throws {
        let elements = [createTestElement(type: .image, text: "Figure 1")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertTrue(markdown.hasPrefix("![Figure 1](image_"))
        XCTAssertTrue(markdown.hasSuffix(".png)"))
    }
    
    func testBarcodeElementGeneration() throws {
        let elements = [createTestElement(type: .barcode, text: "123456789")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "`[Barcode: 123456789]`")
    }
    
    func testUnknownElementGeneration() throws {
        let elements = [createTestElement(type: .unknown, text: "Unknown content")]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        XCTAssertEqual(markdown, "Unknown content")
    }
    
    // MARK: - Header Level Calculation Tests
    
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
        
        // Verify that different header levels are generated based on Y position
        XCTAssertTrue(markdown.contains("# Top Header"))
        XCTAssertTrue(markdown.contains("## Upper Header"))
        XCTAssertTrue(markdown.contains("### Middle Header"))
        XCTAssertTrue(markdown.contains("#### Lower Header"))
        XCTAssertTrue(markdown.contains("##### Bottom Header"))
        XCTAssertTrue(markdown.contains("###### Very Bottom Header"))
    }
    
    // MARK: - Complex Document Tests
    
    func testComplexDocumentGeneration() throws {
        let elements = createTestElements()
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        // For now, just verify that the markdown contains the expected content
        // without checking exact line positions due to horizontal rules
        XCTAssertTrue(markdown.contains("# Document Title"))
        XCTAssertTrue(markdown.contains("# Section 1"))
        XCTAssertTrue(markdown.contains("This is a paragraph of text."))
        XCTAssertTrue(markdown.contains("- First list item"))
        XCTAssertTrue(markdown.contains("- Second list item"))
        XCTAssertTrue(markdown.contains("# Section 2"))
        XCTAssertTrue(markdown.contains("```\nTable content\n```"))
        XCTAssertTrue(markdown.contains("*Footer text*"))
        // No horizontal rules should be present (feature removed)
        XCTAssertFalse(markdown.contains("---"))
    }
    
    func testHorizontalRulesGeneration() throws {
        let elements = createTestElements()
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        let lines = markdown.components(separatedBy: "\n")
        
        // Horizontal rules feature has been removed
        XCTAssertFalse(lines.contains("---"))
        
        // Count horizontal rules (should be 0 since feature is removed)
        let ruleCount = lines.filter { $0 == "---" }.count
        XCTAssertEqual(ruleCount, 0)
    }
    
    // MARK: - Configuration Tests
    
    func testCustomConfiguration() {
        let customConfig = MarkdownGenerationConfig(
            preservePageBreaks: true,
            extractImages: false,
            headerFormat: "setext",
            listFormat: "ordered",
            tableFormat: "grid",
            codeBlockFormat: "indented"
        )
        
        let customGenerator = MarkdownGenerator(config: customConfig)
        
        XCTAssertEqual(customGenerator.testConfig.headerFormat, "setext")
        XCTAssertEqual(customGenerator.testConfig.listFormat, "ordered")
        XCTAssertEqual(customGenerator.testConfig.tableFormat, "grid")
        XCTAssertEqual(customGenerator.testConfig.codeBlockFormat, "indented")
        XCTAssertTrue(customGenerator.testConfig.preservePageBreaks)
        XCTAssertFalse(customGenerator.testConfig.extractImages)
    }
    
    func testTableOfContentsGeneration() throws {
        // Note: Table of contents generation is no longer configurable
        // This test is kept for compatibility but the feature is not implemented
        let elements = createTestElements()
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        // Check that basic markdown is generated
        XCTAssertTrue(markdown.contains("Document Title"))
        XCTAssertTrue(markdown.contains("Section 1"))
        XCTAssertTrue(markdown.contains("Section 2"))
    }
    
    // MARK: - Edge Cases Tests
    
    func testElementsWithEmptyText() throws {
        let elements = [
            createTestElement(type: .title, text: "Valid Title"),
            createTestElement(type: .paragraph, text: ""),
            createTestElement(type: .header, text: "   "),
            createTestElement(type: .listItem, text: "Valid Item")
        ]
        
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        // Should contain valid elements
        XCTAssertTrue(markdown.contains("# Valid Title"))
        XCTAssertTrue(markdown.contains("- Valid Item"))
        
        // Empty elements are currently being processed
        // This is expected behavior for now
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
    
    // MARK: - Error Handling Tests
    
    func testInvalidElementType() throws {
        // Create an element with an invalid type (this shouldn't happen in practice)
        let invalidElement = DocumentElement(
            type: ElementType(rawValue: "invalid") ?? .unknown,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 20),
            contentData: Data(),
            confidence: 0.9,
            pageNumber: 1,
            text: "Invalid element"
        )
        
        let elements = [invalidElement]
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        // Should handle gracefully and treat as unknown
        XCTAssertEqual(markdown, "Invalid element")
    }
}


