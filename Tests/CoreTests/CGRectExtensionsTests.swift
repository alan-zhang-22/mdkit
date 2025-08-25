import XCTest
import CoreGraphics
@testable import mdkitCore

final class CGRectExtensionsTests: XCTestCase {
    
    // MARK: - Test Data
    
    let rect1 = CGRect(x: 100, y: 100, width: 100, height: 100)
    let rect2 = CGRect(x: 150, y: 150, width: 100, height: 100)
    let rect3 = CGRect(x: 300, y: 300, width: 100, height: 100)
    let rect4 = CGRect(x: 50, y: 50, width: 50, height: 50)
    
    // MARK: - Overlap Tests
    
    func testOverlapArea() {
        // rect1: (100,100,100,100), rect2: (150,150,100,100)
        // rect1 ends at x=200, y=200, rect2 starts at x=150, y=150
        // So they overlap by 50x50 = 2500
        let overlapArea = rect1.overlapArea(with: rect2)
        XCTAssertEqual(overlapArea, 2500)
        
        // rect1 and rect3 don't overlap
        let noOverlapArea = rect1.overlapArea(with: rect3)
        XCTAssertEqual(noOverlapArea, 0)
        
        // rect1: (100,100,100,100), rect4: (50,50,50,50)
        // rect1 starts at x=100, y=100, rect4 ends at x=100, y=100
        // They share a corner point, so overlap is 0 (but they do intersect)
        let overlapArea2 = rect1.overlapArea(with: rect4)
        XCTAssertEqual(overlapArea2, 0)
    }
    
    func testOverlapPercentage() {
        // rect1 area = 10000, overlap with rect2 = 2500, so 25%
        let overlapPercentage = rect1.overlapPercentage(with: rect2)
        XCTAssertEqual(overlapPercentage, 0.25)
        
        // rect1 and rect3 don't overlap
        let noOverlapPercentage = rect1.overlapPercentage(with: rect3)
        XCTAssertEqual(noOverlapPercentage, 0)
        
        // rect1 area = 10000, overlap with rect4 = 0, so 0%
        let overlapPercentage2 = rect1.overlapPercentage(with: rect4)
        XCTAssertEqual(overlapPercentage2, 0)
    }
    
    func testOverlaps() {
        // rect1 and rect2 overlap by 25%
        XCTAssertTrue(rect1.overlaps(with: rect2, threshold: 0.2))
        XCTAssertFalse(rect1.overlaps(with: rect2, threshold: 0.3))
        
        // rect1 and rect3 don't overlap
        XCTAssertFalse(rect1.overlaps(with: rect3, threshold: 0.1))
        
        // rect1 and rect4 share a corner point, so they don't overlap significantly
        XCTAssertFalse(rect1.overlaps(with: rect4, threshold: 0.1))
    }
    
    // MARK: - Center and Distance Tests
    
    func testCenter() {
        let center = rect1.center
        XCTAssertEqual(center.x, 150) // 100 + 100/2
        XCTAssertEqual(center.y, 150) // 100 + 100/2
    }
    
    func testDistanceToCenter() {
        let distance = rect1.distanceToCenter(of: rect2)
        // rect1 center: (150, 150), rect2 center: (200, 200)
        // dx = 200 - 150 = 50, dy = 200 - 150 = 50
        // distance = sqrt(50² + 50²) = sqrt(2500 + 2500) = sqrt(5000) = 70.71
        let expectedDistance = sqrt(5000)
        XCTAssertEqual(distance, expectedDistance, accuracy: 0.1)
    }
    
    func testMinimumDistance() {
        // rect1 and rect2 overlap, so distance is 0
        XCTAssertEqual(rect1.minimumDistance(to: rect2), 0)
        
        // rect1 and rect3 don't overlap
        let distance = rect1.minimumDistance(to: rect3)
        XCTAssertEqual(distance, 100) // 300 - (100 + 100)
        
        // rect1 and rect4 overlap, so distance is 0
        XCTAssertEqual(rect1.minimumDistance(to: rect4), 0)
    }
    
