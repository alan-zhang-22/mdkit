# Position-Based Ordering and Duplication Handling Proposal

## Overview

This document outlines the proposed implementation for handling position-based ordering and potential duplications between different document element types when processing PDFs using Apple's Vision framework. The goal is to ensure that document elements are processed in the correct top-to-bottom order while detecting and resolving any overlapping content.

## Problem Statement

### 1. **Position-Based Ordering Requirement**
When converting PDFs to Markdown, document elements (titles, text blocks, paragraphs, tables, lists, barcodes) must be processed in the correct order based on their position on the page. Elements should be processed from top to bottom to maintain the logical flow of the document.

### 2. **Potential Duplication Issues**
The Vision framework may return overlapping content across different element types:
- `textBlocks` might contain the same content as `paragraphs`
- `paragraphs` might overlap with `lists`
- `titles` might be included in both `textBlocks` and `paragraphs`
- Lists might be detected as both `textBlocks` and `lists`

### 3. **Page Header and Footer Detection**
Page headers and footers are repetitive elements that appear at the top and bottom of each page, often containing:
- Document titles, chapter names, or section numbers
- Page numbers
- Company names, logos, or branding
- Date stamps or version information
- Legal disclaimers or copyright notices

These elements should be detected and filtered out to avoid:
- Repetitive content in the final markdown
- Interference with the main document flow
- Reduced readability and quality

## Proposed Solution Architecture

### 1. **Unified Document Element Structure**

```swift
struct DocumentElement {
    let type: ElementType
    let boundingBox: CGRect
    let content: Any // Vision framework data structure
    let confidence: Float
    
    enum ElementType {
        case title
        case textBlock
        case paragraph
        case header
        case table
        case list
        case barcode
    }
}
```

### 2. **Unified Document Processor**

The `UnifiedDocumentProcessor` class will:
- Collect all document elements from the Vision framework
- Assign position information to each element
- Sort elements by their vertical position (top to bottom)
- Detect and resolve duplications
- Return a clean, ordered list of elements

```swift
struct UnifiedDocumentProcessor {
    func processDocumentContainer(_ container: DocumentObservation.Container, config: OCRConfig) async throws -> [DocumentElement] {
        var allElements: [DocumentElement] = []
        
        // Collect all elements with their positions
        if let title = container.title {
            allElements.append(DocumentElement(
                type: .title,
                boundingBox: title.boundingBox,
                content: title,
                confidence: title.confidence
            ))
        }
        
        // Add text blocks
        allElements.append(contentsOf: container.text.map { text in
            DocumentElement(
                type: .textBlock,
                boundingBox: text.boundingBox,
                content: text,
                confidence: text.confidence
            )
        })
        
        // Add paragraphs
        allElements.append(contentsOf: container.paragraphs.map { paragraph in
            DocumentElement(
                type: .paragraph,
                boundingBox: paragraph.boundingBox,
                content: paragraph,
                confidence: paragraph.confidence
            )
        })
        
        // Add tables
        allElements.append(contentsOf: container.tables.map { table in
            DocumentElement(
                type: .table,
                boundingBox: table.boundingBox,
                content: table,
                confidence: table.confidence
            )
        })
        
        // Add lists
        allElements.append(contentsOf: container.lists.map { list in
            DocumentElement(
                type: .list,
                boundingBox: list.boundingBox,
                content: list,
                confidence: list.confidence
            )
        })
        
        // Add barcodes
        allElements.append(contentsOf: container.barcodes.map { barcode in
            DocumentElement(
                type: .barcode,
                boundingBox: barcode.boundingBox,
                content: barcode,
                confidence: barcode.confidence
            )
        })
        
        // Sort by position (top to bottom)
        allElements.sort { $0.boundingBox.minY < $1.boundingBox.minY }
        
        return allElements
    }
}
```

### 3. **Duplication Detection and Resolution**

```swift
extension UnifiedDocumentProcessor {
    func detectAndResolveDuplications(_ elements: [DocumentElement]) -> [DocumentElement] {
        var processedElements: [DocumentElement] = []
        var processedRegions: [CGRect] = []
        
        for element in elements {
            let elementRegion = element.boundingBox
            
            // Check for significant overlap with previously processed elements
            let hasOverlap = processedRegions.contains { region in
                let intersection = elementRegion.intersection(region)
                let overlapRatio = intersection.width * intersection.height / (elementRegion.width * elementRegion.height)
                return overlapRatio > config.duplicationDetection.overlapThreshold
            }
            
            if !hasOverlap {
                processedElements.append(element)
                processedRegions.append(elementRegion)
            } else {
                // Log potential duplication for analysis
                if config.duplicationDetection.logOverlaps {
                    print("⚠️ Potential duplication detected: \(element.type) at \(elementRegion)")
                }
            }
        }
        
        return processedElements
    }
}
```

### 4. **Header and Footer Detection and Filtering**

The system will implement intelligent detection and filtering of page headers and footers:

```swift
struct HeaderFooterDetector {
    let config: HeaderFooterConfig
    
    func detectAndFilterHeadersFooters(_ elements: [DocumentElement], from pages: [PDFPage]) -> [DocumentElement] {
        var filteredElements: [DocumentElement] = []
        var headerPatterns: [String: Int] = [:] // content -> frequency
        var footerPatterns: [String: Int] = [:]
        
        // Analyze patterns across all pages
        for page in pages {
            let pageElements = elements.filter { element in
                // Filter elements that belong to this page
                // This would need page association logic
                return true // Placeholder
            }
            
            // Detect potential headers using region-based or percentage-based method
            let headerElements = pageElements.filter { element in
                if let headerY = config.headerRegionY {
                    // Use absolute Y-coordinate: elements below this Y are headers
                    return element.boundingBox.minY <= headerY + config.regionTolerance
                } else {
                    // Fallback to percentage-based: top 10% of page
                    let pageHeight = page.bounds.height
                    let elementY = element.boundingBox.minY
                    return elementY < pageHeight * config.headerRegionHeight
                }
            }
            
            // Detect potential footers using region-based or percentage-based method
            let footerElements = pageElements.filter { element in
                if let footerY = config.footerRegionY {
                    // Use absolute Y-coordinate: elements above this Y are footers
                    return element.boundingBox.maxY >= footerY - config.regionTolerance
                } else {
                    // Fallback to percentage-based: bottom 10% of page
                    let pageHeight = page.bounds.height
                    let elementY = element.boundingBox.maxY
                    return elementY > pageHeight * (1.0 - config.footerRegionHeight)
                }
            }
            
            // Count patterns
            for element in headerElements {
                let content = extractTextContent(from: element)
                headerPatterns[content, default: 0] += 1
            }
            
            for element in footerElements {
                let content = extractTextContent(from: element)
                footerPatterns[content, default: 0] += 1
            }
        }
        
        // Filter out repetitive headers and footers
        let headerThreshold = pages.count * config.headerFrequencyThreshold
        let footerThreshold = pages.count * config.footerFrequencyThreshold
        
        for element in elements {
            let content = extractTextContent(from: element)
            let isHeader = headerPatterns[content, default: 0] >= headerThreshold
            let isFooter = footerPatterns[content, default: 0] >= footerThreshold
            
            if !isHeader && !isFooter {
                filteredElements.append(element)
            } else {
                print("🚫 Filtered out \(isHeader ? "header" : "footer"): \(content)")
            }
        }
        
        return filteredElements
    }
    
    private func extractTextContent(from element: DocumentElement) -> String {
        // Extract text content based on element type
        switch element.type {
        case .title, .textBlock, .paragraph:
            if let text = element.content as? DocumentObservation.Container.Text {
                return text.transcript
            }
        case .list:
            if let list = element.content as? DocumentObservation.Container.List {
                return list.items.map { $0.itemString }.joined(separator: " ")
            }
        case .table:
            if let table = element.content as? DocumentObservation.Container.Table {
                return table.rows.flatMap { row in
                    row.map { cell in cell.content.text.transcript }
                }.joined(separator: " ")
            }
        default:
            break
        }
        return ""
    }
}

struct HeaderFooterConfig {
    let headerFrequencyThreshold: Float = 0.7 // Must appear in 70% of pages
    let footerFrequencyThreshold: Float = 0.7
    let headerRegionHeight: Float = 0.1 // Top 10% of page
    let footerRegionHeight: Float = 0.1 // Bottom 10% of page
    let enableSmartDetection: Bool = true
    let excludePageNumbers: Bool = true
    let excludeCommonHeaders: [String] = ["Page", "Chapter", "Section"]
    let excludeCommonFooters: [String] = ["Confidential", "Copyright", "All rights reserved"]
}
```

### 5. **Header and List Item Detection and Merging**

The system will implement intelligent detection and merging of headers and list items that may be split across multiple OCR elements:

