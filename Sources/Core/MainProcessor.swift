import Foundation
import Logging
import mdkitConfiguration
import mdkitFileManagement
import mdkitProtocols



// MARK: - LLM Processing Protocol (Core Module Version)

/// Protocol for LLM processing operations (simplified version for Core module)
public protocol LLMProcessing {
    func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String) async throws -> String
}

/// Main processor that orchestrates the entire document processing pipeline
public class MainProcessor {
    
    // MARK: - Properties
    
    /// Configuration for the processor
    private let config: MDKitConfig
    
    /// File manager for handling input/output operations
    private let fileManager: mdkitFileManagement.FileManaging
    
    /// Document processor for PDF analysis and element extraction
    private let documentProcessor: TraditionalOCRDocumentProcessor
    
    /// LLM processor for markdown optimization and structure analysis (optional)
    private let llmProcessor: LLMProcessing?
    
    /// Language detector for identifying document language
    private let languageDetector: LanguageDetector
    
    /// Markdown generator for converting document elements to markdown
    private let markdownGenerator: MarkdownGenerator
    
    /// Output generator for multiple output types (OCR, markdown, prompts, LLM-optimized)
    private let outputGenerator: OutputGenerator
    
    /// Logger instance
    private let logger: Logger
    
    /// Processing statistics
    private var processingStats: ProcessingStatistics
    
    /// Stored image data from PDF processing
    private var storedImageData: [Int: Data] = [:]
    
    // MARK: - Initialization
    
    /// Initialize the main processor with all required services
    /// - Parameters:
    ///   - config: Configuration for the processor
    ///   - documentProcessor: Document processor for PDF analysis
    ///   - languageDetector: Language detection service
    ///   - markdownGenerator: Markdown generation service
    ///   - fileManager: File management service
    ///   - outputGenerator: Output generation service
    ///   - llmProcessor: Optional LLM processing service
    public init(
        config: MDKitConfig,
        documentProcessor: TraditionalOCRDocumentProcessor,
        languageDetector: LanguageDetector,
        markdownGenerator: MarkdownGenerator,
        fileManager: mdkitFileManagement.FileManaging,
        outputGenerator: OutputGenerator,
        llmProcessor: LLMProcessing? = nil
    ) {
        self.config = config
        self.documentProcessor = documentProcessor
        self.languageDetector = languageDetector
        self.markdownGenerator = markdownGenerator
        self.fileManager = fileManager
        self.outputGenerator = outputGenerator
        self.llmProcessor = llmProcessor
        self.logger = Logger(label: "mdkit.mainprocessor")
        self.processingStats = ProcessingStatistics()
        
        logger.info("MainProcessor initialized successfully with injected services")
    }
    

    
    // MARK: - Main Processing Methods
    
