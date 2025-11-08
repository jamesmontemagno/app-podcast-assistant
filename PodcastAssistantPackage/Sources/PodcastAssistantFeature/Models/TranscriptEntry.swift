import Foundation

/// Represents a single entry in a transcript with timestamp and text
public struct TranscriptEntry: Identifiable {
    public let id = UUID()
    public let timestamp: String
    public let text: String
    
    public init(timestamp: String, text: String) {
        self.timestamp = timestamp
        self.text = text
    }
}