```swift
struct HeaderAndListDetector {
    let config: HeaderDetectionConfig
    let listConfig: ListDetectionConfig
    
    func detectAndMergeHeadersAndLists(_ elements: [DocumentElement]) -> [DocumentElement] {
        var processedElements: [DocumentElement] = []
        var i = 0
        
        while i < elements.count {
            let currentElement = elements[i]
            
            // Check if current element is a potential header marker
            if let headerInfo = detectHeaderMarker(in: currentElement) {
                // Look ahead for potential header content in the same line
                if let mergedHeader = tryMergeHeaderWithContent(
                    markerElement: currentElement,
                    markerInfo: headerInfo,
                    remainingElements: Array(elements.dropFirst(i + 1))
                ) {
                    processedElements.append(mergedHeader)
                    // Skip the content element that was merged
                    i += 2
                } else {
                    // No content found, treat as standalone header
                    processedElements.append(currentElement)
                    i += 1
                }
            }
            // Check if current element is a potential list item marker
            else if let listItemInfo = detectListItemMarker(in: currentElement) {
                // Look ahead for potential list item content
                if let mergedListItem = tryMergeListItemWithContent(
                    markerElement: currentElement,
                    markerInfo: listItemInfo,
                    remainingElements: Array(elements.dropFirst(i + 1))
                ) {
                    processedElements.append(mergedListItem)
                    // Skip the content element that was merged
                    i += 2
                } else {
                    // No content found, treat as standalone list item
                    processedElements.append(currentElement)
                    i += 1
                }
            } else {
                // Not a header or list item, add as-is
                processedElements.append(currentElement)
                i += 1
            }
        }
        
        return processedElements
    }
    
    private func detectHeaderMarker(in element: DocumentElement) -> HeaderMarkerInfo? {
        guard let text = extractTextContent(from: element) else { return nil }
        
        // Check for various header patterns from configuration
        let patterns = [
            // Numbered headers: 5, 5.1, 5.1.2, 5.1.2.1, etc.
            (patterns: config.headerDetection.patterns.numberedHeaders, level: "numbered"),
            // Lettered headers: A, A.1, A.1.2, etc.
            (patterns: config.headerDetection.patterns.letteredHeaders, level: "lettered"),
            // Roman numeral headers: I, I.1, I.1.2, etc.
            (patterns: config.headerDetection.patterns.romanHeaders, level: "roman"),
            // Named headers: Chapter 5, Section 5.1, etc.
            (patterns: config.headerDetection.patterns.namedHeaders, level: "named")
        ]
        
        for (patternList, levelType) in patterns {
            for pattern in patternList {
                if let match = text.range(of: pattern, options: .regularExpression) {
                    let marker = String(text[match])
                    let headerLevel = calculateHeaderLevel(from: marker, type: levelType)
                    return HeaderMarkerInfo(
                        marker: marker,
                        level: headerLevel,
                        type: levelType,
                        element: element
                    )
                }
            }
        }
        
        return nil
    }
    
    private func calculateHeaderLevel(from marker: String, type: String) -> Int {
        switch type {
        case "numbered", "lettered", "roman":
            // Count the number of dot-separated parts
            let level = marker.components(separatedBy: ".").count
            return min(level, config.headerDetection.levelCalculation.maxLevel)
        case "named":
            // Check for custom level mapping in configuration
            let parts = marker.components(separatedBy: " ")
            if parts.count >= 1 {
                let headerType = parts[0]
                if let customLevel = config.headerDetection.levelCalculation.customLevels[headerType] {
                    return customLevel
                }
            }
            
            // Fallback: Named headers get +1 level (Chapter 5 -> level 2, Section 5.1 -> level 3)
            if parts.count >= 2 {
                let numberPart = parts[1]
                let level = numberPart.components(separatedBy: ".").count + 1
                return min(level, config.headerDetection.levelCalculation.maxLevel)
            }
            return 1
        default:
            return 1
        }
    }
    
    private func tryMergeHeaderWithContent(
        markerElement: DocumentElement,
        markerInfo: HeaderMarkerInfo,
        remainingElements: [DocumentElement]
    ) -> DocumentElement? {
        guard let nextElement = remainingElements.first else { return nil }
        
        // Check if next element is on approximately the same line using configuration
        let yTolerance = config.headerDetection.sameLineTolerance
        let isSameLine = abs(markerElement.boundingBox.minY - nextElement.boundingBox.minY) <= yTolerance
        
        if isSameLine {
            // Check if next element contains header content (not another marker)
            let nextContent = extractTextContent(from: nextElement) ?? ""
            if !isHeaderMarker(nextContent) && !nextContent.isEmpty {
                // Merge marker and content
                return createMergedHeader(
                    markerElement: markerElement,
                    markerInfo: markerInfo,
                    contentElement: nextElement
                )
            }
        }
        
        return nil
    }
    
    private func isHeaderMarker(_ text: String) -> Bool {
        // Check if text matches any header marker pattern from configuration
        let allPatterns = config.headerDetection.patterns.numberedHeaders +
                         config.headerDetection.patterns.letteredHeaders +
                         config.headerDetection.patterns.romanHeaders +
                         config.headerDetection.patterns.namedHeaders
        
        return allPatterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    // List item detection methods
    private func detectListItemMarker(in element: DocumentElement) -> ListItemMarkerInfo? {
        guard let text = extractTextContent(from: element) else { return nil }
        
        // Check for various list item marker patterns
        let patterns = [
            // Numbered list items: 1), 2), 3), etc.
            (patterns: listConfig.patterns.numberedMarkers, type: "numbered"),
            // Lettered list items: a), b), c), etc.
            (patterns: listConfig.patterns.letteredMarkers, type: "lettered"),
            // Bullet list items: •, -, *, etc.
            (patterns: listConfig.patterns.bulletMarkers, type: "bullet"),
            // Roman numeral list items: i), ii), iii), etc.
            (patterns: listConfig.patterns.romanMarkers, type: "roman"),
            // Custom list items: 1., 2., a., b., etc.
            (patterns: listConfig.patterns.customMarkers, type: "custom")
        ]
        
        for (patternList, markerType) in patterns {
            for pattern in patternList {
                if let match = text.range(of: pattern, options: .regularExpression) {
                    let marker = String(text[match])
                    let level = calculateListItemLevel(from: marker, type: markerType, element: element)
                    return ListItemMarkerInfo(
                        marker: marker,
                        level: level,
                        type: markerType,
                        element: element
                    )
                }
            }
        }
        
        return nil
    }
    
    private func calculateListItemLevel(from marker: String, type: String, element: DocumentElement) -> Int {
        // Base level from marker pattern
        var baseLevel = 0
        
        switch type {
        case "numbered", "lettered", "roman":
            // Count the number of dot-separated parts
            baseLevel = marker.components(separatedBy: ".").count
        case "bullet":
            // Bullet items start at level 0
            baseLevel = 0
        case "custom":
            // Custom markers start at level 0
            baseLevel = 0
        default:
            baseLevel = 0
        }
        
        // Adjust level based on x-coordinate indentation
        let xCoordinate = element.boundingBox.minX
        let indentationLevel = calculateIndentationLevel(xCoordinate: xCoordinate)
        
        return baseLevel + indentationLevel
    }
    
    private func calculateIndentationLevel(xCoordinate: Float) -> Int {
        // Calculate level based on x-coordinate indentation
        let baseIndentation = listConfig.indentation.baseIndentation
        let levelThreshold = listConfig.indentation.levelThreshold
        
        let indentation = xCoordinate - baseIndentation
        let level = Int(indentation / levelThreshold)
        
        return max(0, level)
    }
    
    private func tryMergeListItemWithContent(
        markerElement: DocumentElement,
        markerInfo: ListItemMarkerInfo,
        remainingElements: [DocumentElement]
    ) -> DocumentElement? {
        guard let nextElement = remainingElements.first else { return nil }
        
        // Check if next element is on approximately the same line or close
        let yTolerance = listConfig.sameLineTolerance
        let isSameLine = abs(markerElement.boundingBox.minY - nextElement.boundingBox.minY) <= yTolerance
        
        if isSameLine {
            // Check if next element contains list item content (not another marker)
            let nextContent = extractTextContent(from: nextElement) ?? ""
            if !isListItemMarker(nextContent) && !nextContent.isEmpty {
                // Merge marker and content
                return createMergedListItem(
                    markerElement: markerElement,
                    markerInfo: markerInfo,
                    contentElement: nextElement
                )
            }
        }
        
        return nil
    }
    
    private func isListItemMarker(_ text: String) -> Bool {
        // Check if text matches any list item marker pattern
        let allPatterns = listConfig.patterns.numberedMarkers +
                         listConfig.patterns.letteredMarkers +
                         listConfig.patterns.bulletMarkers +
                         listConfig.patterns.romanMarkers +
                         listConfig.patterns.customMarkers
        
        return allPatterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    private func createMergedListItem(
        markerElement: DocumentElement,
        markerInfo: ListItemMarkerInfo,
        contentElement: DocumentElement
    ) -> DocumentElement {
        let mergedContent = "\(markerInfo.marker) \(extractTextContent(from: contentElement) ?? "")"
        
        return DocumentElement(
            type: .listItem,
            boundingBox: CGRect(
                x: min(markerElement.boundingBox.minX, contentElement.boundingBox.minX),
                y: min(markerElement.boundingBox.minY, contentElement.boundingBox.minY),
                width: max(markerElement.boundingBox.maxX, contentElement.boundingBox.maxX) - min(markerElement.boundingBox.minX, contentElement.boundingBox.minX),
                height: max(markerElement.boundingBox.maxY, contentElement.boundingBox.maxY) - min(markerElement.boundingBox.minY, contentElement.boundingBox.minY)
            ),
            content: MergedListItemContent(
                marker: markerInfo.marker,
                content: extractTextContent(from: contentElement) ?? "",
                level: markerInfo.level,
                type: markerInfo.type
            ),
            confidence: min(markerElement.confidence, contentElement.confidence)
        )
    }
    
    private func createMergedHeader(
        markerElement: DocumentElement,
        markerInfo: HeaderMarkerInfo,
        contentElement: DocumentElement
    ) -> DocumentElement {
        let mergedContent = "\(markerInfo.marker) \(extractTextContent(from: contentElement) ?? "")"
        
        return DocumentElement(
            type: .header,
            boundingBox: CGRect(
                x: min(markerElement.boundingBox.minX, contentElement.boundingBox.minX),
                y: min(markerElement.boundingBox.minY, contentElement.boundingBox.minY),
                width: max(markerElement.boundingBox.maxX, contentElement.boundingBox.maxX) - min(markerElement.boundingBox.minX, contentElement.boundingBox.minX),
                height: max(markerElement.boundingBox.maxY, contentElement.boundingBox.maxY) - min(markerElement.boundingBox.minY, contentElement.boundingBox.minY)
            ),
            content: MergedHeaderContent(
                marker: markerInfo.marker,
                content: extractTextContent(from: contentElement) ?? "",
                level: markerInfo.level,
                type: markerInfo.type
            ),
            confidence: min(markerElement.confidence, contentElement.confidence)
        )
    }
}

struct HeaderMarkerInfo {
    let marker: String
    let level: Int
    let type: String
    let element: DocumentElement
}

struct MergedHeaderContent {
    let marker: String
    let content: String
    let level: Int
    let type: String
}

struct HeaderDetectionConfig {
    let sameLineTolerance: Float = 5.0 // Pixels tolerance for same-line detection
    let enableHeaderMerging: Bool = true
    let enableLevelCalculation: Bool = true
    let markdownLevelOffset: Int = 1 // Add this many levels to markdown headers
    
    // Header pattern configurations
    let numberedHeaderPatterns: [String] = [#"^\d+(?:\.\d+)*\s*$"#]
    let letteredHeaderPatterns: [String] = [#"^[A-Z](?:\.\d+)*\s*$"#]
    let romanHeaderPatterns: [String] = [#"^[IVX]+(?:\.\d+)*\s*$"#]
    let namedHeaderPatterns: [String] = [
        #"^(Chapter|Section|Part)\s+\d+(?:\.\d+)*\s*$"#,
        #"^Appendix\s+[A-Z](?:\.\d+)*\s*$"#
    ]
}

struct ListItemMarkerInfo {
    let marker: String
    let level: Int
    let type: String
    let element: DocumentElement
}

struct MergedListItemContent {
    let marker: String
    let content: String
    let level: Int
    let type: String
}

struct ListDetectionConfig {
    let sameLineTolerance: Float = 5.0 // Pixels tolerance for same-line detection
    let enableListItemMerging: Bool = true
    let enableLevelCalculation: Bool = true
    let enableNestedLists: Bool = true
    
    // List item pattern configurations
    let patterns: ListItemPatterns
    let indentation: IndentationConfig
}

struct ListItemPatterns {
    let numberedMarkers: [String]
    let letteredMarkers: [String]
    let bulletMarkers: [String]
    let romanMarkers: [String]
    let customMarkers: [String]
}

struct IndentationConfig {
    let baseIndentation: Float = 50.0 // Base indentation for level 0
    let levelThreshold: Float = 20.0 // Pixel threshold for each level
    let enableXCoordinateAnalysis: Bool = true
}
```

### 6. **Updated Markdown Generation**

The `MarkdownGenerator` class will be updated to process the unified element list with header support:

```swift
class MarkdownGenerator {
    let headerConfig: HeaderDetectionConfig
    let listConfig: ListDetectionConfig
    
    func generateMarkdown(from elements: [DocumentElement]) -> String {
        var markdown = ""
        var currentListLevel = -1
        var listStack: [String] = []
        
        for element in elements {
            switch element.type {
            case .header:
                markdown += processHeader(element.content as! MergedHeaderContent)
                // Reset list context when we encounter a header
                currentListLevel = -1
                listStack.removeAll()
            case .listItem:
                markdown += processListItem(
                    element.content as! MergedListItemContent,
                    currentLevel: &currentListLevel,
                    listStack: &listStack
                )
            case .title:
                markdown += processTitle(element.content as! DocumentObservation.Container.Text)
            case .textBlock:
                markdown += processTextBlock(element.content as! DocumentObservation.Container.Text)
            case .paragraph:
                markdown += processParagraph(element.content as! DocumentObservation.Container.Text)
            case .table:
                markdown += processTable(element.content as! DocumentObservation.Container.Table)
            case .list:
                markdown += processList(element.content as! DocumentObservation.Container.List)
            case .barcode:
                markdown += processBarcode(element.content as! BarcodeObservation)
            }
            
            markdown += "\n"
        }
        
        return markdown
    }
    
    private func processHeader(_ header: MergedHeaderContent) -> String {
        let markdownLevel = min(header.level + headerConfig.markdownLevelOffset, 6)
        let markdownSymbols = String(repeating: "#", count: markdownLevel)
        return "\(markdownSymbols) \(header.marker) \(header.content)\n"
    }
    
    private func processListItem(
        _ listItem: MergedListItemContent,
        currentLevel: inout Int,
        listStack: inout [String]
    ) -> String {
        var markdown = ""
        
        // Handle list level changes
        if listItem.level > currentLevel {
            // Going deeper - add indentation
            while currentLevel < listItem.level - 1 {
                currentLevel += 1
                listStack.append("  ") // Add indentation
            }
            currentLevel = listItem.level
        } else if listItem.level < currentLevel {
            // Going shallower - remove indentation
            while currentLevel > listItem.level {
                if !listStack.isEmpty {
                    listStack.removeLast()
                }
                currentLevel -= 1
            }
        }
        
        // Generate list item markdown
        let indentation = listStack.joined()
        let marker = generateListMarker(for: listItem.type, marker: listItem.marker)
        
        markdown += "\(indentation)\(marker) \(listItem.content)\n"
        
        return markdown
    }
    
    private func generateListMarker(for type: String, marker: String) -> String {
        switch type {
        case "numbered":
            return marker.replacingOccurrences(of: ")", with: ".")
        case "lettered":
            return marker.replacingOccurrences(of: ")", with: ".")
        case "bullet":
            return "-"
        case "roman":
            return marker.replacingOccurrences(of: ")", with: ".")
        case "custom":
            return marker
        default:
            return marker
        }
    }
}
```

## Implementation Steps

### Phase 1: Foundation
1. Create the `DocumentElement` struct
2. Implement the `UnifiedDocumentProcessor` class
3. Add basic position-based sorting

### Phase 2: Duplication Detection
1. Implement overlap detection algorithms
2. Add configurable overlap thresholds
3. Create logging and analysis tools

