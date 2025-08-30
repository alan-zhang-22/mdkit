import Foundation
import CoreGraphics
import Logging
import mdkitConfiguration
import mdkitProtocols

// MARK: - Header and List Detection Error

public enum HeaderListDetectionError: LocalizedError {
    case invalidPattern(String)
    case unsupportedElementType
    case mergeFailure(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPattern(let pattern):
            return "Invalid detection pattern: \(pattern)"
        case .unsupportedElementType:
            return "Element type not supported for header/list detection"
        case .mergeFailure(let reason):
            return "Failed to merge elements: \(reason)"
        }
    }
}

// MARK: - Header Detection Result

public struct HeaderDetectionResult {
    public let isHeader: Bool
    public let level: Int
    public let confidence: Float
    public let pattern: String?
    
    public init(isHeader: Bool, level: Int = 1, confidence: Float = 0.0, pattern: String? = nil) {
        self.isHeader = isHeader
        self.level = level
        self.confidence = confidence
        self.pattern = pattern
    }
}

// MARK: - List Item Detection Result

public struct ListItemDetectionResult {
    public let isListItem: Bool
    public let level: Int
    public let marker: String?
    public let confidence: Float
    
    public init(isListItem: Bool, level: Int = 1, marker: String? = nil, confidence: Float = 0.0) {
        self.isListItem = isListItem
        self.level = level
        self.marker = marker
        self.confidence = confidence
    }
}

// MARK: - Header and List Detector

public class HeaderAndListDetector {
    private let logger: Logger
    private let config: MDKitConfig
    
    public init(config: MDKitConfig) {
        self.config = config
        self.logger = Logger(label: "HeaderAndListDetector")
    }
    
    // MARK: - Header Detection
    
    /// Detects if an element is a header based on content patterns and position
    public func detectHeader(in element: DocumentElement) -> HeaderDetectionResult {
        guard let text = element.text, !text.isEmpty else {
            return HeaderDetectionResult(isHeader: false)
        }
        
        // Check if header detection is enabled
        guard config.headerDetection.enabled else {
            return HeaderDetectionResult(isHeader: false)
        }
        
        // Check if element is in header region (already handled by UnifiedDocumentProcessor)
        if element.type == .header {
            return HeaderDetectionResult(isHeader: true, level: 1, confidence: 0.9)
        }
        
        // Pattern-based header detection using configuration
        let patternResult = detectHeaderPattern(in: text)
        if patternResult.isHeader {
            return patternResult
        }
        
        // Content-based header detection
        let contentResult = detectHeaderByContent(text)
        if contentResult.isHeader {
            return contentResult
        }
        
        return HeaderDetectionResult(isHeader: false)
    }
    
