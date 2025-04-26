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
        VStack(spacing: 0) {
            // Chat messages section with auto-scroll
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
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
            .onTapGesture {
                isFocused = false
            }
            
            // Message input section
            VStack(spacing: 0) {
                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    // Text input field with dynamic height
                    TextField("Ask your trainer...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isFocused)
                        .lineLimit(1...5)
                    
                    // Send button
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle("FitSwift AI Trainer")
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.isUser ? Color.green.opacity(0.4) : Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(20)
            
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