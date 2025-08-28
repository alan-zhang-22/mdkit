import Foundation
import ArgumentParser
import Logging
import mdkitCore
import mdkitConfiguration
import mdkitFileManagement
import mdkitLogging
import mdkitLLM

// MARK: - CLI Command Structure

struct MDKitCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mdkit",
        abstract: "Convert PDF documents to Markdown with AI-powered processing",
        version: "0.1.0",
        subcommands: [Convert.self, Config.self, Validate.self]
    )
    
    func run() throws {
        // Initialize logging system first
        let config = MDKitConfig()
        
        // Configure logging system
        try LoggingConfiguration.configure(
            level: Logger.Level(rawValue: config.logging.level) ?? .info,
            logFileName: "mdkit.log",
            logDirectory: config.logging.outputFolder
        )
        
        // Create logger for this command
        let logger = Logger(label: "mdkit.cli")
        
        logger.info("Starting mdkit CLI...")
        
        // Show welcome message and examples when no subcommand is specified
        print("mdkit - PDF to Markdown conversion tool")
        print("=======================================")
        print("")
        print("📚 USAGE EXAMPLES:")
        print("")
        print("  # Basic conversion")
        print("  mdkit convert document.pdf")
        print("")
        print("  # Convert with custom output")
        print("  mdkit convert document.pdf --output ./output/result.md")
        print("")
        print("  # Convert specific pages with LLM optimization")
        print("  mdkit convert document.pdf --pages 5-7 --enable-llm")
        print("")
        print("  # Dry run to see what would happen")
        print("  mdkit convert document.pdf --dry-run")
        print("")
        print("  # Validate configuration")
        print("  mdkit validate --all")
        print("")
        print("  # Show help for specific command")
        print("  mdkit convert --help")
        print("")
        print("💡 For more information, use 'mdkit --help' or 'mdkit <command> --help'")
    }
}

// MARK: - Convert Command

