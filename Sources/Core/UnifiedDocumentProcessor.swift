import Foundation
import Vision
import CoreGraphics
import Logging

// MARK: - Document Processing Error

public enum DocumentProcessingError: LocalizedError {
    case noDocumentFound
    case noTextFound
    case invalidImageData
    case processingTimeout
    case unsupportedDocumentType
    case unsupportedPlatform
    
    public var errorDescription: String? {
        switch self {
        case .noDocumentFound:
            return "No document structure found in image"
        case .noTextFound:
            return "No text content found in document"
        case .invalidImageData:
            return "Invalid or corrupted image data"
        case .processingTimeout:
            return "Document processing timed out"
        case .unsupportedDocumentType:
            return "Unsupported document type"
        case .unsupportedPlatform:
            return "Document recognition requires macOS 15.0 or newer"
        }
    }
}

// MARK: - Document Processing Result

public struct DocumentProcessingResult {
    public let elements: [DocumentElement]
    public let processingTime: TimeInterval
    public let pageCount: Int
    public let totalElements: Int
    public let duplicatesRemoved: Int
    public let warnings: [String]
    
    public init(
        elements: [DocumentElement],
        processingTime: TimeInterval,
        pageCount: Int,
        totalElements: Int,
        duplicatesRemoved: Int,
        warnings: [String] = []
    ) {
        self.elements = elements
        self.processingTime = processingTime
        self.pageCount = pageCount
        self.totalElements = totalElements
        self.duplicatesRemoved = duplicatesRemoved
        self.warnings = warnings
    }
}

// MARK: - Simple Processing Configuration

public struct SimpleProcessingConfig {
    public let overlapThreshold: Double
    public let enableElementMerging: Bool
    public let enableHeaderFooterDetection: Bool
    public let headerRegion: ClosedRange<Double>
    public let footerRegion: ClosedRange<Double>
    public let enableLLMOptimization: Bool
    
    public init(
        overlapThreshold: Double = 0.1,
        enableElementMerging: Bool = true,
        enableHeaderFooterDetection: Bool = true,
        headerRegion: ClosedRange<Double> = 0.0...0.15,
        footerRegion: ClosedRange<Double> = 0.85...1.0,
        enableLLMOptimization: Bool = false
    ) {
        self.overlapThreshold = overlapThreshold
        self.enableElementMerging = enableElementMerging
        self.enableHeaderFooterDetection = enableHeaderFooterDetection
        self.headerRegion = headerRegion
        self.footerRegion = footerRegion
        self.enableLLMOptimization = enableLLMOptimization
    }
}

// MARK: - Unified Document Processor

@available(macOS 26.0, *)
public class UnifiedDocumentProcessor {
    
    // MARK: - Properties
    
    internal let config: SimpleProcessingConfig
    private let logger: Logger
    private let overlapDetector: SimpleOverlapDetector
    
    // MARK: - Initialization
    
    public init(config: SimpleProcessingConfig, logger: Logger) {
        self.config = config
        self.logger = logger
        self.overlapDetector = SimpleOverlapDetector(config: config, logger: logger)
    }
    
    // MARK: - Main Processing Method
    