### Phase 3: Header and Footer Detection
1. Implement `HeaderFooterDetector` class
2. Add region-based detection with absolute Y-coordinates
3. Implement percentage-based fallback detection
4. Add configurable tolerance and multi-region support
5. Implement frequency-based pattern recognition
6. Create content analysis for common header/footer patterns
7. Add automatic region detection for unknown document types

### Phase 4: Integration
1. Update the `OCRProcessor` to use the unified approach
2. Modify the `MarkdownGenerator` to process unified elements
3. Integrate header/footer filtering into the main pipeline
4. Integrate centralized file management system
5. Update the main processing pipeline

### Phase 5: Testing and Refinement
1. Test with various PDF types (technical documents, reports, manuals)
2. Analyze duplication patterns and header/footer detection accuracy
3. Fine-tune overlap thresholds and frequency thresholds
4. Optimize performance and memory usage
5. Validate with real-world documents containing complex headers/footers

## JSON Configuration System

The system will use a JSON configuration file to configure all options and parameters, making it easy to customize behavior without code changes.

### 1. **Main Configuration File Structure**

```json
{
  "version": "1.0",
  "description": "mdkit PDF to Markdown conversion configuration",
  
  "headerFooterDetection": {
    "enabled": true,
    "headerFrequencyThreshold": 0.7,
    "footerFrequencyThreshold": 0.7,
    
    "regionBasedDetection": {
      "enabled": true,
      "headerRegionY": 72.0,
      "footerRegionY": 720.0,
      "regionTolerance": 5.0
    },
    
    "percentageBasedDetection": {
      "enabled": true,
      "headerRegionHeight": 0.1,
      "footerRegionHeight": 0.1
    },
    
    "smartDetection": {
      "enabled": true,
      "excludePageNumbers": true,
      "excludeCommonHeaders": ["Page", "Chapter", "Section"],
      "excludeCommonFooters": ["Confidential", "Copyright", "All rights reserved"],
      "enableContentAnalysis": true,
      "minHeaderFooterLength": 3,
      "maxHeaderFooterLength": 200
    },
    
    "multiRegionDetection": {
      "enabled": false,
      "maxRegions": 3
    }
  },
  
  "headerDetection": {
    "enabled": true,
    "sameLineTolerance": 5.0,
    "enableHeaderMerging": true,
    "enableLevelCalculation": true,
    "markdownLevelOffset": 1,
    
    "patterns": {
      "numberedHeaders": [
        "^\\d+(?:\\.\\d+)*\\s*$",
        "^\\d+[A-Z](?:\\.\\d+)*\\s*$"
      ],
      "letteredHeaders": [
        "^[A-Z](?:\\.\\d+)*\\s*$",
        "^[A-Z]\\d+(?:\\.\\d+)*\\s*$"
      ],
      "romanHeaders": [
        "^[IVX]+(?:\\.\\d+)*\\s*$"
      ],
      "namedHeaders": [
        "^(Chapter|Section|Part)\\s+\\d+(?:\\.\\d+)*\\s*$",
        "^Appendix\\s+[A-Z](?:\\.\\d+)*\\s*$"
      ]
    },
    
    "levelCalculation": {
      "autoCalculate": true,
      "maxLevel": 6,
      "customLevels": {
        "Part": 1,
        "Chapter": 2,
        "Section": 3
      }
    }
  },
  
  "listDetection": {
    "enabled": true,
    "sameLineTolerance": 5.0,
    "enableListItemMerging": true,
    "enableLevelCalculation": true,
    "enableNestedLists": true,
    
    "patterns": {
      "numberedMarkers": [
        "^\\d+\\)\\s*$",
        "^\\d+\\.\\s*$",
        "^\\d+-\\s*$"
      ],
      "letteredMarkers": [
        "^[a-z]\\)\\s*$",
        "^[a-z]\\.\\s*$",
        "^[a-z]-\\s*$"
      ],
      "bulletMarkers": [
        "^[•\\-\\*]\\s*$",
        "^[\\u2022\\u2023\\u25E6]\\s*$"
      ],
      "romanMarkers": [
        "^[ivx]+\\)\\s*$",
        "^[ivx]+\\.\\s*$"
      ],
      "customMarkers": [
        "^[\\u25A0\\u25A1\\u25A2]\\s*$"
      ]
    },
    
    "indentation": {
      "baseIndentation": 50.0,
      "levelThreshold": 20.0,
      "enableXCoordinateAnalysis": true
    }
  },
  
  "duplicationDetection": {
    "enabled": true,
    "overlapThreshold": 0.3,
    "enableLogging": true,
    "logOverlaps": true,
    "strictMode": false
  },
  
  "llm": {
    "enabled": false,
    "backend": "LocalLLMClientLlama",
    "modelPath": "",
    
    "model": {
      "id": "llama-3.1-8b-instruct-q4_0",
      "name": "Llama 3.1 8B Instruct",
      "type": "gguf",
      "downloadUrl": "https://huggingface.co/TheBloke/Llama-3.1-8B-Instruct-GGUF/resolve/main/llama-3.1-8b-instruct-q4_0.gguf",
      "localPath": "~/models/llama-3.1-8b-instruct-q4_0.gguf"
    },
    
    "parameters": {
      "temperature": 0.1,
      "topP": 0.9,
      "topK": 40,
      "penaltyRepeat": 1.1,
      "penaltyFrequency": 0.8,
      "context": 4096,
      "batch": 512,
      "threads": 8,
      "gpuLayers": 0
    },
    
    "options": {
      "responseFormat": "markdown",
      "verbose": false,
      "streaming": true,
      "jsonMode": false
    },
    
    "contextManagement": {
      "maxContextLength": 4096,
      "overlapLength": 200,
      "chunkSize": 1000,
      "enableSlidingWindow": true,
      "enableHierarchicalProcessing": true
    },
    
    "memoryOptimization": {
      "maxMemoryUsage": "4GB",
      "enableStreaming": true,
      "cleanupAfterBatch": true,
      "enableMemoryMapping": true
    },
    
    "promptTemplates": {
      "languages": {
        "en": {
          "systemPrompt": [
            "You are an expert document processor specializing in converting technical documents to well-structured markdown.",
            "Your expertise includes:",
            "- ISO standards and technical specifications",
            "- Engineering documentation and compliance requirements",
            "- Academic papers and research documents",
            "- Business reports and procedural manuals",
            "",
            "Key responsibilities:",
            "1. Preserve all technical accuracy and compliance requirements",
            "2. Improve document structure and readability",
            "3. Maintain consistent formatting and hierarchy",
            "4. Ensure proper markdown syntax and standards",
            "",
            "Always respond in markdown format and maintain the original document's technical integrity."
          ],
          
          "markdownOptimizationPrompt": [
            "Document: {documentTitle}",
            "Pages: {pageCount}",
            "Elements: {elementCount}",
            "Context: {documentContext}",
            "Detected Language: {detectedLanguage} (Confidence: {languageConfidence})",
            "",
            "Please optimize this markdown for:",
            "1. Better structure and organization",
            "2. Improved readability and clarity",
            "3. Consistent formatting and hierarchy",
            "4. Technical accuracy preservation",
            "",
            "Markdown to optimize:",
            "{markdown}"
          ],
          
          "structureAnalysisPrompt": [
            "Document Type: {documentType}",
            "Total Elements: {elementCount}",
            "Detected Language: {detectedLanguage}",
            "",
            "Analyze the following document structure and identify headers, lists, tables, and other elements.",
            "Provide suggestions for improved organization:",
            "",
            "{elementDescriptions}",
            "",
            "Please provide your analysis in the following format:",
            "- Document Type: [type]",
            "- Structure Issues: [list of issues]",
            "- Recommendations: [list of improvements]",
            "- Confidence: [0.0-1.0]"
          ],
          
          "tableOptimizationPrompt": [
            "Please optimize the following table structure for better readability and markdown formatting.",
            "Ensure proper alignment and spacing:",
            "",
            "{tableContent}"
          ],
          
          "listOptimizationPrompt": [
            "Please optimize the following list structure for better markdown formatting and hierarchy.",
            "Maintain the logical structure while improving readability:",
            "",
            "{listContent}"
          ],
          
          "headerOptimizationPrompt": [
            "Please optimize the following header structure for better markdown hierarchy and consistency.",
            "Ensure proper level numbering and formatting:",
            "",
            "{headerContent}"
          ],
          
          "technicalStandardPrompt": [
            "This is a technical standards document.",
            "Please ensure all technical terms, specifications, and references are preserved exactly",
            "while improving the overall structure and readability."
          ]
        },
        
        "zh": {
          "systemPrompt": [
            "您是一位专业的文档处理专家，专门负责将技术文档转换为结构良好的markdown格式。",
            "您的专业领域包括：",
            "- ISO标准和国际技术规范",
            "- 工程文档和合规要求",
            "- 学术论文和研究文档",
            "- 商业报告和程序手册",
            "- 技术标准和法规文档",
            "",
            "主要职责：",
            "1. 保持所有技术准确性和合规要求",
            "2. 改进文档结构和可读性",
            "3. 维护一致的格式和层次结构",
            "4. 确保正确的markdown语法和标准",
            "5. 保持专业术语的准确性",
            "6. 优化中文文档的阅读体验",
            "",
            "始终以markdown格式回复，并保持原始文档的技术完整性。"
          ],
          
          "markdownOptimizationPrompt": [
            "文档信息：",
            "标题：{documentTitle}",
            "页数：{pageCount}",
            "元素数量：{elementCount}",
            "上下文：{documentContext}",
            "检测语言：{detectedLanguage}（置信度：{languageConfidence}）",
            "",
            "请优化此markdown以实现：",
            "1. 更好的结构和组织",
            "2. 改进的可读性和清晰度",
            "3. 一致的格式和层次结构",
            "4. 技术准确性保持",
            "5. 中文文档的本地化优化",
            "6. 专业术语的一致性",
            "",
            "要优化的Markdown内容：",
            "{markdown}"
          ],
          
          "structureAnalysisPrompt": [
            "文档类型：{documentType}",
            "总元素数：{elementCount}",
            "检测语言：{detectedLanguage}",
            "",
            "请分析以下文档结构，识别标题、列表、表格和其他元素：",
            "",
            "{elementDescriptions}",
            "",
            "请按以下格式提供分析：",
            "- 文档类型：[类型]",
            "- 结构问题：[问题列表]",
            "- 改进建议：[建议列表]",
            "- 置信度：[0.0-1.0]",
            "- 语言特定建议：[针对{detectedLanguage}的优化建议]"
          ],
          
          "tableOptimizationPrompt": [
            "请优化以下表格结构，提高可读性和markdown格式质量：",
            "确保正确的对齐和间距：",
            "",
            "{tableContent}"
          ],
          
          "listOptimizationPrompt": [
            "请优化以下列表结构，改进markdown格式和层次结构：",
            "保持逻辑结构的同时提高可读性：",
            "",
            "{listContent}"
          ],
          
          "headerOptimizationPrompt": [
            "请优化以下标题结构，改进markdown层次结构和一致性：",
            "确保正确的级别编号和格式：",
            "",
            "{headerContent}"
          ],
          
          "technicalStandardPrompt": [
            "这是一份技术标准文档。",
            "请确保所有技术术语、规格和引用都完全保持原样，",
            "同时改进整体结构和可读性。",
            "特别注意中文技术术语的准确性和一致性。"
          ]
        }
      },
      "defaultLanguage": "en",
      "fallbackLanguage": "en"
    }
  },
  
  "positionSorting": {
    "sortBy": "verticalPosition",
    "tolerance": 5.0,
    "enableHorizontalSorting": false,
    "confidenceWeighting": 0.2
  },
  
  "markdownGeneration": {
    "preservePageBreaks": false,
    "extractImages": true,
    "headerFormat": "atx",
    "listFormat": "unordered",
    "tableFormat": "standard",
    "codeBlockFormat": "fenced"
  },
  
  "ocr": {
    "recognitionLevel": "accurate",
    "languages": ["en-US"],
    "useLanguageCorrection": true,
    "minimumTextHeight": 0.01,
    "customWords": [],
    "enableDocumentAnalysis": true,
    "preserveLayout": true,
    "tableDetection": true,
    "listDetection": true,
    "barcodeDetection": true
  },
  
  "performance": {
    "maxMemoryUsage": "2GB",
    "enableStreaming": true,
    "batchSize": 10,
    "cleanupAfterBatch": true,
    "enableMultiThreading": true,
    "maxThreads": 8
  },
  
  "fileManagement": {
    "outputDirectory": "./output",
    "markdownDirectory": "./markdown",
    "logDirectory": "./logs",
    "tempDirectory": "./temp",
    "createDirectories": true,
    "overwriteExisting": false,
    "preserveOriginalNames": true,
    "fileNamingStrategy": "timestamped"
  },
  
  "logging": {
    "enabled": true,
    "level": "info",
    "outputFolder": "logs",
    "enableConsoleOutput": true,
    "logFileRotation": true,
    "maxLogFileSize": "10MB",
    
    "logCategories": {
      "ocrElements": {
        "enabled": true,
        "format": "json",
        "includeBoundingBoxes": true,
        "includeConfidence": true
      },
      "documentObservation": {
        "enabled": true,
        "format": "json",
        "includePositionData": true,
        "includeElementTypes": true
      },
      "markdownGeneration": {
        "enabled": true,
        "format": "markdown",
        "includeSourceMapping": true,
        "includeProcessingTime": true
      },
      "llmPrompts": {
        "enabled": true,
        "format": "json",
        "includeSystemPrompt": true,
        "includeUserPrompt": true,
        "includeLLMResponse": true,
        "includeTokenCounts": true,
        "includeProcessingTime": true
      },
      "llmOptimizedMarkdown": {
        "enabled": true,
        "format": "markdown",
        "includeOptimizationDetails": true,
        "includeBeforeAfterComparison": true
      }
    },
    
    "logFileNaming": {
      "pattern": "{timestamp}_{document}_{category}.{extension}",
      "timestampFormat": "yyyyMMdd_HHmmss",
      "includeDocumentHash": true,
      "maxFileNameLength": 100
    }
  }
}
```

