import Foundation

// MARK: - Configuration Validation Error

public enum ConfigurationValidationError: LocalizedError {
    case invalidOverlapThreshold(Double)
    case invalidHeaderRegion(ClosedRange<Double>)
    case invalidFooterRegion(ClosedRange<Double>)
    case invalidMaxMergeDistance(Double)
    case invalidOutputDirectory(String)
    case invalidFilenamePattern(String)
    case invalidLogLevel(String)
    case invalidMaxFileSize(Int)
    case invalidMaxFiles(Int)
    case invalidTemperature(Double)
    case invalidTopP(Double)
    case invalidMaxTokens(Int)
    case invalidHeaderLevelOffset(Int)
    case conflictingConfigurations([String])
    
    public var errorDescription: String? {
        switch self {
        case .invalidOverlapThreshold(let value):
            return "Overlap threshold must be between 0.0 and 1.0, got: \(value)"
        case .invalidHeaderRegion(let range):
            return "Header region must be between 0.0 and 1.0, got: \(range)"
        case .invalidFooterRegion(let range):
            return "Footer region must be between 0.0 and 1.0, got: \(range)"
        case .invalidMaxMergeDistance(let value):
            return "Max merge distance must be positive, got: \(value)"
        case .invalidOutputDirectory(let path):
            return "Invalid output directory path: \(path)"
        case .invalidFilenamePattern(let pattern):
            return "Invalid filename pattern: \(pattern)"
        case .invalidLogLevel(let level):
            return "Invalid log level: \(level). Must be one of: debug, info, warning, error, critical"
        case .invalidMaxFileSize(let size):
            return "Max file size must be positive, got: \(size)"
        case .invalidMaxFiles(let count):
            return "Max files must be positive, got: \(count)"
        case .invalidTemperature(let value):
            return "Temperature must be between 0.0 and 1.0, got: \(value)"
        case .invalidTopP(let value):
            return "Top-P must be between 0.0 and 1.0, got: \(value)"
        case .invalidMaxTokens(let value):
            return "Max tokens must be positive, got: \(value)"
        case .invalidHeaderLevelOffset(let value):
            return "Header level offset must be non-negative, got: \(value)"
        case .conflictingConfigurations(let conflicts):
            return "Configuration conflicts detected: \(conflicts.joined(separator: ", "))"
        }
    }
}

// MARK: - Configuration Validator

public struct ConfigurationValidator {
    
    // MARK: - Validation Methods
    
    /// Validates the entire configuration structure
    /// - Parameter config: The configuration to validate
    /// - Throws: ConfigurationValidationError if validation fails
    public func validate(_ config: MDKitConfig) throws {
        var errors: [String] = []
        
        // Validate processing configuration
        do {
            try validateProcessingConfig(config.processing)
        } catch {
            errors.append("Processing config: \(error.localizedDescription)")
        }
        
        // Validate output configuration
        do {
            try validateOutputConfig(config.output)
        } catch {
            errors.append("Output config: \(error.localizedDescription)")
        }
        
        // Validate LLM configuration
        do {
            try validateLLMConfig(config.llm)
        } catch {
            errors.append("LLM config: \(error.localizedDescription)")
        }
        
        // Validate logging configuration
        do {
            try validateLoggingConfig(config.logging)
        } catch {
            errors.append("Logging config: \(error.localizedDescription)")
        }
        
        // Validate cross-configuration constraints
        do {
            try validateCrossConfigurationConstraints(config)
        } catch {
            errors.append("Cross-config validation: \(error.localizedDescription)")
        }
        
        if !errors.isEmpty {
            throw ConfigurationValidationError.conflictingConfigurations(errors)
        }
    }
    
    // MARK: - Individual Configuration Validation
    
    private func validateProcessingConfig(_ config: ProcessingConfig) throws {
        // Validate overlap threshold
        if config.overlapThreshold < 0.0 || config.overlapThreshold > 1.0 {
            throw ConfigurationValidationError.invalidOverlapThreshold(config.overlapThreshold)
        }
        
        // Validate header region
        if config.headerRegion.lowerBound < 0.0 || config.headerRegion.upperBound > 1.0 {
            throw ConfigurationValidationError.invalidHeaderRegion(config.headerRegion)
        }
        
        // Validate footer region
        if config.footerRegion.lowerBound < 0.0 || config.footerRegion.upperBound > 1.0 {
            throw ConfigurationValidationError.invalidFooterRegion(config.footerRegion)
        }
        
        // Validate max merge distance
        if config.maxMergeDistance <= 0.0 {
            throw ConfigurationValidationError.invalidMaxMergeDistance(config.maxMergeDistance)
        }
        
        // Validate that header and footer regions don't overlap
        if config.headerRegion.overlaps(config.footerRegion) {
            throw ConfigurationValidationError.conflictingConfigurations([
                "Header region (\(config.headerRegion)) overlaps with footer region (\(config.footerRegion))"
            ])
        }
    }
    
    private func validateOutputConfig(_ config: OutputConfig) throws {
        // Validate output directory
        if config.outputDirectory.isEmpty {
            throw ConfigurationValidationError.invalidOutputDirectory(config.outputDirectory)
        }
        
        // Validate filename pattern
        if config.filenamePattern.isEmpty {
            throw ConfigurationValidationError.invalidFilenamePattern(config.filenamePattern)
        }
        
        // Validate that filename pattern contains at least one placeholder
        if !config.filenamePattern.contains("{") || !config.filenamePattern.contains("}") {
            throw ConfigurationValidationError.invalidFilenamePattern(
                "Filename pattern should contain placeholders like {filename}, {timestamp}, etc."
            )
        }
    }
    
