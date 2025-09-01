//
//  MDKitConfig.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation
import Logging

// MARK: - Main Configuration

public struct MDKitConfig: Codable, Sendable {
    public let processing: ProcessingConfig
    public let llm: LLMConfig
    public let headerFooterDetection: HeaderFooterDetectionConfig
    public let headerDetection: HeaderDetectionConfig
    public let listDetection: ListDetectionConfig
    public let duplicationDetection: DuplicationDetectionConfig
    public let positionSorting: PositionSortingConfig
    public let markdownGeneration: MarkdownGenerationConfig
    public let imageExtraction: ImageExtractionConfig
    public let ocr: OCRConfig
    public let performance: PerformanceConfig
    public let fileManagement: FileManagementConfig
    public let logging: LoggingConfig
    
    public init(
        processing: ProcessingConfig = ProcessingConfig(),
        llm: LLMConfig = LLMConfig(),
        headerFooterDetection: HeaderFooterDetectionConfig = HeaderFooterDetectionConfig(),
        headerDetection: HeaderDetectionConfig = HeaderDetectionConfig(markdownLevelOffset: 0),
        listDetection: ListDetectionConfig = ListDetectionConfig(),
        duplicationDetection: DuplicationDetectionConfig = DuplicationDetectionConfig(),
        positionSorting: PositionSortingConfig = PositionSortingConfig(),
        markdownGeneration: MarkdownGenerationConfig = MarkdownGenerationConfig(),
        imageExtraction: ImageExtractionConfig = ImageExtractionConfig(),
        ocr: OCRConfig = OCRConfig(),
        performance: PerformanceConfig = PerformanceConfig(),
        fileManagement: FileManagementConfig = FileManagementConfig(),
        logging: LoggingConfig = LoggingConfig()
    ) {
        self.processing = processing
        self.llm = llm
        self.headerFooterDetection = headerFooterDetection
        self.headerDetection = headerDetection
        self.listDetection = listDetection
        self.duplicationDetection = duplicationDetection
        self.positionSorting = positionSorting
        self.markdownGeneration = markdownGeneration
        self.imageExtraction = imageExtraction
        self.ocr = ocr
        self.performance = performance
        self.fileManagement = fileManagement
        self.logging = logging
    }
}

// MARK: - Processing Configuration

public struct ProcessingConfig: Codable, Sendable {
    public let overlapThreshold: Double
    public let enableHeaderFooterDetection: Bool
    public let pageHeaderRegion: [Double]
    public let pageFooterRegion: [Double]
    public let enableElementMerging: Bool
    public let mergeDistanceThreshold: Double
    public let isMergeDistanceNormalized: Bool
    public let horizontalMergeThreshold: Double
    public let isHorizontalMergeThresholdNormalized: Bool
    public let enableLLMOptimization: Bool
    public let pdfImageScaleFactor: Double
    public let enableImageEnhancement: Bool
    public let languageDetection: LanguageDetectionConfig?
    
    public init(
        overlapThreshold: Double = 0.15,
        enableHeaderFooterDetection: Bool = true,
        pageHeaderRegion: [Double] = [0.0, 0.12],
        pageFooterRegion: [Double] = [0.88, 1.0],
        enableElementMerging: Bool = true,
        mergeDistanceThreshold: Double = 0.02,
        isMergeDistanceNormalized: Bool = true,
        horizontalMergeThreshold: Double = 0.15,
        isHorizontalMergeThresholdNormalized: Bool = true,
        enableLLMOptimization: Bool = true,
        pdfImageScaleFactor: Double = 2.0,
        enableImageEnhancement: Bool = true,
        languageDetection: LanguageDetectionConfig? = nil
    ) {
        self.overlapThreshold = overlapThreshold
        self.enableHeaderFooterDetection = enableHeaderFooterDetection
        self.pageHeaderRegion = pageHeaderRegion
        self.pageFooterRegion = pageFooterRegion
        self.enableElementMerging = enableElementMerging
        self.mergeDistanceThreshold = mergeDistanceThreshold
        self.isMergeDistanceNormalized = isMergeDistanceNormalized
        self.horizontalMergeThreshold = horizontalMergeThreshold
        self.isHorizontalMergeThresholdNormalized = isHorizontalMergeThresholdNormalized
        self.enableLLMOptimization = enableLLMOptimization
        self.pdfImageScaleFactor = pdfImageScaleFactor
        self.enableImageEnhancement = enableImageEnhancement
        self.languageDetection = languageDetection
    }
}