### 2. **Configuration File Locations**

```swift
struct ConfigurationManager {
    enum ConfigLocation {
        case defaultConfig      // Built-in default configuration
        case userConfig        // ~/.config/mdkit/config.json
        case projectConfig     // ./mdkit-config.json
        case customPath(String) // User-specified path
    }
    
    func loadConfiguration(from location: ConfigLocation) throws -> MDKitConfig {
        switch location {
        case .defaultConfig:
            return try loadDefaultConfiguration()
        case .userConfig:
            return try loadUserConfiguration()
        case .projectConfig:
            return try loadProjectConfiguration()
        case .customPath(let path):
            return try loadConfigurationFromPath(path)
        }
    }
}
```

### 3. **Configuration Validation**

```json
{
  "validation": {
    "schema": "https://raw.githubusercontent.com/mdkit/schemas/main/config-v1.0.json",
    "strictMode": true,
    "allowUnknownFields": false,
    "requiredFields": [
      "headerFooterDetection",
      "headerDetection",
      "duplicationDetection"
    ]
  }
}
```

### 4. **Environment-Specific Configurations**

```json
{
  "environments": {
    "development": {
      "logging": { "level": "debug" },
      "performance": { "maxMemoryUsage": "1GB" }
    },
    "production": {
      "logging": { "level": "warning" },
      "performance": { "maxMemoryUsage": "4GB" }
    },
    "testing": {
      "logging": { "level": "info" },
      "performance": { "enableMultiThreading": false }
    }
  }
}
```

### 5. **Configuration Inheritance and Overrides**

```json
{
  "baseConfig": "configs/base.json",
  "overrides": {
    "headerFooterDetection.regionBasedDetection.headerRegionY": 80.0,
    "headerDetection.sameLineTolerance": 3.0,
    "performance.maxThreads": 4
  },
  "environment": "development"
}
```

### 6. **Configuration Loading and Management**

```swift
class ConfigurationManager {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // Load configuration with fallback chain
    func loadConfiguration() throws -> MDKitConfig {
        // 1. Try custom path from command line
        if let customPath = CommandLine.arguments.customConfigPath {
            return try loadConfigurationFromPath(customPath)
        }
        
        // 2. Try project-specific config
        if let projectConfig = try? loadProjectConfiguration() {
            return projectConfig
        }
        
        // 3. Try user config
        if let userConfig = try? loadUserConfiguration() {
            return userConfig
        }
        
        // 4. Fall back to default config
        return try loadDefaultConfiguration()
    }
    
    // Validate configuration against schema
    func validateConfiguration(_ config: MDKitConfig) throws {
        let validator = ConfigurationValidator()
        try validator.validate(config)
    }
    
    // Save configuration to file
    func saveConfiguration(_ config: MDKitConfig, to path: String) throws {
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: path))
    }
    
    // Generate configuration template
    func generateTemplate() -> String {
        return """
        {
          "version": "1.0",
          "description": "PDF to Markdown conversion configuration",
          "headerFooterDetection": { ... },
          "headerDetection": { ... },
          "duplicationDetection": { ... }
        }
        """
    }
}

// Configuration validation
struct ConfigurationValidator {
    func validate(_ config: MDKitConfig) throws {
        var errors: [String] = []
        
        // Validate required fields
        if config.headerFooterDetection == nil {
            errors.append("headerFooterDetection is required")
        }
        
        // Validate numeric ranges
        if config.headerDetection.sameLineTolerance < 0 || config.headerDetection.sameLineTolerance > 50 {
            errors.append("sameLineTolerance must be between 0 and 50")
        }
        
        if !errors.isEmpty {
            throw ConfigurationError.validationFailed(errors)
        }
    }
}

enum ConfigurationError: Error {
    case fileNotFound(String)
    case invalidJSON(String)
    case validationFailed([String])
    case unsupportedVersion(String)
}
```

### 7. **Centralized File Management System**

```swift
class FileManager {
    let config: FileManagementConfig
    let logger: Logger
    
    init(config: FileManagementConfig, logger: Logger) {
        self.config = config
        self.logger = logger
        setupDirectories()
    }
    
    // Setup output directories
    private func setupDirectories() {
        let directories = [
            config.outputDirectory,
            config.markdownDirectory,
            config.logDirectory,
            config.tempDirectory
        ]
        
        for directory in directories {
            try? FileManager.default.createDirectory(
                atPath: directory,
                withIntermediateDirectories: true
            )
        }
    }
    
    // Generate output file paths
    func generateOutputPaths(for document: String) -> DocumentOutputPaths {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let documentHash = document.sha256.prefix(8)
        
        let baseName = "\(timestamp)_\(documentHash)"
        
        return DocumentOutputPaths(
            markdown: "\(config.markdownDirectory)/\(baseName).md",
            logs: [
                "ocrElements": "\(config.logDirectory)/\(baseName)_ocr_elements.json",
                "documentObservation": "\(config.logDirectory)/\(baseName)_document_observation.json",
                "markdownGeneration": "\(config.logDirectory)/\(baseName)_markdown_generation.md",
                "llmPrompts": "\(config.logDirectory)/\(baseName)_llm_prompts.json",
                "llmOptimizedMarkdown": "\(config.logDirectory)/\(baseName)_llm_optimized.md"
            ],
            temp: "\(config.tempDirectory)/\(baseName)_temp"
        )
    }
    
    // Save markdown output
    func saveMarkdown(_ content: String, to path: String) throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        logger.info("Markdown saved to: \(path)")
    }
    
    // Save log data
    func saveLog(_ data: Data, category: String, to path: String) throws {
        try data.write(to: URL(fileURLWithPath: path))
        logger.info("\(category) log saved to: \(path)")
    }
    
    // Cleanup temporary files
    func cleanupTempFiles() {
        let tempURL = URL(fileURLWithPath: config.tempDirectory)
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
    }
}

struct DocumentOutputPaths {
    let markdown: String
    let logs: [String: String]
    let temp: String
}

struct FileManagementConfig {
    let outputDirectory: String
    let markdownDirectory: String
    let logDirectory: String
    let tempDirectory: String
    let createDirectories: Bool
    let overwriteExisting: Bool
    let preserveOriginalNames: Bool
    let fileNamingStrategy: FileNamingStrategy
    
    enum FileNamingStrategy: String, Codable {
        case timestamped = "timestamped"
        case original = "original"
        case hash = "hash"
        case custom = "custom"
    }
}
```

### 8. **Comprehensive Logging System**

```swift
class Logger {
    let config: LoggingConfig
    let fileManager: FileManager
    
    init(config: LoggingConfig, fileManager: FileManager) {
        self.config = config
        self.fileManager = fileManager
    }
    
    // Log OCR elements
    func logOCRElements(_ elements: [DocumentElement], for document: String) throws {
        guard config.logCategories.ocrElements.enabled else { return }
        
        let logData = OCRElementsLog(
            timestamp: Date(),
            document: document,
            elements: elements.map { element in
                OCRElementLog(
                    type: element.type,
                    boundingBox: element.boundingBox,
                    confidence: element.confidence,
                    content: extractContentSummary(from: element)
                )
            }
        )
        
        let data = try JSONEncoder().encode(logData)
        let path = fileManager.generateOutputPaths(for: document).logs["ocrElements"] ?? ""
        try fileManager.saveLog(data, category: "OCR Elements", to: path)
    }
    
    // Log document observation results
    func logDocumentObservation(_ result: DocumentAnalysisResult, for document: String) throws {
        guard config.logCategories.documentObservation.enabled else { return }
        
        let logData = DocumentObservationLog(
            timestamp: Date(),
            document: document,
            result: result
        )
        
        let data = try JSONEncoder().encode(logData)
        let path = fileManager.generateOutputPaths(for: document).logs["documentObservation"] ?? ""
        try fileManager.saveLog(data, category: "Document Observation", to: path)
    }
    
    // Log markdown generation
    func logMarkdownGeneration(_ markdown: String, source: String, for document: String) throws {
        guard config.logCategories.markdownGeneration.enabled else { return }
        
        let logData = MarkdownGenerationLog(
            timestamp: Date(),
            document: document,
            source: source,
            markdown: markdown,
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        let path = fileManager.generateOutputPaths(for: document).logs["markdownGeneration"] ?? ""
        try fileManager.saveLog(logData.markdown.data(using: .utf8) ?? Data(), category: "Markdown Generation", to: path)
    }
    
    // Log LLM prompts and responses
    func logLLMPrompts(
        systemPrompt: String,
        userPrompt: String,
        llmResponse: String,
        tokenCounts: TokenCounts,
        for document: String
    ) throws {
        guard config.logCategories.llmPrompts.enabled else { return }
        
        let logData = LLMPromptsLog(
            timestamp: Date(),
            document: document,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            llmResponse: llmResponse,
            tokenCounts: tokenCounts,
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        let data = try JSONEncoder().encode(logData)
        let path = fileManager.generateOutputPaths(for: document).logs["llmPrompts"] ?? ""
        try fileManager.saveLog(data, category: "LLM Prompts", to: path)
    }
    
    // Log LLM optimized markdown
    func logLLMOptimizedMarkdown(
        original: String,
        optimized: String,
        optimizationDetails: String,
        for document: String
    ) throws {
        guard config.logCategories.llmOptimizedMarkdown.enabled else { return }
        
        let logData = LLMOptimizedMarkdownLog(
            timestamp: Date(),
            document: document,
            original: original,
            optimized: optimized,
            optimizationDetails: optimizationDetails
        )
        
        let path = fileManager.generateOutputPaths(for: document).logs["llmOptimizedMarkdown"] ?? ""
        try fileManager.saveLog(logData.optimized.data(using: .utf8) ?? Data(), category: "LLM Optimized Markdown", to: path)
    }
}

// Log data structures
struct OCRElementsLog: Codable {
    let timestamp: Date
    let document: String
    let elements: [OCRElementLog]
}

struct OCRElementLog: Codable {
    let type: DocumentElement.ElementType
    let boundingBox: CGRect
    let confidence: Float
    let content: String
}

struct DocumentObservationLog: Codable {
    let timestamp: Date
    let document: String
    let result: DocumentAnalysisResult
}

struct MarkdownGenerationLog: Codable {
    let timestamp: Date
    let document: String
    let source: String
    let markdown: String
    let processingTime: TimeInterval
}

struct LLMPromptsLog: Codable {
    let timestamp: Date
    let document: String
    let systemPrompt: String
    let userPrompt: String
    let llmResponse: String
    let tokenCounts: TokenCounts
    let processingTime: TimeInterval
}

struct LLMOptimizedMarkdownLog: Codable {
    let timestamp: Date
    let document: String
    let original: String
    let optimized: String
    let optimizationDetails: String
}

struct TokenCounts: Codable {
    let input: Int
    let output: Int
    let total: Int
}
```

### 9. **Command Line Configuration Options**

