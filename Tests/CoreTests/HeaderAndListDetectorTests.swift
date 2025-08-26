import XCTest
import CoreGraphics
@testable import mdkitCore
@testable import mdkitConfiguration

final class HeaderAndListDetectorTests: XCTestCase {
    
    var detector: HeaderAndListDetector!
    var config: MDKitConfig!
    
    override func setUp() {
        super.setUp()
        let manager = ConfigurationManager()
        config = try! manager.loadConfigurationFromResources(fileName: "dev-config.json")
        detector = HeaderAndListDetector(config: config)
    }
    
    override func tearDown() {
        detector = nil
        config = nil
        super.tearDown()
    }
    
    // MARK: - Header Detection Tests
    
    func testHeaderDetectionEnabled() {
        XCTAssertTrue(config.headerDetection.enabled)
        XCTAssertTrue(config.headerDetection.enableHeaderMerging)
        XCTAssertTrue(config.headerDetection.enableLevelCalculation)
    }
    
    func testHeaderPatternsConfiguration() {
        let patterns = config.headerDetection.patterns
        
        // Test numbered headers
        XCTAssertFalse(patterns.numberedHeaders.isEmpty)
        XCTAssertTrue(patterns.numberedHeaders.contains("^\\d+(?:\\.\\d+)*\\s*$"))
        
        // Test lettered headers
        XCTAssertFalse(patterns.letteredHeaders.isEmpty)
        XCTAssertTrue(patterns.letteredHeaders.contains("^[A-Z](?:\\.\\d+)*\\s*$"))
        
        // Test Roman numeral headers
        XCTAssertFalse(patterns.romanHeaders.isEmpty)
        XCTAssertTrue(patterns.romanHeaders.contains("^[IVX]+(?:\\.\\d+)*\\s*$"))
        
        // Test named headers
        XCTAssertFalse(patterns.namedHeaders.isEmpty)
        XCTAssertTrue(patterns.namedHeaders.contains("^(Chapter|Section|Part|章节|部分)\\s+\\d+(?:\\.\\d+)*\\s*$"))
    }
    
    func testHeaderLevelCalculation() {
        let levelConfig = config.headerDetection.levelCalculation
        
        XCTAssertTrue(levelConfig.autoCalculate)
        XCTAssertEqual(levelConfig.maxLevel, 6)
        XCTAssertEqual(levelConfig.customLevels["Part"], 1)
        XCTAssertEqual(levelConfig.customLevels["Chapter"], 2)
        XCTAssertEqual(levelConfig.customLevels["Section"], 3)
    }
    