    /// Detects header patterns in text using configuration-driven patterns
    private func detectHeaderPattern(in text: String) -> HeaderDetectionResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check numbered headers
        for pattern in config.headerDetection.patterns.numberedHeaders {
            if let _ = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateHeaderLevel(from: trimmedText)
                let confidence = calculatePatternConfidence(text: trimmedText, pattern: "Numbered")
                return HeaderDetectionResult(isHeader: true, level: level, confidence: confidence, pattern: "Numbered")
            }
        }
        
        // Check lettered headers
        for pattern in config.headerDetection.patterns.letteredHeaders {
            if let _ = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateHeaderLevel(from: trimmedText)
                let confidence = calculatePatternConfidence(text: trimmedText, pattern: "Lettered")
                return HeaderDetectionResult(isHeader: true, level: level, confidence: confidence, pattern: "Lettered")
            }
        }
        
        // Check Roman numeral headers
        for pattern in config.headerDetection.patterns.romanHeaders {
            if let _ = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateHeaderLevel(from: trimmedText)
                let confidence = calculatePatternConfidence(text: trimmedText, pattern: "Roman")
                return HeaderDetectionResult(isHeader: true, level: level, confidence: confidence, pattern: "Roman")
            }
        }
        
        // Check named headers
        for pattern in config.headerDetection.patterns.namedHeaders {
            if let _ = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateNamedHeaderLevel(from: trimmedText)
                let confidence = calculatePatternConfidence(text: trimmedText, pattern: "Named")
                return HeaderDetectionResult(isHeader: true, level: level, confidence: confidence, pattern: "Named")
            }
        }
        
        return HeaderDetectionResult(isHeader: false)
    }
    
    /// Detects headers by content characteristics
    private func detectHeaderByContent(_ text: String) -> HeaderDetectionResult {
        // Check if content-based detection is enabled
        guard config.headerFooterDetection.smartDetection.enableContentBasedDetection else {
            return HeaderDetectionResult(isHeader: false)
        }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if text is within reasonable header length
        let maxLength = config.headerFooterDetection.smartDetection.maxHeaderFooterLength
        if trimmedText.count <= maxLength {
            // All caps text
            if trimmedText == trimmedText.uppercased() && trimmedText.count > 3 {
                return HeaderDetectionResult(isHeader: true, level: 1, confidence: 0.7, pattern: "AllCaps")
            }
            
            // Title case with no sentence ending
            if isTitleCase(trimmedText) && !hasSentenceEnding(trimmedText) {
                return HeaderDetectionResult(isHeader: true, level: 2, confidence: 0.6, pattern: "TitleCase")
            }
            
            // Contains common header words
            if containsHeaderKeywords(trimmedText) {
                return HeaderDetectionResult(isHeader: true, level: 2, confidence: 0.5, pattern: "Keywords")
            }
        }
        
        return HeaderDetectionResult(isHeader: false)
    }
    
    /// Calculates header level based on numbering depth
    private func calculateHeaderLevel(from text: String) -> Int {
        guard config.headerDetection.levelCalculation.autoCalculate else {
            return 1
        }
        
        // Extract the header marker (the part that matches the pattern)
        let marker = extractHeaderMarker(from: text)
        
        // Calculate level based on the marker only, not the entire text
        // Trim the marker to remove any trailing spaces before splitting
        let trimmedMarker = marker.trimmingCharacters(in: .whitespaces)
        let components = trimmedMarker.components(separatedBy: ".")
        // Filter out empty components (e.g., ["1", ""] becomes ["1"])
        let filteredComponents = components.filter { !$0.isEmpty }
        let calculatedLevel = min(filteredComponents.count, config.headerDetection.levelCalculation.maxLevel)
        let finalLevel = calculatedLevel + config.headerDetection.markdownLevelOffset
        

        
        return finalLevel
    }
    
    /// Extracts the header marker from the text based on configured patterns
    private func extractHeaderMarker(from text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check numbered headers
        for pattern in config.headerDetection.patterns.numberedHeaders {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                return String(trimmedText[..<match.upperBound])
            }
        }
        
        // Check lettered headers
        for pattern in config.headerDetection.patterns.letteredHeaders {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                return String(trimmedText[..<match.upperBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Check Roman numeral headers
        for pattern in config.headerDetection.patterns.romanHeaders {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                return String(trimmedText[..<match.upperBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Check named headers
        for pattern in config.headerDetection.patterns.namedHeaders {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                return String(trimmedText[..<match.upperBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Fallback: return the text up to the first space or period
        if let spaceIndex = trimmedText.firstIndex(of: " ") {
            return String(trimmedText[..<spaceIndex])
        }
        if let periodIndex = trimmedText.firstIndex(of: ".") {
            return String(trimmedText[...periodIndex])
        }
        
        return trimmedText
    }
    
    /// Calculates header level for named headers using custom level mapping
    private func calculateNamedHeaderLevel(from text: String) -> Int {
        guard config.headerDetection.levelCalculation.autoCalculate else {
            return 1
        }
        
        let lowercasedText = text.lowercased()
        
        // Check custom level mappings
        for (keyword, level) in config.headerDetection.levelCalculation.customLevels {
            if lowercasedText.contains(keyword.lowercased()) {
                return level + config.headerDetection.markdownLevelOffset
            }
        }
        
        // Default level calculation
        return 1 + config.headerDetection.markdownLevelOffset
    }
    
    /// Calculates confidence score for pattern detection
    private func calculatePatternConfidence(text: String, pattern: String) -> Float {
        var confidence: Float = 0.85 // Increased base confidence for pattern match
        
        // Adjust confidence based on text length
        if text.count < 10 {
            confidence += 0.1
        } else if text.count > 50 {
            confidence -= 0.2
        }
        
        // Adjust confidence based on pattern type
        switch pattern {
        case "Named":
            confidence += 0.1
        case "Numbered":
            confidence += 0.06 // Increased to ensure > 0.5
        case "Lettered", "Roman":
            confidence += 0.06 // Increased to ensure > 0.5
        default:
            break
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - List Item Detection
    
    /// Detects if an element is a list item
    public func detectListItem(in element: DocumentElement) -> ListItemDetectionResult {
        guard let text = element.text, !text.isEmpty else {
            return ListItemDetectionResult(isListItem: false)
        }
        
        // Check if list detection is enabled
        guard config.listDetection.enabled else {
            return ListItemDetectionResult(isListItem: false)
        }
        
        // Check if element is already classified as list item
        if element.type == .listItem {
            return ListItemDetectionResult(isListItem: true, level: 1, confidence: 0.9)
        }
        
        // Pattern-based list detection using configuration
        let patternResult = detectListItemPattern(in: text)
        if patternResult.isListItem {
            return patternResult
        }
        
        // Content-based list detection
        let contentResult = detectListItemByContent(text)
        if contentResult.isListItem {
            return contentResult
        }
        
        return ListItemDetectionResult(isListItem: false)
    }
    
    /// Detects list item patterns in text using configuration-driven patterns
    private func detectListItemPattern(in text: String) -> ListItemDetectionResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check numbered markers
        for pattern in config.listDetection.patterns.numberedMarkers {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateListLevel(from: trimmedText)
                let marker = String(trimmedText[..<match.upperBound])
                let confidence = calculateListPatternConfidence(text: trimmedText, pattern: "Numbered")
                return ListItemDetectionResult(isListItem: true, level: level, marker: marker, confidence: confidence)
            }
        }
        
        // Check lettered markers
        for pattern in config.listDetection.patterns.letteredMarkers {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateListLevel(from: trimmedText)
                let marker = String(trimmedText[..<match.upperBound])
                let confidence = calculateListPatternConfidence(text: trimmedText, pattern: "Lettered")
                return ListItemDetectionResult(isListItem: true, level: level, marker: marker, confidence: confidence)
            }
        }
        
        // Check bullet markers
        for pattern in config.listDetection.patterns.bulletMarkers {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateListLevel(from: trimmedText)
                let marker = String(trimmedText[..<match.upperBound])
                let confidence = calculateListPatternConfidence(text: trimmedText, pattern: "Bullet")
                return ListItemDetectionResult(isListItem: true, level: level, marker: marker, confidence: confidence)
            }
        }
        
        // Check Roman numeral markers
        for pattern in config.listDetection.patterns.romanMarkers {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateListLevel(from: trimmedText)
                let marker = String(trimmedText[..<match.upperBound])
                let confidence = calculateListPatternConfidence(text: trimmedText, pattern: "Roman")
                return ListItemDetectionResult(isListItem: true, level: level, marker: marker, confidence: confidence)
            }
        }
        
        // Check custom markers
        for pattern in config.listDetection.patterns.customMarkers {
            if let match = trimmedText.range(of: pattern, options: .regularExpression) {
                let level = calculateListLevel(from: trimmedText)
                let marker = String(trimmedText[..<match.upperBound])
                let confidence = calculateListPatternConfidence(text: trimmedText, pattern: "Custom")
                return ListItemDetectionResult(isListItem: true, level: level, marker: marker, confidence: confidence)
            }
        }
        
        return ListItemDetectionResult(isListItem: false)
    }
    
    /// Detects list items by content characteristics
    private func detectListItemByContent(_ text: String) -> ListItemDetectionResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if text is within reasonable list item length
        let maxLength = config.headerFooterDetection.smartDetection.maxHeaderFooterLength
        if trimmedText.count <= maxLength && !hasSentenceEnding(trimmedText) {
            // Starts with common list indicators
            if startsWithListIndicator(trimmedText) {
                return ListItemDetectionResult(isListItem: true, level: 1, marker: nil, confidence: 0.6)
            }
            
            // Very short text (likely list items)
            if trimmedText.count <= 5 {
                return ListItemDetectionResult(isListItem: true, level: 1, marker: nil, confidence: 0.5)
            }
        }
        
        return ListItemDetectionResult(isListItem: false)
    }
    
    /// Calculates list level based on indentation or nesting
    private func calculateListLevel(from text: String) -> Int {
        guard config.listDetection.enableLevelCalculation else {
            return 1
        }
        
        // For now, return level 1. In the future, this could analyze indentation
        // using config.listDetection.indentation settings
        return 1
    }
    
    /// Calculates confidence score for list pattern detection
    private func calculateListPatternConfidence(text: String, pattern: String) -> Float {
        var confidence: Float = 0.8 // Base confidence for pattern match
        
        // Adjust confidence based on text length
        if text.count < 20 {
            confidence += 0.1
        } else if text.count > 100 {
            confidence -= 0.2
        }
        
        // Adjust confidence based on pattern type
        switch pattern {
        case "Bullet":
            confidence += 0.1
        case "Numbered":
            confidence += 0.06 // Increased to ensure > 0.5
        case "Lettered", "Roman":
            confidence += 0.06 // Increased to ensure > 0.5
        case "Custom":
            confidence += 0.06 // Increased to ensure > 0.5
        default:
            break
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - Element Merging
    
    /// Merges split headers that span multiple elements
    public func mergeSplitHeaders(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        guard config.headerDetection.enableHeaderMerging else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element is a header
            let headerResult = detectHeader(in: currentElement)
            
            if headerResult.isHeader {
                // Look for continuation elements
                var headerElements: [DocumentElement] = [currentElement]
                var j = i + 1
                
                while j < elements.count {
                    let nextElement = elements[j]
                    
                    // Check if next element is a continuation of the header
                    if isHeaderContinuation(currentElement, nextElement) {
                        headerElements.append(nextElement)
                        j += 1
                    } else {
                        break
                    }
                }
                
                // Merge header elements
                if headerElements.count > 1 {
                    do {
                        let mergedHeader = try await mergeHeaderElements(headerElements, level: headerResult.level)
                        mergedElements.append(mergedHeader)
                        i = j // Skip processed elements
                    } catch {
                        logger.error("Failed to merge header elements: \(error)")
                        mergedElements.append(currentElement)
                        i += 1
                    }
                } else {
                    mergedElements.append(currentElement)
                    i += 1
                }
            } else {
                mergedElements.append(currentElement)
                i += 1
            }
        }
        
        logger.info("Merged \(elements.count - mergedElements.count) split headers")
        return mergedElements
    }
    
    /// Merges split list items
    public func mergeSplitListItems(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        guard config.listDetection.enableListItemMerging else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element is a list item
            let listResult = detectListItem(in: currentElement)
            
            if listResult.isListItem {
                // Look for continuation elements
                var listElements: [DocumentElement] = [currentElement]
                var j = i + 1
                
                while j < elements.count {
                    let nextElement = elements[j]
                    
                    // Check if next element is a continuation of the list item
                    if isListItemContinuation(currentElement, nextElement) {
                        listElements.append(nextElement)
                        j += 1
                    } else {
                        break
                    }
                }
                
                // Merge list elements
                if listElements.count > 1 {
                    do {
                        let mergedListItem = try await mergeListItemElements(listElements, level: listResult.level)
                        mergedElements.append(mergedListItem)
                        i = j // Skip processed elements
                    } catch {
                        logger.error("Failed to merge list item elements: \(error)")
                        mergedElements.append(currentElement)
                        i += 1
                    }
                } else {
                    mergedElements.append(currentElement)
                    i += 1
                }
            } else {
                mergedElements.append(currentElement)
                i += 1
            }
        }
        
        logger.info("Merged \(elements.count - mergedElements.count) split list items")
        return mergedElements
    }
    
    // MARK: - Helper Methods
    
    /// Checks if an element is a header continuation
    private func isHeaderContinuation(_ header: DocumentElement, _ continuation: DocumentElement) -> Bool {
        // Elements must be on the same page
        guard header.pageNumber == continuation.pageNumber else { return false }
        
        // Continuation should be close to the header (using same-line tolerance)
        let tolerance = Float(config.headerDetection.sameLineTolerance)
        let distance = header.mergeDistance(to: continuation)
        let normalizedDistance = distance * 792.0 // Convert to points (standard PDF height)
        guard normalizedDistance <= tolerance else { return false }
        
        // Continuation should not be a complete sentence
        guard let continuationText = continuation.text else { return false }
        return !hasSentenceEnding(continuationText)
    }
    
    /// Checks if an element is a list item continuation
    private func isListItemContinuation(_ listItem: DocumentElement, _ continuation: DocumentElement) -> Bool {
        // Elements must be on the same page
        guard listItem.pageNumber == continuation.pageNumber else { return false }
        
        // Continuation should be close to the list item (using same-line tolerance)
        let tolerance = Float(config.listDetection.sameLineTolerance)
        let distance = listItem.mergeDistance(to: continuation)
        let normalizedDistance = distance * 792.0 // Convert to points (standard PDF height)
        guard normalizedDistance <= tolerance else { return false }
        
        // Continuation should not be a complete sentence
        guard let continuationText = continuation.text else { return false }
        return !hasSentenceEnding(continuationText)
    }
    
    /// Merges multiple header elements into one
    private func mergeHeaderElements(_ elements: [DocumentElement], level: Int) async throws -> DocumentElement {
        guard let firstElement = elements.first else {
            throw HeaderListDetectionError.mergeFailure("No elements to merge")
        }
        
        // Merge bounding boxes
        let mergedBoundingBox = elements.reduce(firstElement.boundingBox) { result, element in
            result.union(with: element.boundingBox)
        }
        
        // Merge text content
        let mergedText = elements.compactMap { $0.text }.joined(separator: " ")
        
        // Merge metadata
        var mergedMetadata = firstElement.metadata
        mergedMetadata["merged_headers"] = "\(elements.count)"
        mergedMetadata["header_level"] = "\(level)"
        mergedMetadata["merge_timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // Calculate average confidence
        let mergedConfidence = elements.map { $0.confidence }.reduce(0, +) / Float(elements.count)
        
        return DocumentElement(
            type: .header,
            boundingBox: mergedBoundingBox,
            contentData: firstElement.contentData,
            confidence: mergedConfidence,
            pageNumber: firstElement.pageNumber,
            text: mergedText,
            metadata: mergedMetadata
        )
    }
    
    /// Merges multiple list item elements into one
    private func mergeListItemElements(_ elements: [DocumentElement], level: Int) async throws -> DocumentElement {
        guard let firstElement = elements.first else {
            throw HeaderListDetectionError.mergeFailure("No elements to merge")
        }
        
        // Merge bounding boxes
        let mergedBoundingBox = elements.reduce(firstElement.boundingBox) { result, element in
            result.union(with: element.boundingBox)
        }
        
        // Merge text content
        let mergedText = elements.compactMap { $0.text }.joined(separator: " ")
        
        // Merge metadata
        var mergedMetadata = firstElement.metadata
        mergedMetadata["merged_list_items"] = "\(elements.count)"
        mergedMetadata["list_level"] = "\(level)"
        mergedMetadata["merge_timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // Calculate average confidence
        let mergedConfidence = elements.map { $0.confidence }.reduce(0, +) / Float(elements.count)
        
        return DocumentElement(
            type: .listItem,
            boundingBox: mergedBoundingBox,
            contentData: firstElement.contentData,
            confidence: mergedConfidence,
            pageNumber: firstElement.pageNumber,
            text: mergedText,
            metadata: mergedMetadata
        )
    }
    
    /// Checks if text is in title case
    private func isTitleCase(_ text: String) -> Bool {
        let words = text.components(separatedBy: " ")
        return words.allSatisfy { word in
            guard let firstChar = word.first else { return false }
            return firstChar.isUppercase
        }
    }
    
    /// Checks if text ends with sentence punctuation
    private func hasSentenceEnding(_ text: String) -> Bool {
        return text.hasSuffix(".") || text.hasSuffix("!") || text.hasSuffix("?")
    }
    
    /// Checks if text contains common header keywords
    private func containsHeaderKeywords(_ text: String) -> Bool {
        let headerKeywords = ["introduction", "conclusion", "summary", "overview", "background", "method", "results", "discussion", "appendix", "references", "bibliography"]
        let lowercasedText = text.lowercased()
        return headerKeywords.contains { lowercasedText.contains($0) }
    }
    
    /// Checks if text starts with common list indicators
    private func startsWithListIndicator(_ text: String) -> Bool {
        let listIndicators = ["-", "•", "·", "▪", "▫", "◦", "‣", "⁃"]
        return listIndicators.contains { text.hasPrefix($0) }
    }
}
