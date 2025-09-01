//
//  TraditionalOCRDocumentProcessor.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation
import Vision
import AppKit
import CoreGraphics
import Logging
import PDFKit
import mdkitProtocols
import mdkitConfiguration

/// Traditional OCR-based document processor using VNRecognizeTextRequest
@available(macOS 10.15, *)
public class TraditionalOCRDocumentProcessor: DocumentProcessing {
    
    // MARK: - Properties
    
    private var configuration: MDKitConfig
    private let logger: Logger
    private let markdownGenerator: MarkdownGenerator
    private let languageDetector: LanguageDetector
    private let headerAndListDetector: HeaderAndListDetector
    
    // Track current PDF processing context for language detection
    private var currentPDFURL: URL?
    private var currentPageNumber: Int = 0
    
    // Store generated image data for output generation
    private var storedImageData: [Int: Data] = [:]
    
    // MARK: - Initialization
    
    public init(configuration: MDKitConfig, markdownGenerator: MarkdownGenerator, languageDetector: LanguageDetector, headerAndListDetector: HeaderAndListDetector) {
        self.configuration = configuration
        self.markdownGenerator = markdownGenerator
        self.languageDetector = languageDetector
        self.headerAndListDetector = headerAndListDetector
        self.logger = Logger(label: "TraditionalOCRDocumentProcessor")
    }
    
    // MARK: - DocumentProcessing Implementation
    