// MARK: - Language Detection Configuration

public struct LanguageDetectionConfig: Codable, Sendable {
    public let minimumTextLength: Int
    public let confidenceThreshold: Double
    public let enableMultilingualDetection: Bool
    public let maxLanguages: Int
    public let fallbackLanguage: String
    
    public init(
        minimumTextLength: Int = 10,
        confidenceThreshold: Double = 0.6,
        enableMultilingualDetection: Bool = true,
        maxLanguages: Int = 3,
        fallbackLanguage: String = "en"
    ) {
        self.minimumTextLength = minimumTextLength
        self.confidenceThreshold = confidenceThreshold
        self.enableMultilingualDetection = enableMultilingualDetection
        self.maxLanguages = maxLanguages
        self.fallbackLanguage = fallbackLanguage
    }
}

// MARK: - LLM Configuration

public struct LLMConfig: Codable, Sendable {
    public let enabled: Bool
    public let backend: String
    public let modelPath: String
    public let model: ModelConfig
    public let parameters: ProcessingParameters
    public let options: LLMOptions
    public let contextManagement: ContextManagement
    public let memoryOptimization: MemoryOptimization
    public let promptTemplates: PromptTemplates
    
    public init(
        enabled: Bool = true,
        backend: String = "LocalLLMClientLlama",
        modelPath: String = "",
        model: ModelConfig = ModelConfig(),
        parameters: ProcessingParameters = ProcessingParameters(),
        options: LLMOptions = LLMOptions(),
        contextManagement: ContextManagement = ContextManagement(),
        memoryOptimization: MemoryOptimization = MemoryOptimization(),
        promptTemplates: PromptTemplates = PromptTemplates()
    ) {
        self.enabled = enabled
        self.backend = backend
        self.modelPath = modelPath
        self.model = model
        self.parameters = parameters
        self.options = options
        self.contextManagement = contextManagement
        self.memoryOptimization = memoryOptimization
        self.promptTemplates = promptTemplates
    }
}

public struct ModelConfig: Codable, Sendable {
    public let identifier: String
    public let name: String
    public let type: String
    public let downloadUrl: String
    public let localPath: String
    
    public init(
        identifier: String = "ggml-org/Meta-Llama-3.1-8B-Instruct-Q4_0-GGUF",
        name: String = "Meta Llama 3.1 8B Instruct Q4_0",
        type: String = "llama",
        downloadUrl: String = "",
        localPath: String = "~/.localllmclient/huggingface/models/meta-llama-3.1-8b-instruct-q4_0.gguf"
    ) {
        self.identifier = identifier
        self.name = name
        self.type = type
        self.downloadUrl = downloadUrl
        self.localPath = localPath
    }
}

public struct ProcessingParameters: Codable, Sendable {
    public let temperature: Double
    public let topP: Double
    public let topK: Int
    public let penaltyRepeat: Double
    public let penaltyFrequency: Double
    public let maxTokens: Int
    public let batch: Int
    public let threads: Int
    public let gpuLayers: Int
    
    public init(
        temperature: Double = 0.3,
        topP: Double = 0.9,
        topK: Int = 40,
        penaltyRepeat: Double = 1.1,
        penaltyFrequency: Double = 0.8,
        maxTokens: Int = 2048,
        batch: Int = 256,
        threads: Int = 4,
        gpuLayers: Int = 0
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.penaltyRepeat = penaltyRepeat
        self.penaltyFrequency = penaltyFrequency
        self.maxTokens = maxTokens
        self.batch = batch
        self.threads = threads
        self.gpuLayers = gpuLayers
    }
}