```swift
struct CommandLineOptions {
    let configPath: String?
    let outputFormat: String
    let verbose: Bool
    let dryRun: Bool
    let outputDirectory: String?
    let logDirectory: String?
    
    static func parse() -> CommandLineOptions {
        var configPath: String?
        var outputFormat = "markdown"
        var verbose = false
        var dryRun = false
        var outputDirectory: String?
        var logDirectory: String?
        
        // Parse command line arguments
        for argument in CommandLine.arguments {
            switch argument {
            case "--config", "-c":
                if let index = CommandLine.arguments.firstIndex(of: argument),
                   index + 1 < CommandLine.arguments.count {
                    configPath = CommandLine.arguments[index + 1]
                }
            case "--output-format", "-f":
                if let index = CommandLine.arguments.firstIndex(of: argument),
                   index + 1 < CommandLine.arguments.count {
                    outputFormat = CommandLine.arguments[index + 1]
                }
            case "--output-dir", "-o":
                if let index = CommandLine.arguments.firstIndex(of: argument),
                   index + 1 < CommandLine.arguments.count {
                    outputDirectory = CommandLine.arguments[index + 1]
                }
            case "--log-dir", "-l":
                if let index = CommandLine.arguments.firstIndex(of: argument),
                   index + 1 < CommandLine.arguments.count {
                    logDirectory = CommandLine.arguments[index + 1]
                }
            case "--verbose", "-v":
                verbose = true
            case "--dry-run", "-n":
                dryRun = true
            default:
                break
            }
        }
        
        return CommandLineOptions(
            configPath: configPath,
            outputFormat: outputFormat,
            verbose: verbose,
            dryRun: dryRun,
            outputDirectory: outputDirectory,
            logDirectory: logDirectory
        )
    }
}
```

### Region-Based Configuration Examples

```json
// Example 1: Standard A4 document with 1-inch margins
{
  "headerFooterDetection": {
    "regionBasedDetection": {
      "enabled": true,
      "headerRegionY": 72.0,
      "footerRegionY": 720.0,
      "regionTolerance": 10.0
    }
  }
}

// Example 2: Technical document with narrow header region
{
  "headerFooterDetection": {
    "regionBasedDetection": {
      "enabled": true,
      "headerRegionY": 50.0,
      "footerRegionY": 750.0,
      "regionTolerance": 5.0
    }
  }
}

// Example 3: Percentage-based fallback (default behavior)
{
  "headerFooterDetection": {
    "percentageBasedDetection": {
      "enabled": true,
      "headerRegionHeight": 0.15,
      "footerRegionHeight": 0.12
    }
  }
}

// Example 4: Multi-region detection for complex layouts
{
  "headerFooterDetection": {
    "multiRegionDetection": {
      "enabled": true,
      "maxRegions": 3
    },
    "regionBasedDetection": {
      "enabled": true,
      "headerRegionY": 60.0,
      "footerRegionY": 730.0,
      "regionTolerance": 8.0
    }
  }
}
```

### Header Detection Configuration Examples

```json
// Example 1: Standard technical document headers
{
  "headerDetection": {
    "enabled": true,
    "sameLineTolerance": 5.0,
    "enableHeaderMerging": true,
    "enableLevelCalculation": true,
    "markdownLevelOffset": 1,
    "patterns": {
      "numberedHeaders": ["^\\d+(?:\\.\\d+)*\\s*$"],
      "letteredHeaders": ["^[A-Z](?:\\.\\d+)*\\s*$"],
      "romanHeaders": ["^[IVX]+(?:\\.\\d+)*\\s*$"]
    }
  }
}

// Example 2: Strict header detection with custom patterns
{
  "headerDetection": {
    "enabled": true,
    "sameLineTolerance": 2.0,
    "enableHeaderMerging": true,
    "enableLevelCalculation": true,
    "markdownLevelOffset": 2,
    "patterns": {
      "numberedHeaders": [
        "^\\d+(?:\\.\\d+)*\\s*$",
        "^\\d+[A-Z](?:\\.\\d+)*\\s*$"
      ],
      "letteredHeaders": [
        "^[A-Z](?:\\.\\d+)*\\s*$",
        "^[A-Z]\\d+(?:\\.\\d+)*\\s*$"
      ]
    }
  }
}

// Example 3: Multi-level document with parts
{
  "headerDetection": {
    "enabled": true,
    "sameLineTolerance": 8.0,
    "enableHeaderMerging": true,
    "enableLevelCalculation": true,
    "markdownLevelOffset": 2,
    "patterns": {
      "namedHeaders": [
        "^Part\\s+\\d+\\s*$",
        "^Chapter\\s+\\d+(?:\\.\\d+)*\\s*$",
        "^Section\\s+\\d+(?:\\.\\d+)*\\s*$",
        "^Appendix\\s+[A-Z]\\s*$"
      ]
    },
    "levelCalculation": {
      "customLevels": {
        "Part": 1,
        "Chapter": 2,
        "Section": 3
      }
    }
  }
}

// Example 4: List item detection configuration
{
  "listDetection": {
    "enabled": true,
    "sameLineTolerance": 5.0,
    "enableListItemMerging": true,
    "enableLevelCalculation": true,
    "enableNestedLists": true,
    "patterns": {
      "numberedMarkers": [
        "^\\d+\\)\\s*$",
        "^\\d+\\.\\s*$",
        "^\\d+-\\s*$"
      ],
      "letteredMarkers": [
        "^[a-z]\\)\\s*$",
        "^[a-z]\\.\\s*$",
        "^[a-z]-\\s*$"
      ],
      "bulletMarkers": [
        "^[•\\-\\*]\\s*$"
      ]
    },
    "indentation": {
      "baseIndentation": 50.0,
      "levelThreshold": 20.0,
      "enableXCoordinateAnalysis": true
    }
  }
}

// Example 5: Strict list detection with custom patterns
{
  "listDetection": {
    "enabled": true,
    "sameLineTolerance": 2.0,
    "enableListItemMerging": true,
    "enableLevelCalculation": true,
    "enableNestedLists": true,
    "patterns": {
      "numberedMarkers": [
        "^\\d+\\)\\s*$",
        "^\\d+\\.\\s*$"
      ],
      "letteredMarkers": [
        "^[a-z]\\)\\s*$",
        "^[a-z]\\.\\s*$"
      ],
      "bulletMarkers": [
        "^[•\\-\\*]\\s*$"
      ],
      "customMarkers": [
        "^[\\u25A0\\u25A1]\\s*$"
      ]
    },
    "indentation": {
      "baseIndentation": 40.0,
      "levelThreshold": 15.0,
      "enableXCoordinateAnalysis": true
    }
  }
}

// Example 6: LLM integration for markdown optimization
{
  "llm": {
    "enabled": true,
    "backend": "LocalLLMClientLlama",
    "model": {
      "id": "llama-3.1-8b-instruct-q4_0",
      "localPath": "~/models/llama-3.1-8b-instruct-q4_0.gguf"
    },
    "parameters": {
      "temperature": 0.1,
      "context": 4096,
      "threads": 8
    },
    "options": {
      "responseFormat": "markdown",
      "streaming": true
    },
    "contextManagement": {
      "maxContextLength": 4096,
      "chunkSize": 1000,
      "enableSlidingWindow": true
    }
  }
}

// Example 7: High-performance LLM configuration
{
  "llm": {
    "enabled": true,
    "backend": "LocalLLMClientLlama",
    "model": {
      "id": "llama-3.1-70b-instruct-q4_0",
      "localPath": "~/models/llama-3.1-70b-instruct-q4_0.gguf"
    },
    "parameters": {
      "temperature": 0.05,
      "context": 8192,
      "batch": 1024,
      "threads": 16,
      "gpuLayers": 32
    },
    "options": {
      "responseFormat": "markdown",
      "streaming": true,
      "verbose": true
    },
    "memoryOptimization": {
      "maxMemoryUsage": "16GB",
      "enableMemoryMapping": true
    }
  }
}

// Example 8: Custom prompt templates for technical documents
{
  "llm": {
    "enabled": true,
    "backend": "LocalLLMClientLlama",
    "model": {
      "id": "llama-3.1-8b-instruct-q4_0",
      "localPath": "~/models/llama-3.1-8b-instruct-q4_0.gguf"
    },
    "parameters": {
      "temperature": 0.1,
      "context": 4096,
      "threads": 8
    },
    "promptTemplates": {
      "systemPrompt": "You are a technical documentation specialist with expertise in ISO standards, engineering specifications, and regulatory compliance documents. Your role is to convert technical PDFs into clear, structured markdown while preserving all technical accuracy and compliance requirements.",
      
      "markdownOptimizationPrompt": "Technical Document: {documentTitle}\nStandard/Compliance: {documentContext}\nPages: {pageCount}\nElements: {elementCount}\n\nPlease optimize this technical document markdown for:\n1. Clear technical terminology preservation\n2. Proper compliance reference formatting\n3. Improved readability for engineers and technicians\n4. Consistent technical document structure\n\nMarkdown to optimize:\n{markdown}",
      
      "technicalStandardPrompt": "This document contains technical specifications, compliance requirements, and engineering standards. Preserve all numerical values, technical terms, and regulatory references exactly as written. Focus on improving structure and readability without altering technical content."
    }
  }
}

// Example 9: Specialized prompts for different document types
{
  "llm": {
    "enabled": true,
    "backend": "LocalLLMClientLlama",
    "model": {
      "id": "llama-3.1-8b-instruct-q4_0",
      "localPath": "~/models/llama-3.1-8b-instruct-q4_0.gguf"
    },
    "promptTemplates": {
      "languages": {
        "en": {
          "systemPrompt": "You are an expert document processor specializing in academic, technical, and business documents. Adapt your processing style based on the document type detected.",
          "markdownOptimizationPrompt": "Document: {documentTitle}\nType: {documentType}\nContext: {documentContext}\n\nPlease optimize this markdown according to the document type:\n- Academic: Focus on citation formatting and logical flow\n- Technical: Preserve technical accuracy and specifications\n- Business: Improve clarity and professional presentation\n\nMarkdown: {markdown}"
        }
      },
      "defaultLanguage": "en"
    }
  }
}

// Example 10: Multi-language support with Chinese and English
{
  "llm": {
    "enabled": true,
    "backend": "LocalLLMClientLlama",
    "model": {
      "id": "llama-3.1-8b-instruct-q4_0",
      "localPath": "~/models/llama-3.1-8b-instruct-q4_0.gguf"
    },
    "promptTemplates": {
      "languages": {
        "en": {
          "systemPrompt": [
            "You are an expert document processor specializing in technical documents.",
            "Focus on ISO standards, engineering specifications, and compliance requirements."
          ]
        },
        "zh": {
          "systemPrompt": [
            "您是一位专门处理技术文档的专家。",
            "专注于ISO标准、工程规范和合规要求。"
          ]
        }
      },
      "defaultLanguage": "en",
      "fallbackLanguage": "en"
    }
  }
}

// Example 11: Chinese technical standards configuration
{
  "llm": {
    "enabled": true,
    "backend": "LocalLLMClientLlama",
    "model": {
      "id": "llama-3.1-8b-instruct-q4_0",
      "localPath": "~/models/llama-3.1-8b-instruct-q4_0.gguf"
    },
    "promptTemplates": {
      "languages": {
        "zh": {
          "systemPrompt": [
            "您是一位专门处理中文技术标准文档的专家，具备以下专长：",
            "- 中国国家标准（GB）和行业标准",
            "- 国际标准的中文版本",
            "- 工程和技术规范文档",
            "- 合规性和认证要求",
            "",
            "特别要求：",
            "1. 保持中文技术术语的准确性",
            "2. 维护标准编号和引用格式",
            "3. 确保中文文档的可读性",
            "4. 遵循中文技术文档的写作规范"
          ],
          "technicalStandardPrompt": [
            "这是一份中文技术标准文档。",
            "请确保所有技术术语、规格和引用都完全保持原样，",
            "同时改进整体结构和可读性。",
            "特别注意中文技术术语的准确性和一致性。"
          ]
        }
      },
      "defaultLanguage": "zh",
      "fallbackLanguage": "en"
    }
  }
}

### Overlap Detection Settings
```swift
struct DuplicationDetectionConfig {
    let overlapThreshold: Float = 0.3 // 30% overlap threshold
    let enableLogging: Bool = true
    let logOverlaps: Bool = true
    let strictMode: Bool = false // More aggressive duplication detection
}

### Position Sorting Options
```swift
struct PositionSortingConfig {
    let sortBy: SortCriteria = .verticalPosition
    let tolerance: Float = 5.0 // Pixels tolerance for Y-coordinate comparison
    
    enum SortCriteria {
        case verticalPosition    // Top to bottom
        case horizontalPosition  // Left to right
        case confidence         // High confidence first
        case elementType        // Specific element type priority
    }
}
```

## Analysis and Debugging Tools

