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
    case unsupportedOperation(String)
    
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
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
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
    private let markdownGenerator: MarkdownGenerator
    
    // MARK: - Initialization
    
    public init(config: SimpleProcessingConfig) {
        self.config = config
        self.logger = Logger(label: "UnifiedDocumentProcessor")
        self.overlapDetector = SimpleOverlapDetector(config: config)
        self.markdownGenerator = MarkdownGenerator(config: MarkdownGenerationConfig(addTableOfContents: false))
    }
    
    // MARK: - Main Processing Method
    
    /// Process a single document page with markdown generation and LLM optimization
    /// - Parameter imageData: Single page image data
    /// - Parameter outputStream: OutputStream where the markdown will be written
    /// - Parameter pageNumber: Page number for this document (default: 1)
    /// - Parameter previousPageContext: Context from previous page for cross-page LLM optimization (optional)
    /// - Returns: DocumentProcessingResult with processing summary
    /// - Throws: DocumentProcessingError if processing fails
    public func processDocument(
        _ imageData: Data, 
        outputStream: OutputStream, 
        pageNumber: Int = 1,
        previousPageContext: [DocumentElement] = []
    ) async throws -> DocumentProcessingResult {
        let startTime = Date()
        
        logger.info("Processing document page \(pageNumber)")
        logger.debug("Processing config: overlapThreshold=\(config.overlapThreshold), enableElementMerging=\(config.enableElementMerging)")
        
        // Step 1: Extract elements from this page
        let pageElements = try await extractDocumentElements(imageData: imageData)
        logger.debug("Page \(pageNumber): extracted \(pageElements.count) elements")
        
        // Step 2: Update page numbers for all elements from this page
        let updatedElements = pageElements.map { element in
            element.updating(pageNumber: pageNumber)
        }
        
        // Step 3: Sort elements by position within this page only
        let sortedElements = sortElementsByPositionWithinPage(updatedElements)
        
        // Step 4: Remove duplicates within this page
        let (deduplicatedElements, duplicatesRemoved) = await removeDuplicates(sortedElements)
        
        // Step 5: Merge nearby elements if enabled
        let mergedElements = config.enableElementMerging ? 
            await mergeNearbyElements(deduplicatedElements) : 
            deduplicatedElements
        
        // Step 6: Generate markdown for this page
        let pageMarkdown = try markdownGenerator.generateMarkdown(from: mergedElements)
        
        // Step 7: Apply LLM optimization with cross-page context if enabled
        let optimizedMarkdown: String
        if config.enableLLMOptimization {
            optimizedMarkdown = try await optimizeMarkdownWithLLMCrossPage(
                currentPageMarkdown: pageMarkdown,
                previousPageContext: previousPageContext,
                currentPageElements: mergedElements
            )
        } else {
            optimizedMarkdown = pageMarkdown
        }
        
        // Step 8: Write optimized markdown to output stream
        try appendMarkdownToStream(optimizedMarkdown, to: outputStream, pageNumber: pageNumber)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let result = DocumentProcessingResult(
            elements: mergedElements, // Keep elements for this page
            processingTime: processingTime,
            pageCount: 1,
            totalElements: pageElements.count,
            duplicatesRemoved: duplicatesRemoved,
            warnings: []
        )
        
        logger.info("Page \(pageNumber) processing completed in \(String(format: "%.2f", processingTime))s")
        logger.info("Markdown written to output stream")
        
        return result
    }
    
    // MARK: - File Operations and Cross-Page Optimization
    

    

    
    /// Create an output stream for writing to a file
    private func createOutputStream(for url: URL) throws -> OutputStream {
        // Create the file if it doesn't exist, or truncate if it does
        let outputStream = OutputStream(url: url, append: false)
        guard let outputStream = outputStream else {
            throw DocumentProcessingError.unsupportedOperation("Failed to create output stream for \(url.path)")
        }
        outputStream.open()
        return outputStream
    }
    
    /// Write initial header to the output stream
    private func writeHeaderToStream(_ outputStream: OutputStream) throws {
        let header = "# Document Processing Results\n\n"
        
        guard let data = header.data(using: .utf8) else {
            throw DocumentProcessingError.unsupportedOperation("Failed to convert header to UTF-8 data")
        }
        
        let bytesWritten = data.withUnsafeBytes { buffer in
            outputStream.write(buffer.bindMemory(to: UInt8.self).baseAddress!, maxLength: buffer.count)
        }
        
        if bytesWritten != data.count {
            throw DocumentProcessingError.unsupportedOperation("Failed to write complete header to output stream")
        }
        
        logger.info("Initial header written to output stream")
    }
    
    /// Append markdown content to output stream with page separator
    private func appendMarkdownToStream(_ markdown: String, to outputStream: OutputStream, pageNumber: Int) throws {
        let pageSeparator = "\n\n---\n\n## Page \(pageNumber)\n\n"
        let content = pageSeparator + markdown
        
        guard let data = content.data(using: .utf8) else {
            throw DocumentProcessingError.unsupportedOperation("Failed to convert markdown to UTF-8 data")
        }
        
        let bytesWritten = data.withUnsafeBytes { buffer in
            outputStream.write(buffer.bindMemory(to: UInt8.self).baseAddress!, maxLength: buffer.count)
        }
        
        if bytesWritten != data.count {
            throw DocumentProcessingError.unsupportedOperation("Failed to write complete markdown content to output stream")
        }
    }
    

    
    /// Extract context elements from the end of a page for cross-page LLM optimization
    private func extractContextForNextPage(from elements: [DocumentElement]) -> [DocumentElement] {
        // Keep last 2-3 paragraphs for context (configurable)
        let contextCount = min(3, elements.count)
        let contextElements = Array(elements.suffix(contextCount))
        
        logger.debug("Extracted \(contextElements.count) context elements for next page")
        return contextElements
    }
    
    /// Optimize markdown with LLM using cross-page context
    @available(macOS 26.0, *)
    private func optimizeMarkdownWithLLMCrossPage(
        currentPageMarkdown: String,
        previousPageContext: [DocumentElement],
        currentPageElements: [DocumentElement]
    ) async throws -> String {
        logger.info("Applying cross-page LLM optimization")
        
        // Build context from previous page
        let contextMarkdown: String
        if !previousPageContext.isEmpty {
            let contextGenerator = MarkdownGenerator(config: MarkdownGenerationConfig(addTableOfContents: false))
            let contextString = try contextGenerator.generateMarkdown(from: previousPageContext)
            contextMarkdown = "**Previous Page Context:**\n\(contextString)\n\n**Current Page:**\n"
        } else {
            contextMarkdown = ""
        }
        
        // Combine context and current page
        let fullMarkdown = contextMarkdown + currentPageMarkdown
        
        // TODO: Implement actual LLM call with context
        // For now, return the combined markdown
        logger.debug("Cross-page optimization would send \(fullMarkdown.count) characters to LLM")
        
        return fullMarkdown
    }
    
    /// Generate table of contents and append to output stream
    private func generateAndAppendTableOfContents(to outputStream: OutputStream, from elements: [DocumentElement]) async throws {
        logger.info("Generating table of contents from \(elements.count) elements")
        
        // Generate TOC using the same logic as MarkdownGenerator
        let tocLines = generateTableOfContents(from: elements)
        let toc = "\n\n---\n\n" + tocLines.joined(separator: "\n")
        
        guard let data = toc.data(using: .utf8) else {
            throw DocumentProcessingError.unsupportedOperation("Failed to convert TOC to UTF-8 data")
        }
        
        let bytesWritten = data.withUnsafeBytes { buffer in
            outputStream.write(buffer.bindMemory(to: UInt8.self).baseAddress!, maxLength: buffer.count)
        }
        
        if bytesWritten != data.count {
            throw DocumentProcessingError.unsupportedOperation("Failed to write complete TOC to output stream")
        }
        
        logger.info("Table of contents appended to output stream")
    }
    
    /// Generate table of contents from document elements (same logic as MarkdownGenerator)
    private func generateTableOfContents(from elements: [DocumentElement]) -> [String] {
        var tocLines = ["## Table of Contents", ""]
        
        for element in elements {
            switch element.type {
            case .title:
                let anchor = (element.text ?? "Untitled").lowercased().replacingOccurrences(of: " ", with: "-")
                tocLines.append("- [\(element.text ?? "Untitled")](#\(anchor))")
            case .header:
                let level = calculateHeaderLevel(for: element, in: elements)
                let indent = String(repeating: "  ", count: level - 1)
                let anchor = (element.text ?? "Header").lowercased().replacingOccurrences(of: " ", with: "-")
                tocLines.append("\(indent)- [\(element.text ?? "Header")](#\(anchor))")
            default: break
            }
        }
        
        return tocLines
    }
    
    /// Calculate header level based on position and content (same logic as MarkdownGenerator)
    private func calculateHeaderLevel(for element: DocumentElement, in elements: [DocumentElement]) -> Int {
        let normalizedY = element.boundingBox.minY
        if normalizedY < 0.1 { return 1 }
        else if normalizedY < 0.2 { return 2 }
        else if normalizedY < 0.3 { return 3 }
        else if normalizedY < 0.4 { return 4 }
        else if normalizedY < 0.5 { return 5 }
        else { return 6 }
    }
    
    // MARK: - PDF Processing
    
    /// Process a PDF document by converting pages to images and processing each page sequentially
    /// - Parameter pdfURL: URL to the PDF document
    /// - Parameter outputFileURL: URL where the final markdown file will be written
    /// - Returns: DocumentProcessingResult with processing summary
    /// - Throws: DocumentProcessingError if processing fails
    @available(macOS 26.0, *)
    public func processPDF(_ pdfURL: URL, outputFileURL: URL) async throws -> DocumentProcessingResult {
        let startTime = Date()
        
        logger.info("Starting PDF processing: \(pdfURL.lastPathComponent)")
        
        // Convert PDF pages to images
        let pageImages = try await convertPDFToImages(pdfURL)
        logger.info("PDF converted to \(pageImages.count) page images")
        
        var totalDuplicatesRemoved = 0
        var warnings: [String] = []
        var previousPageContext: [DocumentElement] = [] // Keep last few paragraphs for cross-page context
        var allProcessedElements: [DocumentElement] = [] // Collect all elements for TOC generation
        
        // Create output stream and write initial header
        let outputStream = try createOutputStream(for: outputFileURL)
        defer {
            outputStream.close()
        }
        
        // Write initial header through the stream
        try writeHeaderToStream(outputStream)
        
        // Process each page sequentially using processDocument
        for (pageIndex, pageImageData) in pageImages.enumerated() {
            let pageNumber = pageIndex + 1
            logger.info("Processing PDF page \(pageNumber) of \(pageImages.count)")
            
            do {
                // Process this page with cross-page context
                let pageResult = try await processDocument(
                    pageImageData, 
                    outputStream: outputStream, 
                    pageNumber: pageNumber,
                    previousPageContext: previousPageContext
                )
                
                // Accumulate statistics
                totalDuplicatesRemoved += pageResult.duplicatesRemoved
                
                // Extract context for next page
                previousPageContext = extractContextForNextPage(from: pageResult.elements)
                
                // Collect all elements for TOC generation
                allProcessedElements.append(contentsOf: pageResult.elements)
                
                logger.info("PDF page \(pageNumber) completed successfully")
                
            } catch {
                let warning = "PDF page \(pageNumber) failed: \(error.localizedDescription)"
                logger.warning("\(warning)")
                warnings.append(warning)
                // Continue with next page instead of failing completely
            }
        }
        
        // Final step: Generate and append table of contents
        // We need to collect all elements from all pages to generate proper TOC
        try await generateAndAppendTableOfContents(to: outputStream, from: allProcessedElements)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let result = DocumentProcessingResult(
            elements: [], // We don't keep all elements in memory
            processingTime: processingTime,
            pageCount: pageImages.count,
            totalElements: 0, // Not applicable since we write to file
            duplicatesRemoved: totalDuplicatesRemoved,
            warnings: warnings
        )
        
        logger.info("PDF processing completed in \(String(format: "%.2f", processingTime))s")
        logger.info("Final markdown written to: \(outputFileURL.path)")
        
        return result
    }
    
    /// Convert PDF pages to image data for Vision framework processing
    @available(macOS 26.0, *)
    private func convertPDFToImages(_ pdfURL: URL) async throws -> [Data] {
        // TODO: Implement PDF to image conversion
        // This would use PDFKit to extract pages and convert to images
        // For now, we'll throw an error indicating this needs implementation
        
        throw DocumentProcessingError.unsupportedOperation("PDF to image conversion not yet implemented")
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
            // Primary sort: Page number (first page to last page)
            if first.pageNumber != second.pageNumber {
                return first.pageNumber < second.pageNumber
            }
            
            // Secondary sort: Y position within page (top to bottom)
            // Only compare positions within the same page
            if abs(first.boundingBox.midY - second.boundingBox.midY) > 0.01 {
                return first.boundingBox.midY < second.boundingBox.midY
            }
            
            // Tertiary sort: X position within page (left to right)
            return first.boundingBox.midX < second.boundingBox.midX
        }
    }
    
    /// Sort elements by position within a single page
    internal func sortElementsByPositionWithinPage(_ elements: [DocumentElement]) -> [DocumentElement] {
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
    
    init(config: SimpleProcessingConfig) {
        self.config = config
        self.logger = Logger(label: "SimpleOverlapDetector")
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