    private func validateLLMConfig(_ config: LLMConfig) throws {
        // Only validate if LLM is enabled
        guard config.enabled else { return }
        
        // Validate model configuration
        try validateModelConfig(config.model)
        
        // Validate processing parameters
        try validateProcessingParameters(config.parameters)
        
        // Validate prompts
        try validatePromptConfig(config.prompts)
    }
    
    private func validateModelConfig(_ config: ModelConfig) throws {
        // Validate model identifier
        if config.identifier.isEmpty {
            throw ConfigurationValidationError.conflictingConfigurations([
                "Model identifier cannot be empty"
            ])
        }
        
        // Validate model path if provided
        if let modelPath = config.modelPath, !modelPath.isEmpty {
            // Check if file exists and is accessible
            let url = URL(fileURLWithPath: modelPath)
            if !FileManager.default.fileExists(atPath: url.path) {
                throw ConfigurationValidationError.conflictingConfigurations([
                    "Model file not found at path: \(modelPath)"
                ])
            }
        }
    }
    
    private func validateProcessingParameters(_ config: ProcessingParameters) throws {
        // Validate temperature
        if config.temperature < 0.0 || config.temperature > 1.0 {
            throw ConfigurationValidationError.invalidTemperature(config.temperature)
        }
        
        // Validate top-K
        if config.topK <= 0 {
            throw ConfigurationValidationError.conflictingConfigurations([
                "Top-K must be positive, got: \(config.topK)"
            ])
        }
        
        // Validate top-P
        if config.topP < 0.0 || config.topP > 1.0 {
            throw ConfigurationValidationError.invalidTopP(config.topP)
        }
        
        // Validate max tokens
        if config.maxTokens <= 0 {
            throw ConfigurationValidationError.invalidMaxTokens(config.maxTokens)
        }
    }
    
    private func validatePromptConfig(_ config: PromptConfig) throws {
        // Validate that prompts are not empty
        if config.systemPrompt.isEmpty {
            throw ConfigurationValidationError.conflictingConfigurations([
                "System prompt cannot be empty"
            ])
        }
        
        if config.optimizationPrompt.isEmpty {
            throw ConfigurationValidationError.conflictingConfigurations([
                "Optimization prompt cannot be empty"
            ])
        }
        
        if config.languagePrompt.isEmpty {
            throw ConfigurationValidationError.conflictingConfigurations([
                "Language prompt cannot be empty"
            ])
        }
    }
    
    private func validateLoggingConfig(_ config: LoggingConfig) throws {
        // Validate log level
        let validLevels = ["debug", "info", "warning", "error", "critical"]
        if !validLevels.contains(config.level.lowercased()) {
            throw ConfigurationValidationError.invalidLogLevel(config.level)
        }
        
        // Validate max file size
        if config.maxFileSize <= 0 {
            throw ConfigurationValidationError.invalidMaxFileSize(config.maxFileSize)
        }
        
        // Validate max files
        if config.maxFiles <= 0 {
            throw ConfigurationValidationError.invalidMaxFiles(config.maxFiles)
        }
        
        // Validate log directory
        if config.logDirectory.isEmpty {
            throw ConfigurationValidationError.invalidOutputDirectory(config.logDirectory)
        }
        
        // Validate log filename
        if config.logFileName.isEmpty {
            throw ConfigurationValidationError.invalidFilenamePattern(config.logFileName)
        }
    }
    
    private func validateCrossConfigurationConstraints(_ config: MDKitConfig) throws {
        var conflicts: [String] = []
        
        // Check if LLM optimization is enabled but LLM is disabled
        if config.processing.enableLLMOptimization && !config.llm.enabled {
            conflicts.append("LLM optimization is enabled but LLM processing is disabled")
        }
        
        // Check if file logging is enabled but log files are disabled
        if config.logging.enableFile && !config.output.createLogFiles {
            conflicts.append("File logging is enabled but log file creation is disabled")
        }
        
        // Check if output directory and log directory are the same
        if config.output.outputDirectory == config.logging.logDirectory {
            conflicts.append("Output directory and log directory should be different to avoid conflicts")
        }
        
        if !conflicts.isEmpty {
            throw ConfigurationValidationError.conflictingConfigurations(conflicts)
        }
    }
}

// MARK: - Convenience Extensions

extension ConfigurationValidator {
    
    /// Validates a configuration file at the given path
    /// - Parameter path: Path to the configuration file
    /// - Returns: The validated configuration
    /// - Throws: ConfigurationValidationError or file reading errors
    public func validateFile(at path: String) throws -> MDKitConfig {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(MDKitConfig.self, from: data)
        try validate(config)
        return config
    }
    
    /// Validates configuration data
    /// - Parameter data: Configuration data to validate
    /// - Returns: The validated configuration
    /// - Throws: ConfigurationValidationError or decoding errors
    public func validateData(_ data: Data) throws -> MDKitConfig {
        let config = try JSONDecoder().decode(MDKitConfig.self, from: data)
        try validate(config)
        return config
    }
    
    /// Creates a default configuration and validates it
    /// - Returns: A validated default configuration
    /// - Throws: ConfigurationValidationError if validation fails
    public func createDefaultValidatedConfig() throws -> MDKitConfig {
        let config = MDKitConfig()
        try validate(config)
        return config
    }
}