### Header and Footer Analysis
```swift
func analyzeHeadersFooters(_ elements: [DocumentElement], from pages: [PDFPage]) {
    print("=== Header and Footer Analysis ===")
    
    var headerCandidates: [String: Int] = [:]
    var footerCandidates: [String: Int] = [:]
    
    for (pageIndex, page) in pages.enumerated() {
        let pageElements = elements.filter { /* page association logic */ }
        
        // Analyze header region (top 10%)
        let headerElements = pageElements.filter { element in
            let pageHeight = page.bounds.height
            let elementY = element.boundingBox.minY
            return elementY < pageHeight * 0.1
        }
        
        // Analyze footer region (bottom 10%)
        let footerElements = pageElements.filter { element in
            let pageHeight = page.bounds.height
            let elementY = element.boundingBox.maxY
            return elementY > pageHeight * 0.9
        }
        
        print("Page \(pageIndex + 1):")
        print("  Header candidates: \(headerElements.count)")
        for element in headerElements {
            let content = extractTextContent(from: element)
            headerCandidates[content, default: 0] += 1
            print("    - \(content)")
        }
        
        print("  Footer candidates: \(footerElements.count)")
        for element in footerElements {
            let content = extractTextContent(from: element)
            footerCandidates[content, default: 0] += 1
            print("    - \(content)")
        }
    }
    
    print("\nHeader patterns (appearing in multiple pages):")
    for (content, frequency) in headerCandidates.sorted(by: { $0.value > $1.value }) {
        if frequency > 1 {
            print("  \(content) - appears in \(frequency) pages")
        }
    }
    
    print("\nFooter patterns (appearing in multiple pages):")
    for (content, frequency) in footerCandidates.sorted(by: { $0.value > $1.value }) {
        if frequency > 1 {
            print("  \(content) - appears in \(frequency) pages")
        }
    }
}
```

### Element Overlap Analysis
```swift
func analyzeElementOverlap(_ elements: [DocumentElement]) {
    print("=== Document Element Analysis ===")
    
    for (i, element) in elements.enumerated() {
        print("\(i+1). \(element.type) - Y: \(element.boundingBox.minY), Height: \(element.boundingBox.height)")
        
        // Check for overlaps with other elements
        for (j, otherElement) in elements.enumerated() where i != j {
            let intersection = element.boundingBox.intersection(otherElement.boundingBox)
            if !intersection.isNull {
                let overlapRatio = intersection.width * intersection.height / (element.boundingBox.width * element.boundingBox.height)
                print("   Overlaps with \(j+1). \(otherElement.type) - Ratio: \(overlapRatio * 100)%")
            }
        }
    }
}
```

### Confidence Analysis
```swift
func analyzeElementConfidence(_ elements: [DocumentElement]) {
    print("=== Element Confidence Analysis ===")
    
    let confidenceGroups = Dictionary(grouping: elements) { element in
        switch element.confidence {
        case 0.9...: return "High (90%+)"
        case 0.7..<0.9: return "Good (70-89%)"
        case 0.5..<0.7: return "Fair (50-69%)"
        default: return "Low (<50%)"
        }
    }
    
    for (confidence, elements) in confidenceGroups.sorted(by: { $0.key < $1.key }) {
        print("\(confidence): \(elements.count) elements")
        for element in elements {
            print("  - \(element.type) at Y: \(element.boundingBox.minY)")
        }
    }
}
```

### Header Detection Analysis
```swift
func analyzeHeaderDetection(_ elements: [DocumentElement]) {
    print("=== Header Detection Analysis ===")
    
    let headers = elements.filter { $0.type == .header }
    let potentialHeaders = elements.filter { element in
        if let text = extractTextContent(from: element) {
            return isHeaderMarker(text)
        }
        return false
    }
    
    print("Detected headers: \(headers.count)")
    for header in headers {
        if let headerContent = header.content as? MergedHeaderContent {
            print("  - \(headerContent.marker) \(headerContent.content) (Level \(headerContent.level))")
        }
    }
    
    print("\nPotential header markers (not merged): \(potentialHeaders.count)")
    for element in potentialHeaders {
        let text = extractTextContent(from: element) ?? ""
        print("  - '\(text)' at Y: \(element.boundingBox.minY)")
    }
    
    // Analyze header level distribution
    let levelGroups = Dictionary(grouping: headers) { header in
        if let headerContent = header.content as? MergedHeaderContent {
            return headerContent.level
        }
        return 0
    }
    
    print("\nHeader level distribution:")
    for level in levelGroups.keys.sorted() {
        let count = levelGroups[level]?.count ?? 0
        print("  Level \(level): \(count) headers")
    }
}

private func isHeaderMarker(_ text: String) -> Bool {
    // Same logic as in HeaderDetector
    let patterns = [
        #"^\d+(?:\.\d+)*\s*$"#,
        #"^[A-Z](?:\.\d+)*\s*$"#,
        #"^[IVX]+(?:\.\d+)*\s*$"#,
        #"^(Chapter|Section|Part)\s+\d+(?:\.\d+)*\s*$"#,
        #"^Appendix\s+[A-Z](?:\.\d+)*\s*$"#
    ]
    
    return patterns.contains { pattern in
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
```

## Benefits of This Approach

### 1. **Consistent Processing Order**
- Elements are always processed from top to bottom
- Maintains logical document flow
- Predictable output structure

### 2. **Duplicate Prevention**
- Eliminates redundant content
- Improves output quality
- Reduces processing time

### 3. **Header and Footer Filtering**
- Automatically detects repetitive page elements
- Filters out common headers (titles, chapter names, page numbers)
- Removes footers (copyright notices, company branding, legal disclaimers)
- Significantly improves markdown quality and readability
- **Region-based detection** provides precise control over header/footer boundaries
- **Absolute coordinate support** enables consistent detection across different document sizes
- **Configurable tolerance** handles slight variations in element positioning

### 4. **Precise Region Control**
- **Absolute Coordinates**: Define exact Y-coordinates for header/footer boundaries
- **Consistent Detection**: Same boundaries work across different document sizes
- **Professional Layouts**: Handle documents with specific margin requirements
- **Multi-Region Support**: Detect complex layouts with multiple header/footer areas

### 5. **Centralized File Management**
- **Single Source of Truth**: All file paths generated from configuration
- **Consistent Naming**: Timestamped files with document hashes
- **Organized Output**: Separate directories for markdown, logs, and temp files
- **Comprehensive Logging**: Detailed logs for every processing step
- **Traceability**: Link generated markdown to source OCR elements and LLM prompts

### 6. **Unified Header and List Detection**
- **Generic Paragraph Merging**: Handles both broken headers and list items
- **Pattern-Based Detection**: Recognizes various marker patterns (1), a), •, etc.)
- **Level Calculation**: Automatic nesting level detection using x-coordinate analysis
- **Smart Merging**: Combines split markers and content using Y-coordinate tolerance
- **Markdown Generation**: Proper nested list syntax with indentation

### 7. **LLM-Powered Markdown Optimization**
- **Intelligent Structure Analysis**: AI-powered document structure understanding
- **Content Enhancement**: Improves readability and formatting quality
- **Context-Aware Processing**: Considers document context for better optimization
- **Customizable Prompts**: Configurable system and optimization prompts
- **Performance Optimization**: Streaming responses and memory management

### 8. **Flexible Configuration**
- Adjustable overlap thresholds
- Configurable sorting criteria
- Customizable header/footer detection regions
- Debugging and analysis tools

### 9. **Maintainable Code**
- Single source of truth for element processing
- Clear separation of concerns
- Easy to extend and modify

## Potential Challenges and Mitigations

### 1. **Performance Impact**
- **Challenge**: Processing all elements together might be slower
- **Mitigation**: Implement lazy evaluation and batch processing

### 2. **Memory Usage**
- **Challenge**: Storing all elements in memory
- **Mitigation**: Stream processing for large documents

### 3. **Overlap Detection Accuracy**
- **Challenge**: Finding the right overlap threshold
- **Mitigation**: Configurable thresholds and extensive testing

### 4. **Element Type Conflicts**
- **Challenge**: Deciding which element type to keep when duplicates exist
- **Mitigation**: Priority-based selection and confidence weighting

## Next Steps

1. **Review and Approve** this proposal
2. **Implement Phase 1** (Foundation)
3. **Test with sample PDFs** to understand duplication patterns
4. **Iterate and refine** based on real-world usage
5. **Integrate with existing codebase**

## Advanced Header/Footer Detection Strategies

### 1. **Content-Based Pattern Recognition**
- **Text Similarity**: Use fuzzy string matching to detect similar headers/footers
- **Regular Expressions**: Pattern matching for common header/footer formats
- **Semantic Analysis**: Identify document structure patterns (e.g., "Chapter X", "Section Y")

### 2. **Position and Layout Analysis**
- **Consistent Positioning**: Headers/footers often appear at exact same coordinates
- **Font Consistency**: Same font family, size, and style across pages
- **Alignment Patterns**: Consistent left/center/right alignment

### 3. **Frequency and Repetition Analysis**
- **Cross-Page Comparison**: Content that appears on multiple pages
- **Page Number Detection**: Automatic page numbering patterns
- **Document Metadata**: Title, author, date patterns

### 4. **Machine Learning Enhancement**
- **Training Data**: Use labeled documents to improve detection accuracy
- **Feature Extraction**: Combine position, content, and visual characteristics
- **Adaptive Thresholds**: Learn optimal detection parameters for different document types

### 5. **Automatic Region Detection**
- **Layout Analysis**: Automatically detect header/footer regions from document structure
- **Pattern Recognition**: Identify consistent positioning across multiple pages
- **Coordinate Learning**: Learn optimal Y-coordinates for different document types
- **Adaptive Boundaries**: Adjust region boundaries based on content analysis

## Testing and Validation Strategy

### 1. **Header Detection Testing**
```swift
// Test cases for header detection and merging
let headerTestCases = [
    // Basic numbered headers
    ("5", "Access Control", "5 Access Control", 1),
    ("5.1", "Authentication", "5.1 Authentication", 2),
    ("5.1.2", "Password Policy", "5.1.2 Password Policy", 3),
    ("5.1.2.1", "Complexity Requirements", "5.1.2.1 Complexity Requirements", 4),
    
    // Lettered headers
    ("A", "Introduction", "A Introduction", 1),
    ("A.1", "Background", "A.1 Background", 2),
    ("A.1.2", "Scope", "A.1.2 Scope", 3),
    
    // Named headers
    ("Chapter 5", "Security", "Chapter 5 Security", 2),
    ("Section 5.1", "Access Control", "Section 5.1 Access Control", 3),
    ("Part 1", "Overview", "Part 1 Overview", 2),
    ("Appendix A", "Glossary", "Appendix A Glossary", 2)
]

// Test OCR splitting scenarios
let ocrSplitTestCases = [
    // Marker and content on same line (should merge)
    (CGRect(x: 10, y: 100, width: 50, height: 20), "5.1.2"),
    (CGRect(x: 70, y: 102, width: 200, height: 18), "Access Control"),
    
    // Marker and content on different lines (should not merge)
    (CGRect(x: 10, y: 100, width: 50, height: 20), "5.1.2"),
    (CGRect(x: 70, y: 130, width: 200, height: 18), "Access Control")
]

// Test list item splitting scenarios
let listItemSplitTestCases = [
    // List marker and content on same line (should merge)
    (CGRect(x: 50, y: 200, width: 30, height: 20), "1)"),
    (CGRect(x: 85, y: 202, width: 300, height: 18), "Access control must be established"),
    
    // List marker and content on different lines (should not merge)
    (CGRect(x: 50, y: 200, width: 30, height: 20), "1)"),
    (CGRect(x: 85, y: 250, width: 300, height: 18), "Access control must be established"),
    
    // Nested list items with different indentation
    (CGRect(x: 50, y: 300, width: 30, height: 20), "1)"),
    (CGRect(x: 85, y: 302, width: 280, height: 18), "Main list item"),
    (CGRect(x: 70, y: 330, width: 30, height: 20), "a)"),
    (CGRect(x: 105, y: 332, width: 260, height: 18), "Sub-list item"),
    (CGRect(x: 90, y: 360, width: 30, height: 20), "i)"),
    (CGRect(x: 125, y: 362, width: 240, height: 18), "Sub-sub-list item")
]
```

### 2. **Validation Metrics**
- **Header Detection Accuracy**: Percentage of correctly identified headers
- **Merging Success Rate**: Percentage of split headers successfully merged
- **Level Calculation Accuracy**: Correct header level assignment
- **Markdown Generation Quality**: Proper markdown syntax and structure

### 3. **Test Document Types**
- **Technical Standards**: ISO, IEEE, RFC documents
- **Academic Papers**: Journal articles with hierarchical structure
- **Technical Manuals**: User guides with numbered sections
- **Legal Documents**: Contracts with section numbering
- **Corporate Reports**: Business documents with structured headers