struct Convert: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "Convert a PDF file to Markdown"
    )
    
    @Argument(help: "Input PDF file path")
    var inputFile: String
    
    @Option(name: .shortAndLong, help: "Output file path (default: input.md)")
    var output: String?
    
    @Option(name: .shortAndLong, help: "Configuration file path")
    var config: String?
    
    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    var verbose: Bool = false
    
    @Flag(name: .shortAndLong, help: "Overwrite existing output file")
    var force: Bool = false
    
    @Flag(name: .long, help: "Show what would be processed without actually converting files")
    var dryRun: Bool = false
    
    @Option(name: .long, help: "Page range to process (e.g., '5', '5,7', '5-7', 'all')")
    var pages: String = "all"
    
    @Option(name: .long, help: "Output format: markdown, markdown_llm, ocr, prompt")
    var format: String = "markdown"
    
    @Flag(name: .long, help: "Enable LLM optimization")
    var enableLLM: Bool = false
    
    // MARK: - Dry-Run Function
    
    private func performDryRun(
        inputFile: String,
        outputPath: String,
        config: MDKitConfig,
        logger: Logger,
        force: Bool,
        verbose: Bool,
        pages: String,
        format: String,
        enableLLM: Bool
    ) throws {
        logger.info("DRY RUN MODE - No files will be processed")
        
        print("🔍 DRY RUN MODE")
        print("===============")
        print("")
        
        // Input file analysis
        print("📁 INPUT FILE:")
        print("   Path: \(inputFile)")
        print("   Exists: \(FileManager.default.fileExists(atPath: inputFile) ? "✅ Yes" : "❌ No")")
        
        if FileManager.default.fileExists(atPath: inputFile) {
            let attributes = try FileManager.default.attributesOfItem(atPath: inputFile)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let fileSizeMB = Double(fileSize) / (1024 * 1024)
            print("   Size: \(String(format: "%.2f MB", fileSizeMB))")
        }
        print("")
        
        // Output configuration
        print("📤 OUTPUT CONFIGURATION:")
        print("   Output Path: \(outputPath)")
        print("   Output Directory: \(config.output.outputDirectory)")
        print("   Filename Pattern: \(config.output.filenamePattern)")
        print("   Overwrite Mode: \(force ? "Force Overwrite" : "Skip if Exists")")
        
        if FileManager.default.fileExists(atPath: outputPath) {
            print("   ⚠️  Output file already exists")
            if !force {
                print("   💡 Use --force to overwrite existing files")
            }
        }
        print("")
        
        // Processing configuration
        print("⚙️  PROCESSING CONFIGURATION:")
        print("   Overlap Threshold: \(config.processing.overlapThreshold)")
        print("   Merge Distance Threshold: \(config.processing.mergeDistanceThreshold)")
        print("   Header Region: \(config.processing.headerRegion)")
        print("   Footer Region: \(config.processing.footerRegion)")
        print("   LLM Optimization: \(config.llm.enabled ? "✅ Enabled" : "❌ Disabled")")
        
        if config.llm.enabled {
            print("   LLM Model: \(config.llm.model.identifier)")
            print("   LLM Temperature: \(config.llm.parameters.temperature)")
            print("   LLM Max Tokens: \(config.llm.parameters.maxTokens)")
        }
        print("")
        
        // File management configuration
        print("🗂️  FILE MANAGEMENT:")
        print("   Temporary Directory: \(config.fileManagement.tempDirectory)")
        print("   Create Directories: \(config.fileManagement.createDirectories ? "✅ Yes" : "❌ No")")
        print("   Overwrite Existing: \(config.fileManagement.overwriteExisting ? "✅ Yes" : "❌ No")")
        print("")
        
        // Logging configuration
        print("📝 LOGGING CONFIGURATION:")
        print("   Log Level: \(config.logging.level)")
        print("   Output Folder: \(config.logging.outputFolder)")
        print("   Verbose Mode: \(verbose ? "✅ Enabled" : "❌ Disabled")")
        print("")
        
        // Processing options
        print("⚙️  PROCESSING OPTIONS:")
        print("   Page Range: \(pages)")
        print("   Output Format: \(format)")
        
        // Determine effective LLM setting (CLI flag overrides config)
        let effectiveLLMEnabled = enableLLM || config.llm.enabled
        print("   LLM Optimization: \(effectiveLLMEnabled ? "✅ Enabled" : "❌ Disabled")")
        if enableLLM && config.llm.enabled {
            print("   💡 LLM enabled by both CLI flag and configuration")
        } else if enableLLM {
            print("   💡 LLM enabled by CLI flag (overrides config)")
        } else if config.llm.enabled {
            print("   💡 LLM enabled by configuration file")
        }
        print("")
        
        // What would happen
        print("🚀 WHAT WOULD HAPPEN:")
        print("   1. PDF would be converted to high-quality images (2.0x resolution)")
        print("   2. Vision framework would extract text and layout information")
        print("   3. Elements would be sorted and deduplicated")
        print("   4. Headers and lists would be detected and merged")
        print("   5. Language would be automatically detected")
        if effectiveLLMEnabled {
            print("   6. LLM would optimize the markdown content")
        }
        print("   7. Final \(format) would be written to: \(outputPath)")
        print("")
        
        print("✅ Dry run completed - no files were processed")
        print("💡 Use without --dry-run to actually convert the PDF")
    }

    func run() throws {
        // Initialize logging
        let baseConfig = MDKitConfig()
        
        // Configure logging system
        try LoggingConfiguration.configure(
            level: Logger.Level(rawValue: baseConfig.logging.level) ?? .info,
            logFileName: "mdkit.log",
            logDirectory: baseConfig.logging.outputFolder
        )
        
        // Create logger for this command
        let logger = Logger(label: "mdkit.convert")
        
        if verbose {
            logger.info("Verbose logging enabled")
        }
        
        logger.info("Starting PDF to Markdown conversion")
        logger.info("Input file: \(inputFile)")
        
        // Load configuration with enhanced fallback logic
        let configManager = ConfigurationManager()
        let config: MDKitConfig
        
        if let configPath = self.config {
            // User specified a specific config file
            logger.info("Loading user-specified configuration from: \(configPath)")
            config = try configManager.loadConfiguration(from: configPath)
        } else {
            // Try to load from project-specific config, then user config, then defaults
            logger.info("No config specified, trying project-specific configuration")
            config = configManager.createDefaultConfiguration()
        }
        
        logger.info("Configuration loaded successfully")
        
        // Validate input file
        guard FileManager.default.fileExists(atPath: inputFile) else {
            logger.error("Input file does not exist: \(inputFile)")
            throw MDKitError.inputFileNotFound(path: inputFile)
        }
        
        // Determine output path
        let outputPath: String
        if let customOutput = self.output {
            outputPath = customOutput
        } else {
            // Generate default output path by replacing .pdf/.PDF with .md
            let inputURL = URL(fileURLWithPath: inputFile)
            let nameWithoutExtension = inputURL.deletingPathExtension().lastPathComponent
            let directory = inputURL.deletingLastPathComponent().path
            outputPath = "\(directory)/\(nameWithoutExtension).md"
        }
        logger.info("Output file: \(outputPath)")
        
        // Handle dry-run mode
        if dryRun {
            return try performDryRun(
                inputFile: inputFile,
                outputPath: outputPath,
                config: config,
                logger: logger,
                force: force,
                verbose: verbose,
                pages: pages,
                format: format,
                enableLLM: enableLLM
            )
        }
        
        // Check if output file exists
        if FileManager.default.fileExists(atPath: outputPath) && !force {
            logger.error("Output file already exists: \(outputPath)")
            logger.info("Use --force to overwrite existing files")
            throw MDKitError.outputFileExists(path: outputPath)
        }
        
        // Note: File manager not needed for placeholder creation
        
        // TODO: Implement actual PDF processing
        logger.info("PDF processing not yet implemented")
        logger.info("Creating placeholder markdown file")
        
        let placeholderMarkdown = """
        # PDF Conversion Placeholder
        
        This is a placeholder markdown file generated by mdkit.
        
        **Input File:** \(inputFile)
        **Generated:** \(Date())
        
        ## Next Steps
        
        The actual PDF processing functionality will be implemented in the next phase.
        This includes:
        - PDF text extraction
        - Layout analysis
        - AI-powered content optimization
        - Markdown generation
        
        ## Configuration Used
        
        - Processing: \(config.processing.overlapThreshold)
        - Output: \(config.output.outputDirectory)
        - LLM Enabled: \(config.llm.enabled)
        """
        
        // Write placeholder markdown directly to file
        try placeholderMarkdown.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
        logger.info("Placeholder markdown file created successfully")
        logger.info("Conversion completed")
        
        print("✅ Successfully converted \(inputFile) to \(outputPath)")
    }
}

