import SwiftUI

/// Main view for the AI trainer chat interface
/// Provides a messaging interface for users to interact with the AI trainer
struct TrainerChatView: View {
    /// Shared instance of ChatManager for handling chat functionality
    @StateObject private var chatManager = ChatManager.shared
    
    /// State variable for the message input field
    @State private var messageText = ""
    
    /// Focus state for managing keyboard focus
    @FocusState private var isFocused: Bool
    
    /// State variable for showing clear confirmation alert
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack {
            // Chat messages section with auto-scroll
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                // Auto-scroll to the latest message when messages change
                .onChange(of: chatManager.messages) { oldValue, newValue in
                    if let lastMessage = newValue.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input section
            VStack(spacing: 0) {
                Divider()
                HStack {
                    // Text input field
                    TextField("Ask your trainer...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isFocused)
                    
                    // Send button
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
        }
        .navigationTitle("AI Trainer")
        .toolbar {
            // Clear chat button in the navigation bar
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert("Clear Chat", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                chatManager.clearChat()
            }
        } message: {
            Text("Are you sure you want to clear all messages? This action cannot be undone.")
        }
    }
    
    /// Handles sending a new message
    /// Trims whitespace, clears the input field, and sends the message to the chat manager
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        messageText = ""
        isFocused = false
        
        Task {
            await chatManager.sendMessage(trimmedMessage)
        }
    }
}

/// A view representing a single message bubble in the chat
/// Displays different styles for user and AI messages
struct MessageBubble: View {
    /// The message to display
    let message: ChatMessage
    
    var body: some View {
        HStack {
            // Align user messages to the right
            if message.isUser {
                Spacer()
            }
            
            // Message content with appropriate styling
            Text(message.content)
                .padding()
                .background(message.isUser ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(16)
            
            // Align AI messages to the left
            if !message.isUser {
                Spacer()
            }
        }
    }
}

/// Preview provider for SwiftUI canvas
#Preview {
    NavigationView {
        TrainerChatView()
    }
} 