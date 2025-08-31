import Foundation
import Logging
import mdkitConfiguration
import mdkitCore
import mdkitFileManagement

/// Central application context that manages all major components
/// This ensures consistency and prevents multiple instances from being created
/// Located in CLI module as it's the application entry point
public final class ApplicationContext: @unchecked Sendable {
    
    // MARK: - Singleton Instance
    
    public static let shared = ApplicationContext()
    
    private init() {
        self.logger = Logger(label: "mdkit.applicationcontext")
    }
    
    // MARK: - Core Components
    
    /// Logger instance
    private let logger: Logger
    
    /// Shared configuration manager instance
    public private(set) lazy var configurationManager: ConfigurationManager = {
        let manager = ConfigurationManager()
        return manager
    }()
    
    /// Shared configuration instance
    public private(set) var configuration: MDKitConfig?
    
    /// Shared main processor instance
    public private(set) var mainProcessor: MainProcessor?
    
    /// Shared language detector instance
    public private(set) var languageDetector: LanguageDetector?
    
    /// Shared markdown generator instance
    public private(set) var markdownGenerator: MarkdownGenerator?
    
    // MARK: - Initialization
    
    /// Initialize the application context with a configuration file
    /// - Parameter configPath: Path to the configuration file
    /// - Throws: Configuration errors
    public func initialize(configPath: String? = nil) throws {
        // Load configuration
        if let configPath = configPath {
            configuration = try configurationManager.loadConfiguration(from: configPath)
        } else {
            // Try to load default configuration
            configuration = try configurationManager.loadDefaultConfiguration()
        }
        
        // Initialize logging system
        if let config = configuration {
            try LoggingConfiguration.configure(from: config)
        }
        
        // Initialize core components
        try initializeCoreComponents()
    }
    
    /// Reload configuration from a different file
    /// - Parameter configPath: Path to the new configuration file
    /// - Throws: Configuration errors
    public func reloadConfiguration(from configPath: String) throws {
        // Load new configuration
        let newConfig = try configurationManager.loadConfiguration(from: configPath)
        
        // Update configuration
        configuration = newConfig
        
        // Reconfigure logging system
        try LoggingConfiguration.configure(from: newConfig)
        
        // Reinitialize core components with new configuration
        try initializeCoreComponents()
        
        logger.info("Configuration reloaded from: \(configPath)")
    }
    
    /// Initialize core components with the loaded configuration
    /// Follows the same initialization order as MainProcessor
    private func initializeCoreComponents() throws {
        guard let config = configuration else {
            throw ConfigurationError.configurationNotLoaded
        }
        
        // Step 1: Initialize file manager first (no dependencies)
        let fileManager = MDKitFileManager(config: config.fileManagement)
        
        // Step 2: Initialize markdown generator (no dependencies)
        self.markdownGenerator = MarkdownGenerator(config: config.markdownGeneration)
        
        // Step 3: Initialize output generator (no dependencies)
        let outputGenerator = OutputGenerator(config: config)
        
        // Step 4: Initialize language detector (no dependencies, but needs config)
        let minimumTextLength = config.processing.languageDetection?.minimumTextLength ?? 10
        let confidenceThreshold = config.processing.languageDetection?.confidenceThreshold ?? 0.6
        self.languageDetector = LanguageDetector(
            minimumTextLength: minimumTextLength,
            confidenceThreshold: confidenceThreshold
        )
        
        // Step 5: Initialize header and list detector (no dependencies, but needs config)
        let headerAndListDetector = HeaderAndListDetector(config: config)
        
        // Step 6: Initialize document processor (depends on markdownGenerator, languageDetector, and headerAndListDetector)
        guard let markdownGenerator = self.markdownGenerator,
              let languageDetector = self.languageDetector else {
            throw ConfigurationError.componentInitializationFailed
        }
        
        let documentProcessor = TraditionalOCRDocumentProcessor(
            configuration: config,
            markdownGenerator: markdownGenerator,
            languageDetector: languageDetector,
            headerAndListDetector: headerAndListDetector
        )
        
        // Step 7: Initialize main processor with all injected services
        self.mainProcessor = MainProcessor(
            config: config,
            documentProcessor: documentProcessor,
            languageDetector: languageDetector,
            markdownGenerator: markdownGenerator,
            fileManager: fileManager,
            outputGenerator: outputGenerator
        )
        
        logger.info("All core components initialized successfully")
    }
    
    /// Get the current configuration
    /// - Returns: The loaded configuration or nil if not initialized
    public func getConfiguration() -> MDKitConfig? {
        return configuration
    }
    
    /// Get the main processor instance
    /// - Returns: The initialized main processor or nil if not initialized
    public func getMainProcessor() -> MainProcessor? {
        return mainProcessor
    }
    
    /// Get the language detector instance
    /// - Returns: The initialized language detector or nil if not initialized
    public func getLanguageDetector() -> LanguageDetector? {
        return languageDetector
    }
    
    /// Get the markdown generator instance
    /// - Returns: The initialized markdown generator or nil if not initialized
    public func getMarkdownGenerator() -> MarkdownGenerator? {
        return markdownGenerator
    }
    
    /// Reset the application context (useful for testing)
    public func reset() {
        configuration = nil
        mainProcessor = nil
        languageDetector = nil
        markdownGenerator = nil
    }
}

// MARK: - Configuration Errors

public enum ConfigurationError: Error, LocalizedError {
    case configurationNotLoaded
    case componentInitializationFailed
    
    public var errorDescription: String? {
        switch self {
        case .configurationNotLoaded:
            return "Configuration not loaded. Call initialize() first."
        case .componentInitializationFailed:
            return "Failed to initialize core components."
        }
    }
}