    /// Processes a document image using Vision framework's document recognition
    /// - Parameter imageData: The document image data
    /// - Returns: DocumentProcessingResult with all extracted elements
    /// - Throws: DocumentProcessingError if processing fails
    public func processDocument(imageData: Data) async throws -> DocumentProcessingResult {
        let startTime = Date()
        
        logger.info("Starting document processing")
        logger.debug("Processing config: overlapThreshold=\(config.overlapThreshold), enableElementMerging=\(config.enableElementMerging)")
        

        
        // Step 1: Extract document structure using Vision framework
        let documentElements = try await extractDocumentElements(imageData: imageData)
        logger.info("Vision framework extracted \(documentElements.count) document elements")
        
        // Step 2: Sort elements by position
        let sortedElements = sortElementsByPosition(documentElements)
        logger.debug("Elements sorted by position")
        
        // Step 3: Detect and remove duplicates
        let (deduplicatedElements, duplicatesRemoved) = await removeDuplicates(sortedElements)
        logger.info("Removed \(duplicatesRemoved) duplicate elements")
        
        // Step 4: Merge nearby elements if enabled
        let finalElements = config.enableElementMerging ? 
            await mergeNearbyElements(deduplicatedElements) : 
            deduplicatedElements
        
        // Step 5: Apply LLM optimization if enabled
        let optimizedElements = config.enableLLMOptimization ? 
            try await optimizeMarkdownWithLLM(finalElements) : 
            finalElements
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let result = DocumentProcessingResult(
            elements: optimizedElements,
            processingTime: processingTime,
            pageCount: 1, // TODO: Support multi-page documents
            totalElements: documentElements.count,
            duplicatesRemoved: duplicatesRemoved,
            warnings: []
        )
        
        logger.info("Document processing completed in \(String(format: "%.2f", processingTime))s")
        logger.info("Final result: \(finalElements.count) elements")
        
        return result
    }
    
    // MARK: - Vision Framework Integration
    
    @available(macOS 26.0, *)
    private func extractDocumentElements(imageData: Data) async throws -> [DocumentElement] {
        // Create the Vision request for document recognition
        let request = RecognizeDocumentsRequest()
        
        // Perform the request on the image data
        let observations = try await request.perform(on: imageData)
        
        guard !observations.isEmpty else {
            throw DocumentProcessingError.noDocumentFound
        }
        
        // Convert document observations to DocumentElements
        let documentElements = try convertDocumentObservations(observations)
        
        if documentElements.isEmpty {
            throw DocumentProcessingError.noTextFound
        }
        
        return documentElements
    }
    
    // MARK: - Document Observation Conversion
    
    @available(macOS 26.0, *)
    private func convertDocumentObservations(_ observations: [DocumentObservation]) throws -> [DocumentElement] {
        var documentElements: [DocumentElement] = []
        
        for (pageIndex, observation) in observations.enumerated() {
            let document = observation.document
            
            // Extract title if present
            if let title = document.title {
                let titleElement = createDocumentElement(
                    from: title,
                    type: .title,
                    pageNumber: pageIndex + 1,
                    metadata: ["source": "document_title"]
                )
                documentElements.append(titleElement)
            }
            
            // Extract paragraphs
            for (paraIndex, paragraph) in document.paragraphs.enumerated() {
                let paragraphElement = createDocumentElement(
                    from: paragraph,
                    type: .paragraph,
                    pageNumber: pageIndex + 1,
                    metadata: [
                        "source": "document_paragraph",
                        "paragraph_index": String(paraIndex)
                    ]
                )
                documentElements.append(paragraphElement)
            }
            
            // Extract lists
            for (listIndex, list) in document.lists.enumerated() {
                let listElement = createDocumentElement(
                    from: list,
                    type: .list,
                    pageNumber: pageIndex + 1,
                    metadata: [
                        "source": "document_list",
                        "list_index": String(listIndex)
                    ]
                )
                documentElements.append(listElement)
                
                // Extract list items
                for (itemIndex, item) in list.items.enumerated() {
                    let listItemElement = createDocumentElement(
                        fromListItem: item,
                        type: .listItem,
                        pageNumber: pageIndex + 1,
                        metadata: [
                            "source": "document_list_item",
                            "list_index": String(listIndex),
                            "item_index": String(itemIndex)
                        ]
                    )
                    documentElements.append(listItemElement)
                }
            }
            
            // Extract tables
            for (tableIndex, table) in document.tables.enumerated() {
                let tableElement = createDocumentElement(
                    from: table,
                    type: .table,
                    pageNumber: pageIndex + 1,
                    metadata: [
                        "source": "document_table",
                        "table_index": String(tableIndex)
                    ]
                )
                documentElements.append(tableElement)
                
                // Extract table content (cells with text)
                for (rowIndex, row) in table.rows.enumerated() {
                    for (colIndex, cell) in row.enumerated() {
                        let cellText = cell.content.text.transcript
                        if !cellText.isEmpty {
                            let cellElement = DocumentElement(
                                type: .textBlock,
                                boundingBox: convertNormalizedRegionToCGRect(cell.content.boundingRegion),
                                contentData: cellText.data(using: .utf8) ?? Data(),
                                confidence: 1.0,
                                pageNumber: pageIndex + 1,
                                text: cellText,
                                metadata: [
                                    "source": "document_table_cell",
                                    "table_index": String(tableIndex),
                                    "row_index": String(rowIndex),
                                    "col_index": String(colIndex)
                                ]
                            )
                            documentElements.append(cellElement)
                        }
                    }
                }
            }
        }
        
        return documentElements
    }
    
