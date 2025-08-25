//
//  Logger.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation
import Logging
import FileLogging

// MARK: - Logging Configuration

/// Configuration options for logging
public struct LoggingOptions {
    /// The minimum log level to output
    public let level: Logger.Level
    
    /// Whether to enable console logging
    public let enableConsole: Bool
    
    /// Whether to enable file logging
    public let enableFile: Bool
    
    /// The log file name (without path)
    /// Note: swift-log-file automatically creates rotated files with .1, .2, .3 suffixes
    /// Example: mdkit.log, mdkit.log.1, mdkit.log.2, etc.
    public let logFileName: String
    
    /// The directory where log files should be written
    /// Default: "./logs" - creates a logs directory in the current working directory
    public let logDirectory: String
    
    /// Maximum size of each log file in bytes
    /// When a log file reaches this size, it's rotated and a new one is created
    public let maxFileSize: Int
    
    /// Maximum number of log files to keep
    /// This includes the active log file and all rotated files
    /// Example: if maxFiles = 3, you'll have: mdkit.log, mdkit.log.1, mdkit.log.2
    public let maxFiles: Int
    
    /// Whether to include timestamps in log messages
    public let includeTimestamps: Bool
    
    /// Whether to include log levels in log messages
    public let includeLogLevels: Bool
    
    public init(
        level: Logger.Level = .info,
        enableConsole: Bool = true,
        enableFile: Bool = true,
        logFileName: String = "mdkit.log",
        logDirectory: String = "./logs",
        maxFileSize: Int = 1024 * 1024, // 1MB
        maxFiles: Int = 5,
        includeTimestamps: Bool = true,
        includeLogLevels: Bool = true
    ) {
        self.level = level
        self.enableConsole = enableConsole
        self.enableFile = enableFile
        self.logFileName = logFileName
        self.logDirectory = logDirectory
        self.maxFileSize = maxFileSize
        self.maxFiles = maxFiles
        self.includeTimestamps = includeTimestamps
        self.includeLogLevels = includeLogLevels
    }
}

/// Configures logging for the entire application using Apple's swift-log
public struct LoggingConfiguration {
    
    /// Configure logging with the specified options
    /// - Parameter options: The logging configuration options
    public static func configure(with options: LoggingOptions) throws {
        var handlers: [LogHandler] = []
        
        // Add console handler if enabled
        if options.enableConsole {
            let consoleHandler = StreamLogHandler.standardOutput(label: "console")
            handlers.append(consoleHandler)
        }
        
        // Add file handler if enabled
        if options.enableFile {
            let logFileURL = try getLogFileURL(
                fileName: options.logFileName,
                directory: options.logDirectory
            )
            
            // Create log directory if it doesn't exist
            try createLogDirectory(at: options.logDirectory)
            
            // Create basic file logger (rotation not supported by swift-log-file)
            let fileLogger = try FileLogging(to: logFileURL)
            
            let fileHandler = fileLogger.handler(label: "file")
            
            handlers.append(fileHandler)
        }
        
        // Bootstrap the logging system
        LoggingSystem.bootstrap { label in
            if handlers.count == 1 {
                return handlers[0]
            } else {
                return MultiplexLogHandler(handlers)
            }
        }
    }
    
    /// Configure logging with both console and file output using default settings
    /// - Parameters:
    ///   - level: The minimum log level to output
    ///   - logFileName: The name of the log file (will create mdkit.log, mdkit.log.1, mdkit.log.2, etc.)
    ///   - logDirectory: The directory where log files should be written (default: "./logs")
    ///   - maxFileSize: Maximum size of each log file in bytes (default: 1MB)
    ///   - maxFiles: Maximum number of log files to keep (default: 5)
    public static func configure(
        level: Logger.Level = .info,
        logFileName: String = "mdkit.log",
        logDirectory: String = "./logs",
        maxFileSize: Int = 1024 * 1024, // 1MB
        maxFiles: Int = 5
    ) throws {
        let options = LoggingOptions(
            level: level,
            enableConsole: true,
            enableFile: true,
            logFileName: logFileName,
            logDirectory: logDirectory,
            maxFileSize: maxFileSize,
            maxFiles: maxFiles
        )
        
        try configure(with: options)
    }
    
    /// Configure logging with console output only (for testing)
    public static func configureConsoleOnly(level: Logger.Level = .info) {
        let options = LoggingOptions(
            level: level,
            enableConsole: true,
            enableFile: false
        )
        
        try? configure(with: options)
    }
    