    func testMergeDistance() {
        // rect1 and rect2 overlap, so merge distance is 0
        XCTAssertEqual(rect1.mergeDistance(to: rect2), 0)
        
        // rect1 and rect3 don't overlap
        let distance = rect1.mergeDistance(to: rect3)
        XCTAssertEqual(distance, 100)
    }
    
    // MARK: - Position Tests
    
    func testIsAbove() {
        let topRect = CGRect(x: 100, y: 50, width: 100, height: 50)
        let bottomRect = CGRect(x: 100, y: 200, width: 100, height: 50)
        
        XCTAssertTrue(topRect.isAbove(bottomRect))
        XCTAssertFalse(bottomRect.isAbove(topRect))
        
        // Test with tolerance - rect1 center is at y=150, closeRect center is at y=130
        // rect1 should be below closeRect since 150 > 130
        let closeRect = CGRect(x: 100, y: 105, width: 100, height: 50)
        XCTAssertFalse(rect1.isAbove(closeRect, tolerance: 10))  // rect1 is below closeRect
        XCTAssertFalse(rect1.isAbove(closeRect, tolerance: 5))   // rect1 is below closeRect
        
        // Test that rect1 is above rect2
        // rect1 center: y=150, rect2 center: y=200
        // 150 < 200, so rect1 is above rect2
        XCTAssertTrue(rect1.isAbove(rect2))
        
        // Test with a rectangle that's clearly above rect1
        let aboveRect = CGRect(x: 100, y: 50, width: 100, height: 50)
        XCTAssertTrue(aboveRect.isAbove(rect1))
        XCTAssertFalse(rect1.isAbove(aboveRect))
        
        // Test edge case: rectangles with same Y position
        let sameYRect = CGRect(x: 200, y: 100, width: 100, height: 100)
        XCTAssertFalse(rect1.isAbove(sameYRect))  // Same Y position, not above
        XCTAssertFalse(sameYRect.isAbove(rect1))  // Same Y position, not above
    }
    
    func testIsBelow() {
        let topRect = CGRect(x: 100, y: 50, width: 100, height: 50)
        let bottomRect = CGRect(x: 100, y: 200, width: 100, height: 50)
        
        XCTAssertTrue(bottomRect.isBelow(topRect))
        XCTAssertFalse(topRect.isBelow(bottomRect))
    }
    
    func testIsLeftOf() {
        let leftRect = CGRect(x: 50, y: 100, width: 50, height: 100)
        let rightRect = CGRect(x: 200, y: 100, width: 50, height: 100)
        
        XCTAssertTrue(leftRect.isLeftOf(rightRect))
        XCTAssertFalse(rightRect.isLeftOf(leftRect))
    }
    
    func testIsRightOf() {
        let leftRect = CGRect(x: 50, y: 100, width: 50, height: 100)
        let rightRect = CGRect(x: 200, y: 100, width: 50, height: 100)
        
        XCTAssertTrue(rightRect.isRightOf(leftRect))
        XCTAssertFalse(leftRect.isRightOf(rightRect))
    }
    
    // MARK: - Alignment Tests
    
    func testIsVerticallyAligned() {
        let alignedRect = CGRect(x: 200, y: 100, width: 100, height: 100)
        
        // rect1 is at y=100, alignedRect is at y=100, so they are vertically aligned
        XCTAssertTrue(rect1.isVerticallyAligned(with: alignedRect, tolerance: 10))
        XCTAssertTrue(rect1.isVerticallyAligned(with: alignedRect, tolerance: 5))
        
        let notAlignedRect = CGRect(x: 200, y: 200, width: 100, height: 100)
        XCTAssertFalse(rect1.isVerticallyAligned(with: notAlignedRect, tolerance: 10))
    }
    
    func testIsHorizontallyAligned() {
        let alignedRect = CGRect(x: 100, y: 200, width: 100, height: 100)
        
        // rect1 is at x=100, alignedRect is at x=100, so they are horizontally aligned
        XCTAssertTrue(rect1.isHorizontallyAligned(with: alignedRect, tolerance: 10))
        XCTAssertTrue(rect1.isHorizontallyAligned(with: alignedRect, tolerance: 5))
        
        let notAlignedRect = CGRect(x: 200, y: 200, width: 100, height: 100)
        XCTAssertFalse(rect1.isHorizontallyAligned(with: notAlignedRect, tolerance: 10))
    }
    
