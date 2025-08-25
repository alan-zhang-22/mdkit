//
//  Logging.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation

// MARK: - Logging Protocol

/// Protocol defining the interface for logging operations
public protocol Logging {
    /// Logs a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The source file (defaults to caller's file)
    ///   - function: The source function (defaults to caller's function)
    ///   - line: The source line number (defaults to caller's line)
    func debug(_ message: String, file: String, function: String, line: Int)
    
    /// Logs an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The source file (defaults to caller's file)
    ///   - function: The source function (defaults to caller's function)
    ///   - line: The source line number (defaults to caller's line)
    func info(_ message: String, file: String, function: String, line: Int)
    
    /// Logs a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The source file (defaults to caller's file)
    ///   - function: The source function (defaults to caller's function)
    ///   - line: The source line number (defaults to caller's line)
    func warning(_ message: String, file: String, function: String, line: Int)
    
    /// Logs an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The source file (defaults to caller's file)
    ///   - function: The source function (defaults to caller's function)
    ///   - line: The source line number (defaults to caller's line)
    func error(_ message: String, file: String, function: String, line: Int)
    
    /// Logs a critical error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The source file (defaults to caller's file)
    ///   - function: The source function (defaults to caller's function)
    ///   - line: The source line number (defaults to caller's line)
    func critical(_ message: String, file: String, function: String, line: Int)
    
    /// Sets the minimum log level
    /// - Parameter level: The minimum level to log
    func setLogLevel(_ level: LogLevel)
    
    /// Gets the current log level
    /// - Returns: The current minimum log level
    func getLogLevel() -> LogLevel
}

// MARK: - Log Level

public enum LogLevel: Int, CaseIterable, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}

// MARK: - Logging Errors

public enum LoggingError: Error, LocalizedError {
    case invalidLogLevel
    case writeFailed(String)
    case configurationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidLogLevel:
            return "Invalid log level specified"
        case .writeFailed(let reason):
            return "Failed to write log: \(reason)"
        case .configurationError(let reason):
            return "Logging configuration error: \(reason)"
        }
    }
}
