import Foundation

/// Simple async service for testing async functionality
/// This provides various async methods to test different scenarios
@available(macOS 14.0, *)
public final class SimpleAsyncService: Sendable {
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Simple Async Test Methods
    
    /// Simple async method for testing basic async functionality
    public func simpleAsyncTest(delay: TimeInterval) async throws -> String {
        print("   🚀 Starting simple async test...")
        
        // Simulate async work
        try await Task.sleep(for: .seconds(delay))
        
        let result = "Async operation completed after \(delay) seconds"
        print("   ✅ \(result)")
        
        return result
    }
    
    /// Async method that processes data in chunks
    public func processDataInChunks(data: [String], chunkSize: Int = 2) async throws -> [String] {
        print("   🔄 Processing \(data.count) items in chunks of \(chunkSize)...")
        
        var results: [String] = []
        
        for (index, chunk) in data.chunked(into: chunkSize).enumerated() {
            print("   📦 Processing chunk \(index + 1)...")
            
            // Simulate async processing
            try await Task.sleep(for: .milliseconds(500))
            
            let processedChunk = chunk.map { "Processed: \($0)" }
            results.append(contentsOf: processedChunk)
            
            print("   ✅ Chunk \(index + 1) completed: \(chunk.count) items")
        }
        
        return results
    }
    
    /// Async method with error simulation
    public func asyncMethodWithErrors(shouldFail: Bool, delay: TimeInterval = 1.0) async throws -> String {
        print("   ⚠️  Testing async error handling...")
        
        // Simulate async work
        try await Task.sleep(for: .seconds(delay))
        
        if shouldFail {
            throw SimpleAsyncError.simulatedFailure
        }
        
        return "Successfully completed without errors"
    }
    
    /// Async method that demonstrates concurrent processing
    public func concurrentProcessing(items: [Int]) async throws -> [String] {
        print("   🚀 Starting concurrent processing of \(items.count) items...")
        
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for item in items {
                group.addTask {
                    // Simulate async work
                    try await Task.sleep(for: .milliseconds(100))
                    return "Processed item \(item)"
                }
            }
            
            var results: [String] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted()
        }
        
        print("   ✅ Concurrent processing completed: \(results.count) results")
        return results
    }
    
    /// Async method that simulates network requests
    public func simulateNetworkRequests(urls: [String]) async throws -> [NetworkResult] {
        print("   🌐 Simulating network requests for \(urls.count) URLs...")
        
        let results = try await withThrowingTaskGroup(of: NetworkResult.self) { group in
            for url in urls {
                group.addTask {
                    // Simulate network delay
                    let delay = Double.random(in: 0.1...2.0)
                    try await Task.sleep(for: .seconds(delay))
                    
                    // Simulate success/failure
                    let shouldSucceed = Bool.random()
                    if shouldSucceed {
                        return NetworkResult(url: url, status: 200, data: "Data for \(url)")
                    } else {
                        throw SimpleAsyncError.networkFailure(url: url)
                    }
                }
            }
            
            var results: [NetworkResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        print("   ✅ Network simulation completed: \(results.count) successful requests")
        return results
    }
    
    /// Async method that demonstrates progress reporting
    public func processWithProgress(totalSteps: Int) async throws -> [String] {
        print("   📊 Processing with progress reporting...")
        
        var results: [String] = []
        
        for step in 1...totalSteps {
            // Simulate work
            try await Task.sleep(for: .milliseconds(300))
            
            let progress = Double(step) / Double(totalSteps)
            let progressBar = createProgressBar(progress: progress)
            
            print("   \(progressBar) Step \(step)/\(totalSteps) (\(Int(progress * 100))%)")
            
            results.append("Completed step \(step)")
        }
        
        print("   ✅ Progress processing completed: \(results.count) steps")
        return results
    }
    
    // MARK: - Private Helper Methods
    
    private func createProgressBar(progress: Double) -> String {
        let width = 20
        let filled = Int(progress * Double(width))
        let empty = width - filled
        
        let filledBar = String(repeating: "█", count: filled)
        let emptyBar = String(repeating: "░", count: empty)
        
        return "[\(filledBar)\(emptyBar)]"
    }
}

// MARK: - Supporting Types

@available(macOS 14.0, *)
public struct NetworkResult: Sendable {
    public let url: String
    public let status: Int
    public let data: String
    
    public init(url: String, status: Int, data: String) {
        self.url = url
        self.status = status
        self.data = data
    }
}

@available(macOS 14.0, *)
public enum SimpleAsyncError: Error, LocalizedError, Sendable {
    case simulatedFailure
    case networkFailure(url: String)
    case timeout
    case invalidInput
    
    public var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            return "Simulated failure for testing purposes"
        case .networkFailure(let url):
            return "Network request failed for URL: \(url)"
        case .timeout:
            return "Operation timed out"
        case .invalidInput:
            return "Invalid input provided"
        }
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    /// Splits the array into chunks of the specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
