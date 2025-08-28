//
//  PromptTemplatesTests.swift
//  mdkit
//
// Created by alan zhang on 2025/8/27.
//

import XCTest
@testable import mdkitLLM
@testable import mdkitConfiguration

final class PromptManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    var promptManager: mdkitLLM.PromptManager!
    var mockConfig: mdkitConfiguration.PromptTemplates!
    
    // MARK: - Test Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create mock configuration with English and Chinese prompts
        mockConfig = PromptTemplates(
            languages: [
                "en": LanguagePrompts(
                    systemPrompt: [
                        "You are an expert document processor.",
                        "Your expertise includes technical documents."
                    ],
                    markdownOptimizationPrompt: [
                        "Document: {documentTitle}",
                        "Pages: {pageCount}",
                        "Elements: {elementCount}",
                        "Language: {detectedLanguage}",
                        "Confidence: {languageConfidence}",
                        "Context: {documentContext}",
                        "Markdown: {markdown}"
                    ],
                    structureAnalysisPrompt: [
                        "Document Type: {documentType}",
                        "Elements: {elementCount}",
                        "Language: {detectedLanguage}",
                        "Descriptions: {elementDescriptions}"
                    ],
                    tableOptimizationPrompt: [
                        "Optimize table: {tableContent}"
                    ],
                    listOptimizationPrompt: [
                        "Optimize list: {listContent}"
                    ],
                    headerOptimizationPrompt: [
                        "Optimize headers: {headerContent}"
                    ],
                    technicalStandardPrompt: [
                        "This is a technical standard document."
                    ]
                ),
                "zh": LanguagePrompts(
                    systemPrompt: [
                        "您是一位专业的文档处理专家。",
                        "您的专业领域包括技术文档。"
                    ],
                    markdownOptimizationPrompt: [
                        "文档：{documentTitle}",
                        "页数：{pageCount}",
                        "元素：{elementCount}",
                        "语言：{detectedLanguage}",
                        "置信度：{languageConfidence}",
                        "上下文：{documentContext}",
                        "Markdown：{markdown}"
                    ],
                    structureAnalysisPrompt: [
                        "文档类型：{documentType}",
                        "元素：{elementCount}",
                        "语言：{detectedLanguage}",
                        "描述：{elementDescriptions}"
                    ],
                    tableOptimizationPrompt: [
                        "优化表格：{tableContent}"
                    ],
                    listOptimizationPrompt: [
                        "优化列表：{listContent}"
                    ],
                    headerOptimizationPrompt: [
                        "优化标题：{headerContent}"
                    ],
                    technicalStandardPrompt: [
                        "这是一份技术标准文档。"
                    ]
                )
            ],
            defaultLanguage: "en",
            fallbackLanguage: "en"
        )
        
        promptManager = PromptManager(config: mockConfig)
    }
    
    override func tearDownWithError() throws {
        promptManager = nil
        mockConfig = nil
        try super.tearDownWithError()
    }
    
    // MARK: - System Prompt Tests
    
    func testGetSystemPromptForEnglish() throws {
        let prompt = promptManager.getSystemPrompt(for: "en")
        
        XCTAssertTrue(prompt.contains("You are an expert document processor"))
        XCTAssertTrue(prompt.contains("Your expertise includes technical documents"))
        XCTAssertFalse(prompt.contains("您是一位专业的文档处理专家"))
    }
    
    func testGetSystemPromptForChinese() throws {
        let prompt = promptManager.getSystemPrompt(for: "zh")
        
        XCTAssertTrue(prompt.contains("您是一位专业的文档处理专家"))
        XCTAssertTrue(prompt.contains("您的专业领域包括技术文档"))
        XCTAssertFalse(prompt.contains("You are an expert document processor"))
    }
    
    func testGetSystemPromptForUnsupportedLanguage() throws {
        let prompt = promptManager.getSystemPrompt(for: "fr")
        
        // Should fall back to default language (English)
        XCTAssertTrue(prompt.contains("You are an expert document processor"))
        XCTAssertTrue(prompt.contains("Your expertise includes technical documents"))
    }
    
    // MARK: - Markdown Optimization Prompt Tests
    
    func testGetMarkdownOptimizationPromptForEnglish() throws {
        let prompt = promptManager.getMarkdownOptimizationPrompt(
            for: "en",
            documentTitle: "Test Document",
            pageCount: 5,
            elementCount: 25,
            documentContext: "Technical specification",
            detectedLanguage: "en",
            languageConfidence: 0.95,
            markdown: "# Test\n\nContent here"
        )
        
        XCTAssertTrue(prompt.contains("Document: Test Document"))
        XCTAssertTrue(prompt.contains("Pages: 5"))
        XCTAssertTrue(prompt.contains("Elements: 25"))
        XCTAssertTrue(prompt.contains("Language: en"))
        XCTAssertTrue(prompt.contains("Confidence: 0.95"))
        XCTAssertTrue(prompt.contains("Context: Technical specification"))
        XCTAssertTrue(prompt.contains("Markdown: # Test\n\nContent here"))
        
        // Should not contain placeholders
        XCTAssertFalse(prompt.contains("{documentTitle}"))
        XCTAssertFalse(prompt.contains("{pageCount}"))
        XCTAssertFalse(prompt.contains("{elementCount}"))
        XCTAssertFalse(prompt.contains("{detectedLanguage}"))
        XCTAssertFalse(prompt.contains("{languageConfidence}"))
        XCTAssertFalse(prompt.contains("{documentContext}"))
        XCTAssertFalse(prompt.contains("{markdown}"))
    }
    
    func testGetMarkdownOptimizationPromptForChinese() throws {
        let prompt = promptManager.getMarkdownOptimizationPrompt(
            for: "zh",
            documentTitle: "测试文档",
            pageCount: 3,
            elementCount: 15,
            documentContext: "技术规范",
            detectedLanguage: "zh",
            languageConfidence: 0.88,
            markdown: "# 测试\n\n内容在这里"
        )
        
        XCTAssertTrue(prompt.contains("文档：测试文档"))
        XCTAssertTrue(prompt.contains("页数：3"))
        XCTAssertTrue(prompt.contains("元素：15"))
        XCTAssertTrue(prompt.contains("语言：zh"))
        XCTAssertTrue(prompt.contains("置信度：0.88"))
        XCTAssertTrue(prompt.contains("上下文：技术规范"))
        XCTAssertTrue(prompt.contains("Markdown：# 测试\n\n内容在这里"))
        
        // Should not contain placeholders
        XCTAssertFalse(prompt.contains("{documentTitle}"))
        XCTAssertFalse(prompt.contains("{pageCount}"))
        XCTAssertFalse(prompt.contains("{elementCount}"))
        XCTAssertFalse(prompt.contains("{detectedLanguage}"))
        XCTAssertFalse(prompt.contains("{languageConfidence}"))
        XCTAssertFalse(prompt.contains("{documentContext}"))
        XCTAssertFalse(prompt.contains("{markdown}"))
    }
    
    // MARK: - Structure Analysis Prompt Tests
    
    func testGetStructureAnalysisPromptForEnglish() throws {
        let prompt = promptManager.getStructureAnalysisPrompt(
            for: "en",
            documentType: "Technical Manual",
            elementCount: 30,
            detectedLanguage: "en",
            elementDescriptions: "Headers, lists, tables"
        )
        
        XCTAssertTrue(prompt.contains("Document Type: Technical Manual"))
        XCTAssertTrue(prompt.contains("Elements: 30"))
        XCTAssertTrue(prompt.contains("Language: en"))
        XCTAssertTrue(prompt.contains("Descriptions: Headers, lists, tables"))
        
        // Should not contain placeholders
        XCTAssertFalse(prompt.contains("{documentType}"))
        XCTAssertFalse(prompt.contains("{elementCount}"))
        XCTAssertFalse(prompt.contains("{detectedLanguage}"))
        XCTAssertFalse(prompt.contains("{elementDescriptions}"))
    }
    
    func testGetStructureAnalysisPromptForChinese() throws {
        let prompt = promptManager.getStructureAnalysisPrompt(
            for: "zh",
            documentType: "技术手册",
            elementCount: 20,
            detectedLanguage: "zh",
            elementDescriptions: "标题、列表、表格"
        )
        
        XCTAssertTrue(prompt.contains("文档类型：技术手册"))
        XCTAssertTrue(prompt.contains("元素：20"))
        XCTAssertTrue(prompt.contains("语言：zh"))
        XCTAssertTrue(prompt.contains("描述：标题、列表、表格"))
        
        // Should not contain placeholders
        XCTAssertFalse(prompt.contains("{documentType}"))
        XCTAssertFalse(prompt.contains("{elementCount}"))
        XCTAssertFalse(prompt.contains("{detectedLanguage}"))
        XCTAssertFalse(prompt.contains("{elementDescriptions}"))
    }
    
    // MARK: - Table Optimization Prompt Tests
    
    func testGetTableOptimizationPromptForEnglish() throws {
        let prompt = promptManager.getTableOptimizationPrompt(
            for: "en",
            tableContent: "| Header | Value |\n|--------|-------|"
        )
        
        XCTAssertTrue(prompt.contains("Optimize table: | Header | Value |\n|--------|-------|"))
        XCTAssertFalse(prompt.contains("{tableContent}"))
    }
    
    func testGetTableOptimizationPromptForChinese() throws {
        let prompt = promptManager.getTableOptimizationPrompt(
            for: "zh",
            tableContent: "| 标题 | 值 |\n|------|-----|"
        )
        
        XCTAssertTrue(prompt.contains("优化表格：| 标题 | 值 |\n|------|-----|"))
        XCTAssertFalse(prompt.contains("{tableContent}"))
    }
    
    // MARK: - List Optimization Prompt Tests
    
    func testGetListOptimizationPromptForEnglish() throws {
        let prompt = promptManager.getListOptimizationPrompt(
            for: "en",
            listContent: "- Item 1\n- Item 2"
        )
        
        XCTAssertTrue(prompt.contains("Optimize list: - Item 1\n- Item 2"))
        XCTAssertFalse(prompt.contains("{listContent}"))
    }
    
    func testGetListOptimizationPromptForChinese() throws {
        let prompt = promptManager.getListOptimizationPrompt(
            for: "zh",
            listContent: "- 项目 1\n- 项目 2"
        )
        
        XCTAssertTrue(prompt.contains("优化列表：- 项目 1\n- 项目 2"))
        XCTAssertFalse(prompt.contains("{listContent}"))
    }
    
    // MARK: - Header Optimization Prompt Tests
    
    func testGetHeaderOptimizationPromptForEnglish() throws {
        let prompt = promptManager.getHeaderOptimizationPrompt(
            for: "en",
            headerContent: "# Main Title\n## Subtitle"
        )
        
        XCTAssertTrue(prompt.contains("Optimize headers: # Main Title\n## Subtitle"))
        XCTAssertFalse(prompt.contains("{headerContent}"))
    }
    
    func testGetHeaderOptimizationPromptForChinese() throws {
        let prompt = promptManager.getHeaderOptimizationPrompt(
            for: "zh",
            headerContent: "# 主标题\n## 副标题"
        )
        
        XCTAssertTrue(prompt.contains("优化标题：# 主标题\n## 副标题"))
        XCTAssertFalse(prompt.contains("{headerContent}"))
    }
    
    // MARK: - Technical Standard Prompt Tests
    
    func testGetTechnicalStandardPromptForEnglish() throws {
        let prompt = promptManager.getTechnicalStandardPrompt(for: "en")
        
        XCTAssertTrue(prompt.contains("This is a technical standard document"))
    }
    
    func testGetTechnicalStandardPromptForChinese() throws {
        let prompt = promptManager.getTechnicalStandardPrompt(for: "zh")
        
        XCTAssertTrue(prompt.contains("这是一份技术标准文档"))
    }
    
    // MARK: - Fallback Language Tests
    
    func testFallbackToDefaultLanguage() throws {
        // Test with unsupported language
        let prompt = promptManager.getSystemPrompt(for: "es")
        
        // Should fall back to English (default)
        XCTAssertTrue(prompt.contains("You are an expert document processor"))
        XCTAssertFalse(prompt.contains("您是一位专业的文档处理专家"))
    }
    
    func testFallbackToFallbackLanguage() throws {
        // Create config with different default and fallback
        let fallbackConfig = PromptTemplates(
            languages: [
                "zh": LanguagePrompts(
                    systemPrompt: ["中文系统提示"],
                    markdownOptimizationPrompt: ["中文优化提示"]
                )
            ],
            defaultLanguage: "en", // Not available
            fallbackLanguage: "zh" // Available
        )
        
        let fallbackTemplates = PromptManager(config: fallbackConfig)
        let prompt = fallbackTemplates.getSystemPrompt(for: "fr")
        
        // Should fall back to Chinese (fallback)
        XCTAssertTrue(prompt.contains("中文系统提示"))
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyLanguagePrompts() throws {
        let emptyConfig = PromptTemplates(
            languages: [:],
            defaultLanguage: "en",
            fallbackLanguage: "en"
        )
        
        let emptyTemplates = PromptManager(config: emptyConfig)
        let prompt = emptyTemplates.getSystemPrompt(for: "en")
        
        // Should return empty string
        XCTAssertEqual(prompt, "")
    }
    
    func testMissingOptionalPrompts() throws {
        let minimalConfig = PromptTemplates(
            languages: [
                "en": LanguagePrompts(
                    systemPrompt: ["System prompt"],
                    markdownOptimizationPrompt: ["Optimization prompt"]
                    // Missing other optional prompts
                )
            ],
            defaultLanguage: "en",
            fallbackLanguage: "en"
        )
        
        let minimalTemplates = PromptManager(config: minimalConfig)
        
        // Should use fallback prompts for missing ones
        let tablePrompt = minimalTemplates.getTableOptimizationPrompt(
            for: "en",
            tableContent: "test"
        )
        
        XCTAssertTrue(tablePrompt.contains("Please optimize the following table structure"))
        XCTAssertTrue(tablePrompt.contains("test"))
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceForMultipleLanguagePrompts() throws {
        let languages = ["en", "zh", "fr", "de", "es"]
        
        measure {
            for language in languages {
                _ = promptManager.getSystemPrompt(for: language)
            }
        }
    }
    
    func testPerformanceForPlaceholderReplacement() throws {
        let longContent = String(repeating: "This is a long content string for testing placeholder replacement performance. ", count: 100)
        
        measure {
            _ = promptManager.getMarkdownOptimizationPrompt(
                for: "en",
                documentTitle: "Test",
                pageCount: 1,
                elementCount: 1,
                documentContext: longContent,
                detectedLanguage: "en",
                languageConfidence: 0.9,
                markdown: longContent
            )
        }
    }
}
