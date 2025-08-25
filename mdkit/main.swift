//
//  main.swift
//  mdkit
//
//  Created by alan zhang on 2025/8/25.
//

import Foundation

print("Hello, World!")

import LocalLLMClient
import LocalLLMClientLlama

// Create a model
let model = LLMSession.DownloadModel.llama(
    id: "lmstudio-community/gemma-3-4B-it-qat-GGUF",
    model: "gemma-3-4B-it-QAT-Q4_0.gguf",
    parameter: .init(
        temperature: 0.7,   // Randomness (0.0〜1.0)
        topK: 40,           // Top-K sampling
        topP: 0.9,          // Top-P (nucleus) sampling
        options: .init(responseFormat: .json) // Response format
    )
)

// You can track download progress
try await model.downloadModel { progress in
    print("Download progress: \(progress)")
}

// Create a session with the downloaded model
let session = LLMSession(model: model)

// Generate a response with a specific prompt
let response = try await session.respond(to: """
Create the beginning of a synopsis for an epic story with a cat as the main character.
Format it in JSON, as shown below.
{
    "title": "<title>",
    "content": "<content>",
}
""")
print(response)

// You can also add system messages before asking questions
session.messages = [.system("You are a helpful assistant.")]