## Configuration Best Practices and Usage

### 1. **Configuration File Organization**
```
project/
├── mdkit-config.json          # Project-specific configuration
├── configs/
│   ├── base.json              # Base configuration template
│   ├── technical-docs.json    # Technical document settings
│   ├── academic-papers.json   # Academic paper settings
│   └── legal-docs.json       # Legal document settings
├── output/                    # Generated markdown files
├── logs/                      # Processing logs
├── temp/                      # Temporary files
└── ~/.config/mdkit/
    └── config.json            # User default configuration
```

### 2. **File Output Structure**
```
output/
├── 20241201_143022_a1b2c3d4.md          # Generated markdown
├── 20241201_143022_e5f6g7h8.md          # Another document
└── ...

logs/
├── 20241201_143022_a1b2c3d4_ocr_elements.json
├── 20241201_143022_a1b2c3d4_document_observation.json
├── 20241201_143022_a1b2c3d4_markdown_generation.md
├── 20241201_143022_a1b2c3d4_llm_prompts.json
├── 20241201_143022_a1b2c3d4_llm_optimized.md
└── ...
```

### 2. **Configuration Inheritance Strategy**
```json
{
  "baseConfig": "configs/base.json",
  "overrides": {
    "headerFooterDetection.regionBasedDetection.headerRegionY": 80.0
  },
  "environment": "development"
}
```

### 3. **Environment-Specific Configurations**
- **Development**: Debug logging, lower memory limits, single-threaded
- **Production**: Warning/error logging, higher memory limits, multi-threaded
- **Testing**: Info logging, strict validation, performance monitoring

### 4. **Configuration Validation Rules**
- **Required Fields**: Essential configuration sections
- **Value Ranges**: Numeric constraints (e.g., tolerance: 0-50 pixels)
- **Pattern Validation**: Regular expression syntax checking
- **Schema Compliance**: JSON schema validation

### 5. **Command Line Usage Examples**
```bash
# Use default configuration
mdkit input.pdf

# Use custom configuration file
mdkit --config my-config.json input.pdf

# Use project configuration
mdkit --config ./mdkit-config.json input.pdf

# Generate configuration template
mdkit --generate-config > template.json

# Validate configuration
mdkit --validate-config my-config.json

# Dry run with configuration
mdkit --dry-run --config my-config.json input.pdf
```

### 6. **Configuration Migration and Versioning**
- **Version Field**: Track configuration schema versions
- **Migration Scripts**: Automatic configuration updates
- **Backward Compatibility**: Support for older configuration formats
- **Deprecation Warnings**: Notify users of deprecated options

## Main Processing Pipeline Integration

### **LLM Integration for Markdown Optimization**

The system will integrate llama.cpp through LocalLLMClientLlama to optimize markdown generation. All prompts are fully configurable using template placeholders:

#### **Prompt Template System**

The system uses a flexible template system with placeholders that get replaced with actual content. Prompts can be defined as either single strings or arrays of lines for better readability and maintenance.

**Multi-Line Prompt Format:**
```json
"systemPrompt": [
  "You are an expert document processor specializing in converting technical documents to well-structured markdown.",
  "Your expertise includes:",
  "- ISO standards and technical specifications",
  "- Engineering documentation and compliance requirements",
  "- Academic papers and research documents",
  "- Business reports and procedural manuals",
  "",
  "Key responsibilities:",
  "1. Preserve all technical accuracy and compliance requirements",
  "2. Improve document structure and readability",
  "3. Maintain consistent formatting and hierarchy",
  "4. Ensure proper markdown syntax and standards",
  "",
  "Always respond in markdown format and maintain the original document's technical integrity."
]
```

**Available Placeholders:**
- `{documentTitle}` - Document title or filename
- `{pageCount}` - Total number of pages
- `{elementCount}` - Total number of detected elements
- `{documentContext}` - Document summary or context
- `{documentType}` - Detected document type (Technical Standard, Data Report, etc.)
- `{markdown}` - The markdown content to optimize
- `{elementDescriptions}` - Descriptions of detected elements
- `{tableContent}` - Table content for table-specific optimization
- `{listContent}` - List content for list-specific optimization
- `{headerContent}` - Header content for header-specific optimization
- `{detectedLanguage}` - Automatically detected document language (en, zh, ja, etc.)
- `{languageConfidence}` - Confidence level of language detection (0.0-1.0)

**Template Categories:**
1. **System Prompts**: Define the AI's role and expertise
2. **General Prompts**: Main optimization and analysis prompts
3. **Specialized Prompts**: Element-specific optimization prompts
4. **Document-Type Prompts**: Specialized prompts for different document types

**Benefits of Multi-Line Format:**
- ✅ **Better Readability**: Each requirement on its own line
- ✅ **Easy Maintenance**: Simple to add/remove/modify lines
- ✅ **Version Control Friendly**: Clear diffs when changes are made
- ✅ **Structured Format**: Logical grouping of related requirements
- ✅ **No Escape Characters**: Clean, readable JSON
- ✅ **Flexible Spacing**: Easy to add empty lines for visual separation

#### **Multi-Language Support**

The system automatically detects document language using Apple's Natural Language framework and selects appropriate prompts:

**Language Detection:**
- **Automatic Detection**: Uses Vision Framework's OCR results with Natural Language framework
- **Confidence Scoring**: Provides confidence levels for language detection
- **Mixed Language Support**: Handles documents with multiple languages
- **Fallback Chain**: Default → Fallback → Primary language selection

**Supported Languages:**
- **English (en)**: Default language with comprehensive technical prompts
- **Chinese (zh)**: Full Chinese language support with localized prompts
- **Japanese (ja)**: Japanese document processing
- **Korean (ko)**: Korean document processing
- **German (de)**: German document processing
- **French (fr)**: French document processing
- **Spanish (es)**: Spanish document processing

**Language-Specific Features:**
- **Localized Prompts**: Language-specific instructions and terminology
- **Cultural Adaptation**: Prompts adapted to different writing conventions
- **Professional Quality**: Native-language document processing
- **Compliance Ready**: Supports international standards and regulations

This allows users to customize the AI's behavior for specific document types, compliance requirements, or organizational standards with clear, maintainable prompt configurations in multiple languages.

```swift
class LLMProcessor {
    let config: LLMConfig
    let client: any LLMClient
    let languageDetector: any LanguageDetecting
    
    init(
        config: LLMConfig,
        client: any LLMClient,
        languageDetector: any LanguageDetecting
    ) {
        self.config = config
        self.client = client
        self.languageDetector = languageDetector
    }
    
    // Factory method for easy creation with default implementations
    static func create(config: LLMConfig) throws -> LLMProcessor {
        let client = try LocalLLMClientLlama(
            parameter: .init(
                temperature: config.parameters.temperature,
                topP: config.parameters.topP,
                topK: config.parameters.topK,
                penaltyRepeat: config.parameters.penaltyRepeat,
                penaltyFrequency: config.parameters.penaltyFrequency,
                context: config.parameters.context,
                batch: config.parameters.batch,
                threads: config.parameters.threads,
                gpuLayers: config.parameters.gpuLayers,
                options: .init(
                    responseFormat: config.options.responseFormat == "json" ? .json : .text,
                    verbose: config.options.verbose,
                    streaming: config.options.streaming
                )
            )
        )
        let languageDetector = LanguageDetector()
        
        return LLMProcessor(
            config: config,
            client: client,
            languageDetector: languageDetector
        )
    }
    
    func optimizeMarkdown(_ markdown: String, documentContext: DocumentContext, elements: [DocumentElement]) async throws -> String {
        // Detect document language
        let languageInfo = languageDetector.detectLanguage(from: elements)
        let prompts = config.promptTemplates.getPrompts(for: languageInfo.primaryLanguage)
        
        let systemPrompt = prompts.systemPrompt.asString
        let optimizationPrompt = prompts.markdownOptimizationPrompt.asString
        
        // Build user prompt using configurable template with placeholders
        let userPrompt = optimizationPrompt
            .replacingOccurrences(of: "{documentContext}", with: documentContext.summary)
            .replacingOccurrences(of: "{markdown}", with: markdown)
            .replacingOccurrences(of: "{documentTitle}", with: documentContext.title ?? "Unknown Document")
            .replacingOccurrences(of: "{pageCount}", with: String(documentContext.pageCount))
            .replacingOccurrences(of: "{elementCount}", with: String(documentContext.elementCount))
            .replacingOccurrences(of: "{detectedLanguage}", with: languageInfo.primaryLanguage)
            .replacingOccurrences(of: "{languageConfidence}", with: String(format: "%.2f", languageInfo.confidence))
        
        let input = LLMInput.chat([
            .system(systemPrompt),
            .user(userPrompt)
        ])
        
        var optimizedMarkdown = ""
        for try await text in client.textStream(from: input) {
            optimizedMarkdown += text
        }
        
        return optimizedMarkdown
    }
    
    func analyzeDocumentStructure(_ elements: [DocumentElement]) async throws -> DocumentStructureAnalysis {
        // Detect document language
        let languageInfo = languageDetector.detectLanguage(from: elements)
        let prompts = config.promptTemplates.getPrompts(for: languageInfo.primaryLanguage)
        
        let systemPrompt = prompts.systemPrompt.asString
        let analysisPrompt = prompts.structureAnalysisPrompt.asString
        
        let elementDescriptions = elements.map { element in
            "\(element.type): \(extractTextContent(from: element) ?? "") at Y: \(element.boundingBox.minY)"
        }.joined(separator: "\n")
        
        // Build user prompt using configurable template with placeholders
        let userPrompt = analysisPrompt
            .replacingOccurrences(of: "{elementDescriptions}", with: elementDescriptions)
            .replacingOccurrences(of: "{elementCount}", with: String(elements.count))
            .replacingOccurrences(of: "{documentType}", with: determineDocumentType(from: elements))
            .replacingOccurrences(of: "{detectedLanguage}", with: languageInfo.primaryLanguage)
        
        let input = LLMInput.chat([
            .system(systemPrompt),
            .user(userPrompt)
        ])
        
        var analysis = ""
        for try await text in client.textStream(from: input) {
            analysis += text
        }
        
        return parseStructureAnalysis(analysis)
    }
    
    private func determineDocumentType(from elements: [DocumentElement]) -> String {
        // Analyze elements to determine document type
        let hasTables = elements.contains { $0.type == .table }
        let hasLists = elements.contains { $0.type == .listItem }
        let hasHeaders = elements.contains { $0.type == .header }
        
        if hasTables && hasLists && hasHeaders {
            return "Technical Standard"
        } else if hasTables {
            return "Data Report"
        } else if hasLists {
            return "Procedure Manual"
        } else if hasHeaders {
            return "Structured Document"
        } else {
            return "General Document"
        }
    }
}

class LanguageDetector {
    func detectLanguage(from elements: [DocumentElement]) -> DocumentLanguageInfo {
        var languageCounts: [String: Int] = [:]
        var totalConfidence: Float = 0.0
        var totalElements = 0
        
        for element in elements {
            if let text = extractTextContent(from: element) {
                let detectedLanguage = detectTextLanguage(text)
                languageCounts[detectedLanguage, default: 0] += 1
                totalElements += 1
            }
        }
        
        // Find primary language
        let primaryLanguage = languageCounts.max(by: { $0.value < $1.value })?.key ?? "en"
        let primaryCount = languageCounts[primaryLanguage] ?? 0
        let confidence = Float(primaryCount) / Float(totalElements)
        
        // Check for mixed language
        let isMixedLanguage = languageCounts.count > 1 && confidence < 0.8
        
        // Calculate confidence for each detected language
        let detectedLanguages = languageCounts.mapValues { Float($0) / Float(totalElements) }
        
        return DocumentLanguageInfo(
            primaryLanguage: primaryLanguage,
            confidence: confidence,
            detectedLanguages: detectedLanguages,
            isMixedLanguage: isMixedLanguage
        )
    }
    
    private func detectTextLanguage(_ text: String) -> String {
        // Use Apple's Natural Language framework for language detection
        let languageRecognizer = NLLanguageRecognizer()
        languageRecognizer.processString(text)
        
        guard let language = languageRecognizer.dominantLanguage else {
            return "en" // Default to English
        }
        
        // Map NLLanguage to our language codes
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return "zh"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .german:
            return "de"
        case .french:
            return "fr"
        case .spanish:
            return "es"
        default:
            return "en"
        }
    }
}

struct LLMConfig {
    let enabled: Bool
    let backend: String
    let modelPath: String
    let model: ModelConfig
    let parameters: LLMParameters
    let options: LLMOptions
    let contextManagement: ContextManagement
    let memoryOptimization: MemoryOptimization
    let promptTemplates: PromptTemplates
}

struct ModelConfig {
    let id: String
    let name: String
    let type: String
    let downloadUrl: String?
    let localPath: String
}

struct LLMParameters {
    let temperature: Float
    let topP: Float
    let topK: Int
    let penaltyRepeat: Float
    let penaltyFrequency: Float
    let context: Int
    let batch: Int
    let threads: Int
    let gpuLayers: Int
}

struct LLMOptions {
    let responseFormat: String
    let verbose: Bool
    let streaming: Bool
    let jsonMode: Bool
}

struct ContextManagement {
    let maxContextLength: Int
    let overlapLength: Int
    let chunkSize: Int
    let enableSlidingWindow: Bool
    let enableHierarchicalProcessing: Bool
}

struct MemoryOptimization {
    let maxMemoryUsage: String
    let enableStreaming: Bool
    let cleanupAfterBatch: Bool
    let enableMemoryMapping: Bool
}

struct PromptTemplates {
    let languages: [String: LanguagePrompts]
    let defaultLanguage: String
    let fallbackLanguage: String
    
    func getPrompts(for language: String) -> LanguagePrompts {
        return languages[language] ?? languages[fallbackLanguage] ?? languages[defaultLanguage]!
    }
}

struct LanguagePrompts {
    let systemPrompt: PromptContent
    let markdownOptimizationPrompt: PromptContent
    let structureAnalysisPrompt: PromptContent
    let tableOptimizationPrompt: PromptContent?
    let listOptimizationPrompt: PromptContent?
    let headerOptimizationPrompt: PromptContent?
    let technicalStandardPrompt: PromptContent?
}

struct DocumentLanguageInfo {
    let primaryLanguage: String
    let confidence: Float
    let detectedLanguages: [String: Float]
    let isMixedLanguage: Bool
}

enum PromptContent {
    case singleLine(String)
    case multiLine([String])
    
    var asString: String {
        switch self {
        case .singleLine(let text):
            return text
        case .multiLine(let lines):
            return lines.joined(separator: "\n")
        }
    }
}

// MARK: - Protocols for Lightweight Dependency Injection

protocol LLMClient {
    func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Error>
    func generateText(from input: LLMInput) async throws -> String
}

protocol LanguageDetecting {
    func detectLanguage(from elements: [DocumentElement]) -> DocumentLanguageInfo
}

protocol FileManaging {
    func generateOutputPaths(for document: String) -> OutputPaths
    func saveMarkdown(_ markdown: String, to path: String) throws
    func saveLog(_ data: Data, category: String, to path: String) throws
    func cleanupTempFiles()
}

protocol Logging {
    func logOCRElements(_ elements: [DocumentElement], for document: String) throws
    func logDocumentObservation(_ result: DocumentObservationResult, for document: String) throws
    func logMarkdownGeneration(_ markdown: String, source: String, for document: String) throws
    func logLLMPrompts(systemPrompt: String, userPrompt: String, llmResponse: String, tokenCounts: TokenCounts?, for document: String) throws
    func logLLMOptimizedMarkdown(original: String, optimized: String, optimizationDetails: String, for document: String) throws
}

protocol DocumentProcessing {
    func processOCR(_ pdfPath: String) async throws -> [DocumentElement]
    func processDocumentObservation(_ elements: [DocumentElement]) async throws -> DocumentObservationResult
    func generateMarkdown(_ result: DocumentObservationResult) async throws -> String
    func optimizeWithLLM(_ markdown: String, elements: [DocumentElement]) async throws -> (String, LLMPrompts, String)
}

struct DocumentContext {
    let title: String?
    let pageCount: Int
    let elementCount: Int
    let summary: String
}

struct DocumentStructureAnalysis {
    let suggestedHeaders: [String]
    let suggestedLists: [String]
    let structureImprovements: [String]
    let confidence: Float
}
```

