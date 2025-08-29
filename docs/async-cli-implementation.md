# Asynchronous Command-Line Implementation for mdkit

## Overview

This document outlines the implementation of asynchronous command-line functionality for the mdkit project. The async CLI provides enhanced user experience with progress monitoring, timeout handling, and non-blocking operations.

## Current Implementation Status

### ✅ Completed
- **Async CLI Structure**: Complete async command-line interface
- **Progress Monitoring**: Real-time progress updates with visual indicators
- **Timeout Handling**: Configurable timeout for long-running operations
- **Error Handling**: Comprehensive error types and graceful failure handling
- **Task Management**: Proper task creation, cancellation, and cleanup

### 🔄 In Progress
- **Integration with Core**: Connecting async CLI to existing async processing pipeline
- **Testing**: Unit and integration tests for async functionality

### 📋 Planned
- **Concurrent Processing**: Multiple file processing simultaneously
- **Interactive Features**: User input during processing
- **Advanced Progress**: Detailed progress bars and ETA calculations

## Architecture

### 1. Async CLI Structure

```swift
struct MDKitAsyncCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mdkit-async",
        abstract: "Convert PDF documents to Markdown with AI-powered processing (Async Version)",
        version: "0.1.0",
        subcommands: [ConvertAsync.self, Config.self, Validate.self]
    )
}
```

### 2. Async Convert Command

```swift
struct ConvertAsync: ParsableCommand {
    // Async processing flags
    @Flag(name: .long, help: "Enable async processing with progress updates")
    var async: Bool = false
    
    @Option(name: .long, help: "Timeout in seconds for async operations (default: 300)")
    var timeout: Int = 300
    
    // Async run method
    func run() async throws {
        // Async implementation
    }
}
```

### 3. Processing Modes

#### Async Mode (`--async`)
- **Progress Monitoring**: Real-time progress updates
- **Timeout Protection**: Configurable timeout with graceful cancellation
- **Task Management**: Proper task lifecycle management
- **Non-blocking**: User can interrupt with Ctrl+C

#### Sync Mode (default)
- **Traditional Processing**: Standard synchronous operation
- **Simple Output**: Basic progress information
- **No Timeout**: Runs until completion or error

## Key Features

### 1. Progress Monitoring

```swift
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
```

**Features:**
- Visual progress indicator with animated dots
- Non-blocking progress updates
- Proper cleanup when cancelled
- Customizable update frequency

### 2. Timeout Handling

```swift
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

**Features:**
- Configurable timeout duration
- Graceful cancellation of operations
- Resource cleanup on timeout
- Custom timeout error types

### 3. Task Management

```swift
// Create a task with timeout
let conversionTask = Task {
    try await performActualConversion(...)
}

// Create progress monitoring task
let progressTask = Task {
    await monitorProgress(logger: logger)
}

// Wait for completion with timeout
do {
    let result = try await withTimeout(seconds: TimeInterval(timeout)) {
        try await conversionTask.value
    }
    
    // Cancel progress monitoring
    progressTask.cancel()
    
} catch is TimeoutError {
    // Handle timeout
    conversionTask.cancel()
    progressTask.cancel()
    throw MDKitAsyncError.processingTimeout(seconds: timeout)
}
```

**Features:**
- Separate tasks for conversion and progress monitoring
- Proper task cancellation on completion or error
- Resource cleanup and memory management
- Error propagation and handling

## Usage Examples

### Basic Async Conversion

```bash
# Enable async processing with default timeout (300s)
mdkit-async convert document.pdf --async

# Custom timeout (10 minutes)
mdkit-async convert document.pdf --async --timeout 600

# Verbose output with async processing
mdkit-async convert document.pdf --async --verbose
```

### Advanced Async Processing

```bash
# Async conversion with LLM optimization
mdkit-async convert document.pdf --async --enable-llm --timeout 900

# Async conversion with custom output and configuration
mdkit-async convert document.pdf \
    --async \
    --output ./output/result.md \
    --config ./custom-config.json \
    --timeout 600

# Async conversion with specific pages
mdkit-async convert document.pdf --async --pages 1-5 --timeout 300
```

### Configuration Management

```bash
# Show current configuration
mdkit-async config --show

# Create sample configuration
mdkit-async config --create

