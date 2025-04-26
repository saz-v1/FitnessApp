import Foundation
import Security
import SwiftUI

/// Service for interacting with Claude AI for fitness-related features
class ClaudeService: ObservableObject {
    /// Singleton instance for app-wide access
    static let shared = ClaudeService()
    
    /// API key for Claude service
    private let apiKey: String
    
    /// Base URL for Claude API
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    /// Keychain service name for API key storage
    private let keychainService = "com.yourdomain.FitnessApp"
    
    /// Keychain account for API key
    private let keychainAccount = "ClaudeAPIKey"
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Set API key directly - in production, use secure storage instead
        self.apiKey = "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"
        print("API Key loaded successfully")
    }
    
    /// Saves API key to keychain
    /// - Parameters:
    ///   - key: The API key to save
    ///   - service: The keychain service name
    ///   - account: The keychain account
    private static func saveAPIKeyToKeychain(_ key: String, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key.data(using: .utf8)!
        ]
        
        // First try to delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Then add the new key
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("Error saving API key to keychain: \(status)")
            return
        }
    }
    
    /// Retrieves API key from keychain
    /// - Parameters:
    ///   - service: The keychain service name
    ///   - account: The keychain account
    /// - Returns: The API key if found, nil otherwise
    private static func getAPIKeyFromKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Main function to estimate calories from food description
    func estimateCalories(foodDescription: String) async throws -> Int {
        // Validate API key
        guard !apiKey.isEmpty else {
            print("Error: API key is empty")
            throw ClaudeError.missingAPIKey
        }
        
        // Prepare the request body with model and message
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 10,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a calorie calculator. You must ONLY return a single number. No text, no explanations, no formatting. Just the number. If you cannot estimate, return -1."
                ],
                [
                    "role": "user",
                    "content": "\(foodDescription)"
                ]
            ]
        ]
        
        // Create and configure the HTTP request
        guard let url = URL(string: baseURL) else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        print("Making API request to Claude for calorie estimation...")
        print("Food description: \(foodDescription)")
        
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
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw calorie estimation response: \(responseString)")
                }
                
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
            
            // Print all content blocks for debugging
            print("Number of content blocks: \(claudeResponse.content.count)")
            for (index, block) in claudeResponse.content.enumerated() {
                print("Content block \(index):")
                print("  Type: \(block.type)")
                print("  Text: \(block.text ?? "nil")")
            }
            
            // Extract calories from the response
            if let textBlock = claudeResponse.content.first(where: { $0.type == "text" }),
               let text = textBlock.text {
                // Clean up the text and try to extract the number
                let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                print("Cleaned response text: '\(cleanedText)'")
                
                // Try to extract just the number
                if let calories = Int(cleanedText) {
                    print("Successfully parsed calories: \(calories)")
                    return calories
                } else {
                    // Try to extract number from text that might contain other characters
                    let numbers = cleanedText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .filter { !$0.isEmpty }
                        .compactMap { Int($0) }
                    
                    print("Found numbers in text: \(numbers)")
                    
                    if let firstNumber = numbers.first {
                        print("Extracted calories from text: \(firstNumber)")
                        return firstNumber
                    }
                }
            }
            
            print("Could not parse calories from response")
            return -1
            
        } catch {
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
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        // Create and configure the HTTP request
        guard let url = URL(string: baseURL) else {
            throw ClaudeError.invalidURL
        }
        
        var request = URLRequest(url: url)
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
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw API Response: \(responseString)")
            }
            
            // Decode the response
            do {
                let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
                
                // Extract text from the response
                if let textBlock = claudeResponse.content.first(where: { $0.type == "text" }),
                   let text = textBlock.text {
                    return text
                }
                
                throw ClaudeError.decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No text content found in response")))
            } catch {
                print("Decoding error: \(error)")
                throw ClaudeError.decodingError(error as! DecodingError)
            }
            
        } catch let error as ClaudeError {
            throw error
        } catch {
            print("Network error: \(error)")
            throw ClaudeError.networkError(error)
        }
    }
    
    /// Generates workout analytics and insights
    /// - Parameter workouts: Array of workout records to analyze
    /// - Returns: Analysis and insights about the workouts
    func generateWorkoutAnalytics(workouts: [WorkoutRecord]) async throws -> String {
        let prompt = """
        Analyze these workout records and provide insights:
        \(workouts.map { "- \($0.type.rawValue) workout on \($0.date.formatted()): \(Int($0.duration/60)) minutes, \($0.intensity.rawValue) intensity" }.joined(separator: "\n"))
        
        Include:
        1. Workout frequency analysis
        2. Intensity distribution
        3. Most common workout types
        4. Progress over time
        5. Recommendations for improvement
        
        Format the response in a clear, easy-to-read structure.
        """
        
        return try await makeRequest(prompt: prompt)
    }
    
    /// Estimates calories for a food item
    /// - Parameter foodDescription: Description of the food item
    /// - Returns: Estimated calorie content
    func estimateFoodCalories(foodDescription: String) async throws -> String {
        let prompt = """
        Estimate the calorie content for this food item:
        \(foodDescription)
        
        Return ONLY the number of calories, no additional information.
        """
        
        return try await makeRequest(prompt: prompt)
    }
}

// MARK: - Response Models

/// Response model for Claude API
struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: Usage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }
}

/// Content block in Claude's response
struct ContentBlock: Codable {
    let type: String
    let text: String?
}

/// Usage information for the API call
struct Usage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Error Handling

/// Custom error types for Claude service
enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case apiError(statusCode: Int)
    case networkError(Error)
    case decodingError(DecodingError)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing. Please check your configuration."
        case .invalidURL:
            return "Invalid API URL."
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        }
    }
}
