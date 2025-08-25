//
//  test_integration.swift
//  mdkit
//
//  Integration test file for testing MDKit library modules in Xcode
//  Copy this to your main Xcode target to test the libraries
//

import Foundation

// MARK: - Integration Test Functions

/// Test configuration loading functionality
public func testConfigurationLoading() {
    print("🧪 Testing Configuration Loading...")
    
    // Test loading dev config
    if let devConfigPath = Bundle.main.path(forResource: "dev-config", ofType: "json", inDirectory: "Resources/configs") {
        print("✅ Dev config found at: \(devConfigPath)")
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: devConfigPath))
            let config = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let llm = config?["llm"] as? [String: Any],
               let prompts = llm["promptTemplates"] as? [String: Any],
               let languages = prompts["languages"] as? [String: Any] {
                print("🌏 Supported languages: \(languages.keys.joined(separator: ", "))")
                
                // Test Chinese language support
                if let chinesePrompts = languages["zh"] as? [String: Any] {
                    print("🇨🇳 Chinese prompts loaded successfully")
                    if let systemPrompt = chinesePrompts["systemPrompt"] as? [String] {
                        print("   System prompt has \(systemPrompt.count) lines")
                    }
                }
            }
        } catch {
            print("❌ Failed to parse dev config: \(error)")
        }
    } else {
        print("❌ Dev config not found")
    }
    
    // Test loading prod config
    if let prodConfigPath = Bundle.main.path(forResource: "prod-config", ofType: "json", inDirectory: "Resources/configs") {
        print("✅ Prod config found at: \(prodConfigPath)")
    } else {
        print("❌ Prod config not found")
    }
}

/// Test file management functionality
public func testFileManagement() {
    print("\n🧪 Testing File Management...")
    
    let testDir = "./test-output"
    let testFile = "\(testDir)/test.txt"
    
    do {
        // Create test directory
        try FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)
        print("✅ Created test directory: \(testDir)")
        
        // Create test file
        let testContent = "Hello, MDKit! 你好，MDKit！"
        try testContent.write(toFile: testFile, atomically: true, encoding: .utf8)
        print("✅ Created test file: \(testFile)")
        
        // Read test file
        let readContent = try String(contentsOfFile: testFile, encoding: .utf8)
        print("✅ Read test file content: \(readContent)")
        
        // Clean up
        try FileManager.default.removeItem(atPath: testFile)
        try FileManager.default.removeItem(atPath: testDir)
        print("✅ Cleaned up test files")
        
    } catch {
        print("❌ File management test failed: \(error)")
    }
}

/// Test logging functionality
public func testLogging() {
    print("\n🧪 Testing Logging...")
    
    // Test basic logging
    print("📝 Testing console logging...")
    print("DEBUG: This is a debug message")
    print("INFO: This is an info message")
    print("WARNING: This is a warning message")
    print("ERROR: This is an error message")
    
    // Test Chinese text logging
    print("🇨🇳 测试中文日志记录...")
    print("DEBUG: 这是调试信息")
    print("INFO: 这是信息消息")
    print("WARNING: 这是警告消息")
    print("ERROR: 这是错误消息")
    
    print("✅ Logging test completed")
}

/// Test LLM configuration
public func testLLMConfiguration() {
    print("\n🧪 Testing LLM Configuration...")
    
    // Test loading LLM config from dev-config.json
    if let devConfigPath = Bundle.main.path(forResource: "dev-config", ofType: "json", inDirectory: "Resources/configs") {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: devConfigPath))
            let config = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let llm = config?["llm"] as? [String: Any] {
                print("✅ LLM configuration loaded")
                
                // Test model configuration
                if let model = llm["model"] as? [String: Any] {
                    let modelName = model["name"] as? String ?? "Unknown"
                    let modelType = model["type"] as? String ?? "Unknown"
                    print("   Model: \(modelName) (\(modelType))")
                }
                
                // Test parameters
                if let parameters = llm["parameters"] as? [String: Any] {
                    let temperature = parameters["temperature"] as? Double ?? 0.0
                    let context = parameters["context"] as? Int ?? 0
                    print("   Temperature: \(temperature)")
                    print("   Context: \(context)")
                }
                
                // Test Chinese prompts
                if let prompts = llm["promptTemplates"] as? [String: Any],
                   let languages = prompts["languages"] as? [String: Any],
                   let chinese = languages["zh"] as? [String: Any] {
                    print("   🇨🇳 Chinese prompts available")
                    
                    if let systemPrompt = chinese["systemPrompt"] as? [String] {
                        print("      System prompt: \(systemPrompt.count) lines")
                    }
                }
            }
        } catch {
            print("❌ Failed to parse LLM config: \(error)")
        }
    } else {
        print("❌ Dev config not found for LLM testing")
    }
}

/// Run all integration tests
public func runAllIntegrationTests() {
    print("🚀 Starting MDKit Integration Tests...")
    print("=====================================")
    
    testConfigurationLoading()
    testFileManagement()
    testLogging()
    testLLMConfiguration()
    
    print("\n🎉 All integration tests completed!")
    print("=====================================")
    print("Next steps:")
    print("1. Import the library modules in your main target")
    print("2. Use the configuration loading functions")
    print("3. Implement PDF processing with the loaded configs")
    print("4. Test with actual Chinese PDFs")
}

// MARK: - Usage Example

/*
 To use this in your Xcode project:
 
 1. Copy this file to your main target
 2. Call the test functions:
 
 import mdkitCore
 import mdkitConfiguration
 import mdkitLogging
 import mdkitFileManagement
 import mdkitLLM
 
 // Run tests
 runAllIntegrationTests()
 
 // Or run individual tests
 testConfigurationLoading()
 testLLMConfiguration()
 
 3. Use the configuration in your PDF processing:
 
 // Load configuration
 let config = try loadConfiguration(from: "dev-config.json")
 
 // Use for Chinese PDF processing
 let processor = DocumentProcessor(config: config)
 let result = try processor.processPDF("chinese-document.pdf")
 */