# Validate all configurations
mdkit-async validate --all
```

## Error Handling

### Error Types

```swift
enum MDKitAsyncError: LocalizedError {
    case inputFileNotFound(path: String)
    case outputFileExists(path: String)
    case configurationError(String)
    case processingTimeout(seconds: Int)
}
```

### Timeout Error

```swift
struct TimeoutError: Error {
    let message = "Operation timed out"
}
```

### Error Recovery

- **Input File Not Found**: Clear error message with file path
- **Output File Exists**: Suggestion to use `--force` flag
- **Configuration Error**: Detailed error with troubleshooting tips
- **Processing Timeout**: Graceful cancellation with timeout information

## Performance Benefits

### 1. Non-blocking Operations
- **User Experience**: Terminal remains responsive during processing
- **Interruption**: Users can cancel operations with Ctrl+C
- **Progress Visibility**: Real-time feedback on operation status

### 2. Resource Management
- **Memory Efficiency**: Proper cleanup of resources
- **Task Isolation**: Separate tasks for different operations
- **Cancellation Support**: Graceful shutdown of operations

### 3. Scalability
- **Concurrent Processing**: Foundation for multi-file processing
- **Timeout Protection**: Prevents hanging operations
- **Error Isolation**: Failures in one operation don't affect others

## Integration with Existing Code

### 1. Core Processing Pipeline

The async CLI integrates with the existing async processing pipeline:

```swift
// Existing async methods in MainProcessor
public func processPDF(
    inputPath: String,
    outputPath: String? = nil,
    options: ProcessingOptions = ProcessingOptions()
) async throws -> ProcessingResult

// Existing async methods in UnifiedDocumentProcessor
public func processDocument(
    _ imageData: Data, 
    outputStream: OutputStream, 
    pageNumber: Int = 1,
    previousPageContext: [DocumentElement] = []
) async throws -> DocumentProcessingResult
```

### 2. LLM Processing

Async CLI supports the existing async LLM operations:

```swift
// Existing async LLM methods
public func optimizeMarkdown(_ markdown: String, documentContext: String, elements: String, detectedLanguage: String) async throws -> String
public func analyzeDocumentStructure(_ elements: String, detectedLanguage: String) async throws -> String
```

## Testing Strategy

### 1. Unit Tests

```swift
class ConvertAsyncTests: XCTestCase {
    func testAsyncConversionSuccess() async throws {
        // Test successful async conversion
    }
    
    func testAsyncConversionTimeout() async throws {
        // Test timeout handling
    }
    
    func testProgressMonitoring() async throws {
        // Test progress monitoring functionality
    }
}
```

### 2. Integration Tests

```swift
class AsyncCLIIntegrationTests: XCTestCase {
    func testEndToEndAsyncConversion() async throws {
        // Test complete async conversion workflow
    }
    
    func testAsyncConversionWithLLM() async throws {
        // Test async conversion with LLM optimization
    }
}
```

## Future Enhancements

### 1. Concurrent Processing

```swift
// Process multiple files simultaneously
public func processMultiplePDFs(
    inputPaths: [String],
    outputDirectory: String? = nil,
    options: ProcessingOptions = ProcessingOptions(),
    maxConcurrency: Int = 4
) async throws -> [ProcessingResult]
```

### 2. Advanced Progress Indicators

```swift
// Detailed progress with ETA
struct ProgressInfo {
    let currentFile: String
    let filesProcessed: Int
    let totalFiles: Int
    let estimatedTimeRemaining: TimeInterval
    let currentFileProgress: Double
}
```

### 3. Interactive Features

```swift
// User input during processing
public func processWithUserInput(
    inputPath: String,
    outputPath: String,
    interactive: Bool = false
) async throws -> ProcessingResult
```

## Configuration

### Async-Specific Settings

```json
{
  "async": {
    "defaultTimeout": 300,
    "progressUpdateInterval": 500,
    "maxConcurrentOperations": 4,
    "enableProgressMonitoring": true
  }
}
```

### Environment Variables

```bash
# Set default timeout
export MDKIT_ASYNC_TIMEOUT=600

# Enable async by default
export MDKIT_ASYNC_ENABLED=true

# Set progress update interval (milliseconds)
export MDKIT_PROGRESS_INTERVAL=250
```

## Troubleshooting

### Common Issues

1. **Timeout Errors**
   - Increase timeout value with `--timeout` flag
   - Check system resources and file sizes
   - Verify LLM model availability

2. **Progress Not Showing**
   - Ensure `--async` flag is used
   - Check terminal support for carriage return
   - Verify logging configuration

3. **Task Cancellation Issues**
   - Use Ctrl+C to interrupt operations
   - Check for proper cleanup in error handlers
   - Verify task group management

### Debug Mode

```bash
# Enable verbose logging
mdkit-async convert document.pdf --async --verbose

# Check log files
tail -f mdkit-async.log
```

## Conclusion

The asynchronous command-line implementation for mdkit provides significant improvements in user experience, resource management, and scalability. By leveraging Swift's modern concurrency features, the async CLI offers:

- **Better User Experience**: Non-blocking operations with progress feedback
- **Improved Reliability**: Timeout protection and graceful error handling
- **Enhanced Scalability**: Foundation for concurrent processing
- **Resource Efficiency**: Proper task lifecycle management

The implementation maintains compatibility with existing synchronous operations while providing a path forward for more advanced features like concurrent processing and interactive user input.
