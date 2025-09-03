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

// MARK: - Page Header Context

public struct PageHeaderContext {
    public let hasChapterHeaders: Bool
    public let hasAppendixHeaders: Bool
    public let hasNamedHeaders: Bool
    public let headerSequence: [String]
    public let headerNumberingByLevel: [Int: [String]]
    public let pageNumber: Int
    
    public init(hasChapterHeaders: Bool = false, hasAppendixHeaders: Bool = false, hasNamedHeaders: Bool = false, headerSequence: [String] = [], headerNumberingByLevel: [Int: [String]] = [:], pageNumber: Int = 0) {
        self.hasChapterHeaders = hasChapterHeaders
        self.hasAppendixHeaders = hasAppendixHeaders
        self.hasNamedHeaders = hasNamedHeaders
        self.headerSequence = headerSequence
        self.headerNumberingByLevel = headerNumberingByLevel
        self.pageNumber = pageNumber
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
    
    /// Detects if an element is a header with page-level context validation
    public func detectHeaderWithContext(in element: DocumentElement, pageContext: PageHeaderContext) -> HeaderDetectionResult {
        // First, do basic header detection
        let basicResult = detectHeader(in: element)
        
        // If not detected as header, return early
        guard basicResult.isHeader else {
            return basicResult
        }
        
        // Validate header in page context
        if !validateHeaderInContext(element, pageContext) {
            logger.debug("❌ Header misaligned with page context: '\(element.text ?? "")' on page \(pageContext.pageNumber)")
            return HeaderDetectionResult(isHeader: false)
        }
        
        return basicResult
    }
    
    /// Validates if a header is consistent with the page context
    private func validateHeaderInContext(_ element: DocumentElement, _ context: PageHeaderContext) -> Bool {
        guard let text = element.text else { return false }
        
        // If we're in an appendix section, don't allow chapter headers
        if context.hasAppendixHeaders && isChapterHeader(text) {
            logger.debug("❌ Chapter header detected in appendix context: '\(text)'")
            return false
        }
        
        // If we're in a chapter section, don't allow appendix headers
        if context.hasChapterHeaders && isAppendixHeader(text) {
            logger.debug("❌ Appendix header detected in chapter context: '\(text)'")
            return false
        }
        
        // Check if it's descriptive text that shouldn't be a header
        if isDescriptiveText(text) {
            logger.debug("❌ Descriptive text detected as header: '\(text)'")
            return false
        }
        
        return true
    }
    
    /// Helper method for string pattern matching
    private func matches(_ text: String, _ pattern: String) -> Bool {
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Checks if text is a chapter header
    private func isChapterHeader(_ text: String) -> Bool {
        // Matches patterns like "5 网络安全等级保护概述", "6 第一级安全要求"
        let pattern = "^\\d+\\s+[\\u4e00-\\u9fff]+$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Checks if text is an appendix header
    private func isAppendixHeader(_ text: String) -> Bool {
        // Matches patterns like "附录A", "附录B"
        let pattern = "^附录[A-Z]"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Checks if text is descriptive content that shouldn't be a header
    private func isDescriptiveText(_ text: String) -> Bool {
        // Long descriptive text that contains explanatory phrases
        let descriptivePatterns = [
            "提出了.*要求",
            "分别针对.*保护",
            "包含.*内容",
            "涉及.*方面",
            "界定的以及.*适用于",
            "适用于.*文件",
            "为了便于使用",
            "重复列出了"
        ]
        
        let isLong = text.count > 30
        let containsDescriptivePhrases = descriptivePatterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
        
        // Check for year + descriptive text pattern (e.g., "2016 界定的以及...")
        let yearDescriptivePattern = "^\\d{4}\\s+[\\u4e00-\\u9fff].*"
        let isYearDescriptive = text.range(of: yearDescriptivePattern, options: .regularExpression) != nil
        
        return (isLong && containsDescriptivePhrases) || isYearDescriptive
    }
    
    /// Analyzes page structure to determine header context
    public func analyzePageHeaderContext(_ elements: [DocumentElement]) -> PageHeaderContext {
        let potentialHeaders = elements.filter { element in
            guard let text = element.text else { return false }
            return detectHeaderPattern(in: text).isHeader
        }
        
        let hasChapterHeaders = potentialHeaders.contains { element in
            guard let text = element.text else { return false }
            return isChapterHeader(text)
        }
        
        let hasAppendixHeaders = potentialHeaders.contains { element in
            guard let text = element.text else { return false }
            return isAppendixHeader(text)
        }
        
        let hasNamedHeaders = potentialHeaders.contains { element in
            guard let text = element.text else { return false }
            return matches(text, "^(前言|引言|参考文献)")
        }
        
        let headerSequence = potentialHeaders.compactMap { $0.text }
        let pageNumber = elements.first?.pageNumber ?? 0
        
        // Extract header numbering sequences for each level
        var headerNumberingByLevel: [Int: [String]] = [:]
        for element in potentialHeaders {
            if let text = element.text,
               let headerLevel = element.headerLevel,
               let marker = extractHeaderMarker(text) {
                if headerNumberingByLevel[headerLevel] == nil {
                    headerNumberingByLevel[headerLevel] = []
                }
                headerNumberingByLevel[headerLevel]?.append(marker)
            }
        }
        
        return PageHeaderContext(
            hasChapterHeaders: hasChapterHeaders,
            hasAppendixHeaders: hasAppendixHeaders,
            hasNamedHeaders: hasNamedHeaders,
            headerSequence: headerSequence,
            headerNumberingByLevel: headerNumberingByLevel,
            pageNumber: pageNumber
        )
    }
    
    /// Processes misaligned headers by checking for multi-line optimization opportunities
    public func processMisalignedHeader(_ misalignedElement: DocumentElement, adjacentElements: [DocumentElement]) -> [DocumentElement] {
        logger.debug("🔄 Processing misaligned header for multi-line optimization: '\(misalignedElement.text ?? "")'")
        
        var processedElements: [DocumentElement] = []
        var i = 0
        
        while i < adjacentElements.count {
            let currentElement = adjacentElements[i]
            
            // If this is the misaligned header element, check for merge opportunities
            if currentElement.id == misalignedElement.id {
                // Check if we can merge with previous element
                if i > 0 {
                    let previousElement = adjacentElements[i - 1]
                    if isSafeSentenceContinuation(previousElement, currentElement) {
                        logger.debug("✅ Merging misaligned header with previous element")
                        let mergedElement = mergeElements(previousElement, currentElement)
                        processedElements.append(mergedElement)
                        i += 1
                        continue
                    }
                }
                
                // Check if we can merge with next element
                if i + 1 < adjacentElements.count {
                    let nextElement = adjacentElements[i + 1]
                    if isSafeSentenceContinuation(currentElement, nextElement) {
                        logger.debug("✅ Merging misaligned header with next element")
                        let mergedElement = mergeElements(currentElement, nextElement)
                        processedElements.append(mergedElement)
                        i += 2
                        continue
                    }
                }
                
                // If no merge possible, keep as paragraph
                let paragraphElement = DocumentElement(
                    id: currentElement.id,
                    type: .paragraph,
                    boundingBox: currentElement.boundingBox,
                    contentData: currentElement.contentData,
                    confidence: currentElement.confidence,
                    pageNumber: currentElement.pageNumber,
                    text: currentElement.text,
                    metadata: currentElement.metadata,
                    headerLevel: nil
                )
                processedElements.append(paragraphElement)
            } else {
                processedElements.append(currentElement)
            }
            
            i += 1
        }
        
        return processedElements
    }
    
    /// Merges two elements into a single element
    private func mergeElements(_ element1: DocumentElement, _ element2: DocumentElement) -> DocumentElement {
        let mergedText = "\(element1.text ?? "")\(element2.text ?? "")"
        let mergedBoundingBox = CGRect(
            x: min(element1.boundingBox.minX, element2.boundingBox.minX),
            y: min(element1.boundingBox.minY, element2.boundingBox.minY),
            width: max(element1.boundingBox.maxX, element2.boundingBox.maxX) - min(element1.boundingBox.minX, element2.boundingBox.minX),
            height: max(element1.boundingBox.maxY, element2.boundingBox.maxY) - min(element1.boundingBox.minY, element2.boundingBox.minY)
        )
        
        return DocumentElement(
            id: UUID(),
            type: .paragraph,
            boundingBox: mergedBoundingBox,
            contentData: Data(),
            confidence: min(element1.confidence, element2.confidence),
            pageNumber: element1.pageNumber,
            text: mergedText,
            metadata: element1.metadata,
            headerLevel: nil
        )
    }
    
    /// Detects if a page is a TOC page based on its content characteristics
    public func isTOCPage(_ elements: [DocumentElement]) -> Bool {
        guard !elements.isEmpty else { return false }
        
        // TOC pages typically have:
        // 1. High ratio of headers to other content
        // 2. Short text elements (mostly titles/headers)
        // 3. Many elements with TOC-like patterns
        // 4. Few or no substantial paragraphs
        
        let headerCount = elements.filter { $0.type == .header }.count
        let totalElements = elements.count
        
        // Calculate header ratio
        let headerRatio = Float(headerCount) / Float(totalElements)
        
        // Check if most elements are headers (typical for TOC pages)
        if headerRatio >= 0.9 && totalElements >= 3 {
            logger.debug("Page identified as TOC page: header ratio \(headerRatio) (\(headerCount)/\(totalElements))")
            return true
        }
        
        return false
    }
    
    /// Detects if an element is a TOC item based on content patterns
    /// This should only be called for elements on pages that are confirmed TOC pages
    public func detectTOCItem(in element: DocumentElement) -> Bool {
        guard let text = element.text, !text.isEmpty else {
            return false
        }
        
        // TOC items typically:
        // 1. Start with numbers or letters followed by dots/spaces
        // 2. End with page numbers or ellipsis
        // 3. Are relatively short
        // 4. Don't contain sentence-ending punctuation
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's short (TOC items are typically brief)
        guard trimmedText.count <= 50 else { return false }
        
        // Check for TOC patterns
        let tocPatterns = [
            "^\\d+\\s+[\\u4e00-\\u9fff]+", // "1 范围", "2 规范性引用文件"
            "^\\d+\\.\\d+\\s+[\\u4e00-\\u9fff]+", // "5.1 等级保护对象"
            "^\\d+\\.\\d+\\.\\d+\\s+[\\u4e00-\\u9fff]+", // "6.1.1 安全物理环境"
            "^附录[A-Z]\\s*[（(][^）)]+[）)]", // "附录A（规范性附录）"
            "^[\\u4e00-\\u9fff]+\\s*\\d+$", // "前言 1", "参考文献 83"
        ]
        
        for pattern in tocPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
                if regex.firstMatch(in: trimmedText, range: range) != nil {
                    return true
                }
            }
        }
        
        // Check for TOC indicators (page numbers, ellipsis)
        let tocIndicators = ["⋯", "…", "•", "：", "："]
        let hasTOCIndicator = tocIndicators.contains { trimmedText.contains($0) }
        
        // Check if it doesn't end with sentence punctuation (TOC items don't end sentences)
        let sentenceEndings = ["。", "！", "？", ".", "!", "?", ";", "；"]
        let endsWithSentence = sentenceEndings.contains { trimmedText.hasSuffix($0) }
        
        return hasTOCIndicator && !endsWithSentence
    }
    
    /// Detects header patterns in text using configuration-driven patterns
    private func detectHeaderPattern(in text: String) -> HeaderDetectionResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Headers should not end with sentence-ending punctuation
        if hasSentenceEnding(trimmedText) {
            return HeaderDetectionResult(isHeader: false)
        }
        
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
            return Swift.String(trimmedText[..<spaceIndex])
        }
        if let periodIndex = trimmedText.firstIndex(of: ".") {
            return Swift.String(trimmedText[...periodIndex])
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
            
            // Very short text (likely list items) - but be more conservative
            // Only detect as list item if it's very short AND doesn't contain Chinese characters
            if trimmedText.count <= 3 && !containsChineseCharacters(trimmedText) {
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
        
        // Phase 1: Same-line merging (tight tolerance)
        let sameLineElements = await mergeHeadersSameLine(elements)
        
        // Phase 2: Multi-line merging (looser tolerance)
        let finalElements = await mergeHeadersMultiLine(sameLineElements)
        
        logger.info("Merged \(elements.count - finalElements.count) split headers")
        return finalElements
    }
    
    /// Phase 1: Merge headers that are on the same line (tight tolerance)
    private func mergeHeadersSameLine(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element is a header
            let headerResult = detectHeader(in: currentElement)
            
            if headerResult.isHeader {
                // Look for same-line continuation elements
                var headerElements: [DocumentElement] = [currentElement]
                var j = i + 1
                
                while j < elements.count {
                    let nextElement = elements[j]
                    
                    // Check if next element is a same-line header continuation
                    if isHeaderContinuationSameLine(currentElement, nextElement) {
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
        
        return mergedElements
    }
    
    /// Phase 2: Merge headers that span multiple lines (looser tolerance)
    private func mergeHeadersMultiLine(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element is a header
            let headerResult = detectHeader(in: currentElement)
            
            if headerResult.isHeader {
                // Look for multi-line continuation elements
                var headerElements: [DocumentElement] = [currentElement]
                var j = i + 1
                
                while j < elements.count {
                    let nextElement = elements[j]
                    
                    // Check if next element is a multi-line header continuation
                    if isHeaderContinuationMultiLine(currentElement, nextElement) {
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
        
        return mergedElements
    }
    
    /// Merges split list items
    public func mergeSplitListItems(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        guard config.listDetection.enableListItemMerging else { return elements }
        
        // Phase 1: Same-line merging (tight tolerance)
        let sameLineElements = await mergeListItemsSameLine(elements)
        
        // Phase 2: Multi-line merging (looser tolerance)
        let finalElements = await mergeListItemsMultiLine(sameLineElements)
        
        logger.info("Merged \(elements.count - finalElements.count) split list items")
        return finalElements
    }
    
    /// Phase 1: Merge list items that are on the same line (tight tolerance)
    private func mergeListItemsSameLine(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element is a list item
            let listResult = detectListItem(in: currentElement)
            
            // Debug logging
            if let text = currentElement.text {
                logger.debug("Element \(i): '\(text)' - List item: \(listResult.isListItem), Level: \(listResult.level)")
            }
            
            if listResult.isListItem {
                // Look for same-line continuation elements
                var listElements: [DocumentElement] = [currentElement]
                var j = i + 1
                
                while j < elements.count {
                    let nextElement = elements[j]
                    
                    // Debug logging for continuation check
                    if let currentText = currentElement.text, let nextText = nextElement.text {
                        let isContinuation = isListItemContinuationSameLine(currentElement, nextElement)
                        let verticalDistance = abs(currentElement.boundingBox.minY - nextElement.boundingBox.minY)
                        logger.debug("Checking continuation: '\(currentText)' -> '\(nextText)' - Distance: \(verticalDistance), IsContinuation: \(isContinuation)")
                    }
                    
                    // Check if next element is a same-line continuation of the list item
                    if isListItemContinuationSameLine(currentElement, nextElement) {
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
        
        return mergedElements
    }
    
    /// Phase 2: Merge list items that span multiple lines (looser tolerance)
    private func mergeListItemsMultiLine(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element is a list item
            let listResult = detectListItem(in: currentElement)
            
            if listResult.isListItem {
                // Look for multi-line continuation elements
                var listElements: [DocumentElement] = [currentElement]
                var j = i + 1
                
                while j < elements.count {
                    let nextElement = elements[j]
                    
                    // Check if next element is a multi-line continuation of the list item
                    if isListItemContinuationMultiLine(currentElement, nextElement) {
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
        
        return mergedElements
    }
    
    /// Merges split sentences that span multiple elements
    public func mergeSplitSentences(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element appears to be a sentence continuation
            if isSentenceContinuation(currentElement) {
                // Look for the previous element to merge with
                if let previousElement = mergedElements.last {
                    // Check if they should be merged (logical continuation)
                    if shouldMergeSentences(previousElement, currentElement) {
                        let merged = mergeSentenceElements(previousElement, currentElement)
                        mergedElements[mergedElements.count - 1] = merged
                        i += 1
                        continue
                    }
                }
            }
            
            mergedElements.append(currentElement)
            i += 1
        }
        
        logger.info("Merged \(elements.count - mergedElements.count) split sentences")
        return mergedElements
    }
    
    /// Merges all elements that are on the same line horizontally (left to right)
    /// This is a simple, reliable approach that doesn't require complex type detection
    /// - Parameter language: The detected language of the document (e.g., "zh-Hans" for Chinese)
    public func mergeSameLineElements(_ elements: [DocumentElement], language: String = "en") async -> [DocumentElement] {
        guard elements.count > 1 else { 
            logger.info("🔗 SAME-LINE MERGING - Only \(elements.count) elements, skipping merge")
            return elements 
        }
        
        // Check if same-line merging is enabled in configuration
        guard config.sameLineMerging.enabled else {
            logger.info("🔗 SAME-LINE MERGING - Disabled in configuration")
            return elements
        }
        
        logger.info("🔗 SAME-LINE MERGING - Starting with \(elements.count) elements, language: \(language)")
        
        // Sort elements by page, then by Y position (top to bottom), then by X position (left to right)
        let sortedElements = elements.sorted { first, second in
            if first.pageNumber != second.pageNumber {
                return first.pageNumber < second.pageNumber
            }
            if abs(first.boundingBox.minY - second.boundingBox.minY) > 0.01 { // Different lines
                return first.boundingBox.minY > second.boundingBox.minY // Top to bottom
            }
            return first.boundingBox.minX < second.boundingBox.minX // Left to right on same line
        }
        
        logger.info("🔗 SAME-LINE MERGING - Sorted elements by position")
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < sortedElements.count {
            let currentElement = sortedElements[i]
            var sameLineElements: [DocumentElement] = [currentElement]
            var j = i + 1
            
            logger.debug("🔗 SAME-LINE MERGING - Processing element \(i): '\(currentElement.text ?? "")' at Y=\(String(format: "%.4f", currentElement.boundingBox.minY))")
            
            // Find all elements on the same line
            while j < sortedElements.count {
                let nextElement = sortedElements[j]
                
                // Check if elements are on the same line (within tolerance)
                if currentElement.pageNumber == nextElement.pageNumber {
                    let verticalDistance = abs(currentElement.boundingBox.minY - nextElement.boundingBox.minY)
                    if config.sameLineMerging.enableLogging {
                        logger.debug("🔗 SAME-LINE MERGING - Checking element \(j): '\(nextElement.text ?? "")' at Y=\(String(format: "%.4f", nextElement.boundingBox.minY)), verticalDistance=\(String(format: "%.4f", verticalDistance))")
                    }
                    
                    if verticalDistance <= config.sameLineMerging.verticalTolerance { // Same line tolerance from config
                        // Same-line merging is MANDATORY - merge all elements on the same line
                        // No horizontal threshold check needed for same-line elements
                        if config.sameLineMerging.enableLogging {
                            logger.debug("🔗 SAME-LINE MERGING - Elements on same line - MERGING MANDATORY")
                        }
                        sameLineElements.append(nextElement)
                        if config.sameLineMerging.enableLogging {
                            logger.debug("🔗 SAME-LINE MERGING - Added to same-line group: '\(nextElement.text ?? "")'")
                        }
                        j += 1
                    } else {
                        if config.sameLineMerging.enableLogging {
                            logger.debug("🔗 SAME-LINE MERGING - Stopping merge due to different line (distance=\(String(format: "%.4f", verticalDistance)))")
                        }
                        break // Different line
                    }
                } else {
                    if config.sameLineMerging.enableLogging {
                        logger.debug("🔗 SAME-LINE MERGING - Stopping merge due to different page")
                    }
                    break // Different page
                }
            }
            
            // Merge elements on the same line
            if sameLineElements.count > 1 {
                logger.info("🔗 SAME-LINE MERGING - Merging \(sameLineElements.count) elements: \(sameLineElements.map { "'\($0.text ?? "")'" }.joined(separator: " + "))")
                
                // Sort by X position (left to right) to maintain reading order
                let leftToRightElements = sameLineElements.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                
                // Determine separator based on language and element types from config
                var separator = language.hasPrefix("zh") ? config.sameLineMerging.separatorForChinese : config.sameLineMerging.separatorForEnglish
                
                // If the first element is a header, always add a space to preserve header detection
                if leftToRightElements.first?.type == .header {
                    separator = " "
                }
                
                let mergedText = leftToRightElements.compactMap { $0.text }.joined(separator: separator)
                let mergedBoundingBox = leftToRightElements.reduce(leftToRightElements[0].boundingBox) { result, element in
                    result.union(element.boundingBox)
                }
                
                logger.info("🔗 SAME-LINE MERGING - Merged result: '\(mergedText)' (separator: '\(separator)')")
                
                let merged = DocumentElement(
                    type: leftToRightElements[0].type, // Keep the type of the first element
                    boundingBox: mergedBoundingBox,
                    contentData: Data(),
                    confidence: leftToRightElements.map { $0.confidence }.reduce(0, +) / Float(leftToRightElements.count),
                    pageNumber: currentElement.pageNumber,
                    text: mergedText,
                    metadata: leftToRightElements[0].metadata,
                    headerLevel: leftToRightElements[0].headerLevel
                )
                
                mergedElements.append(merged)
                i = j // Skip processed elements
            } else {
                logger.debug("🔗 SAME-LINE MERGING - No merge needed for: '\(currentElement.text ?? "")'")
                mergedElements.append(currentElement)
                i += 1
            }
        }
        
        let mergedCount = elements.count - mergedElements.count
        logger.info("🔗 SAME-LINE MERGING - Completed: merged \(mergedCount) elements, final count: \(mergedElements.count)")
        return mergedElements
    }
    

    
    /// Merges split sentences that span multiple lines (conservative approach)
    /// Only merges when confident it's a sentence continuation, not a new list/header
    /// Uses iterative merging to handle multiple consecutive merges
    public func mergeSplitSentencesConservative(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element appears to be an incomplete sentence
            if isIncompleteSentence(currentElement) {
                // Look for the next element to merge with
                if i + 1 < elements.count {
                    let nextElement = elements[i + 1]
                    
                    // DEBUG: Log what we're trying to merge
                    logger.debug("Attempting to merge: '\(currentElement.text ?? "")' + '\(nextElement.text ?? "")'")
                    
                    // Check if next element is a safe continuation
                    if isSafeSentenceContinuation(currentElement, nextElement) {
                        let mergedText = (currentElement.text ?? "") + (nextElement.text ?? "")
                        let mergedBoundingBox = currentElement.boundingBox.union(nextElement.boundingBox)
                        
                        let merged = DocumentElement(
                            type: currentElement.type,
                            boundingBox: mergedBoundingBox,
                            contentData: Data(),
                            confidence: (currentElement.confidence + nextElement.confidence) / 2,
                            pageNumber: currentElement.pageNumber,
                            text: mergedText,
                            metadata: currentElement.metadata
                        )
                        
                        // ITERATIVE MERGING: Check if the merged result should be further merged
                        var finalMerged = merged
                        var mergeIndex = i + 2 // Start checking from the element after the next one
                        
                        while mergeIndex < elements.count {
                            let nextCandidate = elements[mergeIndex]
                            
                            // Check if the merged result is still incomplete and the next candidate is safe to merge
                            if isIncompleteSentence(finalMerged) && isSafeSentenceContinuation(finalMerged, nextCandidate) {
                                let newMergedText = (finalMerged.text ?? "") + (nextCandidate.text ?? "")
                                let newMergedBoundingBox = finalMerged.boundingBox.union(nextCandidate.boundingBox)
                                
                                finalMerged = DocumentElement(
                                    type: finalMerged.type,
                                    boundingBox: newMergedBoundingBox,
                                    contentData: Data(),
                                    confidence: (finalMerged.confidence + nextCandidate.confidence) / 2,
                                    pageNumber: finalMerged.pageNumber,
                                    text: newMergedText,
                                    metadata: finalMerged.metadata
                                )
                                
                                logger.debug("✅ Iterative merge: '\(newMergedText)'")
                                mergeIndex += 1
                            } else {
                                break // Stop merging when we can't merge anymore
                            }
                        }
                        
                        mergedElements.append(finalMerged)
                        logger.debug("✅ Successfully merged: '\(finalMerged.text ?? "")'")
                        i = mergeIndex // Skip all elements that were merged
                        continue
                    } else {
                        logger.debug("❌ Rejected merge: '\(currentElement.text ?? "")' + '\(nextElement.text ?? "")'")
                    }
                }
            }
            
            mergedElements.append(currentElement)
            i += 1
        }
        
        logger.info("Merged \(elements.count - mergedElements.count) split sentences (conservative)")
        return mergedElements
    }
    
    /// Checks if an element appears to be an incomplete sentence
    /// Primary indicator: absence of sentence-ending punctuation
    /// Exception: Headers don't end with punctuation but are complete
    private func isIncompleteSentence(_ element: DocumentElement) -> Bool {
        guard let text = element.text else { return false }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exception: Headers are complete even without ending punctuation
        if isHeader(element) {
            return false
        }
        
        // Primary check: Does it end with sentence-ending punctuation?
        let sentenceEndings = ["。", "！", "？", ".", "!", "?", ";", "；"]
        let hasSentenceEnding = sentenceEndings.contains { trimmedText.hasSuffix($0) }
        
        // If it has a sentence ending, it's complete
        if hasSentenceEnding {
            return false
        }
        
        // If it doesn't have a sentence ending, it's likely incomplete
        // This is more reliable than checking for specific continuation words
        return true
    }
    
    /// Checks if an element is a header using configuration-based patterns
    private func isHeader(_ element: DocumentElement) -> Bool {
        // First check if the element is actually classified as a header
        if element.type == .header {
            return true
        }
        
        // If the element is not classified as a header, don't check text patterns
        // This prevents false positives for converted elements
        return false
    }
    
    /// Checks if next element is a safe sentence continuation
    private func isSafeSentenceContinuation(_ current: DocumentElement, _ next: DocumentElement) -> Bool {
        // For cross-page optimization, we allow different pages
        // but we still need to check vertical distance for same-page elements
        if current.pageNumber == next.pageNumber {
            // Same page: check vertical distance (reasonable proximity)
            let verticalDistance = abs(current.boundingBox.minY - next.boundingBox.minY)
            let maxDistance: CGFloat = 0.05 // 5% tolerance for sentence continuation
            guard verticalDistance <= maxDistance else { 
                logger.debug("❌ Vertical distance too large: \(verticalDistance) > \(maxDistance)")
                return false 
            }
            
            // FIRST: Check if this looks like a sentence completion (including split Chinese words)
            // This takes priority over right edge checks
            if isSentenceCompletion(current, next) {
                logger.debug("✅ Sentence completion detected (early check)")
                return true
            }
            
            // NEW: Check if current element ends far from the right edge (indicating a complete sentence)
            // But only if it's not a split Chinese word
            let currentMaxX = current.boundingBox.maxX
            let rightEdgeThreshold: CGFloat = 0.7 // If element ends before 70% of page width, it's likely complete
            if currentMaxX < rightEdgeThreshold {
                logger.debug("❌ Current element ends far from right edge (maxX: \(currentMaxX) < \(rightEdgeThreshold)) - likely a complete sentence")
                return false
            }
        } else {
            // Cross-page: no vertical distance check needed
            logger.debug("Cross-page continuation: page \(current.pageNumber) -> page \(next.pageNumber)")
        }
        
        guard let nextText = next.text else { 
            logger.debug("❌ Next element has no text")
            return false 
        }
        let trimmedNextText = nextText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // CRITICAL: Check if next element is a header BEFORE any other checks
        // This prevents merging headers with previous text
        if isHeader(next) {
            logger.debug("❌ Next element is a header: '\(trimmedNextText)'")
            return false // This is a NEW header, not a continuation
        }
        
        // DANGEROUS: Don't merge if next element starts with list markers
        // Use configuration-based list detection patterns
        for pattern in config.listDetection.patterns.numberedMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmedNextText.startIndex..<trimmedNextText.endIndex, in: trimmedNextText)
                if regex.firstMatch(in: trimmedNextText, range: range) != nil {
                    logger.debug("❌ Next element starts with numbered list marker: '\(trimmedNextText)'")
                    return false // This is a NEW list item, not a continuation
                }
            }
        }
        
        for pattern in config.listDetection.patterns.letteredMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmedNextText.startIndex..<trimmedNextText.endIndex, in: trimmedNextText)
                if regex.firstMatch(in: trimmedNextText, range: range) != nil {
                    logger.debug("❌ Next element starts with lettered list marker: '\(trimmedNextText)'")
                    return false // This is a NEW list item, not a continuation
                }
            }
        }
        
        // DANGEROUS: Don't merge if next element starts with header markers
        // BUT ONLY if the element is actually classified as a header
        // If it's a paragraph, we should allow merging even if it starts with header-like patterns
        if next.type == .header {
            for pattern in config.headerDetection.patterns.numberedHeaders {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let range = NSRange(trimmedNextText.startIndex..<trimmedNextText.endIndex, in: trimmedNextText)
                    if regex.firstMatch(in: trimmedNextText, range: range) != nil {
                        logger.debug("❌ Next element is a header and starts with header marker: '\(trimmedNextText)'")
                        return false // This is a NEW header, not a continuation
                    }
                }
            }
            
            // Additional check for merged header patterns (e.g., "5.1等级保护对象3")
            // Check if the text starts with a number followed by a dot and another number
            let mergedHeaderPattern = "^\\d+\\.\\d+"
            if let regex = try? NSRegularExpression(pattern: mergedHeaderPattern) {
                let range = NSRange(trimmedNextText.startIndex..<trimmedNextText.endIndex, in: trimmedNextText)
                if regex.firstMatch(in: trimmedNextText, range: range) != nil {
                    logger.debug("❌ Next element is a header and starts with merged header pattern: '\(trimmedNextText)'")
                    return false // This is a NEW header, not a continuation
                }
            }
        }
        
        // DANGEROUS: Don't merge if next element starts with "本项要求包括："
        if trimmedNextText.hasPrefix("本项要求包括：") {
            logger.debug("❌ Next element starts with '本项要求包括：'")
            return false // This introduces a new list
        }
        
        // POSITIVE CONFIRMATION: Check if this looks like a sentence completion
        // This is the key improvement - actively confirm it's safe to merge
        
        // Note: Sentence completion check moved to earlier in the function for priority
        
        // Check if the continuation is very short and doesn't start with dangerous patterns
        if trimmedNextText.count <= 15 && !startsWithDangerousPattern(trimmedNextText) {
            logger.debug("✅ Short continuation without dangerous patterns")
            return true
        }
        
        // Check if starts with dangerous patterns
        if startsWithDangerousPattern(trimmedNextText) {
            logger.debug("❌ Starts with dangerous pattern: '\(trimmedNextText)'")
            return false
        }
        
        // SAFE: Next element doesn't start with dangerous markers
        logger.debug("✅ Safe continuation: '\(trimmedNextText)'")
        return true
    }
    
    /// Checks if the next element logically completes the current sentence
    private func isSentenceCompletion(_ current: DocumentElement, _ next: DocumentElement) -> Bool {
        guard let currentText = current.text, let nextText = next.text else { return false }
        
        let trimmedCurrent = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNext = nextText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if next element completes the sentence (has ending punctuation)
        let completionEndings = ["。", "；", "！", "？", ".", ";", "!", "?"]
        let nextEndsWithCompletion = completionEndings.contains { trimmedNext.hasSuffix($0) }
        
        // Check if next element is reasonably short (likely a completion, not a new sentence)
        let nextIsShort = trimmedNext.count <= 25
        
        // Check if next element doesn't start with dangerous patterns
        let startsWithDangerous = startsWithDangerousPattern(trimmedNext)
        
        // Check if current element appears incomplete (doesn't end with sentence-ending punctuation)
        // For non-header elements, if they don't end with sentence-ending punctuation, they're likely incomplete
        let currentEndings = ["。", "；", "！", "？", ".", ";", "!", "?"]
        let currentEndsWithCompletion = currentEndings.contains { trimmedCurrent.hasSuffix($0) }
        
        // Check if current element is a header (headers can end without punctuation)
        let isCurrentHeader = current.type == .header
        
        // Current appears incomplete if it doesn't end with sentence punctuation AND it's not a header
        let currentAppearsIncomplete = !currentEndsWithCompletion && !isCurrentHeader
        
        // Check if next element could logically continue the current sentence
        // This includes cases where the next element starts with characters that could complete a word
        let nextCouldContinue = !trimmedNext.isEmpty && !startsWithDangerous
        
        // It's a sentence completion if:
        // 1. Next ends with completion punctuation, AND
        // 2. Next is short, AND
        // 3. Next doesn't start with dangerous patterns, AND
        // 4. Current appears incomplete, AND
        // 5. Next could logically continue the sentence
        return nextEndsWithCompletion && nextIsShort && !startsWithDangerous && currentAppearsIncomplete && nextCouldContinue
    }
    
    /// Checks if text starts with dangerous patterns that indicate new content
    private func startsWithDangerousPattern(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for list item markers that indicate new content
        for pattern in config.listDetection.patterns.letteredMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
                if regex.firstMatch(in: trimmedText, range: range) != nil {
                    return true
                }
            }
        }
        
        // Check for specific phrases that introduce new lists
        let dangerousPhrases = ["本项要求包括："]
        for phrase in dangerousPhrases {
            if trimmedText.hasPrefix(phrase) {
                return true
            }
        }
        
        // Check for header markers that indicate new content
        // But be more lenient with patterns that might be part of a sentence
        for pattern in config.headerDetection.patterns.numberedHeaders {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
                if regex.firstMatch(in: trimmedText, range: range) != nil {
                    // Additional check: if the text is long, it might be part of a sentence
                    // rather than a standalone header
                    if trimmedText.count > 30 {
                        // Long text starting with header pattern might be descriptive text
                        // that should be merged, not a standalone header
                        continue
                    }
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Checks if an element is a header continuation (same line - tight tolerance)
    private func isHeaderContinuationSameLine(_ header: DocumentElement, _ continuation: DocumentElement) -> Bool {
        // Elements must be on the same page
        guard header.pageNumber == continuation.pageNumber else { return false }
        
        // Continuation should be on the same line as the header (using tight tolerance)
        let tolerance = CGFloat(config.headerDetection.sameLineTolerance) // 0.01 (1%)
        let verticalDistance = abs(header.boundingBox.minY - continuation.boundingBox.minY)
        guard verticalDistance <= tolerance else { return false }
        
        // Continuation should not be a complete sentence
        guard let continuationText = continuation.text else { return false }
        return !hasSentenceEnding(continuationText)
    }
    
    /// Checks if an element is a header continuation (multi-line - looser tolerance)
    private func isHeaderContinuationMultiLine(_ header: DocumentElement, _ continuation: DocumentElement) -> Bool {
        // Elements must be on the same page
        guard header.pageNumber == continuation.pageNumber else { return false }
        
        // Continuation should be reasonably close to the header (using looser tolerance)
        let tolerance: CGFloat = 0.03 // 3% tolerance for multi-line headers
        let verticalDistance = abs(header.boundingBox.minY - continuation.boundingBox.minY)
        guard verticalDistance <= tolerance else { return false }
        
        // Continuation should not be a complete sentence
        guard let continuationText = continuation.text else { return false }
        return !hasSentenceEnding(continuationText)
    }
    
    /// Legacy method for backward compatibility
    private func isHeaderContinuation(_ header: DocumentElement, _ continuation: DocumentElement) -> Bool {
        return isHeaderContinuationSameLine(header, continuation)
    }
    
    /// Checks if an element is a list item continuation (same line - tight tolerance)
    private func isListItemContinuationSameLine(_ listItem: DocumentElement, _ continuation: DocumentElement) -> Bool {
        // Elements must be on the same page
        guard listItem.pageNumber == continuation.pageNumber else { 
            logger.debug("Different pages: \(listItem.pageNumber) vs \(continuation.pageNumber)")
            return false 
        }
        
        // SIMPLIFIED: If elements are on the same line, merge without any other conditions
        let tolerance: CGFloat = 0.01 // 1% tolerance for same-line list items
        let verticalDistance = abs(listItem.boundingBox.minY - continuation.boundingBox.minY)
        
        logger.debug("Same-line check: distance=\(verticalDistance), tolerance=\(tolerance), withinTolerance=\(verticalDistance <= tolerance)")
        
        // Only check if they're on the same line - no other conditions
        return verticalDistance <= tolerance
    }
    
    /// Checks if an element is a list item continuation (multi-line - looser tolerance)
    private func isListItemContinuationMultiLine(_ listItem: DocumentElement, _ continuation: DocumentElement) -> Bool {
        // Elements must be on the same page
        guard listItem.pageNumber == continuation.pageNumber else { return false }
        
        // For list items, we allow multi-line continuations but with tighter control
        // to avoid merging separate list items that should stay separate
        let maxVerticalDistance: CGFloat = 0.02 // 2% tolerance for multi-line list items
        let verticalDistance = abs(listItem.boundingBox.minY - continuation.boundingBox.minY)
        guard verticalDistance <= maxVerticalDistance else { return false }
        
        // CRITICAL: Check if continuation starts with a new list item marker
        // If it does, it's a NEW list item, not a continuation
        guard let continuationText = continuation.text else { return false }
        let trimmedText = continuationText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // List item markers that indicate a NEW list item (not continuation)
        // Use configuration-based list detection patterns
        for pattern in config.listDetection.patterns.letteredMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
                if regex.firstMatch(in: trimmedText, range: range) != nil {
                    return false // This is a NEW list item, not a continuation
                }
            }
        }
        
        // ADDITIONAL SAFETY CHECK: Ensure the continuation is NOT a complete list item
        // This prevents merging two separate list items even if they're close vertically
        
        // Check if the continuation looks like a complete, independent list item
        if isCompleteListItem(trimmedText) {
            return false // This is a complete list item, not a continuation
        }
        
        // Continuation should not be a complete sentence
        return !hasSentenceEnding(trimmedText)
    }
    
    /// Legacy method for backward compatibility
    private func isListItemContinuation(_ listItem: DocumentElement, _ continuation: DocumentElement) -> Bool {
        return isListItemContinuationSameLine(listItem, continuation)
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
            metadata: mergedMetadata,
            headerLevel: firstElement.headerLevel
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
        
        // Normalize the merged text for better markdown output
        let normalizedText = normalizeListItemText(mergedText)
        
        return DocumentElement(
            id: firstElement.id,
            type: .listItem,
            boundingBox: mergedBoundingBox,
            contentData: Data(),
            confidence: mergedConfidence,
            pageNumber: firstElement.pageNumber,
            text: normalizedText,
            metadata: mergedMetadata,
            headerLevel: nil // List items don't have header levels
        )
    }
    
    /// Normalizes list item text by standardizing markers and spacing
    /// This addresses issues with Chinese characters and inconsistent spacing
    /// Only replaces the FIRST Chinese '）' that serves as the list marker separator
    public func normalizeListItemText(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern to match list item markers and split into (marker, content)
        // This handles various formats:
        // - a) content
        // - a） content  
        // - a〉 content
        // - 1. content
        // - 1） content
        // - 甲 content
        // - • content
        let markerPattern = #"^([a-zA-Z0-9一二三四五六七八九十甲乙丙丁戊己庚辛壬癸•\-\*])\s*[）\)〉\.\-\*]\s*(.*)$"#
        
        guard let regex = try? NSRegularExpression(pattern: markerPattern, options: []) else {
            return trimmedText // Return original if regex fails
        }
        
        let nsString = trimmedText as NSString
        let matches = regex.matches(in: trimmedText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        guard let match = matches.first else {
            return trimmedText // No marker pattern found, return original
        }
        
        // Extract marker and content
        let markerRange = match.range(at: 1)
        let contentRange = match.range(at: 2)
        
        guard markerRange.location != NSNotFound && contentRange.location != NSNotFound else {
            return trimmedText
        }
        
        let marker = nsString.substring(with: markerRange).trimmingCharacters(in: .whitespacesAndNewlines)
        let content = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize the marker format based on type
        let normalizedMarker: String
        if marker.range(of: #"^[一二三四五六七八九十]+$"#, options: .regularExpression) != nil {
            // Chinese numerals - keep as is
            normalizedMarker = marker
        } else if marker.range(of: #"^[甲乙丙丁戊己庚辛壬癸]+$"#, options: .regularExpression) != nil {
            // Chinese letters - keep as is  
            normalizedMarker = marker
        } else if marker.range(of: #"^[a-zA-Z]+$"#, options: .regularExpression) != nil {
            // English letters - use English parenthesis
            normalizedMarker = "\(marker))"
        } else if marker.range(of: #"^\d+$"#, options: .regularExpression) != nil {
            // Numbers - use English parenthesis
            normalizedMarker = "\(marker))"
        } else {
            // Other markers (bullets, etc.) - keep as is
            normalizedMarker = marker
        }
        
        // Combine with exactly one space between marker and content
        // The content preserves any additional Chinese '）' characters that are part of the text
        return "\(normalizedMarker) \(content)"
    }
    
    /// Normalize TOC item text by removing page numbers at the end
    public func normalizeTOCItemText(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern to match: content followed by optional spaces and a page number at the end
        // This will remove the page number and trailing spaces
        let pattern = "^(.+?)\\s*\\d+\\s*$"
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
            if let match = regex.firstMatch(in: trimmedText, range: range) {
                let contentRange = Range(match.range(at: 1), in: trimmedText)!
                let content = String(trimmedText[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                return content
            }
        }
        
        // If no pattern match, return original text
        return trimmedText
    }
    
    /// Normalizes all TOC item elements in a collection
    public func normalizeAllTOCItems(_ elements: [DocumentElement]) -> [DocumentElement] {
        var normalizedElements = elements.map { element in
            if element.type == .header, let text = element.text {
                let normalizedText = normalizeTOCItemText(text)
                return DocumentElement(
                    id: element.id,
                    type: element.type,
                    boundingBox: element.boundingBox,
                    contentData: element.contentData,
                    confidence: element.confidence,
                    pageNumber: element.pageNumber,
                    text: normalizedText,
                    metadata: element.metadata,
                    headerLevel: element.headerLevel
                )
            }
            return element
        }
        
        // Post-process to fix missing header numbers in TOC pages
        normalizedElements = fixMissingHeaderNumbers(normalizedElements)
        
        return normalizedElements
    }
    
    /// Fixes missing header numbers in TOC pages by analyzing context
    private func fixMissingHeaderNumbers(_ elements: [DocumentElement]) -> [DocumentElement] {
        var fixedElements = elements
        
        for i in 0..<fixedElements.count {
            let currentElement = fixedElements[i]
            
            // Only process header elements
            guard currentElement.type == .header, let currentText = currentElement.text else { continue }
            
            // Check if current element is missing a header number (doesn't start with a number)
            if !currentText.matches(pattern: "^\\d+(\\.\\d+)*\\s") {
                // Look for the expected header number based on surrounding context
                if let expectedNumber = predictMissingHeaderNumber(at: i, in: fixedElements) {
                    let fixedText = "\(expectedNumber) \(currentText)"
                    logger.info("Fixed missing header number: '\(currentText)' → '\(fixedText)'")
                    
                    fixedElements[i] = DocumentElement(
                        id: currentElement.id,
                        type: currentElement.type,
                        boundingBox: currentElement.boundingBox,
                        contentData: currentElement.contentData,
                        confidence: currentElement.confidence,
                        pageNumber: currentElement.pageNumber,
                        text: fixedText,
                        metadata: currentElement.metadata,
                        headerLevel: currentElement.headerLevel
                    )
                }
            }
        }
        
        return fixedElements
    }
    
    /// Predicts the missing header number based on surrounding context
    private func predictMissingHeaderNumber(at index: Int, in elements: [DocumentElement]) -> String? {
        // Look at previous and next header elements to determine the pattern
        var previousNumber: String?
        var nextNumber: String?
        
        // Find the previous header with a number
        for i in (0..<index).reversed() {
            if let element = elements[safe: i], 
               element.type == .header, 
               let text = element.text,
               let number = extractHeaderNumber(from: text) {
                previousNumber = number
                break
            }
        }
        
        // Find the next header with a number
        for i in (index + 1)..<elements.count {
            if let element = elements[safe: i], 
               element.type == .header, 
               let text = element.text,
               let number = extractHeaderNumber(from: text) {
                nextNumber = number
                break
            }
        }
        
        // Predict the missing number based on context
        if let prev = previousNumber, let next = nextNumber {
            return predictNumberBetween(prev, next)
        } else if let prev = previousNumber {
            return predictNextNumber(prev)
        } else if let next = nextNumber {
            return predictPreviousNumber(next)
        }
        
        return nil
    }
    
    /// Extracts header number from text (e.g., "5.1 等级保护对象" → "5.1")
    private func extractHeaderNumber(from text: String) -> String? {
        let pattern = "^(\\d+(\\.\\d+)*)\\s"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        
        let numberRange = Range(match.range(at: 1), in: text)!
        return String(text[numberRange])
    }
    
    /// Predicts the number between two given numbers
    private func predictNumberBetween(_ prev: String, _ next: String) -> String? {
        // Handle simple increment (e.g., "5.1" → "5.2" → "5.3")
        if let prevBase = extractBaseNumber(prev),
           let nextBase = extractBaseNumber(next),
           prevBase == nextBase,
           let prevSuffix = extractSuffix(prev),
           let nextSuffix = extractSuffix(next),
           let prevSuffixInt = Int(prevSuffix),
           let nextSuffixInt = Int(nextSuffix),
           nextSuffixInt == prevSuffixInt + 1 {
            return "\(prevBase).\(prevSuffixInt + 1)"
        }
        
        return nil
    }
    
    /// Predicts the next number in sequence
    private func predictNextNumber(_ current: String) -> String? {
        if let base = extractBaseNumber(current),
           let suffix = extractSuffix(current),
           let suffixInt = Int(suffix) {
            return "\(base).\(suffixInt + 1)"
        }
        return nil
    }
    
    /// Predicts the previous number in sequence
    private func predictPreviousNumber(_ current: String) -> String? {
        if let base = extractBaseNumber(current),
           let suffix = extractSuffix(current),
           let suffixInt = Int(suffix),
           suffixInt > 1 {
            return "\(base).\(suffixInt - 1)"
        }
        return nil
    }
    
    /// Extracts base number (e.g., "5.1" → "5")
    private func extractBaseNumber(_ number: String) -> String? {
        let components = number.components(separatedBy: ".")
        return components.first
    }
    
    /// Extracts suffix number (e.g., "5.1" → "1")
    private func extractSuffix(_ number: String) -> String? {
        let components = number.components(separatedBy: ".")
        return components.count > 1 ? components.last : nil
    }
    
    /// Optimized list item normalization with intelligent marker alignment and formatting
    /// This handles both ordered (a, b, c) and unordered (*, +, •) lists with OCR error correction
    public func normalizeAllListItems(_ elements: [DocumentElement]) -> [DocumentElement] {
        return processListItems(elements)
    }
    
    /// Comprehensive list item processing with three-step approach:
    /// 1. Detect and categorize list items (ordered vs unordered)
    /// 2. Align markers for ordered lists using context
    /// 3. Unify formatting for consistent output
    private func processListItems(_ elements: [DocumentElement]) -> [DocumentElement] {
        // Step 1: Detect and categorize list items
        let categorizedElements = categorizeListItems(elements)
        
        // Step 2: Process ordered lists with alignment
        let processedOrdered = processOrderedLists(categorizedElements.ordered)
        
        // Step 3: Process unordered lists with consistent markers
        let processedUnordered = processUnorderedLists(categorizedElements.unordered)
        
        // Step 4: Merge back with non-list items
        return mergeProcessedLists(processedOrdered, processedUnordered, categorizedElements.others)
    }
    
    private struct CategorizedElements {
        let ordered: [DocumentElement]    // a, b, c or 1, 2, 3
        let unordered: [DocumentElement]  // *, +, =, •
        let others: [DocumentElement]     // Non-list items
    }
    
    private func categorizeListItems(_ elements: [DocumentElement]) -> CategorizedElements {
        var ordered: [DocumentElement] = []
        var unordered: [DocumentElement] = []
        var others: [DocumentElement] = []
        
        for element in elements {
            if let text = element.text {
                if isOrderedListItem(text) {
                    ordered.append(element)
                } else if isUnorderedListItem(text) {
                    unordered.append(element)
                } else {
                    others.append(element)
                }
            } else {
                others.append(element)
            }
        }
        
        return CategorizedElements(ordered: ordered, unordered: unordered, others: others)
    }
    
    private func isOrderedListItem(_ text: String) -> Bool {
        // First check if this looks like a header (contains version numbers or multi-part numbering)
        if isLikelyHeader(text) {
            return false
        }
        
        // Use configuration-based patterns for numbered markers
        for pattern in config.listDetection.patterns.numberedMarkers {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Use configuration-based patterns for lettered markers
        for pattern in config.listDetection.patterns.letteredMarkers {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Use configuration-based patterns for Roman markers
        for pattern in config.listDetection.patterns.romanMarkers {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if text looks like a header rather than a list item
    private func isLikelyHeader(_ text: String) -> Bool {
        // Check for multi-part numbering like "8.1.10.5", "3.2.1", etc.
        if text.range(of: #"^\d+\.\d+(\.\d+)*"#, options: .regularExpression) != nil {
            return true
        }
        
        // Check for common header patterns with multiple words after the number
        if text.range(of: #"^\d+[\.）\)]\s*\w+\s+\w+"#, options: .regularExpression) != nil {
            return true
        }
        
        // Check for section-like patterns
        if text.range(of: #"^[第章节条款]\d+"#, options: .regularExpression) != nil {
            return true
        }
        
        return false
    }
    
    private func isUnorderedListItem(_ text: String) -> Bool {
        // Use configuration-based patterns for bullet markers
        for pattern in config.listDetection.patterns.bulletMarkers {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Use configuration-based patterns for custom markers
        for pattern in config.listDetection.patterns.customMarkers {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func processOrderedLists(_ elements: [DocumentElement]) -> [DocumentElement] {
        var processed: [DocumentElement] = []
        var previousMarkers: [String] = []
        
        // First pass: collect all markers for context
        let allMarkers = elements.compactMap { extractMarker(from: $0.text ?? "") }
        
        for (index, element) in elements.enumerated() {
            guard let text = element.text else {
                processed.append(element)
                continue
            }
            
            let currentMarker = extractMarker(from: text) ?? ""
            let nextMarker = index + 1 < allMarkers.count ? allMarkers[index + 1] : nil
            
            // Align marker using context
            let alignedMarker = alignOrderedMarker(
                currentMarker,
                previous: previousMarkers,
                next: nextMarker
            )
            
            // Unify format to ")"
            let unifiedText = unifyOrderedMarker(text, with: alignedMarker)
            
            let processedElement = DocumentElement(
                id: element.id,
                type: .listItem,
                boundingBox: element.boundingBox,
                contentData: element.contentData,
                confidence: element.confidence,
                pageNumber: element.pageNumber,
                text: unifiedText,
                metadata: element.metadata,
                headerLevel: element.headerLevel
            )
            
            processed.append(processedElement)
            previousMarkers.append(alignedMarker)
        }
        
        return processed
    }
    
    private func processUnorderedLists(_ elements: [DocumentElement]) -> [DocumentElement] {
        return elements.map { element in
            guard let text = element.text else { return element }
            
            // Convert all unordered markers to consistent "-" format
            let unifiedText = unifyUnorderedMarker(text)
            
            return DocumentElement(
                id: element.id,
                type: element.type,
                boundingBox: element.boundingBox,
                contentData: element.contentData,
                confidence: element.confidence,
                pageNumber: element.pageNumber,
                text: unifiedText,
                metadata: element.metadata,
                headerLevel: element.headerLevel
            )
        }
    }
    
    private func alignOrderedMarker(
        _ marker: String,
        previous: [String],
        next: String?
    ) -> String {
        // Handle duplicated characters (OCR errors like "gg" -> "g")
        if marker.count == 2 && marker.first == marker.last {
            let singleChar = String(marker.first!)
            
            // Find correct position in sequence
            if let aligned = findCorrectPosition(
                for: singleChar,
                between: previous,
                and: next
            ) {
                return aligned
            }
            
            return singleChar
        }
        
        return marker
    }
    
    private func findCorrectPosition(
        for char: String,
        between previousMarkers: [String],
        and nextMarker: String?
    ) -> String? {
        
        // Get the most recent previous marker
        let lastPrevious = previousMarkers.last
        
        // Determine the correct position in the sequence
        if let last = lastPrevious, let next = nextMarker {
            // We have both previous and next markers
            return findMiddlePosition(between: last, and: next)
        } else if let last = lastPrevious {
            // We only have previous marker - find next in sequence
            return getNextInSequence(after: last)
        } else if let next = nextMarker {
            // We only have next marker - find previous in sequence
            return getPreviousInSequence(before: next)
        }
        
        return nil
    }
    
    private func findMiddlePosition(between first: String, and second: String) -> String? {
        // Handle letter sequences: a < b < c
        if first.count == 1 && second.count == 1,
           let firstChar = first.first, let secondChar = second.first,
           firstChar.isLetter && secondChar.isLetter {
            
            let firstAscii = firstChar.asciiValue!
            let secondAscii = secondChar.asciiValue!
            
            // Check if there's exactly one character between them
            if secondAscii - firstAscii == 2 {
                let middleAscii = firstAscii + 1
                return String(Character(UnicodeScalar(middleAscii)))
            }
        }
        
        // Handle number sequences: 1 < 2 < 3
        if first.count == 1 && second.count == 1,
           let firstChar = first.first, let secondChar = second.first,
           firstChar.isNumber && secondChar.isNumber {
            
            let firstAscii = firstChar.asciiValue!
            let secondAscii = secondChar.asciiValue!
            
            // Check if there's exactly one number between them
            if secondAscii - firstAscii == 2 {
                let middleAscii = firstAscii + 1
                return String(Character(UnicodeScalar(middleAscii)))
            }
        }
        
        return nil
    }
    
    private func getNextInSequence(after marker: String) -> String? {
        // Handle letter sequences: a -> b -> c -> ...
        if marker.count == 1, let char = marker.first, char.isLetter {
            let nextChar = Character(UnicodeScalar(char.asciiValue! + 1))
            return String(nextChar)
        }
        
        // Handle number sequences: 1 -> 2 -> 3 -> ...
        if marker.count == 1, let char = marker.first, char.isNumber {
            let nextChar = Character(UnicodeScalar(char.asciiValue! + 1))
            return String(nextChar)
        }
        
        return nil
    }
    
    private func getPreviousInSequence(before marker: String) -> String? {
        // Handle letter sequences: ... -> a -> b -> c
        if marker.count == 1, let char = marker.first, char.isLetter {
            let prevChar = Character(UnicodeScalar(char.asciiValue! - 1))
            return String(prevChar)
        }
        
        // Handle number sequences: ... -> 1 -> 2 -> 3
        if marker.count == 1, let char = marker.first, char.isNumber {
            let prevChar = Character(UnicodeScalar(char.asciiValue! - 1))
            return String(prevChar)
        }
        
        return nil
    }
    
    private func unifyOrderedMarker(_ text: String, with marker: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to match against configuration patterns and replace with unified format
        
        // Try numbered markers
        for pattern in config.listDetection.patterns.numberedMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let beforeMarker = String(trimmedText[..<Range(match.range, in: trimmedText)!.lowerBound])
                let afterMarker = String(trimmedText[Range(match.range, in: trimmedText)!.upperBound...])
                return "\(beforeMarker)\(marker)) \(afterMarker)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Try lettered markers
        for pattern in config.listDetection.patterns.letteredMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let beforeMarker = String(trimmedText[..<Range(match.range, in: trimmedText)!.lowerBound])
                let afterMarker = String(trimmedText[Range(match.range, in: trimmedText)!.upperBound...])
                return "\(beforeMarker)\(marker)) \(afterMarker)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Try Roman markers
        for pattern in config.listDetection.patterns.romanMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let beforeMarker = String(trimmedText[..<Range(match.range, in: trimmedText)!.lowerBound])
                let afterMarker = String(trimmedText[Range(match.range, in: trimmedText)!.upperBound...])
                return "\(beforeMarker)\(marker)) \(afterMarker)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If no pattern matches, return original text
        return text
    }
    
    private func unifyUnorderedMarker(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try bullet markers from configuration
        for pattern in config.listDetection.patterns.bulletMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let beforeMarker = String(trimmedText[..<Range(match.range, in: trimmedText)!.lowerBound])
                let afterMarker = String(trimmedText[Range(match.range, in: trimmedText)!.upperBound...])
                return "\(beforeMarker)- \(afterMarker)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Try custom markers from configuration
        for pattern in config.listDetection.patterns.customMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let beforeMarker = String(trimmedText[..<Range(match.range, in: trimmedText)!.lowerBound])
                let afterMarker = String(trimmedText[Range(match.range, in: trimmedText)!.upperBound...])
                return "\(beforeMarker)- \(afterMarker)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If no pattern matches, return original text
        return text
    }
    
    private func mergeProcessedLists(
        _ ordered: [DocumentElement],
        _ unordered: [DocumentElement],
        _ others: [DocumentElement]
    ) -> [DocumentElement] {
        // Merge all elements back together
        var result: [DocumentElement] = []
        result.append(contentsOf: ordered)
        result.append(contentsOf: unordered)
        result.append(contentsOf: others)
        
        // Sort by original position (page number and Y coordinate)
        return result.sorted { first, second in
            if first.pageNumber != second.pageNumber {
                return first.pageNumber < second.pageNumber
            }
            return first.boundingBox.minY < second.boundingBox.minY
        }
    }
    
    /// Extracts the marker from list item text using configuration patterns
    private func extractMarker(from text: String) -> String? {
        // Skip header-like text
        if isLikelyHeader(text) {
            return nil
        }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try numbered markers from configuration
        for pattern in config.listDetection.patterns.numberedMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let markerText = String(trimmedText[Range(match.range, in: trimmedText)!])
                // Extract just the alphanumeric part (remove punctuation and spaces)
                if let marker = extractAlphanumericMarker(from: markerText) {
                    return marker
                }
            }
        }
        
        // Try lettered markers from configuration
        for pattern in config.listDetection.patterns.letteredMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let markerText = String(trimmedText[Range(match.range, in: trimmedText)!])
                // Extract just the alphanumeric part (remove punctuation and spaces)
                if let marker = extractAlphanumericMarker(from: markerText) {
                    // Handle OCR errors like "gg" -> "g"
                    return handleOCRErrors(in: marker)
                }
            }
        }
        
        // Try Roman markers from configuration
        for pattern in config.listDetection.patterns.romanMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let markerText = String(trimmedText[Range(match.range, in: trimmedText)!])
                if let marker = extractAlphanumericMarker(from: markerText) {
                    return marker
                }
            }
        }
        
        // Try bullet/custom markers from configuration
        for pattern in config.listDetection.patterns.bulletMarkers + config.listDetection.patterns.customMarkers {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmedText, options: [], range: NSRange(trimmedText.startIndex..., in: trimmedText)) {
                let markerText = String(trimmedText[Range(match.range, in: trimmedText)!])
                return markerText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    /// Extracts alphanumeric marker from matched text
    private func extractAlphanumericMarker(from text: String) -> String? {
        // Extract letters and numbers only
        if let match = text.range(of: #"[a-zA-Z0-9]+"#, options: .regularExpression) {
            return String(text[match])
        }
        return nil
    }
    
    /// Handles OCR errors in markers like "gg" -> "g"
    private func handleOCRErrors(in marker: String) -> String {
        // Handle duplicated single character (OCR error)
        if marker.count == 2 && marker.first == marker.last {
            return String(marker.first!)
        }
        return marker
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
        let sentenceEndings = [".", "!", "?", "。", "！", "？", "；", ";"]
        return sentenceEndings.contains { text.hasSuffix($0) }
    }
    
    /// Checks if text contains common header keywords
    private func containsHeaderKeywords(_ text: String) -> Bool {
        let headerKeywords = ["introduction", "conclusion", "summary", "overview", "background", "method", "results", "discussion", "appendix", "references", "bibliography"]
        let lowercasedText = text.lowercased()
        return headerKeywords.contains { lowercasedText.contains($0) }
    }
    
    /// Checks if text appears to be a complete, independent list item
    private func isCompleteListItem(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // A complete list item typically:
        // 1. Has reasonable length (not too short, not too long)
        // 2. Ends with punctuation that suggests completion
        // 3. Has a logical structure
        
        // Check length - very short text is likely incomplete
        if trimmedText.count < 10 {
            return false
        }
        
        // Check if it ends with completion punctuation
        let completionPunctuation = ["。", "；", "！", "？", ".", ";", "!", "?"]
        let endsWithCompletion = completionPunctuation.contains { trimmedText.hasSuffix($0) }
        
        // Check if it has a logical structure (contains key words that suggest completeness)
        let completenessIndicators = ["应", "必须", "需要", "要求", "确保", "保证", "提供", "实现", "支持", "具备", "具有", "采用", "使用", "配置", "启用", "设置", "建立", "维护", "保护", "检测", "监控", "记录", "备份", "恢复"]
        let hasCompletenessIndicators = completenessIndicators.contains { trimmedText.contains($0) }
        
        // Consider it complete if it ends with completion punctuation AND has logical structure
        return endsWithCompletion && hasCompletenessIndicators
    }
    
    /// Detects if an element appears to be a sentence continuation
    private func isSentenceContinuation(_ element: DocumentElement) -> Bool {
        guard let text = element.text else { return false }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for continuation patterns:
        // 1. Starts with continuation words like "且", "并", "或", etc.
        // 2. Very short text that doesn't form a complete thought
        // 3. Ends with continuation punctuation like "、", "，", "且"
        
        let continuationWords = ["且", "并", "或", "而", "但", "则", "就", "才", "也", "还", "又", "更"]
        let continuationPunctuation = ["、", "，", "且", "和", "与", "及"]
        
        // Check if starts with continuation word
        for word in continuationWords {
            if trimmedText.hasPrefix(word) {
                return true
            }
        }
        
        // Check if starts with lowercase (continues previous sentence)
        if let firstChar = trimmedText.first, firstChar.isLowercase {
            return true
        }
        
        // Check if ends with continuation punctuation
        for punct in continuationPunctuation {
            if trimmedText.hasSuffix(punct) {
                return true
            }
        }
        
        // Check if very short and doesn't end with sentence-ending punctuation
        if trimmedText.count < 20 && !hasSentenceEnding(trimmedText) {
            return true
        }
        
        return false
    }
    
    /// Determines if two elements should be merged as sentences
    private func shouldMergeSentences(_ element1: DocumentElement, _ element2: DocumentElement) -> Bool {
        // Elements must be on the same page
        guard element1.pageNumber == element2.pageNumber else { return false }
        
        // For sentences, we allow multi-line continuations with reasonable distance
        let maxVerticalDistance: CGFloat = 0.08 // 8% tolerance for sentence merging
        let verticalDistance = abs(element1.boundingBox.minY - element2.boundingBox.minY)
        guard verticalDistance <= maxVerticalDistance else { return false }
        
        // Check if element1 ends with continuation indicators
        guard let text1 = element1.text else { return false }
        let trimmedText1 = text1.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let continuationEndings = ["且", "和", "与", "及", "、", "，", "或", "而"]
        let hasContinuationEnding = continuationEndings.contains { trimmedText1.hasSuffix($0) }
        
        // Check if element2 starts with continuation indicators
        guard let text2 = element2.text else { return false }
        let trimmedText2 = text2.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let continuationStartings = ["且", "并", "或", "而", "但", "则", "就", "才", "也", "还", "又", "更"]
        let hasContinuationStarting = continuationStartings.contains { trimmedText2.hasPrefix($0) }
        
        // Merge if either has continuation indicators
        return hasContinuationEnding || hasContinuationStarting
    }
    
    /// Merges two sentence elements
    private func mergeSentenceElements(_ element1: DocumentElement, _ element2: DocumentElement) -> DocumentElement {
        let combinedText = (element1.text ?? "") + (element2.text ?? "")
        
        // Create merged bounding box
        let mergedBoundingBox = CGRect(
            x: min(element1.boundingBox.minX, element2.boundingBox.minX),
            y: min(element1.boundingBox.minY, element2.boundingBox.minY),
            width: max(element1.boundingBox.maxX, element2.boundingBox.maxX) - min(element1.boundingBox.minX, element2.boundingBox.minX),
            height: max(element1.boundingBox.maxY, element2.boundingBox.maxY) - min(element1.boundingBox.minY, element2.boundingBox.minY)
        )
        
        return DocumentElement(
            type: element1.type, // Keep the type of the first element
            boundingBox: mergedBoundingBox,
            contentData: Data(),
            confidence: min(element1.confidence, element2.confidence), // Use lower confidence
            pageNumber: element1.pageNumber,
            text: combinedText,
            metadata: element1.metadata.merging(element2.metadata) { _, new in new },
            headerLevel: element1.headerLevel
        )
    }
    
    /// Checks if text starts with common list indicators
    private func startsWithListIndicator(_ text: String) -> Bool {
        let listIndicators = ["-", "•", "·", "▪", "▫", "◦", "‣", "⁃"]
        return listIndicators.contains { text.hasPrefix($0) }
    }
    
    /// Checks if text contains Chinese characters
    private func containsChineseCharacters(_ text: String) -> Bool {
        let chineseCharacterPattern = "[\\p{Script=Han}]"
        return text.range(of: chineseCharacterPattern, options: .regularExpression) != nil
    }
    
    /// Optimizes cross-page sentences by redistributing content between consecutive pages
    /// This method moves incomplete sentences from the end of one page to the beginning of the next page
    /// to create complete, self-contained sentences on each page.
    /// CRITICAL: Skips optimization when TOC pages are involved to preserve TOC structure
    public func optimizeCrossPageSentences(
        currentPage: [DocumentElement],
        nextPage: [DocumentElement],
        currentPageNumber: Int,
        nextPageNumber: Int
    ) async throws -> (optimizedCurrentPage: [DocumentElement], optimizedNextPage: [DocumentElement]) {
        
        guard !currentPage.isEmpty else {
            return (currentPage, nextPage)
        }
        
        // CRITICAL: Check if either page is a TOC page before applying cross-page optimization
        let currentPageHeaderRatio = calculateHeaderRatio(currentPage)
        let nextPageHeaderRatio = calculateHeaderRatio(nextPage)
        
        // If either page has high header ratio (likely TOC), skip cross-page optimization
        if currentPageHeaderRatio >= 0.9 || nextPageHeaderRatio >= 0.9 {
            logger.info("TOC page detected (current: \(String(format: "%.1f", currentPageHeaderRatio * 100))%, next: \(String(format: "%.1f", nextPageHeaderRatio * 100))%) - skipping cross-page optimization to preserve TOC structure")
            return (currentPage, nextPage)
        }
        
        var optimizedCurrentPage = currentPage
        var optimizedNextPage = nextPage
        
        // Find the last element of the current page
        guard let lastCurrentElement = currentPage.last else {
            return (currentPage, nextPage)
        }
        
        // Check if the last element of current page is an incomplete sentence
        if isIncompleteSentence(lastCurrentElement) {
            logger.debug("Found incomplete sentence at end of page \(currentPageNumber): '\(lastCurrentElement.text ?? "")'")
            
            // Look for sentence continuation at the beginning of the next page
            if let firstNextElement = nextPage.first {
                if isSafeSentenceContinuation(lastCurrentElement, firstNextElement) {
                    logger.debug("Found sentence continuation at beginning of page \(nextPageNumber): '\(firstNextElement.text ?? "")'")
                    
                    // Merge the incomplete sentence with its continuation
                    let mergedText = (lastCurrentElement.text ?? "") + (firstNextElement.text ?? "")
                    
                    // Create a merged element that spans both pages
                    let mergedBoundingBox = lastCurrentElement.boundingBox.union(firstNextElement.boundingBox)
                    
                    let mergedElement = DocumentElement(
                        type: lastCurrentElement.type,
                        boundingBox: mergedBoundingBox,
                        contentData: Data(),
                        confidence: min(lastCurrentElement.confidence, firstNextElement.confidence),
                        pageNumber: currentPageNumber, // Keep it on the current page
                        text: mergedText,
                        metadata: lastCurrentElement.metadata.merging(firstNextElement.metadata) { _, new in new },
                        headerLevel: lastCurrentElement.headerLevel
                    )
                    
                    // Replace the last element of current page with the merged element
                    optimizedCurrentPage[optimizedCurrentPage.count - 1] = mergedElement
                    
                    // Remove the continuation element from the next page
                    optimizedNextPage.removeFirst()
                    
                    logger.info("Successfully merged cross-page sentence: '\(mergedText)'")
                }
            }
        }
        
        return (optimizedCurrentPage, optimizedNextPage)
    }
    
    /// Calculates the header ratio for a page to determine if it's likely a TOC page
    private func calculateHeaderRatio(_ elements: [DocumentElement]) -> Float {
        let headerCount = elements.filter { $0.type == .header || $0.type == .tocItem }.count
        let totalElements = elements.count
        return totalElements > 0 ? Float(headerCount) / Float(totalElements) : 0.0
    }
    
    // MARK: - Page-Level Header Optimization
    
    /// Optimizes headers and list items on a page by analyzing alignment and filtering false positives
    /// This is the main entry point for page-level alignment checking
    public func optimizePageHeaders(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard !elements.isEmpty else { return elements }
        
        // Group elements by page number
        let pageGroups = Dictionary(grouping: elements) { $0.pageNumber }
        
        var optimizedElements: [DocumentElement] = []
        
        for (pageNumber, pageElements) in pageGroups.sorted(by: { $0.key < $1.key }) {
            let optimizedPageElements = await optimizePageElementsWithAlignmentChecking(pageElements, pageNumber: pageNumber)
            optimizedElements.append(contentsOf: optimizedPageElements)
        }
        
        return optimizedElements
    }
    
    /// Comprehensive page-level alignment checking for both headers and list items
    /// This method identifies false headers and list items and converts them to paragraphs
    public func optimizePageElementsWithAlignmentChecking(_ elements: [DocumentElement], pageNumber: Int) async -> [DocumentElement] {
        logger.info("🔍 PAGE-LEVEL ALIGNMENT CHECKING - Page \(pageNumber): Starting with \(elements.count) elements")
        
        // Step 1: Analyze page context for header alignment
        let pageContext = analyzePageHeaderContext(elements)
        logger.info("🔍 PAGE-LEVEL ALIGNMENT CHECKING - Page \(pageNumber): Page context analyzed")
        
        // Step 2: Identify and convert false headers
        var optimizedElements = elements
        var hasFalseHeaderConversion = false
        
        for (index, element) in optimizedElements.enumerated() {
            if element.type == .header {
                // Check if this is a false header using context-aware detection
                if let text = element.text, isFalseHeaderInContext(text, pageContext: pageContext) {
                    logger.info("🔍 PAGE-LEVEL ALIGNMENT CHECKING - Converting false header to paragraph: '\(text)'")
                    optimizedElements[index] = DocumentElement(
                        id: element.id,
                        type: .paragraph,
                        boundingBox: element.boundingBox,
                        contentData: element.contentData,
                        confidence: element.confidence,
                        pageNumber: element.pageNumber,
                        text: element.text,
                        metadata: element.metadata,
                        headerLevel: nil
                    )
                    hasFalseHeaderConversion = true
                }
            }
        }
        
        // Step 3: Identify and convert false list items
        var hasFalseListItemConversion = false
        
        for (index, element) in optimizedElements.enumerated() {
            if element.type == .listItem {
                // Check if this is a false list item using context-aware detection
                if let text = element.text, isFalseListItemInContext(text, pageContext: pageContext) {
                    logger.info("🔍 PAGE-LEVEL ALIGNMENT CHECKING - Converting false list item to paragraph: '\(text)'")
                    optimizedElements[index] = DocumentElement(
                        id: element.id,
                        type: .paragraph,
                        boundingBox: element.boundingBox,
                        contentData: element.contentData,
                        confidence: element.confidence,
                        pageNumber: element.pageNumber,
                        text: element.text,
                        metadata: element.metadata,
                        headerLevel: nil
                    )
                    hasFalseListItemConversion = true
                }
            }
        }
        
        // Step 4: Run multi-line optimization if any conversions were made
        if hasFalseHeaderConversion || hasFalseListItemConversion {
            logger.info("🔍 PAGE-LEVEL ALIGNMENT CHECKING - Running multi-line optimization after alignment corrections on page \(pageNumber)")
            optimizedElements = await mergeSplitSentencesConservative(optimizedElements)
        }
        
        logger.info("🔍 PAGE-LEVEL ALIGNMENT CHECKING - Page \(pageNumber): Completed with \(optimizedElements.count) elements")
        return optimizedElements
    }
    
    /// Optimizes headers on a single page by analyzing numbering patterns
    private func optimizeHeadersOnPage(_ elements: [DocumentElement], pageNumber: Int) async -> [DocumentElement] {
        logger.info("🔍 OPTIMIZE PAGE HEADERS - Page \(pageNumber): Starting with \(elements.count) elements")
        
        // Extract headers from the page
        let headers = elements.filter { $0.type == .header }
        
        logger.info("🔍 OPTIMIZE PAGE HEADERS - Page \(pageNumber): Found \(headers.count) headers")
        for (index, header) in headers.enumerated() {
            logger.info("  Header \(index): '\(header.text ?? "")'")
        }
        
        guard headers.count > 1 else { return elements }
        
        // Create page context for context-aware header validation
        let pageContext = analyzePageHeaderContext(elements)
        
        // Filter out false headers using context-aware detection
        let optimizedHeaders = filterFalseHeadersWithContext(headers, pageContext: pageContext)
        
        // Replace headers in the original elements
        var optimizedElements = elements
        var hasFalseHeaderConversion = false
        
        for (index, element) in optimizedElements.enumerated() {
            if element.type == .header {
                if let optimizedHeader = optimizedHeaders.first(where: { $0.id == element.id }) {
                    optimizedElements[index] = optimizedHeader
                } else {
                    // Convert false header back to paragraph
                    logger.info("🔍 OPTIMIZE PAGE HEADERS - Converting false header to paragraph: '\(element.text ?? "")'")
                    optimizedElements[index] = DocumentElement(
                        id: element.id,
                        type: .paragraph,
                        boundingBox: element.boundingBox,
                        contentData: element.contentData,
                        confidence: element.confidence,
                        pageNumber: element.pageNumber,
                        text: element.text,
                        metadata: element.metadata,
                        headerLevel: nil
                    )
                    logger.info("Converted false header to paragraph on page \(pageNumber): '\(element.text ?? "")'")
                    hasFalseHeaderConversion = true
                }
            }
        }
        
        // If we converted any false headers to paragraphs, run multi-line optimization again
        if hasFalseHeaderConversion {
            logger.info("🔍 OPTIMIZE PAGE HEADERS - Running multi-line optimization after false header conversion on page \(pageNumber)")
            optimizedElements = await mergeSplitSentencesConservative(optimizedElements)
        }
        
        return optimizedElements
    }
    
    /// Analyzes header numbering patterns on a page
    private func analyzeHeaderNumbering(_ headers: [DocumentElement]) -> HeaderNumberingAnalysis {
        var numberedHeaders: [(element: DocumentElement, number: String, level: Int)] = []
        
        for header in headers {
            if let text = header.text,
               let number = extractHeaderNumber(text) {
                numberedHeaders.append((header, number, header.headerLevel ?? 1))
            }
        }
        
        // Group by header level
        let levelGroups = Dictionary(grouping: numberedHeaders) { $0.level }
        
        var analysis = HeaderNumberingAnalysis()
        
        for (level, headers) in levelGroups {
            let numbers = headers.map { $0.number }.sorted()
            analysis.levelPatterns[level] = analyzeNumberSequence(numbers)
        }
        
        return analysis
    }
    
    /// Extracts the header number from text
    private func extractHeaderNumber(_ text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to match numbered header patterns
        for pattern in config.headerDetection.patterns.numberedHeaders {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(trimmedText.startIndex..<trimmedText.endIndex, in: trimmedText)
                if let match = regex.firstMatch(in: trimmedText, range: range) {
                    let matchRange = Range(match.range, in: trimmedText)!
                    let matchText = String(trimmedText[matchRange])
                    // Extract just the number part
                    if let numberMatch = matchText.range(of: "^\\d+(?:\\.\\d+)*", options: .regularExpression) {
                        return String(matchText[numberMatch])
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Analyzes a sequence of numbers to detect patterns and anomalies
    private func analyzeNumberSequence(_ numbers: [String]) -> NumberSequenceAnalysis {
        var analysis = NumberSequenceAnalysis()
        
        guard numbers.count > 1 else {
            analysis.isConsistent = true
            return analysis
        }
        
        // Convert to integers for analysis (handle simple numbers first)
        var integerNumbers: [Int] = []
        for number in numbers {
            if let intValue = Int(number) {
                integerNumbers.append(intValue)
            }
        }
        
        guard integerNumbers.count > 1 else {
            analysis.isConsistent = true
            return analysis
        }
        
        // Sort for analysis
        integerNumbers.sort()
        
        // Check for consistent increment
        var differences: [Int] = []
        for i in 1..<integerNumbers.count {
            differences.append(integerNumbers[i] - integerNumbers[i-1])
        }
        
        // If all differences are 1, it's a perfect sequence
        if differences.allSatisfy({ $0 == 1 }) {
            analysis.isConsistent = true
            analysis.expectedIncrement = 1
            analysis.missingNumbers = findMissingNumbers(integerNumbers)
        } else {
            // Check for consistent increment > 1
            let uniqueDifferences = Set(differences)
            if uniqueDifferences.count == 1, let increment = uniqueDifferences.first {
                analysis.isConsistent = true
                analysis.expectedIncrement = increment
                analysis.missingNumbers = findMissingNumbers(integerNumbers, increment: increment)
            } else {
                analysis.isConsistent = false
                analysis.outliers = findOutliers(integerNumbers, differences: differences)
            }
        }
        
        return analysis
    }
    
    /// Finds missing numbers in a sequence
    private func findMissingNumbers(_ numbers: [Int], increment: Int = 1) -> [Int] {
        guard numbers.count > 1 else { return [] }
        
        var missing: [Int] = []
        let min = numbers.min()!
        let max = numbers.max()!
        
        for i in stride(from: min, through: max, by: increment) {
            if !numbers.contains(i) {
                missing.append(i)
            }
        }
        
        return missing
    }
    
    /// Finds outliers in a sequence
    private func findOutliers(_ numbers: [Int], differences: [Int]) -> [Int] {
        guard differences.count > 1 else { return [] }
        
        // Calculate median difference
        let sortedDifferences = differences.sorted()
        let medianDifference = sortedDifferences[sortedDifferences.count / 2]
        
        // Find numbers that create unusual differences
        var outliers: [Int] = []
        for i in 0..<differences.count {
            if abs(differences[i] - medianDifference) > medianDifference {
                // This difference is significantly different from the median
                outliers.append(numbers[i + 1]) // The number that creates this difference
            }
        }
        
        return outliers
    }
    
    /// Filters out false headers based on context-aware analysis
    private func filterFalseHeadersWithContext(_ headers: [DocumentElement], pageContext: PageHeaderContext) -> [DocumentElement] {
        var filteredHeaders = headers
        
        for header in headers {
            guard let text = header.text else { continue }
            
            // Use the same context-aware logic as detectHeaderWithContext
            let isFalseHeader = isFalseHeaderInContext(text, pageContext: pageContext)
            
            if isFalseHeader {
                logger.info("🔍 OPTIMIZE PAGE HEADERS - Identified false header using context-aware detection: '\(text)'")
                filteredHeaders.removeAll { $0.id == header.id }
            }
        }
        
        return filteredHeaders
    }
    
    /// Checks if a header is false based on page context
    private func isFalseHeaderInContext(_ text: String, pageContext: PageHeaderContext) -> Bool {
        // Check if header numbering is misaligned with surrounding same-level headers
        if isHeaderNumberingMisaligned(text, pageContext: pageContext) {
            logger.debug("❌ Header numbering misaligned with context: '\(text)' on page \(pageContext.pageNumber)")
            return true
        }
        
        // Check if this is a descriptive text that shouldn't be a header
        if isDescriptiveText(text) {
            logger.debug("❌ Descriptive text detected as header: '\(text)'")
            return true
        }
        
        // Check if header is misaligned with page context
        if isHeaderMisalignedWithContext(text, pageContext: pageContext) {
            logger.debug("❌ Header misaligned with page context: '\(text)' on page \(pageContext.pageNumber)")
            return true
        }
        
        return false
    }
    
    /// Checks if a list item is false based on page context
    private func isFalseListItemInContext(_ text: String, pageContext: PageHeaderContext) -> Bool {
        // Check if this is a descriptive text that shouldn't be a list item
        if isDescriptiveText(text) {
            logger.debug("❌ Descriptive text detected as list item: '\(text)'")
            return true
        }
        
        // Check if list item is misaligned with page context
        if isListItemMisalignedWithContext(text, pageContext: pageContext) {
            logger.debug("❌ List item misaligned with page context: '\(text)' on page \(pageContext.pageNumber)")
            return true
        }
        
        return false
    }
    
    /// Checks if a header is misaligned with the page context
    private func isHeaderMisalignedWithContext(_ text: String, pageContext: PageHeaderContext) -> Bool {
        // Check for appendix context
        if pageContext.hasAppendixHeaders {
            // If we have appendix headers, check if this looks like a chapter header
            if matches(text, "^\\d+\\s+章") {
                logger.debug("❌ Chapter header detected in appendix context: '\(text)'")
                return true
            }
        }
        
        // Check for chapter context
        if pageContext.hasChapterHeaders {
            // If we have chapter headers, check if this looks like an appendix header
            if matches(text, "^附录[ABCDEFGHIJKLMNOPQRSTUVWXYZ]") {
                logger.debug("❌ Appendix header detected in chapter context: '\(text)'")
                return true
            }
        }
        
        // Check for named headers context
        if pageContext.hasNamedHeaders {
            // If we have named headers, check if this looks like a numbered header
            if matches(text, "^\\d+\\s+[\\u4e00-\\u9fff]") {
                logger.debug("❌ Numbered header detected in named header context: '\(text)'")
                return true
            }
        }
        
        return false
    }
    
    /// Checks if a list item is misaligned with the page context
    private func isListItemMisalignedWithContext(_ text: String, pageContext: PageHeaderContext) -> Bool {
        // Check if this is a descriptive text that looks like a list item but isn't
        // For example, text that starts with letters/numbers but is actually part of a sentence
        
        // Check if this is a standalone list item without proper context
        // This is a simplified check - in practice, you might want more sophisticated logic
        if text.count > 50 && !text.contains("。") && !text.contains(".") {
            // Long text without sentence endings might be descriptive text, not a list item
            logger.debug("❌ Long descriptive text detected as list item: '\(text)'")
            return true
        }
        
        return false
    }
    
    /// Checks if header numbering is misaligned with surrounding same-level headers
    private func isHeaderNumberingMisaligned(_ text: String, pageContext: PageHeaderContext) -> Bool {
        guard let currentMarker = extractHeaderMarker(text) else { return false }
        
        // Calculate the current header's level to only check against same-level headers
        let currentLevel = calculateHeaderLevel(from: text)
        
        // Only check the same level as the current header
        if let markers = pageContext.headerNumberingByLevel[currentLevel],
           markers.contains(currentMarker) {
            // DON'T sort markers - they should maintain their Y-position order
            // Only check if the current marker follows a logical sequence with nearby markers
            if let currentIndex = markers.firstIndex(of: currentMarker) {
                // Check if this marker follows a logical sequence with the previous marker
                if currentIndex > 0 {
                    let previousMarker = markers[currentIndex - 1]
                    if !isLogicalSequence(previousMarker, currentMarker) {
                        logger.debug("❌ Header numbering misaligned: '\(previousMarker)' -> '\(currentMarker)'")
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Extracts the header marker (number, letter, etc.) from header text
    private func extractHeaderMarker(_ text: String) -> String? {
        // Pattern for numbered headers: "3", "3.1", "3.1.2", etc.
        if let match = text.range(of: "^\\d+(?:\\.\\d+)*", options: .regularExpression) {
            return String(text[match])
        }
        
        // Pattern for lettered headers: "A", "A.1", "B", etc.
        if let match = text.range(of: "^[A-Z](?:\\.\\d+)*", options: .regularExpression) {
            return String(text[match])
        }
        
        // Pattern for year-like markers: "2016", "2020", etc.
        if let match = text.range(of: "^\\d{4}", options: .regularExpression) {
            return String(text[match])
        }
        
        return nil
    }
    
    /// Checks if two header markers form a logical sequence
    private func isLogicalSequence(_ previous: String, _ current: String) -> Bool {
        // For numbered sequences: "3" -> "3.1", "3.1" -> "3.2", etc.
        if previous.matches(pattern: "^\\d+(?:\\.\\d+)*$") && current.matches(pattern: "^\\d+(?:\\.\\d+)*$") {
            // Check if current is a logical next in sequence
            if current.hasPrefix(previous + ".") {
                return true
            }
            
            // Compute the comparable level (the level at which they should be compared)
            let prevComponents = previous.components(separatedBy: ".")
            let currComponents = current.components(separatedBy: ".")
            
            // The comparable level is the minimum of the two levels
            let comparableLevel = min(prevComponents.count, currComponents.count)
            
            // Compare at the comparable level
            if comparableLevel > 0 {
                let prevAtComparableLevel = prevComponents.prefix(comparableLevel).joined(separator: ".")
                let currAtComparableLevel = currComponents.prefix(comparableLevel).joined(separator: ".")
                
                // If they're the same at the comparable level, they're aligned
                if prevAtComparableLevel == currAtComparableLevel {
                    return true
                }
                
                // If they're different at the comparable level, check if current is the next logical sequence
                if comparableLevel <= prevComponents.count && comparableLevel <= currComponents.count {
                    // Compare the component at the comparable level
                    if let prevNum = Int(prevComponents[comparableLevel - 1]),
                       let currNum = Int(currComponents[comparableLevel - 1]) {
                        // Allow for reasonable gaps in numbering (e.g., 3.6 -> 3.8 is valid)
                        let gap = currNum - prevNum
                        return gap >= 1 && gap <= 5
                    }
                }
            }
            
            // Handle same level sequences (same number of components)
            if prevComponents.count == currComponents.count {
                // Check if all components except the last are the same
                let prefixMatch = zip(prevComponents.dropLast(), currComponents.dropLast()).allSatisfy { $0 == $1 }
                if prefixMatch {
                    // Check if the last component is incremented by 1
                    if let prevLast = Int(prevComponents.last ?? ""),
                       let currLast = Int(currComponents.last ?? "") {
                        // Allow for reasonable gaps in numbering (e.g., 3.6 -> 3.8 is valid)
                        let gap = currLast - prevLast
                        return gap >= 1 && gap <= 5
                    }
                }
            }
            
            // Check for different levels: "3.18" -> "4" (subsection to new major section)
            // If previous has dots (like "3.18") and current doesn't (like "4"), 
            // it's likely a new major section, which is valid
            if prevComponents.count > 1 && currComponents.count == 1 {
                if let prevMajor = Int(prevComponents.first ?? ""),
                   let currMajor = Int(currComponents.first ?? "") {
                    return currMajor == prevMajor + 1
                }
            }
        }
        
        // For lettered sequences: "A" -> "B", "A.1" -> "A.2", etc.
        if previous.matches(pattern: "^[A-Z](?:\\.\\d+)*$") && current.matches(pattern: "^[A-Z](?:\\.\\d+)*$") {
            if current.hasPrefix(previous + ".") {
                return true
            }
            // Check if it's the same level but next letter
            if previous.count == 1 && current.count == 1 {
                let prevChar = previous.first!
                let currChar = current.first!
                return currChar.asciiValue == prevChar.asciiValue! + 1
            }
        }
        
        // For year sequences: "2016" -> "2017", etc.
        if previous.matches(pattern: "^\\d{4}$") && current.matches(pattern: "^\\d{4}$") {
            if let prevYear = Int(previous), let currYear = Int(current) {
                return currYear == prevYear + 1
            }
        }
        
        return false
    }
    
    /// Filters out false headers based on numbering analysis
    private func filterFalseHeaders(_ headers: [DocumentElement], analysis: HeaderNumberingAnalysis) -> [DocumentElement] {
        var filteredHeaders = headers
        
        for (level, sequenceAnalysis) in analysis.levelPatterns {
            if !sequenceAnalysis.isConsistent {
                // Find headers at this level that are outliers
                let levelHeaders = headers.filter { $0.headerLevel == level }
                
                for header in levelHeaders {
                    if let text = header.text,
                       let number = extractHeaderNumber(text),
                       let intNumber = Int(number),
                       sequenceAnalysis.outliers.contains(intNumber) {
                        
                        // This is likely a false header
                        logger.info("Identified false header based on numbering analysis: '\(text)' (number: \(number))")
                        
                        // Remove from filtered headers
                        filteredHeaders.removeAll { $0.id == header.id }
                    }
                }
            }
        }
        
        return filteredHeaders
    }
}

// MARK: - Supporting Structures

/// Analysis of header numbering patterns on a page
private struct HeaderNumberingAnalysis {
    var levelPatterns: [Int: NumberSequenceAnalysis] = [:]
}

/// Analysis of a number sequence
private struct NumberSequenceAnalysis {
    var isConsistent: Bool = false
    var expectedIncrement: Int = 1
    var missingNumbers: [Int] = []
    var outliers: [Int] = []
}

// MARK: - Extensions

extension String {
    /// Checks if the string matches a regex pattern
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.firstMatch(in: self, range: range) != nil
    }
}

extension Array {
    /// Safe subscript that returns nil if index is out of bounds
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