### **Centralized File Management Integration**

The main processing pipeline will integrate the centralized file management system to ensure all outputs follow the same source of truth:

```swift
class MainProcessor {
    let config: MDKitConfig
    let fileManager: any FileManaging
    let logger: any Logging
    let documentProcessor: any DocumentProcessing
    let llmProcessor: LLMProcessor?
    
    init(
        config: MDKitConfig,
        fileManager: any FileManaging,
        logger: any Logging,
        documentProcessor: any DocumentProcessing,
        llmProcessor: LLMProcessor? = nil
    ) {
        self.config = config
        self.fileManager = fileManager
        self.logger = logger
        self.documentProcessor = documentProcessor
        self.llmProcessor = llmProcessor
    }
    
    // Factory method for easy creation with default implementations
    static func create(config: MDKitConfig) throws -> MainProcessor {
        let fileManager = FileManager(config: config.fileManagement)
        let logger = Logger(config: config.logging)
        let documentProcessor = DocumentProcessor(config: config)
        
        let llmProcessor: LLMProcessor?
        if config.llm.enabled {
            llmProcessor = try LLMProcessor.create(config: config.llm)
        } else {
            llmProcessor = nil
        }
        
        return MainProcessor(
            config: config,
            fileManager: fileManager,
            logger: logger,
            documentProcessor: documentProcessor,
            llmProcessor: llmProcessor
        )
    }
    
    func processDocument(_ pdfPath: String) async throws {
        let documentName = URL(fileURLWithPath: pdfPath).lastPathComponent
        let outputPaths = fileManager.generateOutputPaths(for: documentName)
        
        // Step 1: OCR Processing
        let ocrElements = try await documentProcessor.processOCR(pdfPath)
        try logger.logOCRElements(ocrElements, for: documentName)
        
        // Step 2: Document Observation
        let documentResult = try await documentProcessor.processDocumentObservation(ocrElements)
        try logger.logDocumentObservation(documentResult, for: documentName)
        
        // Step 3: Markdown Generation
        let markdown = try await documentProcessor.generateMarkdown(documentResult)
        try logger.logMarkdownGeneration(markdown, source: "document_observation", for: documentName)
        
        // Step 4: LLM Optimization (if enabled)
        if let llmProcessor = llmProcessor {
            let (optimizedMarkdown, prompts, response) = try await documentProcessor.optimizeWithLLM(markdown, elements: ocrElements)
            try logger.logLLMPrompts(
                systemPrompt: prompts.system,
                userPrompt: prompts.user,
                llmResponse: response,
                tokenCounts: prompts.tokenCounts,
                for: documentName
            )
            try logger.logLLMOptimizedMarkdown(
                original: markdown,
                optimized: optimizedMarkdown,
                optimizationDetails: "LLM enhanced structure and formatting",
                for: documentName
            )
            
            // Save optimized markdown
            try fileManager.saveMarkdown(optimizedMarkdown, to: outputPaths.markdown)
        } else {
            // Save original markdown
            try fileManager.saveMarkdown(markdown, to: outputPaths.markdown)
        }
        
        // Cleanup temporary files
        fileManager.cleanupTempFiles()
    }
}
```

### **Benefits of Centralized Integration**

1. **Consistent File Naming**: All files follow the same timestamped pattern
2. **Traceability**: Link final markdown to every processing step
3. **Debugging**: Complete logs for troubleshooting and optimization
4. **Reproducibility**: Recreate results from logged data
5. **Quality Assurance**: Compare original and optimized outputs

### **Lightweight Dependency Injection**

The system uses lightweight dependency injection to improve testability and maintainability without over-engineering:

#### **Protocol-Based Interfaces**
```swift
protocol LLMClient {
    func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Error>
    func generateText(from input: LLMInput) async throws -> String
}

protocol LanguageDetecting {
    func detectLanguage(from elements: [DocumentElement]) -> DocumentLanguageInfo
}

protocol FileManaging {
    func generateOutputPaths(for document: String) -> OutputPaths
    func saveMarkdown(_ markdown: String, to path: String) throws
    func cleanupTempFiles()
}
```

#### **Constructor Injection**
```swift
class LLMProcessor {
    let config: LLMConfig
    let client: any LLMClient
    let languageDetector: any LanguageDetecting
    
    init(
        config: LLMConfig,
        client: any LLMClient,
        languageDetector: any LanguageDetecting
    ) {
        self.config = config
        self.client = client
        self.languageDetector = languageDetector
    }
}
```

#### **Factory Methods for Easy Usage**
```swift
// Easy creation with default implementations
let processor = try LLMProcessor.create(config: config)

// Custom dependencies for testing
let mockClient = MockLLMClient()
let mockDetector = MockLanguageDetector()
let processor = LLMProcessor(
    config: config,
    client: mockClient,
    languageDetector: mockDetector
)
```

#### **Benefits of Lightweight DI**
✅ **Easy Testing**: Simple to mock dependencies for unit tests  
✅ **Flexible Configuration**: Easy to swap implementations  
✅ **Clear Dependencies**: Explicit dependencies make code easier to understand  
✅ **No Over-Engineering**: Simple protocols without complex DI containers  
✅ **Performance**: No runtime overhead for dependency resolution  
✅ **Maintainable**: Easy to refactor and extend  
✅ **Backward Compatible**: Existing code continues to work  

#### **When to Use Custom Dependencies**
- **Testing**: Mock implementations for unit tests
- **Different Backends**: Swap LLM providers (OpenAI, Anthropic, etc.)
- **Custom Implementations**: Specialized language detection or file management
- **Performance Optimization**: Reuse existing instances or connections

## Questions for Discussion

1. **Overlap Threshold**: Is 30% the right threshold for detecting duplications?
2. **Header/Footer Threshold**: Is 70% frequency the right threshold for header/footer detection?
3. **Region Sizing**: Are top/bottom 10% the right regions for header/footer detection?
4. **Header Detection**: What header patterns should we prioritize for technical documents?
5. **Same-Line Tolerance**: Is 5-pixel tolerance appropriate for header merging?
6. **Markdown Level Offset**: Should we use 1 or 2 level offset for part-based documents?
7. **Configuration Schema**: Should we use JSON Schema for validation?
8. **Configuration Locations**: What should be the priority order for config file loading?
9. **Environment Support**: How many environments should we support by default?
10. **File Management**: Should we support multiple output directory strategies?
11. **Log Retention**: How long should we keep processing logs?
12. **Sorting Priority**: Should we prioritize by confidence or position when conflicts arise?
13. **Performance Requirements**: What are the acceptable performance benchmarks?
14. **Testing Strategy**: How should we test and validate the duplication detection and header/footer filtering?
15. **ML Integration**: Should we implement machine learning for improved detection accuracy?
16. **Dependency Injection**: Is the lightweight DI approach sufficient, or do we need a full DI container?
17. **Mock Implementations**: What level of mocking should we provide for testing?
18. **Protocol Design**: Are the current protocols comprehensive enough for all use cases?

## Testing with Dependency Injection

The lightweight DI approach makes testing much easier:

### **Unit Testing Example**
```swift
class LLMProcessorTests: XCTestCase {
    func testOptimizeMarkdown() async throws {
        // Arrange
        let mockClient = MockLLMClient()
        let mockDetector = MockLanguageDetector()
        let config = LLMConfig.testConfig()
        
        let processor = LLMProcessor(
            config: config,
            client: mockClient,
            languageDetector: mockDetector
        )
        
        // Act
        let result = try await processor.optimizeMarkdown(
            "Test markdown",
            documentContext: .testContext(),
            elements: [.testElement()]
        )
        
        // Assert
        XCTAssertEqual(result, "Optimized markdown")
        XCTAssertTrue(mockClient.textStreamCalled)
        XCTAssertTrue(mockDetector.detectLanguageCalled)
    }
}

// Mock implementations
class MockLLMClient: LLMClient {
    var textStreamCalled = false
    
    func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Error> {
        textStreamCalled = true
        return AsyncThrowingStream { continuation in
            continuation.yield("Optimized markdown")
            continuation.finish()
        }
    }
    
    func generateText(from input: LLMInput) async throws -> String {
        return "Generated text"
    }
}
```

### **Integration Testing Example**
```swift
class MainProcessorIntegrationTests: XCTestCase {
    func testFullDocumentProcessing() async throws {
        // Arrange
        let config = MDKitConfig.testConfig()
        let processor = try MainProcessor.create(config: config)
        
        // Act
        try await processor.processDocument("test.pdf")
        
        // Assert
        // Verify files were created, logs were written, etc.
    }
}
```

This testing approach provides:
- **Isolated Testing**: Each component can be tested independently
- **Fast Execution**: No real network calls or file I/O during tests
- **Predictable Results**: Mock implementations return known values
- **Easy Debugging**: Clear separation of concerns and dependencies

---

*This proposal is based on the existing Vision framework integration and aims to solve the position-based ordering and duplication issues identified in the PDF to Markdown conversion tool.*
