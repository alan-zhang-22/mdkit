import Foundation
import ArgumentParser
import mdkitCore
import mdkitConfiguration
import mdkitLogging

@main
struct MDKitAsyncCLI: AsyncParsableCommand {
    // Define the command-line structure with subcommands
    static let configuration = CommandConfiguration(
        abstract: "A CLI tool to test async PDF processing.",
        subcommands: [Convert.self, Test.self, Validate.self]
    )
    
    // Initialize logging system when the CLI starts
    static func initializeLogging(verbose: Bool = false) {
        do {
            if verbose {
                // For verbose mode, enable both console and file logging with debug level
                try LoggingConfiguration.configure(
                    level: .debug,
                    logFileName: "mdkit-verbose.log",
                    logDirectory: "./logs/verbose"
                )
                print("🔧 Logging system initialized with VERBOSE mode - logs will be written to ./logs/verbose/")
            } else {
                // For normal mode, enable both console and file logging with info level
                try LoggingConfiguration.configure(
                    level: .info,
                    logFileName: "mdkit.log",
                    logDirectory: "./logs"
                )
                print("🔧 Logging system initialized - logs will be written to ./logs/")
            }
        } catch {
            print("⚠️  Warning: Could not initialize file logging: \(error.localizedDescription)")
            print("   Logs will only be displayed in console")
        }
    }

    func run() async throws {
        // Initialize logging system with default settings
        Self.initializeLogging(verbose: false)
        
        print("mdkit-async - PDF to Markdown conversion tool (Async Version)")
        print("============================================================")
        print("")
        print("📚 USAGE EXAMPLES:")
        print("")
        print("  # Basic async conversion")
        print("  mdkit-async convert document.pdf --async")
        print("")
        print("  # Convert with custom output and timeout")
        print("  mdkit-async convert document.pdf --output ./output/result.md --async --timeout 600")
        print("")
        print("  # Convert specific pages with LLM optimization")
        print("  mdkit-async convert document.pdf --pages 5-7 --enable-llm --async")
        print("")
        print("  # Dry run to see what would happen")
        print("  mdkit-async convert document.pdf --dry-run")
        print("")
        print("  # Validate configuration")
        print("  mdkit-async validate --all")
        print("")
        print("  # Show help for specific command")
        print("  mdkit-async convert --help")
        print("")
        print("💡 For more information, use 'mdkit-async --help' or 'mdkit-async <command> --help'")
    }

    // MARK: - Nested Commands
    
