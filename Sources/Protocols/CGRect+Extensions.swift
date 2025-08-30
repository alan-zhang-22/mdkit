import Foundation
import CoreGraphics

// MARK: - CGRect Extensions for Document Processing

extension CGRect {
    /// Calculates the overlap area between two rectangles
    public func overlapArea(with other: CGRect) -> CGFloat {
        let intersection = self.intersection(other)
        return intersection.width * intersection.height
    }
    
    /// Calculates the overlap percentage relative to this rectangle
    public func overlapPercentage(with other: CGRect) -> CGFloat {
        let overlap = overlapArea(with: other)
        let selfArea = width * height
        return selfArea > 0 ? overlap / selfArea : 0
    }
    
    /// Checks if two rectangles overlap significantly
    public func overlaps(with other: CGRect, threshold: Float) -> Bool {
        let percentage = overlapPercentage(with: other)
        return percentage > CGFloat(threshold)
    }
    
    /// Calculates the center point of the rectangle
    public var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    /// Calculates the distance between centers of two rectangles
    public func distanceToCenter(of other: CGRect) -> CGFloat {
        let selfCenter = self.center
        let otherCenter = other.center
        let dx = selfCenter.x - otherCenter.x
        let dy = selfCenter.y - otherCenter.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculates the minimum distance between two rectangles
    public func minimumDistance(to other: CGRect) -> CGFloat {
        // If rectangles overlap, distance is 0
        if self.intersects(other) {
            return 0
        }
        
        // Calculate minimum distance between edges
        let leftDistance = other.minX - self.maxX
        let rightDistance = self.minX - other.maxX
        let topDistance = other.minY - self.maxY
        let bottomDistance = self.minY - other.maxY
        
        // Find the minimum non-negative distance
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        if leftDistance > 0 { minDistance = min(minDistance, leftDistance) }
        if rightDistance > 0 { minDistance = min(minDistance, rightDistance) }
        if topDistance > 0 { minDistance = min(minDistance, topDistance) }
        if bottomDistance > 0 { minDistance = min(minDistance, bottomDistance) }
        
        // If no positive distances found, rectangles are adjacent
        if minDistance == CGFloat.greatestFiniteMagnitude {
            return 0
        }
        
        return minDistance
    }
    
    /// Calculates the merge distance for combining elements
    public func mergeDistance(to other: CGRect) -> Float {
        return Float(minimumDistance(to: other))
    }
    
    /// Checks if this rectangle is positioned above another rectangle
    public func isAbove(_ other: CGRect, tolerance: CGFloat = 5.0) -> Bool {
        return abs(self.midY - other.midY) > tolerance && self.midY < other.midY
    }
    
    /// Checks if this rectangle is positioned below another rectangle
    public func isBelow(_ other: CGRect, tolerance: CGFloat = 5.0) -> Bool {
        return abs(self.midY - other.midY) > tolerance && self.midY > other.midY
    }
    
    /// Checks if this rectangle is positioned to the left of another rectangle
    public func isLeftOf(_ other: CGRect, tolerance: CGFloat = 5.0) -> Bool {
        return abs(self.midX - other.midX) > tolerance && self.midX < other.midX
    }
    
    /// Checks if this rectangle is positioned to the right of another rectangle
    public func isRightOf(_ other: CGRect, tolerance: CGFloat = 5.0) -> Bool {
        return abs(self.midX - other.midX) > tolerance && self.midX > other.midX
    }
    
    /// Checks if two rectangles are vertically aligned (similar Y positions)
    public func isVerticallyAligned(with other: CGRect, tolerance: CGFloat = 10.0) -> Bool {
        return abs(self.midY - other.midY) <= tolerance
    }
    
    /// Checks if two rectangles are horizontally aligned (similar X positions)
    public func isHorizontallyAligned(with other: CGRect, tolerance: CGFloat = 10.0) -> Bool {
        return abs(self.midX - other.midX) <= tolerance
    }
    
    /// Calculates the vertical gap between two rectangles
    public func verticalGap(to other: CGRect) -> CGFloat {
        if self.maxY < other.minY {
            return other.minY - self.maxY
        } else if other.maxY < self.minY {
            return self.minY - other.maxY
        }
        return 0 // Overlapping or adjacent
    }
    
    /// Calculates the horizontal gap between two rectangles
    public func horizontalGap(to other: CGRect) -> CGFloat {
        if self.maxX < other.minX {
            return other.minX - self.maxX
        } else if other.maxX < self.minX {
            return self.minX - other.maxX
        }
        return 0 // Overlapping or adjacent
    }
    
    /// Creates a new rectangle that encompasses both this rectangle and another
    public func union(with other: CGRect) -> CGRect {
        return self.union(other)
    }
    
    /// Creates a new rectangle that represents the intersection of this rectangle and another
    public func intersection(with other: CGRect) -> CGRect {
        return self.intersection(other)
    }
    
    /// Expands the rectangle by the specified amount on all sides
    public func expanded(by amount: CGFloat) -> CGRect {
        return CGRect(
            x: minX - amount,
            y: minY - amount,
            width: width + (amount * 2),
            height: height + (amount * 2)
        )
    }
    
    /// Contracts the rectangle by the specified amount on all sides
    public func contracted(by amount: CGFloat) -> CGRect {
        return CGRect(
            x: minX + amount,           // Move right
            y: minY + amount,           // Move down
            width: max(0, width - (amount * 2)),  // Reduce width
            height: max(0, height - (amount * 2)) // Reduce height
        )
    }
    
    /// Returns the area of the rectangle
    public var area: CGFloat {
        return width * height
    }
    
    /// Returns the perimeter of the rectangle
    public var perimeter: CGFloat {
        return 2 * (width + height)
    }
    
    /// Returns the aspect ratio (width / height)
    public var aspectRatio: CGFloat {
        return height > 0 ? width / height : 0
    }
    
    /// Checks if this rectangle is approximately square
    public var isSquare: Bool {
        // Handle empty rectangles
        if width == 0 && height == 0 {
            return true  // Empty rectangle is technically square
        }
        if width == 0 || height == 0 {
            return false // Line segments are not square
        }
        let ratio = aspectRatio
        return ratio >= 0.9 && ratio <= 1.1
    }
    
    /// Checks if this rectangle is wider than it is tall
    public var isWide: Bool {
        // Handle empty rectangles
        if width == 0 || height == 0 {
            return false
        }
        return aspectRatio > 1.2
    }
    
    /// Checks if this rectangle is taller than it is wide
    public var isTall: Bool {
        // Handle empty rectangles
        if width == 0 || height == 0 {
            return false
        }
        return aspectRatio < 0.8
    }
}