    public func processDocument(at documentPath: String, pageRange: PageRange?) async throws -> DocumentProcessingResult {
        logger.info("Processing document at path: \(documentPath)")
        
        // Get document info first
        let documentInfo = try await getDocumentInfo(at: documentPath)
        logger.info("Document info: \(documentInfo.pageCount) pages, format: \(documentInfo.format)")
        
        // Determine which pages to process
        let pagesToProcess = pageRange?.getPageNumbers(totalPages: documentInfo.pageCount) ?? Array(1...documentInfo.pageCount)
        logger.info("Processing pages: \(pagesToProcess)")
        
        var allElements: [DocumentElement] = []
        var previousPageElements: [DocumentElement]? = nil
        
        // Process each page with cross-page sentence optimization
        for (index, pageNumber) in pagesToProcess.enumerated() {
            logger.info("Processing page \(pageNumber) of \(documentInfo.pageCount)")
            
            if documentInfo.format.lowercased() == "pdf" {
                // Set current PDF context for language detection
                currentPDFURL = URL(fileURLWithPath: documentPath)
                currentPageNumber = pageNumber
                
                // Extract PDF page as image
                let pageImageData = try await extractPDFPageAsImage(documentPath: documentPath, pageNumber: pageNumber)
                let currentPageElements = try await processDocument(from: pageImageData, pageNumber: pageNumber, pageRange: pageRange)
                
                // Step 1: Check if page has content to process (FIRST!)
                if currentPageElements.isEmpty {
                    logger.info("Page \(pageNumber) has no elements - skipping processing")
                    if let previousElements = previousPageElements {
                        allElements.append(contentsOf: previousElements)
                        previousPageElements = []
                    }
                    continue
                }
                
                // Step 2: Sort by position (within current page)
                let currentPageElementsSorted = sortElementsByPosition(currentPageElements)
                
                // Step 3: Apply same-line merging (with sorted elements) - MOVED HERE
                // Detect language for this page to determine spacing behavior
                let pageLanguage = (try? detectLanguage(from: currentPageElementsSorted)) ?? "en"
                let currentPageElementsWithSameLineMerged = await headerAndListDetector.mergeSameLineElements(currentPageElementsSorted, language: pageLanguage)
                
                // Step 3.5: Re-detect headers after same-line merging
                let currentPageElementsWithHeadersRedetected = currentPageElementsWithSameLineMerged.map { element in
                    let headerResult = headerAndListDetector.detectHeader(in: element)
                    if headerResult.isHeader {
                        return DocumentElement(
                            type: .header,
                            boundingBox: element.boundingBox,
                            contentData: element.contentData,
                            confidence: element.confidence,
                            pageNumber: element.pageNumber,
                            text: element.text,
                            metadata: element.metadata,
                            headerLevel: headerResult.level
                        )
                    } else {
                        return element
                    }
                }
                
                // Step 4: TOC Detection (BEFORE cross-page optimization)
                let currentPageHeaderRatio = calculateHeaderRatio(currentPageElementsWithHeadersRedetected)
                let isCurrentPageTOC = currentPageHeaderRatio >= 0.9 && currentPageElementsWithHeadersRedetected.count >= 3
                
                // Step 4.5: Use headers as they are - TOC conversion will happen during markdown generation
                let currentPageElementsFinal = currentPageElementsWithHeadersRedetected
                
                // Step 4.6: Also check if the previous page was a TOC page to prevent cross-page optimization
                let isPreviousPageTOC: Bool
                if let previousElements = previousPageElements {
                    let previousPageHeaderRatio = calculateHeaderRatio(previousElements)
                    isPreviousPageTOC = previousPageHeaderRatio >= 0.9 && previousElements.count >= 3
                } else {
                    isPreviousPageTOC = false
                }
                
                if isCurrentPageTOC {
                    logger.info("Page \(pageNumber) identified as TOC page (header ratio: \(String(format: "%.1f", currentPageHeaderRatio * 100))%) - will skip cross-page optimization")
                }
                
                // Step 5: Cross-page sentence optimization (TOC-aware, with merged and sorted elements)
                if let previousElements = previousPageElements {
                    // Additional check: Skip cross-page optimization if last element is far from bottom
                    let shouldSkipCrossPageOptimization = shouldSkipCrossPageOptimization(previousElements: previousElements)
                    
                    // Skip cross-page optimization if either page is TOC or if last element is far from bottom
                    if isCurrentPageTOC || isPreviousPageTOC || shouldSkipCrossPageOptimization {
                        let reason = isCurrentPageTOC ? "current page is TOC" : (isPreviousPageTOC ? "previous page is TOC" : "last element far from bottom")
                        logger.info("Skipping cross-page optimization - \(reason)")
                        
                        // Store previous page elements without cross-page optimization
                        let finalPreviousPage = await headerAndListDetector.mergeSplitSentencesConservative(previousElements)
                        let normalizedPreviousPage = headerAndListDetector.normalizeAllListItems(finalPreviousPage)
                        allElements.append(contentsOf: normalizedPreviousPage)
                        
                        // Apply multi-line merging and normalization to current page
                        let finalCurrentPage = await headerAndListDetector.mergeSplitSentencesConservative(currentPageElementsFinal)
                        previousPageElements = headerAndListDetector.normalizeAllListItems(finalCurrentPage)
                    } else {
                        // Only run cross-page optimization if neither page is a TOC page
                        // This ensures TOC pages are never affected by cross-page optimization
                        let (optimizedPreviousPage, optimizedCurrentPage) = try await headerAndListDetector.optimizeCrossPageSentences(
                            currentPage: previousElements,
                            nextPage: currentPageElementsWithHeadersRedetected,
                            currentPageNumber: pagesToProcess[index - 1],
                            nextPageNumber: pageNumber
                        )
                        
                        // Step 6: Multi-line merging for previous page
                        let finalPreviousPage = await headerAndListDetector.mergeSplitSentencesConservative(optimizedPreviousPage)
                        
                        // Step 7: Normalize list items for previous page
                        let normalizedPreviousPage = headerAndListDetector.normalizeAllListItems(finalPreviousPage)
                        
                        // Step 8: Store previous page elements
                        allElements.append(contentsOf: normalizedPreviousPage)
                        
                        // Step 9: Multi-line merging for current page
                        let finalCurrentPage = await headerAndListDetector.mergeSplitSentencesConservative(optimizedCurrentPage)
                        
                        // Step 10: Normalize list items for current page
                        previousPageElements = headerAndListDetector.normalizeAllListItems(finalCurrentPage)
                    }
                } else {
                    // First page - apply multi-line merging and normalization
                    let finalCurrentPage = await headerAndListDetector.mergeSplitSentencesConservative(currentPageElementsFinal)
                    previousPageElements = headerAndListDetector.normalizeAllListItems(finalCurrentPage)
                }
            } else {
                // For non-PDF documents, process as single image
                let imageData = try Data(contentsOf: URL(fileURLWithPath: documentPath))
                let elements = try await processDocument(from: imageData, pageNumber: pageNumber, pageRange: pageRange)
                allElements.append(contentsOf: elements)
                break // Only process once for non-PDF documents
            }
        }
        
        // Add the last page elements (which may have been optimized)
        if let lastPageElements = previousPageElements {
            allElements.append(contentsOf: lastPageElements)
        }
        
        logger.info("Successfully processed document with cross-page optimization, extracted \(allElements.count) elements")
        
        return DocumentProcessingResult(
            elements: allElements,
            blankPages: [],
            totalPagesProcessed: pagesToProcess.count,
            totalPagesRequested: pagesToProcess.count
        )
    }
    
    /// Get stored image data for a specific page
    /// - Parameter pageNumber: The page number to retrieve image data for
    /// - Returns: Image data if available, nil otherwise
    public func getStoredImageData(for pageNumber: Int) -> Data? {
        return storedImageData[pageNumber]
    }
    
    /// Get all stored image data
    /// - Returns: Dictionary mapping page numbers to image data
    public func getAllStoredImageData() -> [Int: Data] {
        return storedImageData
    }
    
    public func processDocument(at documentPath: String) async throws -> DocumentProcessingResult {
        return try await processDocument(at: documentPath, pageRange: nil)
    }
    