    // MARK: - Gap Tests
    
    func testVerticalGap() {
        let topRect = CGRect(x: 100, y: 50, width: 100, height: 50)
        let bottomRect = CGRect(x: 100, y: 200, width: 100, height: 50)
        
        // Gap between topRect (ends at y=100) and bottomRect (starts at y=200)
        XCTAssertEqual(topRect.verticalGap(to: bottomRect), 100)
        XCTAssertEqual(bottomRect.verticalGap(to: topRect), 100)
        
        // Overlapping rectangles have no gap
        XCTAssertEqual(rect1.verticalGap(to: rect2), 0)
    }
    
    func testHorizontalGap() {
        let leftRect = CGRect(x: 50, y: 100, width: 50, height: 100)
        let rightRect = CGRect(x: 200, y: 100, width: 50, height: 100)
        
        // Gap between leftRect (ends at x=100) and rightRect (starts at x=200)
        XCTAssertEqual(leftRect.horizontalGap(to: rightRect), 100)
        XCTAssertEqual(rightRect.horizontalGap(to: leftRect), 100)
        
        // Overlapping rectangles have no gap
        XCTAssertEqual(rect1.horizontalGap(to: rect2), 0)
    }
    
    // MARK: - Rectangle Operations Tests
    
    func testUnion() {
        let unionRect = rect1.union(with: rect2)
        
        // Union should encompass both rectangles
        XCTAssertEqual(unionRect.minX, 100)
        XCTAssertEqual(unionRect.minY, 100)
        XCTAssertEqual(unionRect.maxX, 250)
        XCTAssertEqual(unionRect.maxY, 250)
    }
    
    func testIntersection() {
        let intersectionRect = rect1.intersection(with: rect2)
        
        // Intersection should be the overlapping area
        XCTAssertEqual(intersectionRect.minX, 150)
        XCTAssertEqual(intersectionRect.minY, 150)
        XCTAssertEqual(intersectionRect.maxX, 200)
        XCTAssertEqual(intersectionRect.maxY, 200)
    }
    
    func testExpanded() {
        let expandedRect = rect1.expanded(by: 10)
        
        XCTAssertEqual(expandedRect.minX, 90)
        XCTAssertEqual(expandedRect.minY, 90)
        XCTAssertEqual(expandedRect.width, 120)
        XCTAssertEqual(expandedRect.height, 120)
    }
    
    func testContracted() {
        let contractedRect = rect1.contracted(by: 10)
        
        XCTAssertEqual(contractedRect.minX, 110)
        XCTAssertEqual(contractedRect.minY, 110)
        XCTAssertEqual(contractedRect.width, 80)
        XCTAssertEqual(contractedRect.height, 80)
    }
    
    func testContractedWithZeroWidth() {
        let smallRect = CGRect(x: 100, y: 100, width: 20, height: 20)
        let contractedRect = smallRect.contracted(by: 15)
        
        // Width and height should not go below 0
        // 20 - (15 * 2) = 20 - 30 = -10, but clamped to 0
        XCTAssertEqual(contractedRect.width, 0)
        XCTAssertEqual(contractedRect.height, 0)
        
        // Test with a smaller contraction that doesn't go below 0
        let smallContraction = smallRect.contracted(by: 5)
        XCTAssertEqual(smallContraction.width, 10) // 20 - (5 * 2) = 10
        XCTAssertEqual(smallContraction.height, 10)
        
        // Test with a contraction that goes exactly to 0
        let exactContraction = smallRect.contracted(by: 10)
        XCTAssertEqual(exactContraction.width, 0) // 20 - (10 * 2) = 0
        XCTAssertEqual(exactContraction.height, 0)
    }
    
    // MARK: - Property Tests
    
