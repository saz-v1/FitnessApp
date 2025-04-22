import Foundation
import SwiftUI

/// Manages chat functionality and message persistence for the AI trainer feature
/// Uses the Singleton pattern to ensure a single instance across the app
@MainActor
class ChatManager: ObservableObject {
    /// Shared instance for app-wide access
    static let shared = ChatManager()
    
    /// Published array of chat messages that updates the UI when modified
    @Published var messages: [ChatMessage] = []
    
    /// Maximum number of messages to keep in the chat history
    private let maxMessages = 25
    
    /// UserDefaults instance for persistent storage
    private let userDefaults = UserDefaults.standard
    
    /// Key used to store chat messages in UserDefaults
    private let messagesKey = "chatMessages"
    
    /// Private initializer to enforce singleton pattern
    private init() {
        loadMessages()
    }
    
    /// Loads saved messages from UserDefaults when the app starts
    private func loadMessages() {
        if let data = userDefaults.data(forKey: messagesKey),
           let decodedMessages = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = decodedMessages
        }
    }
    
    /// Saves the current messages to UserDefaults for persistence
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            userDefaults.set(encoded, forKey: messagesKey)
        }
    }
    
    /// Sends a message and gets AI response
    /// - Parameter content: The message text to send
    func sendMessage(_ content: String) async {
        // Add user message to the chat
        let userMessage = ChatMessage(content: content, isUser: true)
        messages.append(userMessage)
        
        // Maintain message limit by removing oldest messages if needed
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
        
        // Save the updated messages
        saveMessages()
        
        // Get and process AI response
        do {
            let response = try await getAIResponse(for: content)
            let aiMessage = ChatMessage(content: response, isUser: false)
            messages.append(aiMessage)
            
            // Check message limit again after adding AI response
            if messages.count > maxMessages {
                messages.removeFirst(messages.count - maxMessages)
            }
            
            saveMessages()
        } catch {
            // Handle any errors during AI response
            let errorMessage = ChatMessage(content: "Sorry, I encountered an error. Please try again.", isUser: false)
            messages.append(errorMessage)
            saveMessages()
        }
    }
    
    /// Gets AI response for a given message using ClaudeService
    /// - Parameter message: The user's message to respond to
    /// - Returns: The AI's response as a string
    private func getAIResponse(for message: String) async throws -> String {
        let prompt = """
        You are a professional personal trainer and fitness expert. Respond to the user's message with helpful, 
        informative, and encouraging advice about fitness, exercise, and health. Keep responses concise but informative.
        
        User message: \(message)
        """
        
        return try await ClaudeService.shared.makeRequest(prompt: prompt)
    }
    
    /// Clears all messages from the chat history
    func clearChat() {
        messages.removeAll()
        saveMessages()
    }
} 