public struct LLMOptions: Codable, Sendable {
    public let responseFormat: String
    public let verbose: Bool
    public let streaming: Bool
    public let jsonMode: Bool
    
    public init(
        responseFormat: String = "markdown",
        verbose: Bool = true,
        streaming: Bool = true,
        jsonMode: Bool = false
    ) {
        self.responseFormat = responseFormat
        self.verbose = verbose
        self.streaming = streaming
        self.jsonMode = jsonMode
    }
}

public struct ContextManagement: Codable, Sendable {
    public let maxContextLength: Int
    public let overlapLength: Int
    public let chunkSize: Int
    public let enableSlidingWindow: Bool
    public let enableHierarchicalProcessing: Bool
    
    public init(
        maxContextLength: Int = 2048,
        overlapLength: Int = 100,
        chunkSize: Int = 500,
        enableSlidingWindow: Bool = true,
        enableHierarchicalProcessing: Bool = true
    ) {
        self.maxContextLength = maxContextLength
        self.overlapLength = overlapLength
        self.chunkSize = chunkSize
        self.enableSlidingWindow = enableSlidingWindow
        self.enableHierarchicalProcessing = enableHierarchicalProcessing
    }
}

public struct MemoryOptimization: Codable, Sendable {
    public let maxMemoryUsage: String
    public let enableStreaming: Bool
    public let cleanupAfterBatch: Bool
    public let enableMemoryMapping: Bool
    
    public init(
        maxMemoryUsage: String = "2GB",
        enableStreaming: Bool = true,
        cleanupAfterBatch: Bool = true,
        enableMemoryMapping: Bool = false
    ) {
        self.maxMemoryUsage = maxMemoryUsage
        self.enableStreaming = enableStreaming
        self.cleanupAfterBatch = cleanupAfterBatch
        self.enableMemoryMapping = enableMemoryMapping
    }
}

public struct PromptTemplates: Codable, Sendable {
    public let languages: [String: LanguagePrompts]
    public let defaultLanguage: String
    public let fallbackLanguage: String
    
    public init(
        languages: [String: LanguagePrompts] = [
            "en": LanguagePrompts(
                systemPrompt: ["You are an expert document processor specializing in converting technical documents to well-structured markdown."],
                markdownOptimizationPrompt: ["Please optimize this markdown for better structure and readability."]
            )
        ],
        defaultLanguage: String = "en",
        fallbackLanguage: String = "en"
    ) {
        self.languages = languages
        self.defaultLanguage = defaultLanguage
        self.fallbackLanguage = fallbackLanguage
    }
}

public struct LanguagePrompts: Codable, Sendable {
    public let systemPrompt: [String]
    public let markdownOptimizationPrompt: [String]
    public let structureAnalysisPrompt: [String]?
    public let tableOptimizationPrompt: [String]?
    public let listOptimizationPrompt: [String]?
    public let headerOptimizationPrompt: [String]?
    public let technicalStandardPrompt: [String]?
    
    public init(
        systemPrompt: [String] = [],
        markdownOptimizationPrompt: [String] = [],
        structureAnalysisPrompt: [String]? = nil,
        tableOptimizationPrompt: [String]? = nil,
        listOptimizationPrompt: [String]? = nil,
        headerOptimizationPrompt: [String]? = nil,
        technicalStandardPrompt: [String]? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.markdownOptimizationPrompt = markdownOptimizationPrompt
        self.structureAnalysisPrompt = structureAnalysisPrompt
        self.tableOptimizationPrompt = tableOptimizationPrompt
        self.listOptimizationPrompt = listOptimizationPrompt
        self.headerOptimizationPrompt = headerOptimizationPrompt
        self.technicalStandardPrompt = technicalStandardPrompt
    }
}



// MARK: - Header Detection Configuration