    func testHeaderDetectionWithNumberedPattern() {
        let element = createMockElement(text: "1. Introduction", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        XCTAssertTrue(result.isHeader)
        XCTAssertEqual(result.level, 2) // 1 + markdownLevelOffset
        XCTAssertEqual(result.pattern, "Numbered")
        XCTAssertGreaterThan(result.confidence, 0.7)
    }
    
    func testHeaderDetectionWithLetteredPattern() {
        let element = createMockElement(text: "A. Background", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        XCTAssertTrue(result.isHeader)
        XCTAssertEqual(result.level, 2) // 1 + markdownLevelOffset
        XCTAssertEqual(result.pattern, "Lettered")
        XCTAssertGreaterThan(result.confidence, 0.7)
    }
    
    func testHeaderDetectionWithNamedPattern() {
        let element = createMockElement(text: "Chapter 1", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        XCTAssertTrue(result.isHeader)
        XCTAssertEqual(result.level, 3) // 2 + markdownLevelOffset (Chapter = 2)
        XCTAssertEqual(result.pattern, "Named")
        XCTAssertGreaterThan(result.confidence, 0.8)
    }
    
    func testHeaderDetectionWithContentBasedPattern() {
        let element = createMockElement(text: "INTRODUCTION", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        XCTAssertTrue(result.isHeader)
        XCTAssertEqual(result.level, 1)
        XCTAssertEqual(result.pattern, "AllCaps")
        XCTAssertGreaterThan(result.confidence, 0.6)
    }
    
    func testHeaderDetectionDisabled() {
        let disabledConfig = MDKitConfig(
            headerDetection: HeaderDetectionConfig(enabled: false)
        )
        let disabledDetector = HeaderAndListDetector(config: disabledConfig)
        
        let element = createMockElement(text: "1. Introduction", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = disabledDetector.detectHeader(in: element)
        
        XCTAssertFalse(result.isHeader)
    }
    
    // MARK: - List Detection Tests
    
    func testListDetectionEnabled() {
        XCTAssertTrue(config.listDetection.enabled)
        XCTAssertTrue(config.listDetection.enableListItemMerging)
        XCTAssertTrue(config.listDetection.enableLevelCalculation)
        XCTAssertTrue(config.listDetection.enableNestedLists)
    }
    
    func testListPatternsConfiguration() {
        let patterns = config.listDetection.patterns
        
        // Test numbered markers
        XCTAssertFalse(patterns.numberedMarkers.isEmpty)
        XCTAssertTrue(patterns.numberedMarkers.contains("^\\d+\\.\\s*$"))
        
        // Test lettered markers
        XCTAssertFalse(patterns.letteredMarkers.isEmpty)
        XCTAssertTrue(patterns.letteredMarkers.contains("^[a-z]\\.\\s*$"))
        
        // Test bullet markers
        XCTAssertFalse(patterns.bulletMarkers.isEmpty)
        XCTAssertTrue(patterns.bulletMarkers.contains("^[•\\-\\*]\\s*$"))
        
        // Test Roman numeral markers
        XCTAssertFalse(patterns.romanMarkers.isEmpty)
        XCTAssertTrue(patterns.romanMarkers.contains("^[ivx]+\\.\\s*$"))
        
        // Test custom markers
        XCTAssertFalse(patterns.customMarkers.isEmpty)
        XCTAssertTrue(patterns.customMarkers.contains("^[\\u25A0\\u25A1\\u25A2]\\s*$"))
    }
    
    func testListIndentationConfiguration() {
        let indentation = config.listDetection.indentation
        
        XCTAssertEqual(indentation.baseIndentation, 60.0)
        XCTAssertEqual(indentation.levelThreshold, 25.0)
        XCTAssertTrue(indentation.enableXCoordinateAnalysis)
    }
    
    func testListItemDetectionWithNumberedMarker() {
        let element = createMockElement(text: "1. First item", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectListItem(in: element)
        
        XCTAssertTrue(result.isListItem)
        XCTAssertEqual(result.level, 1)
        XCTAssertEqual(result.marker, "1. ")
        XCTAssertGreaterThan(result.confidence, 0.7)
    }
    
    func testListItemDetectionWithBulletMarker() {
        let element = createMockElement(text: "• Bullet point", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectListItem(in: element)
        
        XCTAssertTrue(result.isListItem)
        XCTAssertEqual(result.level, 1)
        XCTAssertEqual(result.marker, "• ")
        XCTAssertGreaterThan(result.confidence, 0.8)
    }
    
    func testListItemDetectionWithLetteredMarker() {
        let element = createMockElement(text: "a. Lettered item", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectListItem(in: element)
        
        XCTAssertTrue(result.isListItem)
        XCTAssertEqual(result.level, 1)
        XCTAssertEqual(result.marker, "a. ")
        XCTAssertGreaterThan(result.confidence, 0.7)
    }
    
    func testListItemDetectionWithContentBasedPattern() {
        let element = createMockElement(text: "- Short text", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectListItem(in: element)
        
        XCTAssertTrue(result.isListItem)
        XCTAssertEqual(result.level, 1)
        XCTAssertEqual(result.marker, "- ")
        XCTAssertGreaterThan(result.confidence, 0.8)
    }
    
    func testListItemDetectionDisabled() {
        let disabledConfig = MDKitConfig(
            listDetection: ListDetectionConfig(enabled: false)
        )
        let disabledDetector = HeaderAndListDetector(config: disabledConfig)
        
        let element = createMockElement(text: "1. First item", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = disabledDetector.detectListItem(in: element)
        
        XCTAssertFalse(result.isListItem)
    }
    
    // MARK: - Configuration Tests
    
    func testHeaderFooterDetectionConfiguration() {
        let headerFooterConfig = config.headerFooterDetection
        
        XCTAssertTrue(headerFooterConfig.enabled)
        XCTAssertEqual(headerFooterConfig.headerFrequencyThreshold, 0.6)
        XCTAssertEqual(headerFooterConfig.footerFrequencyThreshold, 0.6)
        XCTAssertTrue(headerFooterConfig.regionBasedDetection.enabled)
        XCTAssertTrue(headerFooterConfig.percentageBasedDetection.enabled)
        XCTAssertTrue(headerFooterConfig.smartDetection.enabled)
        XCTAssertFalse(headerFooterConfig.multiRegionDetection.enabled)
    }
    
    func testSmartDetectionConfiguration() {
        let smartConfig = config.headerFooterDetection.smartDetection
        
        XCTAssertTrue(smartConfig.excludePageNumbers)
        XCTAssertFalse(smartConfig.excludeCommonHeaders.isEmpty)
        XCTAssertFalse(smartConfig.excludeCommonFooters.isEmpty)
        XCTAssertTrue(smartConfig.enableContentAnalysis)
        XCTAssertEqual(smartConfig.minHeaderFooterLength, 2)
        XCTAssertEqual(smartConfig.maxHeaderFooterLength, 150)
    }
    
    // MARK: - Helper Methods
    
    private func createMockElement(text: String, boundingBox: CGRect) -> DocumentElement {
        return DocumentElement(
            type: .paragraph,
            boundingBox: boundingBox,
            contentData: Data(),
            confidence: 0.9,
            pageNumber: 1,
            text: text,
            metadata: [:]
        )
    }
}
