//
//  FileManaging.swift
//  mdkit
//
// Created by alan zhang on 2025/8/25.
//

import Foundation

// MARK: - File Management Protocol

/// Protocol defining the interface for file management operations
public protocol FileManaging {
    /// Creates a directory at the specified path
    /// - Parameter path: The path where the directory should be created
    /// - Throws: An error if the directory creation fails
    func createDirectory(at path: String) throws
    
    /// Checks if a file exists at the specified path
    /// - Parameter path: The path to check
    /// - Returns: True if the file exists, false otherwise
    func fileExists(at path: String) -> Bool
    
    /// Writes data to a file at the specified path
    /// - Parameters:
    ///   - data: The data to write
    ///   - path: The path where the file should be written
    ///   - overwrite: Whether to overwrite existing files
    /// - Throws: An error if the write operation fails
    func writeFile(_ data: Data, to path: String, overwrite: Bool) throws
    
    /// Writes text to a file at the specified path
    /// - Parameters:
    ///   - text: The text to write
    ///   - path: The path where the file should be written
    ///   - overwrite: Whether to overwrite existing files
    /// - Throws: An error if the write operation fails
    func writeText(_ text: String, to path: String, overwrite: Bool) throws
    
    /// Reads data from a file at the specified path
    /// - Parameter path: The path to read from
    /// - Returns: The data read from the file
    /// - Throws: An error if the read operation fails
    func readFile(from path: String) throws -> Data
    
    /// Reads text from a file at the specified path
    /// - Parameter path: The path to read from
    /// - Returns: The text read from the file
    /// - Throws: An error if the read operation fails
    func readText(from path: String) throws -> String
    
    /// Deletes a file at the specified path
    /// - Parameter path: The path of the file to delete
    /// - Throws: An error if the deletion fails
    func deleteFile(at path: String) throws
    
    /// Generates a unique filename based on the original name
    /// - Parameter originalName: The original filename
    /// - Returns: A unique filename that doesn't conflict with existing files
    func generateUniqueFilename(from originalName: String) -> String
    
    /// Gets the size of a file in bytes
    /// - Parameter path: The path of the file
    /// - Returns: The file size in bytes, or nil if the file doesn't exist
    func getFileSize(at path: String) -> Int64?
}

// MARK: - File Management Errors

public enum FileManagementError: Error, LocalizedError {
    case fileNotFound
    case permissionDenied
    case diskFull
    case invalidPath
    case fileAlreadyExists
    case operationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found at the specified path"
        case .permissionDenied:
            return "Permission denied to access the file"
        case .diskFull:
            return "Disk is full, cannot write file"
        case .invalidPath:
            return "Invalid file path provided"
        case .fileAlreadyExists:
            return "File already exists at the specified path"
        case .operationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
}