public struct HeaderDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let sameLineTolerance: Double
    public let enableHeaderMerging: Bool
    public let enableLevelCalculation: Bool
    public let markdownLevelOffset: Int
    public let patterns: HeaderPatternsConfig
    public let levelCalculation: HeaderLevelCalculationConfig
    
    public init(
        enabled: Bool = true,
        sameLineTolerance: Double = 8.0,
        enableHeaderMerging: Bool = true,
        enableLevelCalculation: Bool = true,
        markdownLevelOffset: Int,
        patterns: HeaderPatternsConfig = HeaderPatternsConfig(),
        levelCalculation: HeaderLevelCalculationConfig = HeaderLevelCalculationConfig()
    ) {
        self.enabled = enabled
        self.sameLineTolerance = sameLineTolerance
        self.enableHeaderMerging = enableHeaderMerging
        self.enableLevelCalculation = enableLevelCalculation
        self.markdownLevelOffset = markdownLevelOffset
        self.patterns = patterns
        self.levelCalculation = levelCalculation
    }
}

public struct HeaderPatternsConfig: Codable, Sendable {
    public let numberedHeaders: [String]
    public let letteredHeaders: [String]
    public let romanHeaders: [String]
    public let namedHeaders: [String]
    
    public init(
        numberedHeaders: [String] = [],
        letteredHeaders: [String] = [],
        romanHeaders: [String] = [],
        namedHeaders: [String] = []
    ) {
        self.numberedHeaders = numberedHeaders
        self.letteredHeaders = letteredHeaders
        self.romanHeaders = romanHeaders
        self.namedHeaders = namedHeaders
    }
}

public struct HeaderLevelCalculationConfig: Codable, Sendable {
    public let autoCalculate: Bool
    public let maxLevel: Int
    public let customLevels: [String: Int]
    
    public init(
        autoCalculate: Bool = true,
        maxLevel: Int = 6,
        customLevels: [String: Int] = [:]
    ) {
        self.autoCalculate = autoCalculate
        self.maxLevel = maxLevel
        self.customLevels = customLevels
    }
}

// MARK: - List Detection Configuration

public struct ListDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let sameLineTolerance: Double
    public let enableListItemMerging: Bool
    public let enableLevelCalculation: Bool
    public let enableNestedLists: Bool
    public let patterns: ListPatternsConfig
    public let indentation: ListIndentationConfig
    
    public init(
        enabled: Bool = true,
        sameLineTolerance: Double = 8.0,
        enableListItemMerging: Bool = true,
        enableLevelCalculation: Bool = true,
        enableNestedLists: Bool = true,
        patterns: ListPatternsConfig = ListPatternsConfig(),
        indentation: ListIndentationConfig = ListIndentationConfig()
    ) {
        self.enabled = enabled
        self.sameLineTolerance = sameLineTolerance
        self.enableListItemMerging = enableListItemMerging
        self.enableLevelCalculation = enableLevelCalculation
        self.enableNestedLists = enableNestedLists
        self.patterns = patterns
        self.indentation = indentation
    }
}

public struct ListPatternsConfig: Codable, Sendable {
    public let numberedMarkers: [String]
    public let letteredMarkers: [String]
    public let bulletMarkers: [String]
    public let romanMarkers: [String]
    public let customMarkers: [String]
    
    public init(
        numberedMarkers: [String] = [],
        letteredMarkers: [String] = [],
        bulletMarkers: [String] = [],
        romanMarkers: [String] = [],
        customMarkers: [String] = []
    ) {
        self.numberedMarkers = numberedMarkers
        self.letteredMarkers = letteredMarkers
        self.bulletMarkers = bulletMarkers
        self.romanMarkers = romanMarkers
        self.customMarkers = customMarkers
    }
}

public struct ListIndentationConfig: Codable, Sendable {
    public let baseIndentation: Double
    public let levelThreshold: Double
    public let enableXCoordinateAnalysis: Bool
    
    public init(
        baseIndentation: Double = 60.0,
        levelThreshold: Double = 25.0,
        enableXCoordinateAnalysis: Bool = true
    ) {
        self.baseIndentation = baseIndentation
        self.levelThreshold = levelThreshold
        self.enableXCoordinateAnalysis = enableXCoordinateAnalysis
    }
}

// MARK: - Header Footer Detection Configuration

