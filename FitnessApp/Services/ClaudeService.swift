import Foundation
import SwiftUI

// Service class to handle communication with Claude API
class ClaudeService: ObservableObject {
    // Singleton instance for app-wide access
    static let shared = ClaudeService()
    
    // API configuration
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    // Private initializer to enforce singleton pattern
    private init() {
        // Set API key directly - in production, use secure storage instead
        self.apiKey = "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"
        print("API Key loaded successfully")
    }
    
    // Main function to estimate calories from food description
    func estimateCalories(foodDescription: String) async throws -> Int {
        // Validate API key
        guard !apiKey.isEmpty else {
            print("Error: API key is empty")
            throw ClaudeError.missingAPIKey
        }
        
        // Construct the prompt for Claude
        let prompt = """
        Based on the following food description, estimate the approximate number of calories. 
        Return only the number, no explanation needed. If you can't make a reasonable estimate, return -1.
        
        Food description: \(foodDescription)
        """
        
        // Prepare the request body with model and message
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307", // Using Claude 3 haiku model as it is the cheapest and fastest model
            "max_tokens": 10, // Limit response length
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        // Create and configure the HTTP request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        print("Making API request to Claude...")
        
        do {
            // Serialize request body to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Make the API request
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            // Handle the response
            if let httpResponse = urlResponse as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                
                // Print raw response for debugging
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to convert data to string"
                print("Raw response: \(responseString)")
                
                // Check for HTTP errors
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("Error response: \(errorJson)")
                    }
                    throw ClaudeError.apiError(statusCode: httpResponse.statusCode)
                }
            }
            
            // Decode the response
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            print("Received response from Claude")
            
            // Extract calories from the response
            if let textBlock = claudeResponse.content.first(where: { $0.type == "text" }),
               let text = textBlock.text,
               let calories = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                print("Estimated calories: \(calories)")
                return calories
            }
            
            print("Could not parse calories from response")
            return -1
            
        } catch {
            // Handle any errors during the request
            print("Error making API request: \(error)")
            throw ClaudeError.networkError(error)
        }
    }
    
    /// Helper method to make API requests to Claude
    func makeRequest(prompt: String) async throws -> String {
        // Validate API key
        guard !apiKey.isEmpty else {
            print("Error: API key is empty")
            throw ClaudeError.missingAPIKey
        }
        
        // Prepare the request body
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307", // Using the cheapest and fastest model for near instant responses
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        // Create and configure the HTTP request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        do {
            // Serialize request body to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Make the API request
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            // Handle the response
            if let httpResponse = urlResponse as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("Error response: \(errorJson)")
                    }
                    throw ClaudeError.apiError(statusCode: httpResponse.statusCode)
                }
            }
            
            // Decode the response
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            
            // Extract text from the response
            if let textBlock = claudeResponse.content.first(where: { $0.type == "text" }),
               let text = textBlock.text {
                return text
            }
            
            throw ClaudeError.decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No text content found in response")))
            
        } catch {
            print("Error making API request: \(error)")
            throw ClaudeError.networkError(error)
        }
    }
}

// MARK: - Response Models

// Structure to decode Claude's API response
struct ClaudeResponse: Codable {
    let id: String              // Unique message ID
    let type: String            // Message type
    let role: String            // Role of the message sender
    let content: [ContentBlock] // Array of content blocks
    let model: String           // Model used for the response
    let stopReason: String?     // Reason why the response stopped
    let usage: Usage            // Token usage information
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

// Structure for content blocks in Claude's response
struct ContentBlock: Codable {
    let type: String  // Type of content (e.g., "text")
    let text: String? // The actual content text
}

// Structure for token usage information
struct Usage: Codable {
    let inputTokens: Int   // Number of input tokens used
    let outputTokens: Int  // Number of output tokens used
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Error Handling

// Custom error types for Claude service
enum ClaudeError: LocalizedError {
    case missingAPIKey           // API key is not configured
    case apiError(statusCode: Int) // API returned an error status
    case networkError(Error)     // Network-related errors
    case decodingError(DecodingError) // JSON decoding errors
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing. Please check your configuration."
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        }
    }
}
