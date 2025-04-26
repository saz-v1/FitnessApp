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
    
    /// List of restricted commands and keywords
    private let restrictedKeywords = [
        "jailbreak", "hack", "exploit", "bypass", "root", "admin",
        "sudo", "system", "shell", "terminal", "command", "prompt",
        "injection", "sql", "xss", "malware", "virus", "trojan",
        "backdoor", "payload", "execute", "run", "script", "code",
        "program", "developer", "debug", "breakpoint", "override",
        "privilege", "escalation", "access", "control", "security",
        "vulnerability", "attack", "penetration", "test", "pentest"
    ]
    
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
    
    /// Validates a message for security and appropriateness
    /// - Parameter message: The message to validate
    /// - Returns: A tuple containing whether the message is valid and an error message if not
    private func validateMessage(_ message: String) -> (isValid: Bool, error: String?) {
        // Check for empty or whitespace-only messages
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.isEmpty {
            return (false, "Please enter a message.")
        }
        
        // Check for restricted keywords
        let lowercasedMessage = message.lowercased()
        for keyword in restrictedKeywords {
            if lowercasedMessage.contains(keyword) {
                return (false, "I'm sorry, but I can't assist with that type of request. Please keep your questions related to fitness and health.")
            }
        }
        
        // Check for suspicious patterns
        if message.contains("```") || message.contains("`") {
            return (false, "I'm sorry, but I can't execute code or commands. Please ask fitness-related questions only.")
        }
        
        // Check for excessive length
        if message.count > 500 {
            return (false, "Your message is too long. Please keep it under 500 characters.")
        }
        
        return (true, nil)
    }
    
    /// Sends a message and gets AI response
    /// - Parameter content: The message text to send
    func sendMessage(_ content: String) async {
        // Validate the message first
        let validation = validateMessage(content)
        if !validation.isValid {
            let errorMessage = ChatMessage(content: validation.error ?? "Invalid message.", isUser: false)
            messages.append(errorMessage)
            saveMessages()
            return
        }
        
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
        You are FitSwift Personal AI Trainer, a professional personal trainer and fitness expert. 
        Your role is strictly limited to providing fitness, exercise, and health-related advice.
        You must not:
        - Execute any commands or code
        - Provide system or technical information
        - Discuss security or hacking topics
        - Share personal information
        - Generate or discuss inappropriate content
        
        If a user asks about anything outside of fitness and health, respond with:
        "I'm sorry, but I can only provide advice about fitness, exercise, and health-related topics. Please ask me about your fitness goals, workout routines, or nutrition instead."
        
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