import Foundation
import Logging

/// Simple logging configuration utility for mdkit
public struct LoggingConfiguration {
    
    /// Get the documents directory for logging
    private static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    /// Configure the logging system with file and console output
    /// - Parameters:
    ///   - level: The minimum log level to output
    ///   - logFileName: The name of the log file
    ///   - logDirectory: The directory to store log files
    public static func configure(
        level: Logger.Level = .info,
        logFileName: String = "mdkit.log",
        logDirectory: String = "./logs"
    ) throws {
        // Create logs directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logDirectory) {
            try fileManager.createDirectory(atPath: logDirectory, withIntermediateDirectories: true)
        }
        
        // Configure file logging using standard library
        let logFileURL = getDocumentsDirectory().appendingPathComponent(logFileName)
        
        // Create a custom file handler that writes to both file and console
        let fileHandler = try FileLogHandler(logFileURL: logFileURL, level: level)
        let consoleHandler = StreamLogHandler.standardOutput(label: "mdkit.console")
        
        // Bootstrap the logging system with both file and console handlers
        LoggingSystem.bootstrap { label in
            let handlers: [LogHandler] = [
                fileHandler,
                consoleHandler
            ]
            
            var multiplexHandler = MultiplexLogHandler(handlers)
            multiplexHandler.logLevel = level
            return multiplexHandler
        }
        
        // Log that configuration is complete
        let logger = Logger(label: "mdkit.config")
        logger.info("Logging system configured successfully")
        logger.info("Log level: \(level)")
        logger.info("Log file: \(logFileURL.path)")
        logger.info("Console and file logging enabled")
    }
}

/// Custom file log handler using standard library
private struct FileLogHandler: LogHandler {
    private let logFileURL: URL
    private let level: Logger.Level
    private let fileHandle: FileHandle
    private let queue = DispatchQueue(label: "file-logging", qos: .utility)
    
    init(logFileURL: URL, level: Logger.Level) throws {
        self.logFileURL = logFileURL
        self.level = level
        
        // Create the file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
        }
        
        // Open file handle for writing
        self.fileHandle = try FileHandle(forWritingTo: logFileURL)
        self.fileHandle.seekToEndOfFile()
    }
    
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .info
    
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] [\(level)] [\(source)] \(message)\n"
        
        // Write to file asynchronously
        queue.async {
            if let data = logEntry.data(using: .utf8) {
                self.fileHandle.write(data)
            }
        }
    }
    
    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }
}
