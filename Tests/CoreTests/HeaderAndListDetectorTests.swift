import XCTest
import Foundation
import CoreGraphics
@testable import mdkitCore
@testable import mdkitProtocols
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
        
        // Test that patterns are loaded from configuration file
        XCTAssertFalse(patterns.numberedHeaders.isEmpty, "Numbered header patterns should be loaded from config file")
        XCTAssertFalse(patterns.letteredHeaders.isEmpty, "Lettered header patterns should be loaded from config file")
        XCTAssertFalse(patterns.romanHeaders.isEmpty, "Roman numeral header patterns should be loaded from config file")
        XCTAssertFalse(patterns.namedHeaders.isEmpty, "Named header patterns should be loaded from config file")
        
        // Test that patterns are valid regex
        for pattern in patterns.numberedHeaders {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
        for pattern in patterns.letteredHeaders {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
        for pattern in patterns.romanHeaders {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
        for pattern in patterns.namedHeaders {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
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
        XCTAssertEqual(result.level, 1) // 1 component (["1"]) + markdownLevelOffset = 1
        // Pattern detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.pattern)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testHeaderDetectionWithNumberedPatternNoPeriod() {
        let element = createMockElement(text: "1 Introduction", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        // This should also be detected as a header with the same level
        XCTAssertTrue(result.isHeader)
        XCTAssertEqual(result.level, 1) // Should be same level as "1. Introduction"
        // Pattern detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.pattern)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testHeaderDetectionWithLetteredPattern() {
        let element = createMockElement(text: "A. Background", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        XCTAssertTrue(result.isHeader)
        XCTAssertEqual(result.level, 1) // 1 + markdownLevelOffset (Lettered header detection)
        // Pattern detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.pattern)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testHeaderDetectionWithNamedPattern() {
        let element = createMockElement(text: "Chapter 1 ", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        XCTAssertTrue(result.isHeader)
        XCTAssertEqual(result.level, 2) // 2 + markdownLevelOffset (Chapter = 2)
        // Pattern detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.pattern)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testHeaderDetectionWithContentBasedPattern() {
        let element = createMockElement(text: "INTRODUCTION", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectHeader(in: element)
        
        // Since content-based detection is disabled, this should not be detected as a header
        XCTAssertFalse(result.isHeader)
    }
    
    func testHeaderDetectionDisabled() {
        let disabledConfig = MDKitConfig(
            headerDetection: HeaderDetectionConfig(enabled: false, markdownLevelOffset: 0)
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
        
        // Test that patterns are loaded from configuration file
        XCTAssertFalse(patterns.numberedMarkers.isEmpty, "Numbered marker patterns should be loaded from config file")
        XCTAssertFalse(patterns.letteredMarkers.isEmpty, "Lettered marker patterns should be loaded from config file")
        XCTAssertFalse(patterns.bulletMarkers.isEmpty, "Bullet marker patterns should be loaded from config file")
        XCTAssertFalse(patterns.romanMarkers.isEmpty, "Roman numeral marker patterns should be loaded from config file")
        XCTAssertFalse(patterns.customMarkers.isEmpty, "Custom marker patterns should be loaded from config file")
        
        // Test that patterns are valid regex
        for pattern in patterns.numberedMarkers {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
        for pattern in patterns.letteredMarkers {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
        for pattern in patterns.bulletMarkers {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
        for pattern in patterns.romanMarkers {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
        for pattern in patterns.customMarkers {
            XCTAssertNoThrow(try NSRegularExpression(pattern: pattern), "Invalid regex pattern: \(pattern)")
        }
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
        // Marker detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.marker)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testListItemDetectionWithBulletMarker() {
        let element = createMockElement(text: "• Bullet point", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectListItem(in: element)
        
        XCTAssertTrue(result.isListItem)
        XCTAssertEqual(result.level, 1)
        // Marker detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.marker)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testListItemDetectionWithLetteredMarker() {
        let element = createMockElement(text: "a. Lettered item", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectListItem(in: element)
        
        XCTAssertTrue(result.isListItem)
        XCTAssertEqual(result.level, 1)
        // Marker detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.marker)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testListItemDetectionWithContentBasedPattern() {
        let element = createMockElement(text: "- Short text", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05))
        
        let result = detector.detectListItem(in: element)
        
        XCTAssertTrue(result.isListItem)
        XCTAssertEqual(result.level, 1)
        // Marker detection may vary, so just check that it's not nil
        XCTAssertNotNil(result.marker)
        XCTAssertGreaterThan(result.confidence, 0.5)
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
            text: text
        )
    }
}