    /// Process a single PDF file
    /// - Parameters:
    ///   - inputPath: Path to the input PDF file
    ///   - outputPath: Optional output path (if nil, uses default naming)
    ///   - options: Processing options
    /// - Returns: Processing result
    public func processPDF(
        inputPath: String,
        outputPath: String? = nil,
        options: ProcessingOptions = ProcessingOptions(),
        pageRange: String? = nil
    ) async throws -> ProcessingResult {
        
        let startTime = Date()
        logger.info("Starting PDF processing: \(inputPath)")
        
        // Reset statistics
        processingStats.reset()
        
        do {
            // Step 1: Validate input file
            try validateInputFile(inputPath)
            
            // Step 2: Process the PDF document
            let pdfURL = URL(fileURLWithPath: inputPath)
            let outputURL = URL(fileURLWithPath: "\(config.output.outputDirectory)/temp_output.md")
            
            // Parse page range string to PageRange object
            let parsedPageRange: PageRange?
            if let pageRangeString = pageRange {
                do {
                    // Get document info to determine total pages for parsing
                    let documentInfo = try await documentProcessor.getDocumentInfo(at: inputPath)
                    parsedPageRange = try PageRange.parse(pageRangeString, totalPages: documentInfo.pageCount)
                } catch {
                    logger.warning("Failed to parse page range '\(pageRangeString)': \(error.localizedDescription). Processing all pages.")
                    parsedPageRange = nil
                }
            } else {
                parsedPageRange = nil
            }
            
            // Process the PDF - TraditionalOCRDocumentProcessor returns elements directly
            let elements = try await documentProcessor.processDocument(at: inputPath, pageRange: parsedPageRange)
            
            // Step 3: Generate all output types from the returned elements
            let allOutputs = try generateAllOutputTypes(from: elements)
            
            // Step 4: Write all output types
            let finalOutputPaths = try writeAllOutputs(
                outputs: allOutputs,
                inputPath: inputPath,
                outputPath: outputPath,
                elements: elements
            )
            
            // Step 6: Update statistics
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Use the first available output for language detection (prefer markdown)
            let languageDetectionText = allOutputs[mdkitFileManagement.OutputType.markdown] ?? allOutputs[mdkitFileManagement.OutputType.ocr] ?? allOutputs.values.first ?? ""
            let detectedLanguage = languageDetector.detectLanguage(from: languageDetectionText)
            
            // Get the primary output path (markdown if available, otherwise first available)
            let primaryOutputPath = finalOutputPaths[mdkitFileManagement.OutputType.markdown] ?? finalOutputPaths.values.first ?? "multiple outputs"
            
            processingStats.update(
                inputPath: inputPath,
                outputPath: primaryOutputPath,
                processingTime: processingTime,
                elementCount: elements.count, // Actual element count
                detectedLanguage: detectedLanguage
            )
            
            logger.info("PDF processing completed successfully in \(String(format: "%.2f", processingTime))s")
            logger.info("Generated \(finalOutputPaths.count) output types: \(finalOutputPaths.keys.map { $0.description }.joined(separator: ", "))")
            
            return ProcessingResult(
                success: true,
                inputPath: inputPath,
                outputPath: primaryOutputPath,
                processingTime: processingTime,
                elementCount: elements.count,
                statistics: processingStats
            )
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            logger.error("PDF processing failed: \(error.localizedDescription)")
            
            return ProcessingResult(
                success: false,
                inputPath: inputPath,
                outputPath: nil,
                processingTime: processingTime,
                elementCount: 0,
                error: error,
                statistics: processingStats
            )
        }
    }
    
    /// Process multiple PDF files in batch
    /// - Parameters:
    ///   - inputPaths: Array of input PDF file paths
    ///   - outputDirectory: Directory for output files
    ///   - options: Processing options
    /// - Returns: Array of processing results
    public func processPDFs(
        inputPaths: [String],
        outputDirectory: String? = nil,
        options: ProcessingOptions = ProcessingOptions()
    ) async throws -> [ProcessingResult] {
        
        logger.info("Starting batch processing of \(inputPaths.count) PDF files")
        
        var results: [ProcessingResult] = []
        let batchStartTime = Date()
        
        for (index, inputPath) in inputPaths.enumerated() {
            logger.info("Processing file \(index + 1) of \(inputPaths.count): \(inputPath)")
            
            let outputPath = outputDirectory.map { dir in
                let fileName = URL(fileURLWithPath: inputPath).lastPathComponent
                let baseName = fileName.replacingOccurrences(of: ".pdf", with: "")
                return "\(dir)/\(baseName).md"
            }
            
            let result = try await processPDF(
                inputPath: inputPath,
                outputPath: outputPath,
                options: options
            )
            
            results.append(result)
            
            // Log progress
            let progress = Double(index + 1) / Double(inputPaths.count) * 100
            logger.info("Batch progress: \(String(format: "%.1f", progress))%")
        }
        
        let totalTime = Date().timeIntervalSince(batchStartTime)
        logger.info("Batch processing completed in \(String(format: "%.2f", totalTime))s")
        
        return results
    }
    
    // MARK: - Private Helper Methods
    