    public func processDocument(from imageData: Data, pageNumber: Int, pageRange: PageRange?) async throws -> [DocumentElement] {
        logger.info("Processing image data for page \(pageNumber)")
        
        // Check if this page should be processed
        if let pageRange = pageRange {
            let pagesToProcess = pageRange.getPageNumbers(totalPages: 1) // Assuming single page for now
            if !pagesToProcess.contains(pageNumber) {
                logger.info("Skipping page \(pageNumber) based on page range")
                return []
            }
        }
        
        // Create Vision request with optimized settings
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Configure supported languages for OCR from configuration
        // Use configuration languages if available, otherwise fall back to defaults
        let supportedLanguages = configuration.ocr.languages.isEmpty ? 
            ["zh-Hans", "zh-Hant", "en-US"] : // Default: Chinese (simplified/traditional) + English
            configuration.ocr.languages.map { language in
                // Map configuration language codes to Vision framework codes if needed
                switch language.lowercased() {
                case "zh-cn", "zh-hans", "zh_simplified":
                    return "zh-Hans"  // Simplified Chinese
                case "zh-tw", "zh-hant", "zh_traditional":
                    return "zh-Hant"  // Traditional Chinese
                case "en", "en-us", "en-gb":
                    return "en-US"    // English (US)
                default:
                    return language   // Use as-is for other languages
                }
            }
        
        request.recognitionLanguages = supportedLanguages
        logger.info("OCR configured with supported languages: \(supportedLanguages)")
        
        // Note: Vision framework will use these languages for better recognition accuracy
        // This is especially important for Chinese text which requires specific language models
        
        // Additional optimization settings
        request.minimumTextHeight = 0.01
        
        // Add custom words if specified in configuration
        let customWords = configuration.ocr.customWords
        if !customWords.isEmpty {
            request.customWords = customWords
        }
        
        logger.debug("OCR request configured with languages: \(request.recognitionLanguages)")
        
        // Create CGImage from data
        guard let cgImage = NSImage(data: imageData)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw mdkitProtocols.DocumentProcessingError.processingFailed("Failed to create CGImage from data")
        }
        
        // Perform OCR
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let observations = request.results else {
            throw mdkitProtocols.DocumentProcessingError.processingFailed("No OCR results obtained")
        }
        
        logger.info("OCR completed, extracted \(observations.count) text observations")
        
        // Filter out page headers and footers based on configuration
        let filteredObservations = filterPageHeadersAndFooters(observations, pageNumber: pageNumber)
        logger.info("After header/footer filtering: \(filteredObservations.count) observations")
        
        // Convert observations to document elements
        let elements = try convertObservationsToElements(filteredObservations, pageNumber: pageNumber)
        
