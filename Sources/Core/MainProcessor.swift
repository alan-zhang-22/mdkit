import Foundation
import Logging
import mdkitConfiguration
import mdkitFileManagement

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
    private let documentProcessor: UnifiedDocumentProcessor
    
    /// LLM processor for markdown optimization and structure analysis (optional)
    private let llmProcessor: LLMProcessing?
    
    /// Markdown generator for converting document elements to markdown
    private let markdownGenerator: MarkdownGenerator
    
    /// Logger instance
    private let logger: Logger
    
    /// Processing statistics
    private var processingStats: ProcessingStatistics
    
    // MARK: - Initialization
    
    /// Initialize the main processor with configuration
    /// - Parameter config: Configuration for the processor
    public init(config: MDKitConfig) throws {
        self.config = config
        self.logger = Logger(label: "mdkit.mainprocessor")
        self.processingStats = ProcessingStatistics()
        
        // Initialize file manager
        self.fileManager = MDKitFileManager(config: config.fileManagement)
        
        // Initialize document processor
        self.documentProcessor = UnifiedDocumentProcessor(config: config, fileManager: fileManager)
        
        // Initialize markdown generator
        self.markdownGenerator = MarkdownGenerator(config: config.markdownGeneration)
        
        // Initialize LLM processor if enabled
        if config.llm.enabled {
            // Note: LLM processor initialization would require additional dependencies
            // For now, we'll set it to nil and handle it gracefully
            self.llmProcessor = nil
            logger.warning("LLM processing requested but not available in Core module")
        } else {
            self.llmProcessor = nil
        }
        
        logger.info("MainProcessor initialized successfully")
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
        options: ProcessingOptions = ProcessingOptions()
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
            let processingResult = try await documentProcessor.processPDF(pdfURL, outputFileURL: outputURL)
            let documentElements = processingResult.elements
            
            // Step 3: Generate initial markdown
            let initialMarkdown = try generateMarkdown(from: documentElements)
            
            // Step 4: Optimize markdown using LLM if enabled
            let optimizedMarkdown = try await optimizeMarkdown(initialMarkdown, elements: documentElements)
            
            // Step 5: Write output
            let finalOutputPath = try writeOutput(
                markdown: optimizedMarkdown,
                inputPath: inputPath,
                outputPath: outputPath
            )
            
            // Step 6: Update statistics
            let processingTime = Date().timeIntervalSince(startTime)
            processingStats.update(
                inputPath: inputPath,
                outputPath: finalOutputPath,
                processingTime: processingTime,
                elementCount: documentElements.count
            )
            
            logger.info("PDF processing completed successfully in \(String(format: "%.2f", processingTime))s")
            
            return ProcessingResult(
                success: true,
                inputPath: inputPath,
                outputPath: finalOutputPath,
                processingTime: processingTime,
                elementCount: documentElements.count,
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
        
        return try markdownGenerator.generateMarkdown(from: elements)
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
    }
    
    /// Update statistics with a new result
    public func update(
        inputPath: String,
        outputPath: String?,
        processingTime: TimeInterval,
        elementCount: Int
    ) {
        totalFiles += 1
        totalProcessingTime += processingTime
        
        if outputPath != nil {
            successfulFiles += 1
        } else {
            failedFiles += 1
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
        }
    }
}