    // MARK: - Helper Methods for Creating DocumentElements
    
    @available(macOS 26.0, *)
    private func createDocumentElement(
        from text: DocumentObservation.Container.Text,
        type: ElementType,
        pageNumber: Int,
        metadata: [String: String]
    ) -> DocumentElement {
        // Access the text content and bounding region through the correct API
        let textContent = text.transcript
        let boundingRegion = text.boundingRegion
        
        // Convert NormalizedRegion to CGRect for our DocumentElement
        let boundingBox = convertNormalizedRegionToCGRect(boundingRegion)
        
        // Determine the actual element type based on position and configuration
        let actualType = determineElementType(for: text, boundingBox: boundingBox, originalType: type)
        
        return DocumentElement(
            type: actualType,
            boundingBox: boundingBox,
            contentData: textContent.data(using: .utf8) ?? Data(),
            confidence: 1.0, // DocumentObservation doesn't provide confidence
            pageNumber: pageNumber,
            text: textContent,
            metadata: metadata
        )
    }
    
    @available(macOS 26.0, *)
    private func determineElementType(
        for text: DocumentObservation.Container.Text,
        boundingBox: CGRect,
        originalType: ElementType
    ) -> ElementType {
        // Check if header/footer detection is enabled
        guard config.enableHeaderFooterDetection else {
            return originalType
        }
        
        // Convert bounding box to normalized coordinates (0.0 to 1.0)
        // Since we're working with normalized coordinates from Vision, we can use Y directly
        let normalizedY = boundingBox.minY
        
        // Check if element is in header region (top of page)
        if config.headerRegion.contains(normalizedY) {
            logger.debug("Element detected as header at Y position \(normalizedY)")
            return .header
        }
        
        // Check if element is in footer region (bottom of page)
        if config.footerRegion.contains(normalizedY) {
            logger.debug("Element detected as footer at Y position \(normalizedY)")
            return .footer
        }
        
        // Return original type if not in header/footer regions
        return originalType
    }
    
    @available(macOS 26.0, *)
    private func createDocumentElement(
        fromListItem item: DocumentObservation.Container.List.Item,
        type: ElementType,
        pageNumber: Int,
        metadata: [String: String]
    ) -> DocumentElement {
        // Access the text content through the correct API
        let textContent = item.itemString
        
        // For list items, we'll use a default bounding box since items don't have individual bounding regions
        // In a real implementation, we might calculate this based on the item's position within the list
        let boundingBox = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05) // Default placeholder
        
