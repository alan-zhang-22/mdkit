import Foundation
import Vision
import CoreGraphics
import Logging
import PDFKit
import AppKit
import CoreImage
import mdkitConfiguration

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

// MARK: - Unified Document Processor

@available(macOS 26.0, *)
public class UnifiedDocumentProcessor {
    
    // MARK: - Properties
    
    internal let config: MDKitConfig
    private let logger: Logger
    private let overlapDetector: SimpleOverlapDetector
    private let markdownGenerator: MarkdownGenerator
    
    // MARK: - Initialization
    
    public init(config: MDKitConfig) {
        self.config = config
        self.logger = Logger(label: "UnifiedDocumentProcessor")
        self.overlapDetector = SimpleOverlapDetector(config: config)
        self.markdownGenerator = MarkdownGenerator(config: config.markdownGeneration)
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
        logger.debug("Processing config: overlapThreshold=\(config.processing.overlapThreshold), enableElementMerging=\(config.processing.enableElementMerging)")
        
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
        let mergedElements = config.processing.enableElementMerging ? 
            await mergeNearbyElements(deduplicatedElements) : 
            deduplicatedElements
        
        // Step 6: Generate markdown for this page
        let pageMarkdown = try markdownGenerator.generateMarkdown(from: mergedElements)
        
        // Step 7: Apply LLM optimization with cross-page context if enabled
        let optimizedMarkdown: String
        if config.processing.enableLLMOptimization {
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
            let contextGenerator = MarkdownGenerator(config: config.markdownGeneration)
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
    
    // MARK: - Page Range Parsing
    
    /// Parse page range specification into array of page numbers
    /// Supports formats: "5" (single), "5,7" (multiple), "5-7" (range), "all" (all pages)
    /// - Parameter pageRange: String specifying page range (e.g., "5", "5,7", "5-7", "all")
    /// - Parameter totalPages: Total number of pages in PDF
    /// - Returns: Array of page numbers (1-indexed) to process
    /// - Throws: DocumentProcessingError for invalid page ranges
    private func parsePageRange(_ pageRange: String?, totalPages: Int) throws -> [Int] {
        guard let pageRange = pageRange, !pageRange.isEmpty else {
            // No page range specified, process all pages
            return Array(1...totalPages)
        }
        
        let trimmedRange = pageRange.trimmingCharacters(in: .whitespaces)
        
        if trimmedRange.lowercased() == "all" {
            return Array(1...totalPages)
        }
        
        var pageNumbers: Set<Int> = []
        let components = trimmedRange.components(separatedBy: ",")
        
        for component in components {
            let trimmedComponent = component.trimmingCharacters(in: .whitespaces)
            
            if trimmedComponent.contains("-") {
                // Handle range (e.g., "5-7")
                let rangeComponents = trimmedComponent.components(separatedBy: "-")
                guard rangeComponents.count == 2,
                      let startPage = Int(rangeComponents[0].trimmingCharacters(in: .whitespaces)),
                      let endPage = Int(rangeComponents[1].trimmingCharacters(in: .whitespaces)) else {
                    throw DocumentProcessingError.unsupportedOperation("Invalid page range format: \(trimmedComponent)")
                }
                
                guard startPage >= 1 && endPage <= totalPages && startPage <= endPage else {
                    throw DocumentProcessingError.unsupportedOperation("Page range \(startPage)-\(endPage) is invalid for PDF with \(totalPages) pages")
                }
                
                pageNumbers.formUnion(startPage...endPage)
                
            } else {
                // Handle single page number
                guard let pageNumber = Int(trimmedComponent) else {
                    throw DocumentProcessingError.unsupportedOperation("Invalid page number: \(trimmedComponent)")
                }
                
                guard pageNumber >= 1 && pageNumber <= totalPages else {
                    throw DocumentProcessingError.unsupportedOperation("Page number \(pageNumber) is invalid for PDF with \(totalPages) pages")
                }
                
                pageNumbers.insert(pageNumber)
            }
        }
        
        // Convert to sorted array
        return Array(pageNumbers).sorted()
    }
    
    // MARK: - PDF to Image Conversion
    
    /// Convert a PDF page to NSImage with high-quality rendering
    /// - Parameter page: PDFPage to convert
    /// - Returns: NSImage representation of the page
    /// - Throws: DocumentProcessingError if conversion fails
    private func convertPDFPageToImage(_ page: PDFPage) throws -> NSImage {
        let pageRect = page.bounds(for: .mediaBox)
        
        // Calculate enhanced size for higher resolution
        let scaleFactor = config.processing.pdfImageScaleFactor
        let enhancedSize = CGSize(
            width: pageRect.width * scaleFactor,
            height: pageRect.height * scaleFactor
        )
        
        // Create image with enhanced size
        let image = NSImage(size: enhancedSize)
        
        logger.debug("Converting PDF page: original size \(pageRect.size), enhanced size \(enhancedSize) (scale factor: \(scaleFactor))")
        
        image.lockFocus()
        
        if let context = NSGraphicsContext.current?.cgContext {
            // Set high-quality rendering
            context.setShouldAntialias(true)
            context.setShouldSubpixelPositionFonts(true)
            context.setShouldSubpixelQuantizeFonts(true)
            
            // Fill with white background
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: enhancedSize))
            
            // Scale the context for higher resolution
            context.scaleBy(x: scaleFactor, y: scaleFactor)
            
            // Draw the PDF page
            page.draw(with: .mediaBox, to: context)
        }
        
        image.unlockFocus()
        
        logger.debug("PDF page converted to high-quality image with \(scaleFactor)x resolution")
        
        // Enhance image quality for better OCR accuracy
        let enhancedImage = enhanceImageQuality(image)
        
        return enhancedImage
    }
    