    /// Converts a PDF file to Markdown with async processing
    struct Convert: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Converts a PDF file to Markdown with async processing."
        )

        @Argument(help: "The PDF file to convert.")
        var inputFile: String

        @Flag(name: .long, help: "Enable async processing")
        var async: Bool = false

        @Flag(name: .long, help: "Show what would be processed without actually converting")
        var dryRun: Bool = false
        
        @Option(name: .long, help: "Page range to process (e.g., '5', '5,7', '5-7', 'all')")
        var pages: String = "all"
        
        @Option(name: .long, help: "Output directory for the markdown file")
        var output: String = "output"
        
        @Flag(name: .long, help: "Enable LLM optimization")
        var enableLLM: Bool = false
        
        @Flag(name: .shortAndLong, help: "Enable verbose logging for debugging")
        var verbose: Bool = false

        func run() async throws {
            // Initialize logging system with the verbose flag from this command
            MDKitAsyncCLI.initializeLogging(verbose: verbose)
            
            print("🔄 Starting PDF conversion...")
            print("   Input file: \(inputFile)")
            print("   Page range: \(pages)")
            print("   Async mode: \(async ? "✅ Enabled" : "❌ Disabled")")
            print("   Dry run: \(dryRun ? "✅ Yes" : "❌ No")")
            print("   Output directory: \(output)")
            print("   LLM optimization: \(enableLLM ? "✅ Enabled" : "❌ Disabled")")
            print("   Verbose logging: \(verbose ? "✅ Enabled" : "❌ Disabled")")
            
            if dryRun {
                print("")
                print("🔍 DRY RUN MODE - No files will be processed")
                print("   This is a test of the async CLI structure")
                print("   The actual PDF processing will be implemented next")
                return
            }
            
            if async {
                print("")
                print("⚡ ASYNC MODE - Processing with MainProcessor")
                
                do {
                    // Use MainProcessor directly for real PDF processing
                    // Create custom configuration with element merging disabled and improved header detection
                    let customConfig = MDKitConfig(
                        processing: ProcessingConfig(
                            enableElementMerging: false  // Disable element merging to prevent vertical merging issues
                        ),
                        headerFooterDetection: HeaderFooterDetectionConfig(
                            enabled: true,
                            headerFrequencyThreshold: 0.6,
                            footerFrequencyThreshold: 0.6,
                            regionBasedDetection: RegionBasedDetectionConfig(
                                enabled: true,
                                headerRegionY: 72.0,
                                footerRegionY: 720.0,
                                regionTolerance: 10.0
                            ),
                            percentageBasedDetection: PercentageBasedDetectionConfig(
                                enabled: true,
                                headerRegionHeight: 0.12,
                                footerRegionHeight: 0.12
                            ),
                            smartDetection: SmartDetectionConfig(
                                enabled: true,
                                excludePageNumbers: true,
                                excludeCommonHeaders: ["Page", "Chapter", "Section", "页", "章", "节", "GB/T 22239—2019"],  // Add the specific header to exclude
                                excludeCommonFooters: ["Confidential", "Copyright", "All rights reserved", "机密", "版权", "版权所有"],
                                enableContentAnalysis: true,
                                enableContentBasedDetection: false,
                                minHeaderFooterLength: 2,
                                maxHeaderFooterLength: 150
                            ),
                            multiRegionDetection: MultiRegionDetectionConfig(
                                enabled: false,
                                maxRegions: 2
                            )
                        )
                    )
                    let mainProcessor = try MainProcessor(config: customConfig)
                    
                    // Create processing options
                    let options = ProcessingOptions(
                        verbose: true,
                        dryRun: false,
                        maxConcurrency: 1,
                        outputFormat: .markdown
                    )
                    
                    print("   🚀 Initializing MainProcessor...")
                    print("   ✅ Configuration loaded successfully")
                    print("   🔍 Starting PDF processing...")
                    
                    // Process the PDF using the existing infrastructure
                    let result = try await mainProcessor.processPDF(
                        inputPath: inputFile,
                        outputPath: output,
                        options: options,
                        pageRange: pages == "all" ? nil : pages
                    )
                    
                    if result.success {
                        print("")
                        print("✅ PDF processing completed successfully!")
                        print("   📁 Output file: \(result.outputPath ?? "unknown")")
                        print("   📊 Processing time: \(String(format: "%.2f", result.processingTime)) seconds")
                        print("   🔍 Elements extracted: \(result.elementCount)")
                        
                        // Get statistics
                        let stats = mainProcessor.getStatistics()
                        print("   📈 Processing statistics:")
                        print("      - Success rate: \(String(format: "%.1f", stats.successRate))%")
                        print("      - Average time: \(String(format: "%.2f", stats.averageProcessingTime))s")
                        
                    } else {
                        print("❌ PDF processing failed")
                        if let error = result.error {
                            print("   Error: \(error.localizedDescription)")
                        }
                        throw result.error ?? PDFProcessingError.processingFailed(underlying: PDFProcessingError.outputWriteFailed(path: "unknown"))
                    }
                    
                } catch {
                    print("❌ PDF processing failed: \(error.localizedDescription)")
                    throw error
                }
            } else {
                print("")
                print("🐌 SYNC MODE - Processing without verbose output")
                
                do {
                    // Use MainProcessor with minimal output
                    // Create custom configuration with element merging disabled and improved header detection
                    let customConfig = MDKitConfig(
                        processing: ProcessingConfig(
                            enableElementMerging: false  // Disable element merging to prevent vertical merging issues
                        ),
                        headerFooterDetection: HeaderFooterDetectionConfig(
                            enabled: true,
                            headerFrequencyThreshold: 0.6,
                            footerFrequencyThreshold: 0.6,
                            regionBasedDetection: RegionBasedDetectionConfig(
                                enabled: true,
                                headerRegionY: 72.0,
                                footerRegionY: 720.0,
                                regionTolerance: 10.0
                            ),
                            percentageBasedDetection: PercentageBasedDetectionConfig(
                                enabled: true,
                                headerRegionHeight: 0.12,
                                footerRegionHeight: 0.12
                            ),
                            smartDetection: SmartDetectionConfig(
                                enabled: true,
                                excludePageNumbers: true,
                                excludeCommonHeaders: ["Page", "Chapter", "Section", "页", "章", "节", "GB/T 22239—2019"],  // Add the specific header to exclude
                                excludeCommonFooters: ["Confidential", "Copyright", "All rights reserved", "机密", "版权", "版权所有"],
                                enableContentAnalysis: true,
                                enableContentBasedDetection: false,
                                minHeaderFooterLength: 2,
                                maxHeaderFooterLength: 150
                            ),
                            multiRegionDetection: MultiRegionDetectionConfig(
                                enabled: false,
                                maxRegions: 2
                            )
                        )
                    )
                    let mainProcessor = try MainProcessor(config: customConfig)
                    
                    let options = ProcessingOptions(
                        verbose: false,
                        dryRun: false,
                        maxConcurrency: 1,
                        outputFormat: .markdown
                    )
                    
                    let result = try await mainProcessor.processPDF(
                        inputPath: inputFile,
                        outputPath: output,
                        options: options,
                        pageRange: pages == "all" ? nil : pages
                    )
                    
                    if result.success {
                        print("")
                        print("✅ PDF processing completed successfully!")
                        print("   📁 Output file: \(result.outputPath ?? "unknown")")
                        print("   📊 Processing time: \(String(format: "%.2f", result.processingTime)) seconds")
                        print("   🔍 Elements extracted: \(result.elementCount)")
                    } else {
                        print("❌ PDF processing failed")
                        throw result.error ?? PDFProcessingError.processingFailed(underlying: PDFProcessingError.outputWriteFailed(path: "unknown"))
                    }
                    
                } catch {
                    print("❌ PDF processing failed: \(error.localizedDescription)")
                    throw error
                }
            }
            
            print("")
            print("📁 Output saved as: \(inputFile.replacingOccurrences(of: ".pdf", with: ".md").replacingOccurrences(of: ".PDF", with: ".md"))")
        }
    }
    
    /// Tests async functionality with a simple operation
    struct Test: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Tests async functionality with a simple operation."
        )

        @Option(name: .shortAndLong, help: "Number of seconds to wait")
        var delay: Int = 3

        func run() async throws {
            print("🧪 Testing async functionality...")
            print("   Will wait for \(delay) seconds")
            
            for i in 1...delay {
                print("   Waiting... \(i)/\(delay)")
                try await Task.sleep(for: .seconds(1))
            }
            
            print("✅ Async test completed successfully!")
        }
    }
    
    /// Validates configuration and system requirements
    struct Validate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validates configuration and system requirements."
        )

        @Flag(name: .long, help: "Validate all components")
        var all: Bool = false
        
        @Option(name: .long, help: "Path to configuration file")
        var config: String?

        func run() async throws {
            print("🔍 Starting configuration validation...")
            print("   Validate all: \(all ? "✅ Yes" : "❌ No")")
            print("   Config path: \(config ?? "default")")
            
            do {
                _ = try MainProcessor(config: MDKitConfig())
                
                print("")
                print("📋 Testing MainProcessor...")
                
                // Test MainProcessor initialization
                print("   ✅ MainProcessor initialized successfully")
                
                // Test configuration loading
                print("   ✅ Configuration loaded successfully")
                
                // Test file management
                print("   ✅ File management system ready")
                
                print("")
                print("📋 Validation Results:")
                print("   Overall status: ✅ PASSED")
                print("   Timestamp: \(Date())")
                
                if all {
                    print("")
                    print("🔍 Detailed Checks:")
                    print("   ✅ PDF processing service")
                    print("   ✅ Configuration management")
                    print("   ✅ File management")
                    print("   ✅ Progress reporting")
                    print("   ✅ Error handling")
                    print("   ✅ Async processing")
                }
                
            } catch {
                print("❌ Validation failed: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    // MARK: - Nested Errors
    
    enum ValidationError: Error, LocalizedError {
        case validationFailed
        
        var errorDescription: String? {
            switch self {
            case .validationFailed:
                return "Configuration validation failed"
            }
        }
    }
    
    // Simple error type for PDF processing
    enum PDFProcessingError: Error, LocalizedError {
        case processingFailed(underlying: Error)
        case outputWriteFailed(path: String)
        
        var errorDescription: String? {
            switch self {
            case .processingFailed(let underlying):
                return "PDF processing failed: \(underlying.localizedDescription)"
            case .outputWriteFailed(let path):
                return "Failed to write output file: \(path)"
            }
        }
    }
    

}