public struct HeaderFooterDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let headerFrequencyThreshold: Double
    public let footerFrequencyThreshold: Double
    public let regionBasedDetection: RegionBasedDetectionConfig
    public let percentageBasedDetection: PercentageBasedDetectionConfig
    public let smartDetection: SmartDetectionConfig
    public let multiRegionDetection: MultiRegionDetectionConfig
    
    public init(
        enabled: Bool = true,
        headerFrequencyThreshold: Double = 0.6,
        footerFrequencyThreshold: Double = 0.6,
        regionBasedDetection: RegionBasedDetectionConfig = RegionBasedDetectionConfig(),
        percentageBasedDetection: PercentageBasedDetectionConfig = PercentageBasedDetectionConfig(),
        smartDetection: SmartDetectionConfig = SmartDetectionConfig(),
        multiRegionDetection: MultiRegionDetectionConfig = MultiRegionDetectionConfig()
    ) {
        self.enabled = enabled
        self.headerFrequencyThreshold = headerFrequencyThreshold
        self.footerFrequencyThreshold = footerFrequencyThreshold
        self.regionBasedDetection = regionBasedDetection
        self.percentageBasedDetection = percentageBasedDetection
        self.smartDetection = smartDetection
        self.multiRegionDetection = multiRegionDetection
    }
}

public struct RegionBasedDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let headerRegionY: Double
    public let footerRegionY: Double
    public let regionTolerance: Double
    
    public init(
        enabled: Bool = true,
        headerRegionY: Double = 72.0,
        footerRegionY: Double = 720.0,
        regionTolerance: Double = 10.0
    ) {
        self.enabled = enabled
        self.headerRegionY = headerRegionY
        self.footerRegionY = footerRegionY
        self.regionTolerance = regionTolerance
    }
}

public struct PercentageBasedDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let headerRegionHeight: Double
    public let footerRegionHeight: Double
    
    public init(
        enabled: Bool = true,
        headerRegionHeight: Double = 0.12,
        footerRegionHeight: Double = 0.12
    ) {
        self.enabled = enabled
        self.headerRegionHeight = headerRegionHeight
        self.footerRegionHeight = footerRegionHeight
    }
}

public struct SmartDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let excludePageNumbers: Bool
    public let excludeCommonHeaders: [String]
    public let excludeCommonFooters: [String]
    public let enableContentAnalysis: Bool
    public let enableContentBasedDetection: Bool
    public let minHeaderFooterLength: Int
    public let maxHeaderFooterLength: Int
    
    public init(
        enabled: Bool = true,
        excludePageNumbers: Bool = true,
        excludeCommonHeaders: [String] = [],
        excludeCommonFooters: [String] = [],
        enableContentAnalysis: Bool = true,
        enableContentBasedDetection: Bool = true,
        minHeaderFooterLength: Int = 2,
        maxHeaderFooterLength: Int = 150
    ) {
        self.enabled = enabled
        self.excludePageNumbers = excludePageNumbers
        self.excludeCommonHeaders = excludeCommonHeaders
        self.excludeCommonFooters = excludeCommonFooters
        self.enableContentAnalysis = enableContentAnalysis
        self.enableContentBasedDetection = enableContentBasedDetection
        self.minHeaderFooterLength = minHeaderFooterLength
        self.maxHeaderFooterLength = maxHeaderFooterLength
    }
}

public struct MultiRegionDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let maxRegions: Int
    
    public init(
        enabled: Bool = false,
        maxRegions: Int = 2
    ) {
        self.enabled = enabled
        self.maxRegions = maxRegions
    }
}

// MARK: - Duplication Detection Configuration

public struct DuplicationDetectionConfig: Codable, Sendable {
    public let enabled: Bool
    public let overlapThreshold: Double
    public let enableLogging: Bool
    public let logOverlaps: Bool
    public let strictMode: Bool
    
    public init(
        enabled: Bool = true,
        overlapThreshold: Double = 0.25,
        enableLogging: Bool = true,
        logOverlaps: Bool = true,
        strictMode: Bool = false
    ) {
        self.enabled = enabled
        self.overlapThreshold = overlapThreshold
        self.enableLogging = enableLogging
        self.logOverlaps = logOverlaps
        self.strictMode = strictMode
    }
}