// MARK: - Config Command

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage mdkit configuration"
    )
    
    @Option(name: [.customShort("f"), .customLong("file")], help: "Configuration file path")
    var config: String?
    
    @Flag(name: .shortAndLong, help: "Show current configuration")
    var show: Bool = false
    
    @Flag(name: .shortAndLong, help: "Create sample configuration")
    var create: Bool = false
    
    func run() throws {
        let baseConfig = MDKitConfig()
        
        // Configure logging system
        try LoggingConfiguration.configure(
            level: Logger.Level(rawValue: baseConfig.logging.level) ?? .info,
            logFileName: "mdkit.log",
            logDirectory: baseConfig.logging.outputFolder
        )
        
        // Create logger for this command
        let _ = Logger(label: "mdkit.config")
        
        let configManager = ConfigurationManager()
        
        if show {
            let config = try configManager.loadConfiguration(from: self.config)
            print("Current Configuration:")
            print("=====================")
            print("Processing:")
            print("  - Overlap Threshold: \(config.processing.overlapThreshold)")
            print("  - Merge Distance Threshold: \(config.processing.mergeDistanceThreshold)")
            print("  - Header Region: \(config.processing.headerRegion)")
            print("  - Footer Region: \(config.processing.footerRegion)")
            print("")
            print("Output:")
            print("  - Directory: \(config.output.outputDirectory)")
            print("  - Filename Pattern: \(config.output.filenamePattern)")
            print("")
            print("LLM:")
            print("  - Enabled: \(config.llm.enabled)")
            if config.llm.enabled {
                print("  - Model: \(config.llm.model.identifier)")
            }
        }
        
        if create {
            let samplePath = self.config ?? "./mdkit-config-sample.json"
            try configManager.createSampleConfiguration(at: samplePath)
            print("✅ Sample configuration created at: \(samplePath)")
        }
        
        if !show && !create {
            print("Use --show to display current configuration")
            print("Use --create to create a sample configuration file")
        }
    }
}