    /// Validate the input file exists and is accessible
    private func validateInputFile(_ inputPath: String) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: inputPath) else {
            throw MainProcessorError.inputFileNotFound(path: inputPath)
        }
        
        guard fileManager.isReadableFile(atPath: inputPath) else {
            throw MainProcessorError.inputFileNotReadable(path: inputPath)
        }
        
        let fileExtension = URL(fileURLWithPath: inputPath).pathExtension.lowercased()
        guard fileExtension == "pdf" else {
            throw MainProcessorError.unsupportedFileType(extension: fileExtension)
        }
    }
    
    /// Generate markdown from document elements
    private func generateMarkdown(from elements: [DocumentElement]) throws -> String {
        logger.info("Generating markdown from \(elements.count) elements")
        
        // Detect document language for language-aware processing
        let documentText = elements.compactMap { $0.text }.joined(separator: " ")
        let detectedLanguage = languageDetector.detectLanguage(from: documentText)
        
        logger.info("Detected document language: \(detectedLanguage)")
        
        // Generate markdown using the markdown generator
        let markdown = try markdownGenerator.generateMarkdown(from: elements)
        
        // Add language metadata to the markdown
        let languageHeader = "\n\n---\n*Document Language: \(detectedLanguage)*\n---\n\n"
        
        return markdown + languageHeader
    }
    
    /// Generate all output types from document elements
    private func generateAllOutputTypes(from elements: [DocumentElement]) throws -> [OutputType: String] {
        guard !elements.isEmpty else {
            throw MainProcessorError.noElementsToProcess
        }
        
        logger.info("Generating all output types from \(elements.count) elements")
        
        var outputs: [OutputType: String] = [:]
        
        // Generate each output type
        for outputType in OutputType.allCases {
            do {
                let output = try outputGenerator.generateOutput(from: elements, outputType: outputType)
                outputs[outputType] = output
                logger.info("Generated \(outputType.description) output")
            } catch {
                logger.warning("Failed to generate \(outputType.description) output: \(error.localizedDescription)")
                // Continue with other output types instead of failing completely
            }
        }
        
        return outputs
    }
    
    /// Generate image output data from document elements
    private func generateImageOutput(from elements: [DocumentElement]) throws -> Data? {
        // Get the stored image data from the document processor
        // For now, we'll get the first available image data
        let allImageData = documentProcessor.getAllStoredImageData()
        
        if let firstImageData = allImageData.values.first {
            logger.info("Image output generation: found image data (\(firstImageData.count) bytes)")
            return firstImageData
        } else {
            logger.warning("Image output generation: no image data available")
            return nil
        }
    }
    

    
    /// Optimize markdown using LLM if enabled
    private func optimizeMarkdown(_ markdown: String, elements: [DocumentElement]) async throws -> String {
        guard config.llm.enabled && llmProcessor != nil else {
            logger.info("LLM optimization disabled or not available, returning original markdown")
            return markdown
        }
        
        logger.info("Optimizing markdown using LLM")
        
        do {
            // Convert elements to string representation for LLM processing
            let elementsString = elements.map { "\($0.type): \($0.text ?? "")" }.joined(separator: "\n")
            let optimized = try await llmProcessor!.optimizeMarkdown(markdown, documentContext: "Document", elements: elementsString)
            logger.info("LLM optimization completed successfully")
            return optimized
        } catch {
            logger.warning("LLM optimization failed, falling back to original markdown: \(error.localizedDescription)")
            return markdown
        }
    }
    
    /// Write all output types to files
    private func writeAllOutputs(
        outputs: [OutputType: String],
        inputPath: String,
        outputPath: String?,
        elements: [DocumentElement]
    ) throws -> [OutputType: String] {
        
        var outputPaths: [OutputType: String] = [:]
        
        for (outputType, content) in outputs {
            do {
                let outputPath = try writeOutput(
                    content: content,
                    inputPath: inputPath,
                    outputPath: outputPath,
                    outputType: outputType,
                    elements: elements
                )
                outputPaths[outputType] = outputPath
                logger.info("\(outputType.description) written to: \(outputPath)")
            } catch {
                logger.warning("Failed to write \(outputType.description) output: \(error.localizedDescription)")
                // Continue with other output types instead of failing completely
            }
        }
        
        return outputPaths
    }
    
    /// Write the output markdown to file
    private func writeOutput(
        markdown: String,
        inputPath: String,
        outputPath: String?
    ) throws -> String {
        
        let finalOutputPath: String
        
        if let outputPath = outputPath {
            finalOutputPath = outputPath
        } else {
            // Generate default output path
            let inputFileName = URL(fileURLWithPath: inputPath).lastPathComponent
            let baseName = inputFileName.replacingOccurrences(of: ".pdf", with: "")
            finalOutputPath = "\(config.output.outputDirectory)/\(baseName)\(config.output.filenamePattern)"
        }
        
        // Ensure output directory exists
        let outputURL = URL(fileURLWithPath: finalOutputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Write markdown to file
        try markdown.write(toFile: finalOutputPath, atomically: true, encoding: .utf8)
        
        logger.info("Output written to: \(finalOutputPath)")
        return finalOutputPath
    }
    
    /// Write output content to file with specific output type
    private func writeOutput(
        content: String,
        inputPath: String,
        outputPath: String?,
        outputType: OutputType,
        elements: [DocumentElement]
    ) throws -> String {
        
        let finalOutputPath: String
        
        // Always create the proper directory structure for specific output types
        let inputFileName = URL(fileURLWithPath: inputPath).lastPathComponent
        let baseName = inputFileName.replacingOccurrences(of: ".pdf", with: "")
        let timestamp = DateFormatter().string(from: Date())
        
        if let outputPath = outputPath {
            // If outputPath is provided, use it as the base directory but still create proper structure
            // Ensure outputPath is treated as a directory path
            let baseOutputDir = outputPath.hasSuffix("/") ? outputPath : "\(outputPath)/"
            finalOutputPath = "\(baseOutputDir)\(baseName)/\(outputType.directoryName)/\(baseName)_\(timestamp).\(outputType.fileExtension)"
        } else {
            // Generate default output path for specific output type
            finalOutputPath = "\(config.output.outputDirectory)/\(baseName)/\(outputType.directoryName)/\(baseName)_\(timestamp).\(outputType.fileExtension)"
        }
        
        // Ensure output directory exists
        let outputURL = URL(fileURLWithPath: finalOutputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Write content to file
        if outputType == .images {
            // For images, we need to write binary data, not text
            // Try to get the actual image data
            if let imageData = try generateImageOutput(from: elements) {
                try imageData.write(to: URL(fileURLWithPath: finalOutputPath))
                logger.info("Image data written as binary to: \(finalOutputPath)")
            } else {
                // Fallback to writing the text content
                try content.write(toFile: finalOutputPath, atomically: true, encoding: .utf8)
                logger.warning("No image data available, wrote placeholder text instead")
            }
        } else {
            // For text-based outputs, write as UTF-8
            try content.write(toFile: finalOutputPath, atomically: true, encoding: .utf8)
        }
        
        logger.info("\(outputType.description) written to: \(finalOutputPath)")
        return finalOutputPath
    }
    
    // MARK: - Utility Methods
    
    /// Get current processing statistics
    public func getStatistics() -> ProcessingStatistics {
        return processingStats
    }
    
    /// Reset processing statistics
    public func resetStatistics() {
        processingStats.reset()
    }
    
    /// Get configuration
    public func getConfiguration() -> MDKitConfig {
        return config
    }
    
    /// Detect language from text content
    /// - Parameter text: Text content to analyze
    /// - Returns: Detected language code
    public func detectLanguage(from text: String) -> String {
        return languageDetector.detectLanguage(from: text)
    }
    
    /// Detect language with confidence from text content
    /// - Parameter text: Text content to analyze
    /// - Returns: Tuple of (language, confidence)
    public func detectLanguageWithConfidence(from text: String) -> (language: String, confidence: Double) {
        return languageDetector.detectLanguageWithConfidence(from: text)
    }
    

}



// MARK: - Supporting Types

/// Processing options for the main processor
public struct ProcessingOptions {
    /// Whether to enable verbose logging
    public let verbose: Bool
    
    /// Whether to enable dry-run mode (process but don't write output)
    public let dryRun: Bool
    
    /// Maximum number of concurrent operations
    public let maxConcurrency: Int
    
    /// Custom output format
    public let outputFormat: OutputFormat
    
    public init(
        verbose: Bool = false,
        dryRun: Bool = false,
        maxConcurrency: Int = 1,
        outputFormat: OutputFormat = .markdown
    ) {
        self.verbose = verbose
        self.dryRun = dryRun
        self.maxConcurrency = maxConcurrency
        self.outputFormat = outputFormat
    }
}

/// Output format options
public enum OutputFormat {
    case markdown
    case html
    case plainText
    case json
}

/// Result of a processing operation
public struct ProcessingResult {
    /// Whether the processing was successful
    public let success: Bool
    
    /// Path to the input file
    public let inputPath: String
    
    /// Path to the output file (nil if failed)
    public let outputPath: String?
    
    /// Time taken for processing
    public let processingTime: TimeInterval
    
    /// Number of elements processed
    public let elementCount: Int
    
    /// Error that occurred (nil if successful)
    public let error: Error?
    
    /// Processing statistics
    public let statistics: ProcessingStatistics
    
    public init(
        success: Bool,
        inputPath: String,
        outputPath: String?,
        processingTime: TimeInterval,
        elementCount: Int,
        error: Error? = nil,
        statistics: ProcessingStatistics
    ) {
        self.success = success
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.processingTime = processingTime
        self.elementCount = elementCount
        self.error = error
        self.statistics = statistics
    }
}

/// Processing statistics
public class ProcessingStatistics {
    /// Total files processed
    public private(set) var totalFiles: Int = 0
    
    /// Successfully processed files
    public private(set) var successfulFiles: Int = 0
    
    /// Failed files
    public private(set) var failedFiles: Int = 0
    
    /// Total processing time
    public private(set) var totalProcessingTime: TimeInterval = 0
    
    /// Language distribution across processed documents
    public private(set) var languageDistribution: [String: Int] = [:]
    
    /// Average processing time per file
    public var averageProcessingTime: TimeInterval {
        return totalFiles > 0 ? totalProcessingTime / Double(totalFiles) : 0
    }
    
    /// Success rate as percentage
    public var successRate: Double {
        return totalFiles > 0 ? (Double(successfulFiles) / Double(totalFiles)) * 100 : 0
    }
    
    /// Reset all statistics
    public func reset() {
        totalFiles = 0
        successfulFiles = 0
        failedFiles = 0
        totalProcessingTime = 0
        languageDistribution.removeAll()
    }
    
        /// Update statistics with a new result
    public func update(
        inputPath: String,
        outputPath: String?,
        processingTime: TimeInterval,
        elementCount: Int,
        detectedLanguage: String
    ) {
        totalFiles += 1
        totalProcessingTime += processingTime

        if outputPath != nil {
            successfulFiles += 1
        } else {
            failedFiles += 1
        }
        
        // Track language distribution
        if let count = languageDistribution[detectedLanguage] {
            languageDistribution[detectedLanguage] = count + 1
        } else {
            languageDistribution[detectedLanguage] = 1
        }
    }
}

/// Errors specific to the main processor
public enum MainProcessorError: LocalizedError {
    case inputFileNotFound(path: String)
    case inputFileNotReadable(path: String)
    case unsupportedFileType(extension: String)
    case outputDirectoryCreationFailed(path: String)
    case markdownGenerationFailed
    case llmOptimizationFailed
    case noElementsToProcess
    
    public var errorDescription: String? {
        switch self {
        case .inputFileNotFound(let path):
            return "Input file not found: \(path)"
        case .inputFileNotReadable(let path):
            return "Input file is not readable: \(path)"
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext). Only PDF files are supported."
        case .outputDirectoryCreationFailed(let path):
            return "Failed to create output directory: \(path)"
        case .markdownGenerationFailed:
            return "Failed to generate markdown from document elements"
        case .llmOptimizationFailed:
            return "Failed to optimize markdown using LLM"
        case .noElementsToProcess:
            return "No document elements to process"
        }
    }
}