// MARK: - Position Sorting Configuration

public struct PositionSortingConfig: Codable, Sendable {
    public let sortBy: String
    public let tolerance: Double
    public let enableHorizontalSorting: Bool
    public let confidenceWeighting: Double
    
    public init(
        sortBy: String = "verticalPosition",
        tolerance: Double = 8.0,
        enableHorizontalSorting: Bool = false,
        confidenceWeighting: Double = 0.3
    ) {
        self.sortBy = sortBy
        self.tolerance = tolerance
        self.enableHorizontalSorting = enableHorizontalSorting
        self.confidenceWeighting = confidenceWeighting
    }
}

// MARK: - Image Extraction Configuration

public struct ImageExtractionConfig: Codable, Sendable {
    public let enabled: Bool
    public let savePDFPagesAsImages: Bool
    public let imageFormat: String
    public let imageQuality: Int
    public let saveToOutputFolder: Bool
    public let namingPattern: String
    
    public init(
        enabled: Bool = true,
        savePDFPagesAsImages: Bool = true,
        imageFormat: String = "png",
        imageQuality: Int = 300,
        saveToOutputFolder: Bool = true,
        namingPattern: String = "page_{pageNumber}.png"
    ) {
        self.enabled = enabled
        self.savePDFPagesAsImages = savePDFPagesAsImages
        self.imageFormat = imageFormat
        self.imageQuality = imageQuality
        self.saveToOutputFolder = saveToOutputFolder
        self.namingPattern = namingPattern
    }
}

// MARK: - Generated TOC Configuration

public struct GeneratedTOCConfig: Codable, Sendable {
    public let enabled: Bool
    public let maxHeaderLevel: Int
    public let includeTitleElements: Bool
    public let includeHeaderElements: Bool
    public let excludeTOCPages: Bool
    
    public init(
        enabled: Bool = true,
        maxHeaderLevel: Int = 2,
        includeTitleElements: Bool = true,
        includeHeaderElements: Bool = true,
        excludeTOCPages: Bool = false
    ) {
        self.enabled = enabled
        self.maxHeaderLevel = maxHeaderLevel
        self.includeTitleElements = includeTitleElements
        self.includeHeaderElements = includeHeaderElements
        self.excludeTOCPages = excludeTOCPages
    }
}

// MARK: - Markdown Generation Configuration

public struct MarkdownGenerationConfig: Codable, Sendable {
    public let preservePageBreaks: Bool
    public let extractImages: Bool
    public let headerFormat: String
    public let listFormat: String
    public let tableFormat: String
    public let codeBlockFormat: String
    public let addTableOfContents: Bool
    public let generatedTOC: GeneratedTOCConfig

    
    public init(
        preservePageBreaks: Bool = false,
        extractImages: Bool = true,
        headerFormat: String = "atx",
        listFormat: String = "unordered",
        tableFormat: String = "standard",
        codeBlockFormat: String = "fenced",
        addTableOfContents: Bool = true,
        generatedTOC: GeneratedTOCConfig = GeneratedTOCConfig()
    ) {
        self.preservePageBreaks = preservePageBreaks
        self.extractImages = extractImages
        self.headerFormat = headerFormat
        self.listFormat = listFormat
        self.tableFormat = tableFormat
        self.codeBlockFormat = codeBlockFormat
        self.addTableOfContents = addTableOfContents
        self.generatedTOC = generatedTOC
    }
}

// MARK: - OCR Configuration

public struct OCRConfig: Codable, Sendable {
    public let recognitionLevel: String
    public let languages: [String]
    public let useLanguageCorrection: Bool
    public let minimumTextHeight: Double
    public let customWords: [String]
    public let enableDocumentAnalysis: Bool
    public let preserveLayout: Bool
    public let tableDetection: Bool
    public let listDetection: Bool
    public let barcodeDetection: Bool
    public let autoDetectLanguages: Bool
    