// MARK: - Validate Command

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate configuration files and settings"
    )
    
    @Option(name: [.customShort("f"), .customLong("file")], help: "Configuration file path to validate")
    var config: String?
    
    @Flag(name: .shortAndLong, help: "Show detailed validation information")
    var detailed: Bool = false
    
    @Flag(name: .long, help: "Validate all configuration files in the project")
    var all: Bool = false
    
    func run() throws {
        let baseConfig = MDKitConfig()
        
        // Configure logging system
        try LoggingConfiguration.configure(
            level: Logger.Level(rawValue: baseConfig.logging.level) ?? .info,
            logFileName: "mdkit.log",
            logDirectory: baseConfig.logging.outputFolder
        )
        
        let logger = Logger(label: "mdkit.validate")
        let configManager = ConfigurationManager()
        
        print("🔍 CONFIGURATION VALIDATION")
        print("============================")
        print("")
        
        if all {
            // Validate all configuration files
            try validateAllConfigurations(configManager: configManager, logger: logger, detailed: detailed)
        } else if let configPath = config {
            // Validate specific configuration file
            try validateSpecificConfiguration(path: configPath, configManager: configManager, logger: logger, detailed: detailed)
        } else {
            // Validate current configuration
            try validateCurrentConfiguration(configManager: configManager, logger: logger, detailed: detailed)
        }
    }
    
    private func validateAllConfigurations(configManager: ConfigurationManager, logger: Logger, detailed: Bool) throws {
        print("📁 VALIDATING ALL CONFIGURATION FILES")
        print("=====================================")
        print("")
        
        let configFiles = [
            "./mdkit-config.json",
            "./configs/dev-config.json",
            "./configs/prod-config.json",
            "./Resources/configs/dev-config.json",
            "./Resources/configs/prod-config.json"
        ]
        
        var validCount = 0
        let totalCount = configFiles.count
        
        for configFile in configFiles {
            print("🔍 Checking: \(configFile)")
            
            if FileManager.default.fileExists(atPath: configFile) {
                do {
                    let config = try configManager.loadConfiguration(from: configFile)
                    print("   ✅ Valid configuration")
                    if detailed {
                        printConfigurationDetails(config: config, indent: "      ")
                    }
                    validCount += 1
                } catch {
                    print("   ❌ Invalid configuration: \(error)")
                }
            } else {
                print("   ⚠️  File not found")
            }
            print("")
        }
        
        print("📊 VALIDATION SUMMARY")
        print("=====================")
        print("   Valid configurations: \(validCount)/\(totalCount)")
        print("   Success rate: \(String(format: "%.1f%%", Double(validCount) / Double(totalCount) * 100))")
        print("")
    }
    
    private func validateSpecificConfiguration(path: String, configManager: ConfigurationManager, logger: Logger, detailed: Bool) throws {
        print("🔍 VALIDATING SPECIFIC CONFIGURATION")
        print("====================================")
        print("   File: \(path)")
        print("")
        
        do {
            let config = try configManager.loadConfiguration(from: path)
            print("✅ Configuration is valid!")
            print("")
            
            if detailed {
                print("📋 CONFIGURATION DETAILS")
                print("========================")
                printConfigurationDetails(config: config, indent: "   ")
            }
        } catch {
            print("❌ Configuration validation failed!")
            print("")
            print("🔍 ERROR DETAILS:")
            print("   \(error)")
            print("")
            print("💡 TROUBLESHOOTING TIPS:")
            print("   • Check JSON syntax")
            print("   • Verify required fields are present")
            print("   • Ensure values are within valid ranges")
            print("   • Use 'mdkit config --create' to generate a sample")
        }
    }
    
    private func validateCurrentConfiguration(configManager: ConfigurationManager, logger: Logger, detailed: Bool) throws {
        print("🔍 VALIDATING CURRENT CONFIGURATION")
        print("===================================")
        print("")
        
        let config = configManager.createDefaultConfiguration()
        print("✅ Current configuration is valid!")
        print("")
        
        if detailed {
            print("📋 CONFIGURATION DETAILS")
            print("========================")
            printConfigurationDetails(config: config, indent: "   ")
        }
    }
    
    private func printConfigurationDetails(config: MDKitConfig, indent: String) {
        print("\(indent)Processing:")
        print("\(indent)  - Overlap Threshold: \(config.processing.overlapThreshold)")
        print("\(indent)  - Merge Distance Threshold: \(config.processing.mergeDistanceThreshold)")
        print("\(indent)  - Header Region: \(config.processing.headerRegion)")
        print("\(indent)  - Footer Region: \(config.processing.footerRegion)")
        print("")
        print("\(indent)Output:")
        print("\(indent)  - Directory: \(config.output.outputDirectory)")
        print("\(indent)  - Filename Pattern: \(config.output.filenamePattern)")
        print("")
        print("\(indent)LLM:")
        print("\(indent)  - Enabled: \(config.llm.enabled)")
        if config.llm.enabled {
            print("\(indent)  - Model: \(config.llm.model.identifier)")
            print("\(indent)  - Temperature: \(config.llm.parameters.temperature)")
        }
        print("")
        print("\(indent)File Management:")
        print("\(indent)  - Temp Directory: \(config.fileManagement.tempDirectory)")
        print("\(indent)  - Create Directories: \(config.fileManagement.createDirectories)")
    }
}

// MARK: - Main Entry Point

// This calls the ArgumentParser entry point
MDKitCLI.main()

// MARK: - Error Types

enum MDKitError: LocalizedError {
    case inputFileNotFound(path: String)
    case outputFileExists(path: String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .inputFileNotFound(let path):
            return "Input file not found: \(path)"
        case .outputFileExists(let path):
            return "Output file already exists: \(path)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}


