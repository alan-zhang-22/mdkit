# mdkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://developer.apple.com/macos/)

**Intelligent PDF to Markdown conversion tool using Apple Vision Framework and local LLMs**

mdkit is a powerful, intelligent PDF to Markdown conversion tool that leverages Apple's Vision framework for advanced document analysis and local Large Language Models (LLMs) for markdown optimization. It's designed specifically for technical documents, academic papers, and structured content that requires high-quality conversion.

## ✨ Features

### 🧠 **Intelligent Document Analysis**
- **Apple Vision Framework Integration**: Advanced OCR with document structure detection
- **Position-Based Processing**: Maintains logical document flow from top to bottom
- **Duplicate Detection**: Automatically identifies and resolves overlapping content
- **Smart Element Recognition**: Detects titles, headers, paragraphs, tables, lists, and barcodes

### 📋 **Header & Footer Management**
- **Region-Based Detection**: Precise header/footer detection using absolute coordinates
- **Frequency Analysis**: Identifies repetitive page elements across documents
- **Configurable Thresholds**: Adjustable detection parameters for different document types
- **Multi-Region Support**: Handles complex layouts with multiple header/footer areas

### 🔗 **Header & List Detection**
- **Pattern Recognition**: Automatically detects numbered, lettered, and named headers
- **Smart Merging**: Combines split headers and list items using OCR position data
- **Level Calculation**: Automatic header level detection and markdown hierarchy
- **Nested List Support**: Handles complex nested list structures with indentation

### 🤖 **Local LLM Integration**
- **llama.cpp Backend**: Local processing with LocalLLMClientLlama
- **Language Detection**: Automatic document language detection using Apple's Natural Language framework
- **Multi-Language Prompts**: Support for English, Chinese, and other languages
- **Configurable Prompts**: Customizable system and user prompts with template placeholders
- **Markdown Optimization**: AI-powered structure improvement and formatting enhancement

### ⚙️ **Flexible Configuration**
- **JSON Configuration**: Comprehensive configuration system with no hardcoded values
- **Environment Support**: Development, production, and testing configurations
- **Configuration Inheritance**: Base configs with environment-specific overrides
- **Validation**: JSON schema validation and error checking

### 📁 **Centralized File Management**
- **Consistent Naming**: Timestamped files with document hashes
- **Organized Output**: Separate directories for markdown, logs, and temporary files
- **Comprehensive Logging**: Detailed logs for every processing step
- **Traceability**: Link generated markdown to source OCR elements and LLM prompts

### 🧪 **Testing & Quality**
- **Lightweight Dependency Injection**: Easy testing with protocol-based interfaces
- **Comprehensive Testing**: Unit tests, integration tests, and performance benchmarks
- **Mock Implementations**: Simple mocking for external dependencies
- **Quality Assurance**: >90% test coverage target

## 🚀 Quick Start

### Prerequisites
- macOS 13.0+ (Ventura)
- Xcode 15.0+
- Swift 5.9+
- Local LLM model (optional, for markdown optimization)

### Installation

1. **Clone the repository**
   ```bash
   git clone --recursive https://github.com/alan-zhang-22/mdkit.git
   cd mdkit
   ```

2. **Open in Xcode**
   ```bash
   open mdkit.xcodeproj
   ```

3. **Build and run**
   ```bash
   swift build
   ```

### Basic Usage

```bash
# Convert a PDF using default configuration
mdkit input.pdf

# Use custom configuration
mdkit --config my-config.json input.pdf

# Generate configuration template
mdkit --generate-config > template.json

# Validate configuration
mdkit --validate-config my-config.json

# Dry run (test without processing)
mdkit --dry-run input.pdf
```

## 📖 Configuration

mdkit uses a comprehensive JSON configuration system. Here's a basic example:

```json
{
  "version": "1.0",
  "description": "mdkit PDF to Markdown conversion configuration",
  
  "headerFooterDetection": {
    "enabled": true,
    "regionBasedDetection": {
      "enabled": true,
      "headerRegionY": 72.0,
      "footerRegionY": 720.0,
      "regionTolerance": 5.0
    }
  },
  
  "llm": {
    "enabled": true,
    "backend": "LocalLLMClientLlama",
    "model": {
      "id": "llama-3.1-8b-instruct-q4_0",
      "localPath": "~/models/llama-3.1-8b-instruct-q4_0.gguf"
    },
    "parameters": {
      "temperature": 0.1,
      "context": 4096,
      "threads": 8
    }
  }
}
```

### Configuration Locations
1. **Command-line specified path** (`--config`)
2. **Project-specific config** (`./mdkit-config.json`)
3. **User config** (`~/.config/mdkit/config.json`)
4. **Built-in defaults**

## 🏗️ Architecture

### Core Components

- **`DocumentElement`**: Unified representation of all document elements
- **`UnifiedDocumentProcessor`**: Collects and processes Vision framework output
- **`HeaderFooterDetector`**: Intelligent header/footer detection and filtering
- **`HeaderAndListDetector`**: Pattern-based header and list item detection
- **`MarkdownGenerator`**: Generates properly structured markdown output
- **`LLMProcessor`**: Local LLM integration for markdown optimization
- **`FileManager`**: Centralized file management and logging

### Dependency Injection

mdkit uses lightweight dependency injection for improved testability:

```swift
protocol LLMClient {
    func textStream(from input: LLMInput) async throws -> AsyncThrowingStream<String, Error>
    func generateText(from input: LLMInput) async throws -> String
}

class LLMProcessor {
    let client: any LLMClient
    let languageDetector: any LanguageDetecting
    
    init(client: any LLMClient, languageDetector: any LanguageDetecting) {
        self.client = client
        self.languageDetector = languageDetector
    }
}
```

## 🧪 Testing

### Running Tests
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter CoreTests

# Run with verbose output
swift test --verbose
```

### Test Coverage
- **Unit Tests**: >90% code coverage target
- **Integration Tests**: End-to-end workflow validation
- **Performance Tests**: Memory usage and processing speed benchmarks
- **Mock Implementations**: Easy testing of external dependencies

## 📚 Documentation

- **[Implementation Plan](docs/implementation-plan.md)**: Detailed development roadmap
- **[Complete Implementation Guide](docs/mdkit-complete-implementation-guide.md)**: Comprehensive implementation status, architecture, and roadmap

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Style
- Follow Swift style guidelines
- Use SwiftLint for code formatting
- Write comprehensive tests
- Document public APIs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Apple Vision Framework**: Advanced document analysis and OCR
- **LocalLLMClient**: Local LLM integration capabilities
- **llama.cpp**: Efficient local language model inference
- **Apple Natural Language Framework**: Language detection and analysis

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/alan-zhang-22/mdkit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/alan-zhang-22/mdkit/discussions)
- **Wiki**: [Project Wiki](https://github.com/alan-zhang-22/mdkit/wiki)

## 🔮 Roadmap

- [ ] **Phase 1**: Foundation & Core Infrastructure
- [ ] **Phase 2**: Document Processing Core
- [ ] **Phase 3**: Header & Footer Detection
- [ ] **Phase 4**: File Management & Logging
- [ ] **Phase 5**: LLM Integration
- [ ] **Phase 6**: Integration & Testing
- [ ] **Phase 7**: Optimization & Polish

See our [Implementation Plan](docs/implementation-plan.md) for detailed progress and timeline.

---

**Made with ❤️ for the open source community**