    public init(
        recognitionLevel: String = "accurate",
        languages: [String] = ["zh-Hans", "zh-Hant", "en-US"],
        useLanguageCorrection: Bool = true,
        minimumTextHeight: Double = 0.008,
        customWords: [String] = ["技术规范", "质量标准", "合规要求", "工程文档"],
        enableDocumentAnalysis: Bool = true,
        preserveLayout: Bool = true,
        tableDetection: Bool = true,
        listDetection: Bool = true,
        barcodeDetection: Bool = false,
        autoDetectLanguages: Bool = false
    ) {
        self.recognitionLevel = recognitionLevel
        self.languages = languages
        self.useLanguageCorrection = useLanguageCorrection
        self.minimumTextHeight = minimumTextHeight
        self.customWords = customWords
        self.enableDocumentAnalysis = enableDocumentAnalysis
        self.preserveLayout = preserveLayout
        self.tableDetection = tableDetection
        self.listDetection = listDetection
        self.barcodeDetection = barcodeDetection
        self.autoDetectLanguages = autoDetectLanguages
    }
}

// MARK: - Performance Configuration

public struct PerformanceConfig: Codable, Sendable {
    public let maxMemoryUsage: String
    public let enableStreaming: Bool
    public let batchSize: Int
    public let cleanupAfterBatch: Bool
    public let enableMultiThreading: Bool
    public let maxThreads: Int
    
    public init(
        maxMemoryUsage: String = "1GB",
        enableStreaming: Bool = true,
        batchSize: Int = 5,
        cleanupAfterBatch: Bool = true,
        enableMultiThreading: Bool = true,
        maxThreads: Int = 4
    ) {
        self.maxMemoryUsage = maxMemoryUsage
        self.enableStreaming = enableStreaming
        self.batchSize = batchSize
        self.cleanupAfterBatch = cleanupAfterBatch
        self.enableMultiThreading = enableMultiThreading
        self.maxThreads = maxThreads
    }
}

// MARK: - File Management Configuration

public struct FileManagementConfig: Codable, Sendable {
    public let outputDirectory: String
    public let markdownDirectory: String
    public let tempDirectory: String
    public let imageDirectory: String
    public let createDirectories: Bool
    public let overwriteExisting: Bool
    public let preserveOriginalNames: Bool
    public let fileNamingStrategy: String
    public let filenamePattern: String
    
    // Markdown generation settings
    public let addTableOfContents: Bool
    public let useATXHeaders: Bool
    public let preserveFormatting: Bool
    public let listMarkerStyle: String
    
    public init(
        outputDirectory: String = "./dev-output",
        markdownDirectory: String = "./dev-markdown",
        tempDirectory: String = "./dev-temp",
        imageDirectory: String = "./images",
        createDirectories: Bool = true,
        overwriteExisting: Bool = true,
        preserveOriginalNames: Bool = true,
        fileNamingStrategy: String = "timestamped",
        filenamePattern: String = "{filename}.md",
        addTableOfContents: Bool = true,
        useATXHeaders: Bool = true,
        preserveFormatting: Bool = true,
        listMarkerStyle: String = "-"
    ) {
        self.outputDirectory = outputDirectory
        self.markdownDirectory = markdownDirectory
        self.tempDirectory = tempDirectory
        self.imageDirectory = imageDirectory
        self.createDirectories = createDirectories
        self.overwriteExisting = overwriteExisting
        self.preserveOriginalNames = preserveOriginalNames
        self.fileNamingStrategy = fileNamingStrategy
        self.filenamePattern = filenamePattern
        self.addTableOfContents = addTableOfContents
        self.useATXHeaders = useATXHeaders
        self.preserveFormatting = preserveFormatting
        self.listMarkerStyle = listMarkerStyle
    }
}

// MARK: - Logging Configuration

public struct LoggingConfig: Codable, Sendable {
    public let enabled: Bool
    public let level: String
    public let outputFolder: String
    public let enableConsoleOutput: Bool
    public let logFileRotation: Bool
    public let maxLogFileSize: String
    public let logCategories: LogCategories
    public let logFileNaming: LogFileNaming
    
