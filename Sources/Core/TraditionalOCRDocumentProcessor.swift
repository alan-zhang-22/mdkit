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
    
    // Track current PDF processing context for language detection
    private var currentPDFURL: URL?
    private var currentPageNumber: Int = 0
    
    // Store generated image data for output generation
    private var storedImageData: [Int: Data] = [:]
    
    // MARK: - Initialization
    
    public init(configuration: MDKitConfig, markdownGenerator: MarkdownGenerator, languageDetector: LanguageDetector) {
        self.configuration = configuration
        self.markdownGenerator = markdownGenerator
        self.languageDetector = languageDetector
        self.logger = Logger(label: "TraditionalOCRDocumentProcessor")
    }
    
    // MARK: - DocumentProcessing Implementation
    
    public func processDocument(at documentPath: String, pageRange: PageRange?) async throws -> [DocumentElement] {
        logger.info("Processing document at path: \(documentPath)")
        
        // Get document info first
        let documentInfo = try await getDocumentInfo(at: documentPath)
        logger.info("Document info: \(documentInfo.pageCount) pages, format: \(documentInfo.format)")
        
        // Determine which pages to process
        let pagesToProcess = pageRange?.getPageNumbers(totalPages: documentInfo.pageCount) ?? Array(1...documentInfo.pageCount)
        logger.info("Processing pages: \(pagesToProcess)")
        
        var allElements: [DocumentElement] = []
        
        // Process each page based on the page range
        for pageNumber in pagesToProcess {
            logger.info("Processing page \(pageNumber) of \(documentInfo.pageCount)")
            
            if documentInfo.format.lowercased() == "pdf" {
                // Set current PDF context for language detection
                currentPDFURL = URL(fileURLWithPath: documentPath)
                currentPageNumber = pageNumber
                
                // Extract PDF page as image
                let pageImageData = try await extractPDFPageAsImage(documentPath: documentPath, pageNumber: pageNumber)
                let elements = try await processDocument(from: pageImageData, pageNumber: pageNumber, pageRange: pageRange)
                allElements.append(contentsOf: elements)
            } else {
                // For non-PDF documents, process as single image
                let imageData = try Data(contentsOf: URL(fileURLWithPath: documentPath))
                let elements = try await processDocument(from: imageData, pageNumber: pageNumber, pageRange: pageRange)
                allElements.append(contentsOf: elements)
                break // Only process once for non-PDF documents
            }
        }
        
        logger.info("Successfully processed document, extracted \(allElements.count) elements")
        return allElements
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
    
    public func processDocument(at documentPath: String) async throws -> [DocumentElement] {
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
        
        // Convert observations to document elements
        let elements = try convertObservationsToElements(observations, pageNumber: pageNumber)
        
        // Post-process elements
        let processedElements = try postProcessElements(elements)
        
        logger.info("Document processing completed, generated \(processedElements.count) elements")
        return processedElements
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
    
    public func mergeSplitElements(_ elements: [DocumentElement], language: String) throws -> [DocumentElement] {
        logger.info("Merging split elements for language: \(language)")
        
        let sortedElements = sortElementsByPosition(elements)
        var mergedElements: [DocumentElement] = []
        var currentElement: DocumentElement?
        
        for element in sortedElements {
            if let current = currentElement {
                // Check if elements should be merged based on proximity and content
                if shouldMergeElements(current, element, language: language) {
                    let merged = mergeElements(current, element)
                    currentElement = merged
                } else {
                    mergedElements.append(current)
                    currentElement = element
                }
            } else {
                currentElement = element
            }
        }
        
        // Add the last element
        if let last = currentElement {
            mergedElements.append(last)
        }
        
        logger.info("Element merging completed: \(elements.count) -> \(mergedElements.count)")
        return mergedElements
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
    
    public func generateMarkdown(from elements: [DocumentElement]) throws -> String {
        logger.info("Generating markdown from \(elements.count) elements")
        
        // Sort elements by position before generating markdown
        let sortedElements = sortElementsByPosition(elements)
        
        // Delegate markdown generation to the MarkdownGenerator
        let markdown = try markdownGenerator.generateMarkdown(from: sortedElements)
        
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
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let text = topCandidate.string
            let confidence = topCandidate.confidence
            let boundingBox = observation.boundingBox
            
            // Determine element type based on content and position
            let elementType = determineElementType(text: text, boundingBox: boundingBox, confidence: confidence)
            
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
                ]
            )
            
            elements.append(element)
        }
        
        return elements
    }
    
    private func determineElementType(text: String, boundingBox: CGRect, confidence: Float) -> DocumentElementType {
        let normalizedY = boundingBox.minY
        let textLength = text.count
        
        // Title detection (high position, short text, high confidence)
        if normalizedY > 0.85 && textLength < 50 && confidence > 0.8 {
            return .title
        }
        
        // Heading detection (high position, medium text, contains numbers)
        if normalizedY > 0.7 && (text.contains(".") || text.contains("：")) && textLength < 100 {
            return .header
        }
        
        // List item detection
        if text.hasPrefix("a）") || text.hasPrefix("b）") || text.hasPrefix("c）") || text.hasPrefix("d）") {
            return .listItem
        }
        
        // Footer detection (low position)
        if normalizedY < 0.1 {
            return .footer
        }
        
        // Header detection (very high position)
        if normalizedY > 0.9 {
            return .header
        }
        
        // Default to paragraph
        return .paragraph
    }
    
    private func postProcessElements(_ elements: [DocumentElement]) throws -> [DocumentElement] {
        var processedElements = elements
        
        // Detect language
        let language = try detectLanguage(from: processedElements)
        
        // Merge split elements
        processedElements = try mergeSplitElements(processedElements, language: language)
        
        // Remove duplicates
        let deduplicationResult = try removeDuplicates(from: processedElements)
        processedElements = deduplicationResult.elements
        
        // Sort by position
        processedElements = sortElementsByPosition(processedElements)
        
        return processedElements
    }
    
    private func shouldMergeElements(_ element1: DocumentElement, _ element2: DocumentElement, language: String) -> Bool {
        // Check if elements are close vertically
        let verticalDistance = abs(element1.boundingBox.minY - element2.boundingBox.minY)
        if verticalDistance > 0.05 { // 5% threshold
            return false
        }
        
        // Check if elements are close horizontally
        let horizontalDistance = abs(element1.boundingBox.maxX - element2.boundingBox.minX)
        if horizontalDistance > 0.1 { // 10% threshold
            return false
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
        
        return DocumentElement(
            id: UUID(),
            type: .paragraph, // Merged elements become paragraphs
            boundingBox: mergedBoundingBox,
            contentData: Data(), // Empty data for merged elements
            confidence: min(element1.confidence, element2.confidence),
            pageNumber: element1.pageNumber,
            text: mergedText,
            metadata: mergedMetadata
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
}