    /// Enhances image quality for better OCR accuracy
    /// - Parameter image: The input image to enhance
    /// - Returns: Enhanced image with improved quality
    private func enhanceImageQuality(_ image: NSImage) -> NSImage {
        // Check if image enhancement is enabled in configuration
        guard config.processing.enableImageEnhancement else {
            return image
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            logger.debug("Could not get CGImage for enhancement, returning original image")
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply simple, effective enhancement filters
        var enhancedImage = ciImage
        
        // 1. Simple Contrast Enhancement - Improve text visibility without over-processing
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.15, forKey: kCIInputContrastKey) // Moderate contrast increase
            contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color for better OCR
            contrastFilter.setValue(0.05, forKey: kCIInputBrightnessKey) // Very slight brightness increase
            
            if let outputImage = contrastFilter.outputImage {
                enhancedImage = outputImage
                logger.debug("Applied contrast enhancement filter")
            }
        }
        
        // 2. Gentle Sharpening - Enhance text edges without artifacts
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.3, forKey: kCIInputSharpnessKey) // Gentle sharpening
            
            if let outputImage = sharpenFilter.outputImage {
                enhancedImage = outputImage
                logger.debug("Applied sharpening filter")
            }
        }
        
        // Convert back to NSImage
        let context = CIContext()
        guard let outputCGImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            logger.warning("Failed to create enhanced image, returning original")
            return image
        }
        
        logger.debug("Image enhancement completed successfully")
        return NSImage(cgImage: outputCGImage, size: image.size)
    }
    
    /// Convert NSImage to Data (PNG format)
    /// - Parameter image: NSImage to convert
    /// - Returns: PNG data representation
    /// - Throws: DocumentProcessingError if conversion fails
    private func convertNSImageToData(_ image: NSImage) throws -> Data {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw DocumentProcessingError.unsupportedOperation("Failed to convert image to PNG data")
        }
        
        return pngData
    }
    
    /// Convert specified PDF pages to images
    /// - Parameter pdfURL: URL to the PDF document
    /// - Parameter pageRange: Optional page range specification (e.g., "5", "5,7", "5-7", "all")
    /// - Returns: Array of image data for specified pages
    /// - Throws: DocumentProcessingError if conversion fails
    private func convertPDFToImages(_ pdfURL: URL, pageRange: String? = nil) async throws -> [Data] {
        // Get PDF information
        let (pageCount, pdfDocument) = try getPDFInfo(from: pdfURL)
        
        // Parse page range
        let pagesToProcess = try parsePageRange(pageRange, totalPages: pageCount)
        logger.info("Processing \(pagesToProcess.count) pages: \(pagesToProcess)")
        
        var pageImages: [Data] = []
        
        for pageNumber in pagesToProcess {
            let pageIndex = pageNumber - 1 // Convert to 0-indexed
            
            guard let page = pdfDocument.page(at: pageIndex) else {
                logger.warning("Failed to get page \(pageNumber), skipping")
                continue
            }
            
            do {
                // Convert PDF page to image
                let image = try convertPDFPageToImage(page)
                
                // Convert NSImage to Data
                let imageData = try convertNSImageToData(image)
                
                pageImages.append(imageData)
                logger.debug("Successfully converted page \(pageNumber) to image (\(imageData.count) bytes)")
                
            } catch {
                logger.warning("Failed to convert page \(pageNumber): \(error.localizedDescription)")
                // Continue with other pages instead of failing completely
            }
        }
        
        guard !pageImages.isEmpty else {
            throw DocumentProcessingError.unsupportedOperation("No pages were successfully converted to images")
        }
        
        logger.info("Successfully converted \(pageImages.count) pages to images")
        return pageImages
    }
    
    // MARK: - PDF Information
    
    /// Get PDF document information including page count
    /// - Parameter pdfURL: URL to the PDF document
    /// - Returns: Tuple with page count and PDFDocument reference
    /// - Throws: DocumentProcessingError if PDF cannot be loaded
    private func getPDFInfo(from pdfURL: URL) throws -> (pageCount: Int, document: PDFDocument) {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw DocumentProcessingError.unsupportedOperation("Failed to load PDF document from \(pdfURL.path)")
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw DocumentProcessingError.unsupportedOperation("PDF document has no pages")
        }
        
        logger.info("PDF loaded successfully: \(pageCount) pages")
        return (pageCount, pdfDocument)
    }
    
    // MARK: - PDF Processing
    
    /// Process a PDF document by converting pages to images and processing each page sequentially
    /// - Parameter pdfURL: URL to the PDF document
    /// - Parameter outputFileURL: URL where the final markdown file will be written
    /// - Parameter pageRange: Optional page range specification (e.g., "5", "5,7", "5-7", "all")
    /// - Returns: DocumentProcessingResult with processing summary
    /// - Throws: DocumentProcessingError if processing fails
    @available(macOS 26.0, *)
    public func processPDF(_ pdfURL: URL, outputFileURL: URL, pageRange: String? = nil) async throws -> DocumentProcessingResult {
        let startTime = Date()
        
        logger.info("Starting PDF processing: \(pdfURL.lastPathComponent)")
        
        // Convert PDF pages to images
        let pageImages = try await convertPDFToImages(pdfURL, pageRange: pageRange)
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
        guard config.processing.enableHeaderFooterDetection else {
            return originalType
        }
        
        // Convert bounding box to normalized coordinates (0.0 to 1.0)
        // Since we're working with normalized coordinates from Vision, we can use Y directly
        let normalizedY = boundingBox.minY
        
        // Check if element is in header region (top of page)
        if config.processing.headerRegion.contains(normalizedY) {
            logger.debug("Element detected as header at Y position \(normalizedY)")
            return .header
        }
        
        // Check if element is in footer region (bottom of page)
        if config.processing.footerRegion.contains(normalizedY) {
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
        guard !elements.isEmpty else { return elements }
        
        logger.debug("Starting element merging for \(elements.count) elements")
        
        // Group elements by page for efficient processing
        let elementsByPage = Dictionary(grouping: elements) { $0.pageNumber }
        var mergedElements: [DocumentElement] = []
        
        for (pageNumber, pageElements) in elementsByPage.sorted(by: { $0.key < $1.key }) {
            logger.debug("Processing page \(pageNumber) with \(pageElements.count) elements")
            
            // Sort elements within the page by position (top to bottom, left to right)
            let sortedPageElements = sortElementsByPositionWithinPage(pageElements)
            
            // Merge elements on this page
            let mergedPageElements = await mergeElementsOnPage(sortedPageElements)
            mergedElements.append(contentsOf: mergedPageElements)
            
            logger.debug("Page \(pageNumber): merged \(pageElements.count) elements into \(mergedPageElements.count) elements")
        }
        
        let totalMerged = elements.count - mergedElements.count
        logger.info("Element merging complete: \(elements.count) → \(mergedElements.count) elements (\(totalMerged) merged)")
        
        return mergedElements
    }
    
    /// Merges elements within a single page
    private func mergeElementsOnPage(_ elements: [DocumentElement]) async -> [DocumentElement] {
        guard elements.count > 1 else { return elements }
        
        var mergedElements: [DocumentElement] = []
        var processedIndices: Set<Int> = []
        
        for i in 0..<elements.count {
            guard !processedIndices.contains(i) else { continue }
            
            let currentElement = elements[i]
            var bestMergeCandidate: (index: Int, element: DocumentElement)? = nil
            var bestMergeScore: Float = 0
            
            // Look for the best merge candidate
            for j in (i + 1)..<elements.count {
                guard !processedIndices.contains(j) else { continue }
                
                let candidate = elements[j]
                
                // Check if elements can be merged
                if currentElement.canMerge(with: candidate, config: config.processing) {
                    let mergeScore = calculateMergeScore(currentElement, candidate)
                    
                    if mergeScore > bestMergeScore {
                        bestMergeScore = mergeScore
                        bestMergeCandidate = (j, candidate)
                    }
                }
            }
            
            if let (mergeIndex, mergeElement) = bestMergeCandidate {
                // Perform the merge
                let mergedElement = await mergeElements(currentElement, mergeElement)
                mergedElements.append(mergedElement)
                
                // Mark both elements as processed
                processedIndices.insert(i)
                processedIndices.insert(mergeIndex)
                
                logger.debug("Merged elements: '\(currentElement.text ?? "nil")' + '\(mergeElement.text ?? "nil")' → '\(mergedElement.text ?? "nil")'")
            } else {
                // No merge candidate found, keep the element as-is
                mergedElements.append(currentElement)
                processedIndices.insert(i)
            }
        }
        
        return mergedElements
    }
    
    /// Calculates a score for how well two elements should be merged
    private func calculateMergeScore(_ first: DocumentElement, _ second: DocumentElement) -> Float {
        var score: Float = 0
        
        // Base score for mergeable types
        if first.type.isMergeable && second.type.isMergeable {
            score += 10
        }
        
        // Check alignment type
        let isSameLine = first.boundingBox.isVerticallyAligned(with: second.boundingBox, tolerance: 20.0) // Same line (similar Y)
        let isSideBySide = first.boundingBox.isHorizontallyAligned(with: second.boundingBox, tolerance: 15.0) // Side by side (similar X)
        
        // Distance-based scoring (closer elements get higher scores)
        let distance = first.mergeDistance(to: second)
        
        if isSameLine {
            // Same line merging: much more permissive scoring
            let distanceScore = max(0, 100 - distance) / 100 // Normalize to 0-1 range
            score += distanceScore * 30 // Higher weight for same line merging
            
            // Bonus for header-like patterns (e.g., "5.1.2" + "Access Control")
            if let firstText = first.text, let secondText = second.text {
                let firstIsHeaderMarker = firstText.range(of: #"^\d+\.?\d*\.?\d*$"#, options: .regularExpression) != nil
                let secondIsHeaderText = secondText.count > 3 && !secondText.hasPrefix(".")
                
                if firstIsHeaderMarker && secondIsHeaderText {
                    score += 25 // Significant bonus for header marker + text combinations
                }
            }
        } else if isSideBySide {
            // Side by side merging: standard scoring
            let distanceScore = max(0, 50 - distance) / 50 // Normalize to 0-1 range
            score += distanceScore * 20
        } else {
            // Diagonal merging: reduced scoring
            let distanceScore = max(0, 50 - distance) / 50
            score += distanceScore * 15
        }
        
        // Vertical alignment scoring (same line)
        if isSameLine {
            score += 15
        }
        
        // Horizontal alignment scoring (side by side)
        if isSideBySide {
            score += 20 // Higher score for side by side alignment
        }
        
        // Content-based scoring
        if let firstText = first.text, let secondText = second.text {
            // Prefer merging elements with similar text characteristics
            let firstLength = Float(firstText.count)
            let secondLength = Float(secondText.count)
            let lengthDiff = abs(firstLength - secondLength)
            let lengthScore = max(0, 20 - lengthDiff) / 20
            score += lengthScore * 5
            
            // Bonus for elements that look like they're part of the same sentence/paragraph
            if !firstText.hasSuffix(".") && !firstText.hasSuffix("!") && !firstText.hasSuffix("?") {
                score += 5
            }
        }
        
        // Confidence-based scoring
        let avgConfidence = (first.confidence + second.confidence) / 2
        score += avgConfidence * 10
        
        return score
    }
    
    /// Merges two elements into a single element
    private func mergeElements(_ first: DocumentElement, _ second: DocumentElement) async -> DocumentElement {
        // Determine the merged bounding box
        let mergedBoundingBox = first.boundingBox.union(with: second.boundingBox)
        
        // Merge text content
        let mergedText: String?
        if let firstText = first.text, let secondText = second.text {
            // Check if elements are horizontally aligned (same line)
            let isSameLine = first.boundingBox.isVerticallyAligned(with: second.boundingBox, tolerance: 20.0)
            
            if isSameLine {
                // Same line merging: preserve spacing based on actual distance
                let horizontalGap = first.boundingBox.horizontalGap(to: second.boundingBox)
                let needsSpace = horizontalGap > 5.0 // If gap is more than 5 points, add space
                
                if needsSpace {
                    mergedText = "\(firstText) \(secondText)"
                } else {
                    // Elements are very close, merge without extra space
                    mergedText = "\(firstText)\(secondText)"
                }
            } else {
                // Vertical or diagonal merging: add space if not already separated
                let needsSpace = !firstText.hasSuffix(" ") && !secondText.hasPrefix(" ")
                mergedText = needsSpace ? "\(firstText) \(secondText)" : "\(firstText)\(secondText)"
            }
        } else {
            mergedText = first.text ?? second.text
        }
        
        // Merge metadata
        var mergedMetadata = first.metadata
        for (key, value) in second.metadata {
            if mergedMetadata[key] == nil {
                mergedMetadata[key] = value
            }
        }
        
        // Add merge information to metadata
        mergedMetadata["merged_from"] = "\(first.id.uuidString),\(second.id.uuidString)"
        mergedMetadata["merge_timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // Calculate average confidence
        let mergedConfidence = (first.confidence + second.confidence) / 2
        
        // Determine the merged element type
        let mergedType: ElementType
        switch (first.type, second.type) {
        case (.listItem, .listItem):
            mergedType = .listItem
        case (.textBlock, .textBlock), (.paragraph, .paragraph):
            mergedType = .textBlock
        case (.textBlock, .paragraph), (.paragraph, .textBlock):
            mergedType = .textBlock
        default:
            // Default to the more specific type
            mergedType = first.type.isMergeable ? first.type : second.type
        }
        
        // Create the merged element
        return DocumentElement(
            type: mergedType,
            boundingBox: mergedBoundingBox,
            contentData: first.contentData, // Keep first element's content data
            confidence: mergedConfidence,
            pageNumber: first.pageNumber,
            text: mergedText,
            metadata: mergedMetadata
        )
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
    private let config: MDKitConfig
    private let logger: Logger
    
    init(config: MDKitConfig) {
        self.config = config
        self.logger = Logger(label: "SimpleOverlapDetector")
    }
    
    func removeDuplicates(_ elements: [DocumentElement]) async -> ([DocumentElement], Int) {
        var uniqueElements: [DocumentElement] = []
        var duplicatesRemoved = 0
        
        for element in elements {
            let isDuplicate = uniqueElements.contains { existing in
                element.overlaps(with: existing, threshold: Float(config.processing.overlapThreshold))
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