    public init(
        enabled: Bool = true,
        level: String = "debug",
        outputFolder: String = "dev-logs",
        enableConsoleOutput: Bool = true,
        logFileRotation: Bool = true,
        maxLogFileSize: String = "5MB",
        logCategories: LogCategories = LogCategories(),
        logFileNaming: LogFileNaming = LogFileNaming()
    ) {
        self.enabled = enabled
        self.level = level
        self.outputFolder = outputFolder
        self.enableConsoleOutput = enableConsoleOutput
        self.logFileRotation = logFileRotation
        self.maxLogFileSize = maxLogFileSize
        self.logCategories = logCategories
        self.logFileNaming = logFileNaming
    }
}

public struct LogCategories: Codable, Sendable {
    public let ocrElements: LogCategory
    public let documentObservation: LogCategory
    public let markdownGeneration: LogCategory
    public let llmPrompts: LogCategory
    public let llmOptimizedMarkdown: LogCategory
    
    public init(
        ocrElements: LogCategory = LogCategory(),
        documentObservation: LogCategory = LogCategory(),
        markdownGeneration: LogCategory = LogCategory(),
        llmPrompts: LogCategory = LogCategory(),
        llmOptimizedMarkdown: LogCategory = LogCategory()
    ) {
        self.ocrElements = ocrElements
        self.documentObservation = documentObservation
        self.markdownGeneration = markdownGeneration
        self.llmPrompts = llmPrompts
        self.llmOptimizedMarkdown = llmOptimizedMarkdown
    }
}

public struct LogCategory: Codable, Sendable {
    public let enabled: Bool
    public let format: String
    public let includeBoundingBoxes: Bool?
    public let includeConfidence: Bool?
    public let includePositionData: Bool?
    public let includeElementTypes: Bool?
    public let includeSourceMapping: Bool?
    public let includeProcessingTime: Bool?
    public let includeSystemPrompt: Bool?
    public let includeUserPrompt: Bool?
    public let includeLLMResponse: Bool?
    public let includeTokenCounts: Bool?
    public let includeOptimizationDetails: Bool?
    public let includeBeforeAfterComparison: Bool?
    
    public init(
        enabled: Bool = true,
        format: String = "json",
        includeBoundingBoxes: Bool? = nil,
        includeConfidence: Bool? = nil,
        includePositionData: Bool? = nil,
        includeElementTypes: Bool? = nil,
        includeSourceMapping: Bool? = nil,
        includeProcessingTime: Bool? = nil,
        includeSystemPrompt: Bool? = nil,
        includeUserPrompt: Bool? = nil,
        includeLLMResponse: Bool? = nil,
        includeTokenCounts: Bool? = nil,
        includeOptimizationDetails: Bool? = nil,
        includeBeforeAfterComparison: Bool? = nil
    ) {
        self.enabled = enabled
        self.format = format
        self.includeBoundingBoxes = includeBoundingBoxes
        self.includeConfidence = includeConfidence
        self.includePositionData = includePositionData
        self.includeElementTypes = includeElementTypes
        self.includeSourceMapping = includeSourceMapping
        self.includeProcessingTime = includeProcessingTime
        self.includeSystemPrompt = includeSystemPrompt
        self.includeUserPrompt = includeUserPrompt
        self.includeLLMResponse = includeLLMResponse
        self.includeTokenCounts = includeTokenCounts
        self.includeOptimizationDetails = includeOptimizationDetails
        self.includeBeforeAfterComparison = includeBeforeAfterComparison
    }
}

public struct LogFileNaming: Codable, Sendable {
    public let pattern: String
    public let timestampFormat: String
    public let includeDocumentHash: Bool
    public let maxFileNameLength: Int
    
    public init(
        pattern: String = "dev_{timestamp}_{document}_{category}.{extension}",
        timestampFormat: String = "yyyyMMdd_HHmmss",
        includeDocumentHash: Bool = true,
        maxFileNameLength: Int = 100
    ) {
        self.pattern = pattern
        self.timestampFormat = timestampFormat
        self.includeDocumentHash = includeDocumentHash
        self.maxFileNameLength = maxFileNameLength
    }
}