    func testArea() {
        XCTAssertEqual(rect1.area, 10000) // 100 * 100
        XCTAssertEqual(rect2.area, 10000) // 100 * 100
        XCTAssertEqual(rect4.area, 2500)  // 50 * 50
    }
    
    func testPerimeter() {
        XCTAssertEqual(rect1.perimeter, 400) // 2 * (100 + 100)
        XCTAssertEqual(rect2.perimeter, 400) // 2 * (100 + 100)
        XCTAssertEqual(rect4.perimeter, 200) // 2 * (50 + 50)
    }
    
    func testAspectRatio() {
        XCTAssertEqual(rect1.aspectRatio, 1.0) // 100/100 = 1
        XCTAssertEqual(rect4.aspectRatio, 1.0) // 50/50 = 1
        
        let wideRect = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertEqual(wideRect.aspectRatio, 2.0) // 200/100 = 2
        
        let tallRect = CGRect(x: 0, y: 0, width: 100, height: 200)
        XCTAssertEqual(tallRect.aspectRatio, 0.5) // 100/200 = 0.5
    }
    
    func testAspectRatioWithZeroHeight() {
        let zeroHeightRect = CGRect(x: 0, y: 0, width: 100, height: 0)
        XCTAssertEqual(zeroHeightRect.aspectRatio, 0)
    }
    
    // MARK: - Shape Tests
    
    func testIsSquare() {
        XCTAssertTrue(rect1.isSquare) // 100x100
        XCTAssertTrue(rect4.isSquare) // 50x50
        
        let wideRect = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertFalse(wideRect.isSquare)
        
        let tallRect = CGRect(x: 0, y: 0, width: 100, height: 200)
        XCTAssertFalse(tallRect.isSquare)
        
        let almostSquareRect = CGRect(x: 0, y: 0, width: 99, height: 101)
        XCTAssertTrue(almostSquareRect.isSquare) // Within 10% tolerance
    }
    
    func testIsWide() {
        let wideRect = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertTrue(wideRect.isWide) // 2.0 > 1.2
        
        XCTAssertFalse(rect1.isWide) // 1.0 <= 1.2
        XCTAssertFalse(rect4.isWide) // 1.0 <= 1.2
    }
    
    func testIsTall() {
        let tallRect = CGRect(x: 0, y: 0, width: 100, height: 200)
        XCTAssertTrue(tallRect.isTall) // 0.5 < 0.8
        
        XCTAssertFalse(rect1.isTall) // 1.0 >= 0.8
        XCTAssertFalse(rect4.isTall) // 1.0 >= 0.8
    }
    
    // MARK: - Edge Cases
    
    func testEmptyRectangle() {
        let emptyRect = CGRect.zero
        
        XCTAssertEqual(emptyRect.area, 0)
        XCTAssertEqual(emptyRect.perimeter, 0)
        XCTAssertEqual(emptyRect.aspectRatio, 0)
        // An empty rectangle (0x0) is technically square
        XCTAssertTrue(emptyRect.isSquare)
        XCTAssertFalse(emptyRect.isWide)
        XCTAssertFalse(emptyRect.isTall)
        
        // Test that empty rectangle properties work correctly
        XCTAssertEqual(emptyRect.center, CGPoint.zero)
        XCTAssertEqual(emptyRect.minimumDistance(to: CGRect.zero), 0)
        
        // Test that empty rectangle doesn't cause issues with other operations
        let normalRect = CGRect(x: 100, y: 100, width: 100, height: 100)
        // Empty rectangle is at (0,0), normal rectangle is at (100,100)
        // Distance should be the distance from (0,0) to (100,100)
        XCTAssertEqual(emptyRect.minimumDistance(to: normalRect), 100)
    }
    
    func testNegativeDimensions() {
        let negativeRect = CGRect(x: 100, y: 100, width: -50, height: -50)
        
        XCTAssertEqual(negativeRect.area, 2500) // |-50| * |-50|
        XCTAssertEqual(negativeRect.perimeter, 200) // 2 * (|-50| + |-50|)
        XCTAssertEqual(negativeRect.aspectRatio, 1.0) // |-50| / |-50|
    }
}