        logger.info("Document processing completed, generated \(elements.count) elements")
        return elements
    }
    
    public func getDocumentInfo(at documentPath: String) async throws -> DocumentInfo {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: documentPath)
        
        guard fileManager.fileExists(atPath: documentPath) else {
            throw mdkitProtocols.DocumentProcessingError.documentNotFound
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: documentPath)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let creationDate = attributes[.creationDate] as? Date
        let modificationDate = attributes[.modificationDate] as? Date
        
        // Determine format and page count
        let format = url.pathExtension.uppercased()
        let pageCount: Int
        
        if format == "PDF" {
            // Use PDFKit to get actual page count
            guard let pdfDocument = PDFDocument(url: url) else {
                throw mdkitProtocols.DocumentProcessingError.processingFailed("Failed to load PDF document for page count")
            }
            pageCount = pdfDocument.pageCount
            logger.info("PDF document loaded: \(pageCount) pages")
        } else if ["PNG", "JPG", "JPEG", "TIFF", "BMP"].contains(format) {
            pageCount = 1
        } else {
            throw mdkitProtocols.DocumentProcessingError.unsupportedFormat
        }
        
        return DocumentInfo(
            pageCount: pageCount,
            format: format,
            fileSize: fileSize,
            creationDate: creationDate,
            modificationDate: modificationDate
        )
    }
    
    public func detectHeadersAndFooters(from elements: [DocumentElement]) throws -> (headers: [DocumentElement], footers: [DocumentElement]) {
        logger.info("Detecting headers and footers from \(elements.count) elements")
        
        var headers: [DocumentElement] = []
        var footers: [DocumentElement] = []
        
        for element in elements {
            let normalizedY = element.boundingBox.minY
            
            // Headers are typically at the top (high Y values in normalized coordinates)
            if normalizedY > 0.8 {
                headers.append(element)
            }
            // Footers are typically at the bottom (low Y values in normalized coordinates)
            else if normalizedY < 0.2 {
                footers.append(element)
            }
        }
        
        logger.info("Detected \(headers.count) headers and \(footers.count) footers")
        return (headers: headers, footers: footers)
    }
    
    public func detectLanguage(from elements: [DocumentElement]) throws -> String {
        logger.info("Detecting language from \(elements.count) elements")
        
        // Try to detect language from the original PDF text first (if available)
        if let pdfText = try? extractTextFromPDFPage() {
            logger.info("=== PDF TEXT EXTRACTION SUCCESSFUL ===")
            logger.info("Extracted PDF text: '\(pdfText)'")
            logger.info("PDF text length: \(pdfText.count)")
            
            // Use the injected LanguageDetector for sophisticated language detection
            let detectedLanguage = languageDetector.detectLanguage(from: pdfText)
            let (languageWithConfidence, confidence) = languageDetector.detectLanguageWithConfidence(from: pdfText)
            
            logger.info("=== LANGUAGE DETECTION RESULT (FROM PDF TEXT) ===")
            logger.info("Basic detection: \(detectedLanguage)")
            logger.info("Confidence-based detection: \(languageWithConfidence) (confidence: \(String(format: "%.3f", confidence)))")
            logger.info("Final detected language: \(languageWithConfidence)")
            logger.info("=================================")
            
            return languageWithConfidence
        }
        
        // Fallback to OCR-based language detection
        logger.info("=== FALLBACK TO OCR-BASED LANGUAGE DETECTION ===")
        logger.info("PDF text extraction failed, using OCR elements for language detection")
        
        // Log all text content being analyzed
        logger.info("=== LANGUAGE DETECTION ANALYSIS ===")
        logger.info("Analyzing text from \(elements.count) elements:")
        
        var allText = ""
        var elementTexts: [String] = []
        
        for (index, element) in elements.enumerated() {
            guard let text = element.text else { 
                logger.debug("Element \(index): No text content")
                continue 
            }
            
            logger.info("Element \(index): '\(text)' (length: \(text.count))")
            allText += text + " "
            elementTexts.append(text)
        }
        
        if allText.isEmpty {
            throw mdkitProtocols.DocumentProcessingError.languageDetectionFailed("No text content to analyze")
        }
        
        logger.info("=== COMBINED TEXT FOR LANGUAGE DETECTION ===")
        logger.info("Combined text: '\(allText.trimmingCharacters(in: .whitespacesAndNewlines))'")
        logger.info("Total combined length: \(allText.count)")
        
        // Use the injected LanguageDetector for sophisticated language detection
        let detectedLanguage = languageDetector.detectLanguage(from: allText)
        let (languageWithConfidence, confidence) = languageDetector.detectLanguageWithConfidence(from: allText)
        
        logger.info("=== LANGUAGE DETECTION RESULT ===")
        logger.info("Basic detection: \(detectedLanguage)")
        logger.info("Confidence-based detection: \(languageWithConfidence) (confidence: \(String(format: "%.3f", confidence)))")
        logger.info("Final detected language: \(languageWithConfidence)")
        logger.info("=================================")
        
        return languageWithConfidence
    }
    
    public func mergeSplitElements(_ elements: [DocumentElement], language: String) async throws -> [DocumentElement] {
        logger.info("Legacy mergeSplitElements method called - all processing now done in page-by-page pipeline")
        // This method is deprecated - all processing is now done in the page-by-page pipeline
        return elements
    }
    
    public func removeDuplicates(from elements: [DocumentElement]) throws -> (elements: [DocumentElement], duplicatesRemoved: Int) {
        logger.info("Removing duplicates from \(elements.count) elements")
        
        var uniqueElements: [DocumentElement] = []
        var duplicatesRemoved = 0
        var seenTexts: Set<String> = []
        
        for element in elements {
            guard let text = element.text else { continue }
            let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenTexts.contains(normalizedText) {
                seenTexts.insert(normalizedText)
                uniqueElements.append(element)
            } else {
                duplicatesRemoved += 1
            }
        }
        
        logger.info("Duplicate removal completed: removed \(duplicatesRemoved) duplicates")
        return (elements: uniqueElements, duplicatesRemoved: duplicatesRemoved)
    }
    
    public func sortElementsByPosition(_ elements: [DocumentElement]) -> [DocumentElement] {
        return elements.sorted { element1, element2 in
            // Sort by Y position (top to bottom), then by X position (left to right)
            if abs(element1.boundingBox.minY - element2.boundingBox.minY) < 0.01 {
                return element1.boundingBox.minX < element2.boundingBox.minX
            }
            return element1.boundingBox.minY > element2.boundingBox.minY
        }
    }
    
    public func sortElementsByPositionWithinPage(_ elements: [DocumentElement]) -> [DocumentElement] {
        // For single-page documents, this is the same as sortElementsByPosition
        return sortElementsByPosition(elements)
    }
    
    public func generateMarkdown(from elements: [DocumentElement], inputFilename: String? = nil, blankPages: [Int] = [], totalPagesProcessed: Int = 0, totalPagesRequested: Int = 0) throws -> String {
        logger.info("Generating markdown from \(elements.count) elements")
        
        // Sort elements by position before generating markdown
        let sortedElements = sortElementsByPosition(elements)
        
        // Delegate markdown generation to the MarkdownGenerator
        let markdown = try markdownGenerator.generateMarkdown(from: sortedElements, inputFilename: inputFilename, blankPages: blankPages, totalPagesProcessed: totalPagesProcessed, totalPagesRequested: totalPagesRequested)
        
        logger.info("Markdown generation completed")
        return markdown
    }
    
    public func generateTableOfContents(from elements: [DocumentElement]) throws -> String {
        logger.info("Generating table of contents from \(elements.count) elements")
        
        let sortedElements = sortElementsByPosition(elements)
        var toc = "# Table of Contents\n\n"
        
        for element in sortedElements {
            guard let text = element.text else { continue }
            
            switch element.type {
            case .title:
                toc += "1. [\(text)](#\(text.lowercased().replacingOccurrences(of: " ", with: "-")))\n"
            case .header:
                toc += "   1. [\(text)](#\(text.lowercased().replacingOccurrences(of: " ", with: "-")))\n"
            default:
                break
            }
        }
        
        logger.info("Table of contents generation completed")
        return toc
    }
    

    
    // MARK: - Private Helper Methods
    
    private func convertObservationsToElements(_ observations: [VNRecognizedTextObservation], pageNumber: Int) throws -> [DocumentElement] {
        var elements: [DocumentElement] = []
        
        logger.info("=== ORIGINAL OCR OBSERVATIONS (PAGE \(pageNumber)) ===")
        logger.info("Total observations: \(observations.count)")
        
        // Sort observations by Y-coordinate (top to bottom) for logical reading order
        let sortedObservations = observations.sorted { obs1, obs2 in
            // Use the top edge (minY) for sorting, with smaller Y values first (top of page)
            return obs1.boundingBox.minY > obs2.boundingBox.minY
        }
        
        logger.info("Observations sorted by Y-coordinate (top to bottom)")
        
        for (index, observation) in sortedObservations.enumerated() {
            guard let topCandidate = observation.topCandidates(1).first else { 
                logger.warning("   Observation \(index): No top candidate found, skipping")
                continue 
            }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            let boundingBox = observation.boundingBox
            
            // Log detailed information about each observation
            logger.info("   📝 Observation \(index):")
            logger.info("      📄 Page: \(pageNumber)")
            logger.info("      📍 Region: (\(String(format: "%.6f", boundingBox.minY)), \(String(format: "%.6f", boundingBox.minX)), \(String(format: "%.6f", boundingBox.height)), \(String(format: "%.6f", boundingBox.width)))")
            logger.info("      📍 Coordinates: X=[\(String(format: "%.6f", boundingBox.minX))-\(String(format: "%.6f", boundingBox.maxX))], Y=[\(String(format: "%.6f", boundingBox.minY))-\(String(format: "%.6f", boundingBox.maxY))]")
            logger.info("      📝 Text: '\(text)'")
            logger.info("      📏 Length: \(text.count) characters")
            logger.info("      🎯 Confidence: \(String(format: "%.3f", confidence))")
            
            // Use HeaderAndListDetector for proper element type detection
            let elementType: DocumentElementType
            let headerResult = headerAndListDetector.detectHeader(in: DocumentElement(
                type: .paragraph,
                boundingBox: boundingBox,
                contentData: Data(),
                confidence: confidence,
                pageNumber: pageNumber,
                text: text,
                metadata: [:]
            ))
            let listItemResult = headerAndListDetector.detectListItem(in: DocumentElement(
                type: .paragraph,
                boundingBox: boundingBox,
                contentData: Data(),
                confidence: confidence,
                pageNumber: pageNumber,
                text: text,
                metadata: [:]
            ))
            
            if headerResult.isHeader {
                elementType = .header
            } else if listItemResult.isListItem {
                elementType = .listItem
            } else {
                elementType = .paragraph
            }
            logger.info("      🏷️ Detected Type: \(elementType)")
            
            let element = DocumentElement(
                id: UUID(),
                type: elementType,
                boundingBox: boundingBox,
                contentData: Data(), // Empty data for now
                confidence: confidence,
                pageNumber: pageNumber,
                text: text,
                metadata: [
                    "ocr_method": "traditional_vision",
                    "confidence": String(confidence)
                ],
                headerLevel: headerResult.isHeader ? headerResult.level : nil
            )
            
            // Debug logging for header elements
            if elementType == .header {
                logger.debug("Created header element: '\(text)' with level: \(element.headerLevel ?? -1)")
            }
            
            elements.append(element)
            logger.info("      ✅ Element created with ID: \(element.id)")
        }
        
        logger.info("=== OCR OBSERVATIONS CONVERSION COMPLETE ===")
        logger.info("Successfully converted \(elements.count) observations to DocumentElements")
        logger.info("===============================================")
        
        return elements
    }
    

    

    
    private func shouldMergeElements(_ element1: DocumentElement, _ element2: DocumentElement, language: String) -> Bool {
        // Check if elements are close vertically - use stricter 1% threshold to preserve list items
        let verticalDistance = abs(element1.boundingBox.minY - element2.boundingBox.minY)
        if verticalDistance > 0.01 { // 1% threshold (much stricter than previous 5%)
            return false
        }
        
        // Check if elements are close horizontally
        let horizontalDistance = abs(element1.boundingBox.maxX - element2.boundingBox.minX)
        if horizontalDistance > 0.1 { // 10% threshold
            return false
        }
        
        // Additional check: if either element is a list item, be very conservative about merging
        if let text1 = element1.text, let text2 = element2.text {
            let normalizedText1 = text1.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedText2 = text2.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Don't merge if either text starts with a list item marker
            if normalizedText1.hasPrefix("a）") || normalizedText1.hasPrefix("b）") || normalizedText1.hasPrefix("c）") ||
               normalizedText1.hasPrefix("d）") || normalizedText1.hasPrefix("e）") || normalizedText1.hasPrefix("f）") ||
               normalizedText1.hasPrefix("g）") || normalizedText1.hasPrefix("h）") || normalizedText1.hasPrefix("i）") ||
               normalizedText1.hasPrefix("j）") || normalizedText1.hasPrefix("k）") || normalizedText1.hasPrefix("l）") ||
               normalizedText1.hasPrefix("m）") || normalizedText1.hasPrefix("n）") || normalizedText1.hasPrefix("o）") ||
               normalizedText1.hasPrefix("p）") || normalizedText1.hasPrefix("q）") || normalizedText1.hasPrefix("r）") ||
               normalizedText1.hasPrefix("s）") || normalizedText1.hasPrefix("t）") || normalizedText1.hasPrefix("u）") ||
               normalizedText1.hasPrefix("v）") || normalizedText1.hasPrefix("w）") || normalizedText1.hasPrefix("x）") ||
               normalizedText1.hasPrefix("y）") || normalizedText1.hasPrefix("z）") ||
               normalizedText2.hasPrefix("a）") || normalizedText2.hasPrefix("b）") || normalizedText2.hasPrefix("c）") ||
               normalizedText2.hasPrefix("d）") || normalizedText2.hasPrefix("e）") || normalizedText2.hasPrefix("f）") ||
               normalizedText2.hasPrefix("g）") || normalizedText2.hasPrefix("h）") || normalizedText2.hasPrefix("i）") ||
               normalizedText2.hasPrefix("j）") || normalizedText2.hasPrefix("k）") || normalizedText2.hasPrefix("l）") ||
               normalizedText2.hasPrefix("m）") || normalizedText2.hasPrefix("n）") || normalizedText2.hasPrefix("o）") ||
               normalizedText2.hasPrefix("p）") || normalizedText2.hasPrefix("q）") || normalizedText2.hasPrefix("r）") ||
               normalizedText2.hasPrefix("s）") || normalizedText2.hasPrefix("t）") || normalizedText2.hasPrefix("u）") ||
               normalizedText2.hasPrefix("v）") || normalizedText2.hasPrefix("w）") || normalizedText2.hasPrefix("x）") ||
               normalizedText2.hasPrefix("y）") || normalizedText2.hasPrefix("z）") {
                return false
            }
        }
        
        // Check if text content suggests they should be merged
        guard let text1 = element1.text, let text2 = element2.text else { return false }
        let normalizedText1 = text1.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText2 = text2.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Merge if one ends with punctuation and the other doesn't start with it
        if normalizedText1.hasSuffix("，") || normalizedText1.hasSuffix("。") || normalizedText1.hasSuffix("；") {
            return !normalizedText2.hasPrefix("，") && !normalizedText2.hasPrefix("。") && !normalizedText2.hasPrefix("；")
        }
        
        return false
    }
    
    private func mergeElements(_ element1: DocumentElement, _ element2: DocumentElement) -> DocumentElement {
        let mergedText = (element1.text ?? "") + (element2.text ?? "")
        let mergedBoundingBox = CGRect(
            x: min(element1.boundingBox.minX, element2.boundingBox.minX),
            y: min(element1.boundingBox.minY, element2.boundingBox.minY),
            width: max(element1.boundingBox.maxX, element2.boundingBox.maxX) - min(element1.boundingBox.minX, element2.boundingBox.minX),
            height: max(element1.boundingBox.maxY, element2.boundingBox.maxY) - min(element1.boundingBox.minY, element2.boundingBox.minY)
        )
        
        // Preserve original metadata from both elements
        var mergedMetadata: [String: String] = [:]
        
        // Start with element1's metadata
        for (key, value) in element1.metadata {
            mergedMetadata[key] = value
        }
        
        // Add element2's metadata (element1 takes precedence for conflicts)
        for (key, value) in element2.metadata {
            if mergedMetadata[key] == nil {
                mergedMetadata[key] = value
            }
        }
        
        // Add merge-specific metadata
        mergedMetadata["merged_from"] = "\(element1.id),\(element2.id)"
        mergedMetadata["ocr_method"] = "traditional_vision"
        
        // Preserve the first element's type and properties (important for headers)
        let mergedType = element1.type
        let mergedHeaderLevel = element1.headerLevel
        
        return DocumentElement(
            id: UUID(),
            type: mergedType,
            boundingBox: mergedBoundingBox,
            contentData: Data(), // Empty data for merged elements
            confidence: min(element1.confidence, element2.confidence),
            pageNumber: element1.pageNumber,
            text: mergedText,
            metadata: mergedMetadata,
            headerLevel: mergedHeaderLevel
        )
    }
    
    // MARK: - PDF Processing
    
    /// Extracts text from the current PDF page (for text-based PDFs)
    /// - Returns: Extracted text if available, nil if no text layer or extraction fails
    private func extractTextFromPDFPage() throws -> String? {
        guard let pdfURL = currentPDFURL else {
            logger.debug("No current PDF URL available for text extraction")
            return nil
        }
        
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            logger.debug("Failed to load PDF document for text extraction")
            return nil
        }
        
        // Convert 1-based page number to 0-based index
        let pageIndex = currentPageNumber - 1
        guard pageIndex >= 0 && pageIndex < pdfDocument.pageCount else {
            logger.debug("Page index \(pageIndex) out of range for PDF with \(pdfDocument.pageCount) pages")
            return nil
        }
        
        guard let page = pdfDocument.page(at: pageIndex) else {
            logger.debug("Failed to get page \(pageIndex) from PDF")
            return nil
        }
        
        // Try to extract text from the page
        guard let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("No text content found in PDF page \(currentPageNumber)")
            return nil
        }
        
        logger.info("Successfully extracted \(pageText.count) characters from PDF page \(currentPageNumber)")
        return pageText
    }
    
    /// Converts a PDF page to an NSImage for OCR processing
    /// - Parameter page: The PDF page to convert
    /// - Returns: NSImage representation of the page
    /// - Throws: DocumentProcessingError if conversion fails
    private func convertPDFPageToImage(_ page: PDFPage) throws -> NSImage {
        let pageRect = page.bounds(for: .mediaBox)
        
        // Enhanced resolution for better OCR accuracy
        let scaleFactor: CGFloat = 3.0 // 3x resolution for optimal OCR
        let enhancedSize = CGSize(width: pageRect.width * scaleFactor, height: pageRect.height * scaleFactor)
        
        // Create image with enhanced size
        let image = NSImage(size: enhancedSize)
        
        logger.info("🔧 DEBUG: Converting PDF page: original size \(pageRect.size), enhanced size \(enhancedSize) (scale factor: \(scaleFactor))")
        
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
        
        logger.info("🔧 DEBUG: PDF page converted to high-quality image with \(scaleFactor)x resolution")
        
        // Enhance image quality for better OCR accuracy
        let enhancedImage = enhanceImageQuality(image)
        
        return enhancedImage
    }
    
    /// Converts NSImage to Data for Vision framework with image enhancement
    /// - Parameter image: The NSImage to convert
    /// - Returns: Enhanced image data for better OCR
    /// - Throws: DocumentProcessingError if conversion fails
    private func convertNSImageToData(_ image: NSImage) throws -> Data {
        // First enhance the image quality
        logger.info("🔧 DEBUG: Applying simple, effective image enhancement for better OCR accuracy...")
        logger.info("🔧 DEBUG: Enhancement pipeline: Simple Contrast → Gentle Sharpening")
        
        let enhancedImage = enhanceImageQuality(image)
        
        // Try PNG conversion first (more reliable)
        if let cgImage = enhancedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            if let pngData = bitmap.representation(using: .png, properties: [:]) {
                logger.info("🔧 DEBUG: PNG conversion successful via CGImage. Size: \(pngData.count) bytes")
                return pngData
            }
        }
        
        // Fallback to TIFF method
        guard let tiffData = enhancedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let imageData = bitmap.representation(using: .png, properties: [:]) else {
            throw mdkitProtocols.DocumentProcessingError.imageProcessingFailed("Failed to convert enhanced image to data")
        }
        
        logger.info("🔧 DEBUG: PNG conversion successful via TIFF fallback. Size: \(imageData.count) bytes")
        return imageData
    }
    
    /// Enhances image quality for better OCR accuracy
    /// - Parameter image: The input image to enhance
    /// - Returns: Enhanced image with improved quality
    private func enhanceImageQuality(_ image: NSImage) -> NSImage {
        // Always apply image enhancement for better OCR accuracy
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            logger.warning("🔧 DEBUG: Could not get CGImage for enhancement, returning original image")
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
            } else {
                logger.warning("🔧 DEBUG: Contrast filter failed to produce output")
            }
        } else {
            logger.warning("🔧 DEBUG: Could not create contrast filter")
        }
        
        // 2. Gentle Sharpening - Enhance text edges without artifacts
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(enhancedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.3, forKey: kCIInputSharpnessKey) // Gentle sharpening
            
            if let outputImage = sharpenFilter.outputImage {
                enhancedImage = outputImage
                logger.debug("Applied sharpening filter")
            } else {
                logger.warning("🔧 DEBUG: Sharpening filter failed to produce output")
            }
        } else {
            logger.warning("🔧 DEBUG: Could not create sharpening filter")
        }
        
        // Convert back to NSImage
        let context = CIContext()
        guard let outputCGImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            logger.warning("🔧 DEBUG: Failed to create enhanced CGImage, returning original image")
            return image
        }
        
        logger.info("🔧 DEBUG: Image enhancement completed successfully. Original size: \(image.size), Enhanced size: \(image.size)")
        return NSImage(cgImage: outputCGImage, size: image.size)
    }
    
    /// Extracts a specific page from a PDF as image data
    /// - Parameters:
    ///   - documentPath: Path to the PDF document
    ///   - pageNumber: Page number to extract (1-based)
    /// - Returns: Image data of the extracted page
    private func extractPDFPageAsImage(documentPath: String, pageNumber: Int) async throws -> Data {
        guard let pdfDocument = PDFDocument(url: URL(fileURLWithPath: documentPath)) else {
            throw mdkitProtocols.DocumentProcessingError.documentLoadFailed("Failed to load PDF document")
        }
        
        // Convert 1-based page number to 0-based index
        let pageIndex = pageNumber - 1
        guard pageIndex >= 0 && pageIndex < pdfDocument.pageCount else {
            throw mdkitProtocols.DocumentProcessingError.pageNotFound("Page \(pageNumber) not found in PDF with \(pdfDocument.pageCount) pages")
        }
        
        guard let page = pdfDocument.page(at: pageIndex) else {
            throw mdkitProtocols.DocumentProcessingError.pageNotFound("Failed to get page \(pageNumber) from PDF")
        }
        
        // Convert PDF page to NSImage with enhanced quality
        let nsImage = try convertPDFPageToImage(page)
        
        // Convert NSImage to Data with image enhancement
        let imageData = try convertNSImageToData(nsImage)
        
        // Store the image data for output generation
        storedImageData[pageNumber] = imageData
        
        logger.info("Successfully extracted page \(pageNumber) as image (\(imageData.count) bytes)")
        return imageData
    }
    
    /// Filters out page headers and footers based on configuration parameters
    /// This is applied as the first step before any other processing
    /// - Parameters:
    ///   - observations: Original OCR observations from Vision framework
    ///   - pageNumber: Current page number being processed
    /// - Returns: Filtered observations with headers/footers removed
    private func filterPageHeadersAndFooters(_ observations: [VNRecognizedTextObservation], pageNumber: Int) -> [VNRecognizedTextObservation] {
        // Check if header/footer detection is enabled in configuration
        guard configuration.processing.enableHeaderFooterDetection else {
            logger.info("Header/footer detection disabled in configuration, returning all observations")
            return observations
        }
        
        let headerRegion = configuration.processing.pageHeaderRegion
        let footerRegion = configuration.processing.pageFooterRegion
        
        logger.info("Filtering headers/footers - Header region: \(headerRegion), Footer region: \(footerRegion)")
        
        var filteredObservations: [VNRecognizedTextObservation] = []
        var removedCount = 0
        
        for observation in observations {
            let boundingBox = observation.boundingBox
            
            // Check if observation is in header region (top of page)
            let isInHeaderRegion = boundingBox.minY >= headerRegion[0] && boundingBox.maxY <= headerRegion[1]
            
            // Check if observation is in footer region (bottom of page)
            let isInFooterRegion = boundingBox.minY >= footerRegion[0] && boundingBox.maxY <= footerRegion[1]
            
            if isInHeaderRegion {
                logger.debug("Removing header observation: '\(observation.topCandidates(1).first?.string ?? "")' at Y=[\(String(format: "%.3f", boundingBox.minY))-\(String(format: "%.3f", boundingBox.maxY))]")
                removedCount += 1
                continue
            }
            
            if isInFooterRegion {
                logger.debug("Removing footer observation: '\(observation.topCandidates(1).first?.string ?? "")' at Y=[\(String(format: "%.3f", boundingBox.minY))-\(String(format: "%.3f", boundingBox.maxY))]")
                removedCount += 1
                continue
            }
            
            // Keep observation if it's not in header or footer regions
            filteredObservations.append(observation)
        }
        
        logger.info("Header/footer filtering completed: removed \(removedCount) observations, kept \(filteredObservations.count) observations")
        return filteredObservations
    }
    
    // MARK: - TOC Detection and Conditional Merging
    
    /// Detect TOC pages and convert appropriate elements to TOC items
    /// Returns: (processedElements, tocPageNumbers)
    private func detectTOCPages(_ elements: [DocumentElement]) -> ([DocumentElement], Set<Int>) {
        logger.info("Legacy detectTOCPages method called - TOC detection now done in page-by-page pipeline")
        // This method is deprecated - TOC detection is now done in the page-by-page pipeline
        return (elements, Set<Int>())
    }
    
    /// Apply multi-line merging conditionally - skip TOC pages to preserve structure
    /// Also prevents cross-page merging when TOC pages are involved
    private func mergeSplitSentencesConditionally(_ elements: [DocumentElement], tocPages: Set<Int>) async -> [DocumentElement] {
        logger.info("Legacy mergeSplitSentencesConditionally method called - all processing now done in page-by-page pipeline")
        // This method is deprecated - all processing is now done in the page-by-page pipeline
        return elements
    }
    
    /// Check if cross-page optimization should be skipped based on Y-position of last element
    /// If the last element is far from the bottom (low Y value), skip cross-page optimization
    /// Y = 0 is at the bottom, Y = 1 is at the top
    private func shouldSkipCrossPageOptimization(previousElements: [DocumentElement]) -> Bool {
        guard let lastElement = previousElements.last else {
            return false
        }
        
        let lastElementY = lastElement.boundingBox.minY
        
        // If the last element is far from the bottom (Y < 0.2), skip cross-page optimization
        // This means the page likely ends naturally and doesn't need continuation
        if lastElementY < 0.2 {
            logger.info("Last element Y position (\(String(format: "%.3f", lastElementY))) is far from bottom - skipping cross-page optimization")
            return true
        }
        
        return false
    }
    
    /// Calculate the ratio of header elements in a collection
    private func calculateHeaderRatio(_ elements: [DocumentElement]) -> Float {
        let headerCount = elements.filter { $0.type == .header }.count
        let totalElements = elements.count
        return totalElements > 0 ? Float(headerCount) / Float(totalElements) : 0.0
    }
}
