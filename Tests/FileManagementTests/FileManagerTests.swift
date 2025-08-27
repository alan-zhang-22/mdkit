//
//  FileManagerTests.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import XCTest
import Foundation
import Logging
import mdkitConfiguration
@testable import mdkitFileManagement

final class FileManagerTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var tempDirectory: String!
    private var mdkitFileManager: MDKitFileManager!
    private var testConfig: FileManagementConfig!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a temporary directory for testing
        tempDirectory = NSTemporaryDirectory().appending("mdkit-test-\(UUID().uuidString)")
        try Foundation.FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        
        // Create test configuration
        testConfig = FileManagementConfig(
            outputDirectory: "\(tempDirectory!)/output",
            markdownDirectory: "\(tempDirectory!)/markdown",
            logDirectory: "\(tempDirectory!)/logs",
            tempDirectory: "\(tempDirectory!)/temp",
            createDirectories: true,
            overwriteExisting: true,
            preserveOriginalNames: true,
            fileNamingStrategy: "timestamped"
        )
        
        // Create FileManager instance
        mdkitFileManager = MDKitFileManager(config: testConfig)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        try? Foundation.FileManager.default.removeItem(atPath: tempDirectory)
        try super.tearDownWithError()
    }
    
    // MARK: - OutputType Tests
    
    func testOutputTypeEnum() throws {
        // Test all output types exist
        XCTAssertEqual(OutputType.allCases.count, 4)
        
        // Test file extensions
        XCTAssertEqual(OutputType.ocr.fileExtension, "txt")
        XCTAssertEqual(OutputType.markdown.fileExtension, "md")
        XCTAssertEqual(OutputType.prompt.fileExtension, "txt")
        XCTAssertEqual(OutputType.markdownLLM.fileExtension, "md")
        
        // Test directory names
        XCTAssertEqual(OutputType.ocr.directoryName, "ocr")
        XCTAssertEqual(OutputType.markdown.directoryName, "markdown")
        XCTAssertEqual(OutputType.prompt.directoryName, "prompts")
        XCTAssertEqual(OutputType.markdownLLM.directoryName, "markdown-llm")
        
        // Test descriptions
        XCTAssertEqual(OutputType.ocr.description, "OCR Text Output")
        XCTAssertEqual(OutputType.markdown.description, "Markdown Output")
        XCTAssertEqual(OutputType.prompt.description, "LLM Prompts")
        XCTAssertEqual(OutputType.markdownLLM.description, "LLM-Optimized Markdown")
    }
    
    // MARK: - Constructor Tests
    
    func testFileManagerInitialization() throws {
        // Test that FileManager is created successfully
        XCTAssertNotNil(mdkitFileManager)
        
        // Test that directories are created during initialization
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: testConfig.outputDirectory))
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: testConfig.tempDirectory))
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: testConfig.markdownDirectory))
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: testConfig.logDirectory))
    }
    
    // MARK: - Path Generation Tests
    
    func testGenerateOutputPaths() throws {
        let inputFile = "test-document.pdf"
        let outputType = OutputType.markdown
        
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        
        // Test base directory
        XCTAssertEqual(paths.baseDirectory, testConfig.outputDirectory)
        
        // Test output files
        XCTAssertNotNil(paths.outputFiles[outputType])
        XCTAssertTrue(paths.outputFiles[outputType]!.contains("test-document"))
        XCTAssertTrue(paths.outputFiles[outputType]!.contains("markdown"))
        XCTAssertTrue(paths.outputFiles[outputType]!.hasSuffix(".md"))
        
        // Test temp directory
        XCTAssertTrue(paths.tempDirectory.contains("test-document_temp"))
        XCTAssertTrue(paths.tempDirectory.contains(testConfig.tempDirectory))
    }
    
    func testGenerateOutputPathsWithDifferentTypes() throws {
        let inputFile = "document.pdf"
        
        // Test markdown output
        let markdownPaths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: .markdown)
        XCTAssertNotNil(markdownPaths.outputFiles[.markdown])
        XCTAssertTrue(markdownPaths.outputFiles[.markdown]!.hasSuffix(".md"))
        
        // Test OCR output
        let ocrPaths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: .ocr)
        XCTAssertNotNil(ocrPaths.outputFiles[.ocr])
        XCTAssertTrue(ocrPaths.outputFiles[.ocr]!.hasSuffix(".txt"))
        
        // Test prompt output
        let promptPaths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: .prompt)
        XCTAssertNotNil(promptPaths.outputFiles[.prompt])
        XCTAssertTrue(promptPaths.outputFiles[.prompt]!.hasSuffix(".txt"))
    }
    
    // MARK: - File Naming Strategy Tests
    
    func testTimestampedFileNaming() throws {
        let config = FileManagementConfig(
            outputDirectory: tempDirectory,
            fileNamingStrategy: "timestamped"
        )
        let fileManager = MDKitFileManager(config: config)
        
        let inputFile = "document.pdf"
        let paths = fileManager.generateOutputPaths(for: inputFile, outputType: .markdown)
        
        let outputPath = paths.outputFiles[.markdown]!
        let fileName = (outputPath as NSString).lastPathComponent
        
        // Should contain timestamp pattern (YYYYMMDD_HHMMSS)
        XCTAssertTrue(fileName.contains("document_"))
        XCTAssertTrue(fileName.hasSuffix(".md"))
        
        // Extract timestamp part
        let components = fileName.components(separatedBy: "_")
        XCTAssertEqual(components.count, 3) // document, date, time.md
        XCTAssertEqual(components[0], "document")
        
        let datePart = components[1]
        let timeAndExt = components[2]
        XCTAssertTrue(timeAndExt.hasSuffix(".md"))
        
        let timePart = timeAndExt.replacingOccurrences(of: ".md", with: "")
        
        // The timestamp format is yyyyMMdd_HHmmss
        // Date part: yyyyMMdd (8 characters)
        // Time part: HHmmss (6 characters)
        XCTAssertEqual(datePart.count, 8) // yyyyMMdd format
        XCTAssertEqual(timePart.count, 6) // HHmmss format
    }
    
    func testOriginalFileNaming() throws {
        let config = FileManagementConfig(
            outputDirectory: tempDirectory,
            fileNamingStrategy: "original"
        )
        let fileManager = MDKitFileManager(config: config)
        
        let inputFile = "document.pdf"
        let paths = fileManager.generateOutputPaths(for: inputFile, outputType: .markdown)
        
        let outputPath = paths.outputFiles[.markdown]!
        let fileName = (outputPath as NSString).lastPathComponent
        
        XCTAssertEqual(fileName, "document.md")
    }
    
    // MARK: - Stream Lifecycle Tests
    
    func testOpenAndCloseOutputStream() throws {
        let inputFile = "test.pdf"
        let outputType = OutputType.markdown
        
        // Open output stream with append mode
        let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)
        XCTAssertNotNil(stream)
        
        // Write some content
        let testContent = "Test markdown content"
        try mdkitFileManager.writeString(testContent, to: stream)
        
        // Close stream
        try mdkitFileManager.closeOutputStream(stream)
        
        // Verify file was created and contains content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertEqual(savedContent, testContent)
    }
    
    func testMultipleOutputStreams() throws {
        let inputFile = "multi-test.pdf"
        
        // Open multiple streams for different output types
        let markdownStream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: .markdown, append: true)
        let ocrStream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: .ocr, append: true)
        
        // Write content to both streams
        let markdownContent = "# Test Header\n\nTest content"
        let ocrContent = "Raw OCR text content"
        
        try mdkitFileManager.writeString(markdownContent, to: markdownStream)
        try mdkitFileManager.writeString(ocrContent, to: ocrStream)
        
        // Close streams
        try mdkitFileManager.closeOutputStream(markdownStream)
        try mdkitFileManager.closeOutputStream(ocrStream)
        
        // Verify both files were created
        let markdownPaths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: .markdown)
        let ocrPaths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: .ocr)
        let markdownPath = markdownPaths.outputFiles[.markdown]!
        let ocrPath = ocrPaths.outputFiles[.ocr]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: markdownPath))
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: ocrPath))
        
        // Verify content
        let savedMarkdown = try String(contentsOfFile: markdownPath, encoding: .utf8)
        let savedOCR = try String(contentsOfFile: ocrPath, encoding: .utf8)
        
        XCTAssertEqual(savedMarkdown, markdownContent)
        XCTAssertEqual(savedOCR, ocrContent)
    }
    
    func testAppendingContent() throws {
        let inputFile = "append-test.pdf"
        let outputType = OutputType.markdown
        
        // Open output stream with append mode
        let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)
        
        // Write content in multiple calls to test appending within the same stream
        try mdkitFileManager.writeString("# Page 1\n\n", to: stream)
        try mdkitFileManager.writeString("This is the first page content.\n\n", to: stream)
        try mdkitFileManager.writeString("---\n\n", to: stream)
        try mdkitFileManager.writeString("# Page 2\n\n", to: stream)
        try mdkitFileManager.writeString("This is the second page content.\n\n", to: stream)
        
        // Close stream
        try mdkitFileManager.closeOutputStream(stream)
        
        // Verify file was created and contains all accumulated content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        let expectedContent = "# Page 1\n\nThis is the first page content.\n\n---\n\n# Page 2\n\nThis is the second page content.\n\n"
        
        XCTAssertEqual(savedContent, expectedContent)
    }
    
    func testMultipleWritesWithOverwrite() throws {
        let inputFile = "overwrite-multiple-test.pdf"
        let outputType = OutputType.markdown
        
        // Open output stream with overwrite mode (append: false)
        let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: false)
        
        // Write content in multiple calls to test multiple writes with overwrite
        try mdkitFileManager.writeString("# Page 1\n\n", to: stream)
        try mdkitFileManager.writeString("This is the first page content.\n\n", to: stream)
        try mdkitFileManager.writeString("---\n\n", to: stream)
        try mdkitFileManager.writeString("# Page 2\n\n", to: stream)
        try mdkitFileManager.writeString("This is the second page content.\n\n", to: stream)
        
        // Close stream
        try mdkitFileManager.closeOutputStream(stream)
        
        // Verify file was created and contains all accumulated content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        let expectedContent = "# Page 1\n\nThis is the first page content.\n\n---\n\n# Page 2\n\nThis is the second page content.\n\n"
        
        XCTAssertEqual(savedContent, expectedContent)
    }
    
    func testMinimalMultipleWrites() throws {
        let inputFile = "minimal-test.pdf"
        let outputType = OutputType.markdown
        
        // Open output stream
        let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: false)
        
        // Write just two simple strings
        try mdkitFileManager.writeString("A", to: stream)
        try mdkitFileManager.writeString("B", to: stream)
        
        // Close stream
        try mdkitFileManager.closeOutputStream(stream)
        
        // Check what was actually written
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        
        XCTAssertEqual(savedContent, "AB")
    }
    
    func testConcatenatedWriteString() throws {
        let inputFile = "concatenated-test.pdf"
        let outputType = OutputType.markdown
        
        // Open output stream with append mode
        let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)
        
        // Concatenate all content into one string and write it at once
        let allContent = "# Page 1\n\nThis is the first page content.\n\n---\n\n# Page 2\n\nThis is the second page content.\n\n"
        try mdkitFileManager.writeString(allContent, to: stream)
        
        // Close stream
        try mdkitFileManager.closeOutputStream(stream)
        
        // Verify file was created and contains all content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        let expectedContent = "# Page 1\n\nThis is the first page content.\n\n---\n\n# Page 2\n\nThis is the second page content.\n\n"
        
        XCTAssertEqual(savedContent, expectedContent)
    }
    
    func testSingleWriteString() throws {
        let inputFile = "single-write-test.pdf"
        let outputType = OutputType.markdown
        
        // Open output stream with append mode
        let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)
        
        // Write just one string
        try mdkitFileManager.writeString("# Single Page\n\nThis is a single page content.\n\n", to: stream)
        
        // Close stream
        try mdkitFileManager.closeOutputStream(stream)
        
        // Verify file was created and contains the content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        let expectedContent = "# Single Page\n\nThis is a single page content.\n\n"
        
        XCTAssertEqual(savedContent, expectedContent)
    }
    
    func testAppendingAcrossMultipleStreams() throws {
        let inputFile = "append-multi-test.pdf"
        let outputType = OutputType.markdown
        
        // First stream - create file with initial content
        let stream1 = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)
        try mdkitFileManager.writeString("# Page 1\n\nFirst page content.\n\n", to: stream1)
        try mdkitFileManager.closeOutputStream(stream1)
        
        // Second stream - append more content
        let stream2 = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)
        try mdkitFileManager.writeString("# Page 2\n\nSecond page content.\n\n", to: stream2)
        try mdkitFileManager.closeOutputStream(stream2)
        
        // Verify file contains both pieces of content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        let expectedContent = "# Page 1\n\nFirst page content.\n\n# Page 2\n\nSecond page content.\n\n"
        
        XCTAssertEqual(savedContent, expectedContent)
    }
    
    func testOverwriteContent() throws {
        let inputFile = "overwrite-test.pdf"
        let outputType = OutputType.markdown
        
        // Open output stream with overwrite mode (append: false)
        let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: false)
        
        // Write initial content
        try mdkitFileManager.writeString("Initial content", to: stream)
        try mdkitFileManager.closeOutputStream(stream)
        
        // Open another stream with overwrite mode - should overwrite the file
        let stream2 = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: false)
        try mdkitFileManager.writeString("Overwritten content", to: stream2)
        try mdkitFileManager.closeOutputStream(stream2)
        
        // Verify file was created and contains only the overwritten content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertEqual(savedContent, "Overwritten content")
    }
    
    func testAppendToFile() throws {
        let inputFile = "append-file-test.pdf"
        let outputType = OutputType.markdown
        
        // First append - create file with initial content
        try mdkitFileManager.appendToFile("# Page 1\n\nFirst page content.\n\n", for: inputFile, outputType: outputType)
        
        // Second append - add more content
        try mdkitFileManager.appendToFile("# Page 2\n\nSecond page content.\n\n", for: inputFile, outputType: outputType)
        
        // Third append - add final content
        try mdkitFileManager.appendToFile("# Page 3\n\nThird page content.\n\n", for: inputFile, outputType: outputType)
        
        // Verify file contains all pieces of content
        let paths = mdkitFileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: outputPath))
        
        let savedContent = try String(contentsOfFile: outputPath, encoding: .utf8)
        let expectedContent = "# Page 1\n\nFirst page content.\n\n# Page 2\n\nSecond page content.\n\n# Page 3\n\nThird page content.\n\n"
        
        XCTAssertEqual(savedContent, expectedContent)
    }
    
    // MARK: - Directory Management Tests
    
    func testEnsureDirectoriesExist() throws {
        // Create a new config with createDirectories: true
        let config = FileManagementConfig(
            outputDirectory: "\(tempDirectory!)/new-output",
            createDirectories: true
        )
        
        // Directories should not exist initially
        XCTAssertFalse(Foundation.FileManager.default.fileExists(atPath: config.outputDirectory))
        
        // Create FileManager - this will call setupDirectories() which calls ensureDirectoriesExist()
        _ = MDKitFileManager(config: config)
        
        // Directories should now exist after FileManager initialization
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: config.outputDirectory))
    }
    
    func testEnsureDirectoriesExistDisabled() throws {
        // Create a new config with createDirectories: false
        let config = FileManagementConfig(
            outputDirectory: "\(tempDirectory!)/disabled-output",
            createDirectories: false
        )
        let fileManager = MDKitFileManager(config: config)
        
        // Directories should not exist initially
        XCTAssertFalse(Foundation.FileManager.default.fileExists(atPath: config.outputDirectory))
        
        // Call ensureDirectoriesExist - should not create directories when disabled
        try fileManager.ensureDirectoriesExist()
        
        // Directories should still not exist
        XCTAssertFalse(Foundation.FileManager.default.fileExists(atPath: config.outputDirectory))
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupTempFiles() throws {
        // Create some temporary files
        let tempDir = testConfig.tempDirectory
        let tempFile1 = "\(tempDir)/temp1.txt"
        let tempFile2 = "\(tempDir)/temp2.txt"
        
        try "temp content 1".write(toFile: tempFile1, atomically: true, encoding: .utf8)
        try "temp content 2".write(toFile: tempFile2, atomically: true, encoding: .utf8)
        
        // Verify files exist
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: tempFile1))
        XCTAssertTrue(Foundation.FileManager.default.fileExists(atPath: tempFile2))
        
        // Clean up temp files
        try mdkitFileManager.cleanupTempFiles()
        
        // Verify files were removed
        XCTAssertFalse(Foundation.FileManager.default.fileExists(atPath: tempFile1))
        XCTAssertFalse(Foundation.FileManager.default.fileExists(atPath: tempFile2))
    }
    
    // MARK: - Error Handling Tests
    
    func testFileAlreadyExistsError() throws {
        let config = FileManagementConfig(
            outputDirectory: tempDirectory,
            overwriteExisting: false
        )
        let fileManager = MDKitFileManager(config: config)
        
        let inputFile = "existing.pdf"
        let outputType = OutputType.markdown
        
        // Create a file first
        let paths = fileManager.generateOutputPaths(for: inputFile, outputType: outputType)
        let outputPath = paths.outputFiles[outputType]!
        
        // Ensure the directory exists before trying to write the file
        let outputDir = (outputPath as NSString).deletingLastPathComponent
        try Foundation.FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        try "existing content".write(toFile: outputPath, atomically: true, encoding: .utf8)
        
        // Try to open output stream - should fail
        XCTAssertThrowsError(try fileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)) { error in
            if case FileManagerError.fileAlreadyExists = error {
                // Expected error
            } else {
                XCTFail("Expected FileManagerError.fileAlreadyExists, got: \(error)")
            }
        }
    }
    
    func testInvalidOutputPathError() throws {
        // This test would require mocking the path generation to return nil
        // For now, we'll test that the error type exists
        let error = FileManagerError.invalidOutputPath
        XCTAssertEqual(error.errorDescription, "Invalid output path generated")
    }
    
    // MARK: - Configuration Tests
    
    func testOutputTypeConfigs() throws {
        let configs = testConfig.outputTypeConfigs
        
        // All output types should have configs
        XCTAssertEqual(configs.count, OutputType.allCases.count)
        
        // Each config should have sensible defaults
        for (_, config) in configs {
            XCTAssertTrue(config.enabled)
            XCTAssertEqual(config.fileNamingStrategy, testConfig.fileNamingStrategy)
            XCTAssertEqual(config.overwriteExisting, testConfig.overwriteExisting)
        }
    }
    
    // MARK: - Performance Tests
    
    func testStreamPerformance() throws {
        let inputFile = "performance-test.pdf"
        let outputType = OutputType.markdown
        
        measure {
            do {
                let stream = try mdkitFileManager.openOutputStream(for: inputFile, outputType: outputType, append: true)
                try mdkitFileManager.closeOutputStream(stream)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}