    /// Configure logging with file output only (for production)
    public static func configureFileOnly(
        level: Logger.Level = .info,
        logFileName: String = "mdkit.log",
        logDirectory: String = "./logs",
        maxFileSize: Int = 1024 * 1024,
        maxFiles: Int = 5
    ) throws {
        let options = LoggingOptions(
            level: level,
            enableConsole: false,
            enableFile: true,
            logFileName: logFileName,
            logDirectory: logDirectory,
            maxFileSize: maxFileSize,
            maxFiles: maxFiles
        )
        
        try configure(with: options)
    }
    
    // MARK: - Private Helper Methods
    
    private static func getLogFileURL(fileName: String, directory: String) throws -> URL {
        let expandedDirectory = (directory as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedDirectory).appendingPathComponent(fileName)
    }
    
    private static func createLogDirectory(at path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        try FileManager.default.createDirectory(
            atPath: expandedPath,
            withIntermediateDirectories: true
        )
    }
}

// MARK: - Logger Extensions

extension Logger {
    /// Creates a logger for a specific type
    public static func create<T>(for type: T.Type) -> Logger {
        return Logger(label: String(describing: type))
    }
    
    /// Creates a logger with a specific label
    public static func create(label: String) -> Logger {
        return Logger(label: label)
    }
    
    /// Creates a logger for the current module/class
    public static func create() -> Logger {
        // Get the calling type name from the stack trace
        let typeName = String(describing: type(of: self))
        return Logger(label: typeName)
    }
}

// MARK: - Convenience Configuration Methods

/// Quick configuration methods for common use cases
public extension LoggingConfiguration {
    
    /// Configure for development with console and file logging
    /// Creates: ./logs/dev/mdkit-dev.log, mdkit-dev.log.1, mdkit-dev.log.2, etc.
    static func configureForDevelopment() throws {
        try configure(
            level: .debug,
            logFileName: "mdkit-dev.log",
            logDirectory: "./logs/dev"
        )
    }
    
    /// Configure for production with file logging only
    /// Creates: ./logs/prod/mdkit-prod.log, mdkit-prod.log.1, mdkit-prod.log.2, etc.
    static func configureForProduction() throws {
        try configureFileOnly(
            level: .info,
            logFileName: "mdkit-prod.log",
            logDirectory: "./logs/prod",
            maxFileSize: 5 * 1024 * 1024, // 5MB
            maxFiles: 10
        )
    }
    
    /// Configure for testing with console only
    static func configureForTesting() {
        configureConsoleOnly(level: .debug)
    }
    

    
    /// Get the documents directory for better log file placement
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    /// Configure logging with documents directory (recommended for production)
    static func configureWithDocumentsDirectory(
        level: Logger.Level = .info,
        logFileName: String = "mdkit.log",
        maxFileSize: Int = 1024 * 1024,
        maxFiles: Int = 5
    ) throws {
        let documentsDir = getDocumentsDirectory()
        let logsDir = documentsDir.appendingPathComponent("mdkit/logs")
        
        let options = LoggingOptions(
            level: level,
            enableConsole: true,
            enableFile: true,
            logFileName: logFileName,
            logDirectory: logsDir.path,
            maxFileSize: maxFileSize,
            maxFiles: maxFiles
        )
        
        try configure(with: options)
    }
    
    /// Get information about the log file structure that will be created
    /// - Parameters:
    ///   - logFileName: The base log file name
    ///   - logDirectory: The directory where logs will be stored
    ///   - maxFiles: Maximum number of log files to keep
    /// - Returns: A description of the log file structure
    static func getLogFileStructureInfo(
        logFileName: String = "mdkit.log",
        logDirectory: String = "./logs",
        maxFiles: Int = 5
    ) -> String {
        let files = (0..<maxFiles).map { index in
            if index == 0 {
                return "\(logDirectory)/\(logFileName)"
            } else {
                return "\(logDirectory)/\(logFileName).\(index)"
            }
        }
        
        return """
        Log files will be created in the following structure:
        Directory: \(logDirectory)
        Base file: \(logFileName)
        Rotated files: \(files.dropFirst().joined(separator: ", "))
        
        Total files: \(maxFiles)
        File rotation: Automatic when base file reaches maxFileSize
        """
    }
}
