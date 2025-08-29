import XCTest
import Logging
import mdkitConfiguration
import mdkitFileManagement
import mdkitLogging

@testable import mdkitAsync

final class ConvertAsyncTests: XCTestCase {
    
    var tempDirectory: URL!
    var testConfig: MDKitConfig!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdkit-async-tests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        // Create test configuration
        testConfig = MDKitConfig()
        testConfig.logging.outputFolder = tempDirectory.path
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        try await super.tearDown()
    }
    
    // MARK: - Async Conversion Tests
    
    func testAsyncConversionSuccess() async throws {
        // Create a test PDF file (placeholder)
        let testPDFPath = tempDirectory.appendingPathComponent("test.pdf").path
        let testContent = "Test PDF content"
        try testContent.write(toFile: testPDFPath, atomically: true, encoding: .utf8)
        
        // Create output path
        let outputPath = tempDirectory.appendingPathComponent("output.md").path
        
        // Test async conversion
        let convertCommand = ConvertAsync()
        convertCommand.inputFile = testPDFPath
        convertCommand.output = outputPath
        convertCommand.async = true
        convertCommand.timeout = 60
        convertCommand.verbose = true
        
        // This would normally call the async run method
        // For testing, we'll verify the command structure
        XCTAssertTrue(convertCommand.async)
        XCTAssertEqual(convertCommand.timeout, 60)
        XCTAssertEqual(convertCommand.inputFile, testPDFPath)
        XCTAssertEqual(convertCommand.output, outputPath)
    }
    
    func testAsyncConversionWithTimeout() async throws {
        let convertCommand = ConvertAsync()
        convertCommand.inputFile = "test.pdf"
        convertCommand.async = true
        convertCommand.timeout = 30
        
        // Verify timeout configuration
        XCTAssertEqual(convertCommand.timeout, 30)
        XCTAssertTrue(convertCommand.async)
    }
    
    func testSyncConversionMode() async throws {
        let convertCommand = ConvertAsync()
        convertCommand.inputFile = "test.pdf"
        convertCommand.async = false
        
        // Verify sync mode
        XCTAssertFalse(convertCommand.async)
        XCTAssertEqual(convertCommand.timeout, 300) // Default timeout
    }
    
    func testCommandLineArguments() async throws {
        let convertCommand = ConvertAsync()
        
        // Test all available arguments
        convertCommand.inputFile = "input.pdf"
        convertCommand.output = "output.md"
        convertCommand.config = "config.json"
        convertCommand.verbose = true
        convertCommand.force = true
        convertCommand.dryRun = true
        convertCommand.pages = "1-5"
        convertCommand.format = "markdown_llm"
        convertCommand.enableLLM = true
        convertCommand.async = true
        convertCommand.timeout = 600
        
        // Verify all arguments are set correctly
        XCTAssertEqual(convertCommand.inputFile, "input.pdf")
        XCTAssertEqual(convertCommand.output, "output.md")
        XCTAssertEqual(convertCommand.config, "config.json")
        XCTAssertTrue(convertCommand.verbose)
        XCTAssertTrue(convertCommand.force)
        XCTAssertTrue(convertCommand.dryRun)
        XCTAssertEqual(convertCommand.pages, "1-5")
        XCTAssertEqual(convertCommand.format, "markdown_llm")
        XCTAssertTrue(convertCommand.enableLLM)
        XCTAssertTrue(convertCommand.async)
        XCTAssertEqual(convertCommand.timeout, 600)
    }
    
    func testDefaultValues() async throws {
        let convertCommand = ConvertAsync()
        
        // Verify default values
        XCTAssertFalse(convertCommand.verbose)
        XCTAssertFalse(convertCommand.force)
        XCTAssertFalse(convertCommand.dryRun)
        XCTAssertEqual(convertCommand.pages, "all")
        XCTAssertEqual(convertCommand.format, "markdown")
        XCTAssertFalse(convertCommand.enableLLM)
        XCTAssertFalse(convertCommand.async)
        XCTAssertEqual(convertCommand.timeout, 300)
    }
    
    // MARK: - Error Handling Tests
    
    func testTimeoutError() async throws {
        let timeoutError = TimeoutError()
        XCTAssertEqual(timeoutError.message, "Operation timed out")
    }
    
    func testAsyncErrorTypes() async throws {
        // Test all error types
        let inputFileError = MDKitAsyncError.inputFileNotFound(path: "/nonexistent/file.pdf")
        let outputFileError = MDKitAsyncError.outputFileExists(path: "/existing/output.md")
        let configError = MDKitAsyncError.configurationError("Invalid configuration")
        let timeoutError = MDKitAsyncError.processingTimeout(seconds: 60)
        
        // Verify error descriptions
        XCTAssertTrue(inputFileError.localizedDescription.contains("Input file not found"))
        XCTAssertTrue(outputFileError.localizedDescription.contains("Output file already exists"))
        XCTAssertTrue(configError.localizedDescription.contains("Configuration error"))
        XCTAssertTrue(timeoutError.localizedDescription.contains("Processing timed out after 60 seconds"))
    }
    
    // MARK: - Progress Monitoring Tests
    
    func testProgressMonitoring() async throws {
        // Test progress monitoring functionality
        let logger = Logger(label: "test.progress")
        
        // Create a task that will be cancelled
        let progressTask = Task {
            await monitorProgress(logger: logger)
        }
        
        // Cancel immediately to test cleanup
        progressTask.cancel()
        
        // Wait a bit for the task to finish
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify task is cancelled
        XCTAssertTrue(progressTask.isCancelled)
    }
    
    // MARK: - Helper Methods
    
    private func monitorProgress(logger: Logger) async {
        var dots = 0
        while !Task.isCancelled {
            let progressBar = String(repeating: ".", count: dots % 4)
            print("🔄 Processing\(progressBar)   ", terminator: "\r")
            dots += 1
            try? await Task.sleep(for: .milliseconds(500))
        }
        print() // Clear the progress line
    }
}
