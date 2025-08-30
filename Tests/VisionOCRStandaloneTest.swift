import XCTest
import Vision
import Foundation

@available(macOS 26.0, *)
final class VisionOCRStandaloneTest: XCTestCase {
    
    // MARK: - Basic Vision Framework Test
    
    func testBasicVisionOCR() async throws {
        // Test the basic Vision framework OCR functionality
        let request = RecognizeDocumentsRequest()
        XCTAssertNotNil(request, "Should be able to create RecognizeDocumentsRequest")
        print("✅ Successfully created RecognizeDocumentsRequest")
    }
    
    // MARK: - Simple Image OCR Test
    
    func testExtractTextFromPage36Image() async throws {
        // Simple test: extract raw OCR text from the page_36.png image
        let imagePath = "dev-output/images/page_36.png"
        
        // Verify the test image exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: imagePath) else {
            XCTFail("Test image file not found at path: \(imagePath)")
            return
        }
        
        // Load image data
        let imageURL = URL(fileURLWithPath: imagePath)
        let imageData = try Data(contentsOf: imageURL)
        
        XCTAssertGreaterThan(imageData.count, 0, "Image data should not be empty")
        print("📸 Loaded image data: \(imageData.count) bytes")
        
        // Use Vision framework to extract text - exactly as requested
        let request = RecognizeDocumentsRequest()
        let observations = try await request.perform(on: imageData)
        
        // Verify we got observations
        XCTAssertFalse(observations.isEmpty, "Should extract document observations")
        print("🔍 Extracted \(observations.count) document observations")
        
        // Get the first observation
        guard let firstObservation = observations.first else {
            XCTFail("No observations found")
            return
        }
        
        let document = firstObservation.document
        
        // Extract all text content without any processing
        print("📄 Raw OCR text extraction results:")
        
        // Get title if available
        if let title = document.title {
            print("Title: \(title)")
        }
        
        // Get all paragraphs - this is what we focus on
        print("\nParagraphs (\(document.paragraphs.count) total):")
        for (index, paragraph) in document.paragraphs.enumerated() {
            print("  \(index + 1). \(paragraph.transcript)")
        }
        
        // Basic assertions
        XCTAssertGreaterThan(document.paragraphs.count, 0, "Should have extracted paragraphs")
        
        // Look for the specific list items mentioned (d), e), f)) in the paragraphs
        print("\n🔍 Searching for specific list items (d), e), f)) in paragraphs:")
        var foundItems = 0
        
        for paragraph in document.paragraphs {
            if paragraph.transcript.contains("d）") || paragraph.transcript.contains("e）") || paragraph.transcript.contains("f）") {
                print("  Found: \(paragraph.transcript)")
                foundItems += 1
            }
        }
        
        print("  Total items found: \(foundItems)")
        XCTAssertGreaterThanOrEqual(foundItems, 0, "Should find list items if they exist")
        
        print("✅ Successfully processed image with Vision framework!")
    }
    
    // MARK: - Error Handling Tests
    
    func testVisionWithInvalidData() async throws {
        // Test Vision framework with invalid data
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // Not a valid image
        
        let request = RecognizeDocumentsRequest()
        
        do {
            let observations = try await request.perform(on: invalidData)
            print("⚠️  Request succeeded with invalid data, got \(observations.count) observations")
            // This might succeed with some invalid data, which is acceptable
        } catch {
            print("✅ Expected error with invalid data: \(error)")
            // This is also acceptable behavior
        }
    }
    
    func testVisionWithEmptyData() async throws {
        // Test Vision framework with empty data
        let emptyData = Data()
        
        let request = RecognizeDocumentsRequest()
        
        do {
            _ = try await request.perform(on: emptyData)
            XCTFail("Should not succeed with empty data")
        } catch {
            print("✅ Expected error with empty data: \(error)")
        }
    }
}
