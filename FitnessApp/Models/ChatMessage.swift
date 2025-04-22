import Foundation

/// A model representing a single message in the chat conversation
/// Conforms to Identifiable for unique identification in SwiftUI lists, Codable for serialization, and Equatable for change detection
struct ChatMessage: Identifiable, Codable, Equatable {
    /// Unique identifier for each message
    let id: UUID
    
    /// The actual content/text of the message
    let content: String
    
    /// Boolean indicating if the message is from the user (true) or AI (false)
    let isUser: Bool
    
    /// Timestamp when the message was created
    let timestamp: Date
    
    /// Initializes a new chat message
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID if not provided)
    ///   - content: The message text
    ///   - isUser: Whether the message is from the user
    ///   - timestamp: When the message was created (defaults to current time if not provided)
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
    
    // Implement Equatable
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isUser == rhs.isUser &&
        lhs.timestamp == rhs.timestamp
    }
} 