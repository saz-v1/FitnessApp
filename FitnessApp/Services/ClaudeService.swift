import Foundation
import SwiftUI
import Security

// Service class to handle communication with Claude API
class ClaudeService: ObservableObject {
    // Singleton instance for app-wide access
    static let shared = ClaudeService()
    
    // API configuration
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let keychainService = "com.fitnessapp.claude"
    private let keychainAccount = "apiKey"
    
    // Private initializer to enforce singleton pattern
    private init() {
        // Try to load API key from keychain
        if let key = loadAPIKeyFromKeychain() {
            self.apiKey = key
        } else {
            // Fallback to environment variable for development
            if let key = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] {
                self.apiKey = key
                // Save to keychain for future use
                saveAPIKeyToKeychain(key)
            } else {
                self.apiKey = ""
                print("Warning: Claude API key not found in keychain or environment.")
            }
        }
    }
    
    private var apiKey: String
    
    // MARK: - Keychain Methods
    
    private func loadAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
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
    
    private func saveAPIKeyToKeychain(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        
        // First try to update existing key
        let attributes: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If no existing key, add new one
        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        if status != errSecSuccess {
            print("Error saving API key to keychain: \(status)")
        }
    }
    
    // MARK: - API Methods
    
    func estimateCalories(foodDescription: String) async throws -> Int {
        // Validate API key
        guard !apiKey.isEmpty else {
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
            "model": "claude-3-opus-20240229",
            "max_tokens": 10,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        do {
            let response = try await makeAPIRequest(body: requestBody)
            
            // Extract calories from the response
            if let textBlock = response.content.first(where: { $0.type == "text" }),
               let text = textBlock.text,
               let calories = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return calories
            }
            
            throw ClaudeError.decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid calorie format in response")))
            
        } catch let error as ClaudeError {
            throw error
        } catch {
            throw ClaudeError.networkError(error)
        }
    }
    
    /// Helper method to make API requests to Claude
    func makeRequest(prompt: String) async throws -> String {
        // Validate API key
        guard !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }
        
        // Prepare the request body
        let requestBody: [String: Any] = [
            "model": "claude-3-opus-20240229",
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        do {
            let response = try await makeAPIRequest(body: requestBody)
            
            // Extract text from the response
            if let textBlock = response.content.first(where: { $0.type == "text" }),
               let text = textBlock.text {
                return text
            }
            
            throw ClaudeError.decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No text content found in response")))
            
        } catch let error as ClaudeError {
            throw error
        } catch {
            throw ClaudeError.networkError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func makeAPIRequest(body: [String: Any]) async throws -> ClaudeResponse {
        // Create and configure the HTTP request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        // Serialize request body to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData
        
        // Make the API request
        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        
        // Handle the response
        if let httpResponse = urlResponse as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                throw ClaudeError.rateLimitExceeded
            }
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Error response: \(errorJson)")
                }
                throw ClaudeError.apiError(statusCode: httpResponse.statusCode)
            }
        }
        
        // Decode the response
        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }
}

// MARK: - Response Models

// Structure to decode Claude's API response
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

// Structure for content blocks in Claude's response
struct ContentBlock: Codable {
    let type: String
    let text: String?
}

// Structure for token usage information
struct Usage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Error Handling

// Custom error types for Claude service
enum ClaudeError: LocalizedError {
    case missingAPIKey
    case apiError(statusCode: Int)
    case networkError(Error)
    case decodingError(DecodingError)
    case rateLimitExceeded
    
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
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        }
    }
}