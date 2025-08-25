//
//  DocumentElement.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation
import Vision

// MARK: - Document Element Types

public enum ElementType: String, CaseIterable, Codable {
    case title = "title"
    case textBlock = "textBlock"
    case paragraph = "paragraph"
    case header = "header"
    case table = "table"
    case list = "list"
    case barcode = "barcode"
    case listItem = "listItem"
    case unknown = "unknown"
}

// MARK: - Document Element

public struct DocumentElement: Identifiable, Codable {
    public let id = UUID()
    public let type: ElementType
    public let boundingBox: CGRect
    public let content: String
    public let confidence: Float
    public let pageIndex: Int
    
    public init(
        type: ElementType,
        boundingBox: CGRect,
        content: String,
        confidence: Float,
        pageIndex: Int
    ) {
        self.type = type
        self.boundingBox = boundingBox
        self.content = content
        self.confidence = confidence
        self.pageIndex = pageIndex
    }
}

// MARK: - CGRect Extensions for Overlap Detection

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
    public func overlapsSignificantly(with other: CGRect, threshold: CGFloat = 0.1) -> Bool {
        return overlapPercentage(with: other) > threshold
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
}

// MARK: - Document Element Extensions

extension DocumentElement {
    /// Checks if this element overlaps with another element
    public func overlaps(with other: DocumentElement, threshold: CGFloat = 0.1) -> Bool {
        return boundingBox.overlapsSignificantly(with: other.boundingBox, threshold: threshold)
    }
    
    /// Calculates the overlap percentage with another element
    public func overlapPercentage(with other: DocumentElement) -> CGFloat {
        return boundingBox.overlapPercentage(with: other.boundingBox)
    }
    
    /// Checks if this element is positioned above another element
    public func isAbove(_ other: DocumentElement) -> Bool {
        return boundingBox.midY < other.boundingBox.midY
    }
    
    /// Checks if this element is positioned to the left of another element
    public func isLeftOf(_ other: DocumentElement) -> Bool {
        return boundingBox.midX < other.boundingBox.midX
    }
    
    /// Sorts elements by reading order (top to bottom, left to right)
    public static func sortByReadingOrder(_ elements: [DocumentElement]) -> [DocumentElement] {
        return elements.sorted { first, second in
            // First by Y position (top to bottom)
            if abs(first.boundingBox.midY - second.boundingBox.midY) > 10 {
                return first.boundingBox.midY < second.boundingBox.midY
            }
            // Then by X position (left to right)
            return first.boundingBox.midX < second.boundingBox.midX
        }
    }
}
