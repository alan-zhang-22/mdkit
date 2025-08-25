//
//  MockLogger.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation

// MARK: - Mock Logger

/// Mock implementation of Logging for testing purposes
public class MockLogger: Logging {
    
    // MARK: - Properties
    
    /// The current log level
    public private(set) var currentLogLevel: LogLevel = .info
    
    /// All logged messages
    public private(set) var loggedMessages: [LogMessage] = []
    
    /// Whether to simulate errors
    public var shouldSimulateError: Bool = false
    
    /// The error to throw when simulating errors
    public var mockError: Error = LoggingError.configurationError("Mock error")
    
    /// Whether to enable console output for debugging tests
    public var enableConsoleOutput: Bool = false
    
    // MARK: - Log Message Structure
    
    public struct LogMessage {
        let level: LogLevel
        let message: String
        let file: String
        let function: String
        let line: Int
        let timestamp: Date
        
        init(level: LogLevel, message: String, file: String, function: String, line: Int) {
            self.level = level
            self.message = message
            self.file = file
            self.function = function
            self.line = line
            self.timestamp = Date()
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    public init(initialLogLevel: LogLevel) {
        self.currentLogLevel = initialLogLevel
    }
    
    // MARK: - Logging Implementation
    
    public func debug(_ message: String, file: String, function: String, line: Int) {
        log(.debug, message: message, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String, function: String, line: Int) {
        log(.info, message: message, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String, function: String, line: Int) {
        log(.warning, message: message, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, file: String, function: String, line: Int) {
        log(.error, message: message, file: file, function: function, line: line)
    }
    
    public func critical(_ message: String, file: String, function: String, line: Int) {
        log(.critical, message: message, file: file, function: function, line: line)
    }
    
    public func setLogLevel(_ level: LogLevel) {
        if shouldSimulateError {
            // Note: This method doesn't throw, so we'll just ignore the change
            return
        }
        
        currentLogLevel = level
    }
    
    public func getLogLevel() -> LogLevel {
        return currentLogLevel
    }
    
    // MARK: - Private Methods
    
    private func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        // Only log if the level meets the minimum threshold
        guard level >= currentLogLevel else { return }
        
        let logMessage = LogMessage(
            level: level,
            message: message,
            file: file,
            function: function,
            line: line
        )
        
        loggedMessages.append(logMessage)
        
        if enableConsoleOutput {
            let timestamp = DateFormatter.logFormatter.string(from: logMessage.timestamp)
            print("[\(timestamp)] [\(level.displayName)] \(message) (\(file):\(line) \(function))")
        }
    }
    
    // MARK: - Mock Configuration Methods
    
    /// Clears all logged messages
    public func clearLoggedMessages() {
        loggedMessages.removeAll()
    }
    
    /// Resets the mock to its initial state
    public func reset() {
        loggedMessages.removeAll()
        currentLogLevel = .info
        shouldSimulateError = false
        enableConsoleOutput = false
    }
    
    /// Gets all messages of a specific level
    public func getMessages(for level: LogLevel) -> [LogMessage] {
        return loggedMessages.filter { $0.level == level }
    }
    
    /// Gets all messages containing a specific text
    public func getMessages(containing text: String) -> [LogMessage] {
        return loggedMessages.filter { $0.message.contains(text) }
    }
    
    /// Gets the count of messages for a specific level
    public func messageCount(for level: LogLevel) -> Int {
        return getMessages(for: level).count
    }
    
    /// Gets the total count of logged messages
    public func totalMessageCount() -> Int {
        return loggedMessages.count
    }
    
    /// Verifies that a specific message was logged
    public func loggedMessage(_ message: String, at level: LogLevel) -> Bool {
        return loggedMessages.contains { $0.message == message && $0.level == level }
    }
    
    /// Gets the last logged message
    public func getLastMessage() -> LogMessage? {
        return loggedMessages.last
    }
    
    /// Gets the last message of a specific level
    public func getLastMessage(for level: LogLevel) -> LogMessage? {
        return getMessages(for: level).last
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