        return DocumentElement(
            type: type,
            boundingBox: boundingBox,
            contentData: textContent.data(using: .utf8) ?? Data(),
            confidence: 1.0, // DocumentObservation doesn't provide confidence
            pageNumber: pageNumber,
            text: textContent,
            metadata: metadata
        )
    }
    
    @available(macOS 26.0, *)
    private func createDocumentElement(
        from list: DocumentObservation.Container.List,
        type: ElementType,
        pageNumber: Int,
        metadata: [String: String]
    ) -> DocumentElement {
        // For lists, we'll use the bounding region of the list itself
        let boundingBox = convertNormalizedRegionToCGRect(list.boundingRegion)
        
        return DocumentElement(
            type: type,
            boundingBox: boundingBox,
            contentData: Data(), // Lists don't have direct text content
            confidence: 1.0, // Lists are structural elements
            pageNumber: pageNumber,
            text: nil,
            metadata: metadata
        )
    }
    
    @available(macOS 26.0, *)
    private func createDocumentElement(
        from table: DocumentObservation.Container.Table,
        type: ElementType,
        pageNumber: Int,
        metadata: [String: String]
    ) -> DocumentElement {
        // Access the bounding region through the correct API
        let boundingRegion = table.boundingRegion
        let boundingBox = convertNormalizedRegionToCGRect(boundingRegion)
        
        return DocumentElement(
            type: type,
            boundingBox: boundingBox,
            contentData: Data(), // Tables don't have direct text content
            confidence: 1.0, // Tables are structural elements
            pageNumber: pageNumber,
            text: nil,
            metadata: metadata
        )
    }
    
    // MARK: - Helper Methods
    
    @available(macOS 26.0, *)
    private func convertNormalizedRegionToCGRect(_ region: NormalizedRegion) -> CGRect {
        // Convert NormalizedRegion to CGRect
        // NormalizedRegion uses normalized coordinates (0.0 to 1.0)
        // We'll use the bounding box of the region
        let bounds = region.boundingBox
        return CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.width,
            height: bounds.height
        )
    }
    
    // MARK: - Position-based Sorting
    
    internal func sortElementsByPosition(_ elements: [DocumentElement]) -> [DocumentElement] {
        return elements.sorted { first, second in
            // Primary sort: Y position (top to bottom)
            if abs(first.boundingBox.midY - second.boundingBox.midY) > 0.01 {
                return first.boundingBox.midY < second.boundingBox.midY
            }
            
            // Secondary sort: X position (left to right)
            return first.boundingBox.midX < second.boundingBox.midX
        }
    }
    
    // MARK: - Duplicate Detection and Removal
    
    private func removeDuplicates(_ elements: [DocumentElement]) async -> ([DocumentElement], Int) {
        let result = await overlapDetector.removeDuplicates(elements)
        return result
    }
    
    // MARK: - Element Merging
    
    private func mergeNearbyElements(_ elements: [DocumentElement]) async -> [DocumentElement] {
        // TODO: Implement element merging logic
        // This will merge nearby text elements that likely belong together
        logger.debug("Element merging not yet implemented, returning original elements")
        return elements
    }
    
    // MARK: - LLM Optimization
    
    @available(macOS 26.0, *)
    private func optimizeMarkdownWithLLM(_ elements: [DocumentElement]) async throws -> [DocumentElement] {
        logger.info("LLM optimization enabled, applying markdown improvements")
        
        // TODO: Implement actual LLM integration
        // For now, we'll return the elements as-is and log the intention
        logger.debug("LLM optimization not yet implemented, returning original elements")
        
        // Future implementation would:
        // 1. Convert elements to markdown
        // 2. Send to LLM for optimization
        // 3. Parse optimized markdown back to elements
        // 4. Return improved elements
        
        return elements
    }
}

// MARK: - Simple Overlap Detector

private class SimpleOverlapDetector {
    private let config: SimpleProcessingConfig
    private let logger: Logger
    
    init(config: SimpleProcessingConfig, logger: Logger) {
        self.config = config
        self.logger = logger
    }
    
    func removeDuplicates(_ elements: [DocumentElement]) async -> ([DocumentElement], Int) {
        var uniqueElements: [DocumentElement] = []
        var duplicatesRemoved = 0
        
        for element in elements {
            let isDuplicate = uniqueElements.contains { existing in
                element.overlaps(with: existing, threshold: Float(config.overlapThreshold))
            }
            
            if isDuplicate {
                duplicatesRemoved += 1
                logger.debug("Removing duplicate element: \(element.text ?? "nil") at \(element.boundingBox)")
            } else {
                uniqueElements.append(element)
            }
        }
        
        return (uniqueElements, duplicatesRemoved)
    }
}
