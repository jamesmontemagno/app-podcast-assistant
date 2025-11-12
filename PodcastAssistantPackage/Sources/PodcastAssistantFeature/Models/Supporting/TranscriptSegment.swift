import Foundation

/// Represents a single timestamped segment from a transcript
public struct TranscriptSegment: Hashable, Identifiable {
    public let id: UUID
    public let timestamp: String
    public let text: String
    
    public init(id: UUID = UUID(), timestamp: String, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: TranscriptSegment, rhs: TranscriptSegment) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents a refined/condensed segment that covers multiple original segments
public struct RefinedSegment: Identifiable {
    public let id: UUID
    public let startTimestamp: String
    public let endTimestamp: String
    public let summary: String
    public let originalSegmentIndices: [Int]
    
    public init(
        id: UUID = UUID(),
        startTimestamp: String,
        endTimestamp: String,
        summary: String,
        originalSegmentIndices: [Int]
    ) {
        self.id = id
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.summary = summary
        self.originalSegmentIndices = originalSegmentIndices
    }
    
    /// Human-readable time range
    public var timeRange: String {
        "\(startTimestamp) - \(endTimestamp)"
    }
    
    /// Number of original segments this refined segment covers
    public var segmentsCovered: Int {
        originalSegmentIndices.count
    }
}

// MARK: - String Extensions for Timestamp Utilities

public extension String {
    /// Converts timestamp string to seconds for comparison and calculations
    /// Supports formats: MM:SS, MM:SS.ss, HH:MM:SS, HH:MM:SS.ss
    func timestampToSeconds() -> Double {
        let parts = self.components(separatedBy: ":")
        guard !parts.isEmpty else { return 0 }
        
        var seconds: Double = 0
        
        if parts.count == 2 {
            // MM:SS or MM:SS.ss
            if let minutes = Double(parts[0]), let secs = Double(parts[1]) {
                seconds = minutes * 60 + secs
            }
        } else if parts.count == 3 {
            // HH:MM:SS or HH:MM:SS.ss
            if let hours = Double(parts[0]), let minutes = Double(parts[1]), let secs = Double(parts[2]) {
                seconds = hours * 3600 + minutes * 60 + secs
            }
        }
        
        return seconds
    }
    
    /// Computes similarity score between two strings using word overlap coefficient
    /// Returns value between 0.0 (no similarity) and 1.0 (identical)
    func similarityScore(to other: String) -> Double {
        // Normalize and tokenize
        let words1 = self.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let words2 = other.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !words1.isEmpty && !words2.isEmpty else { return 0.0 }
        
        // Convert to sets for intersection
        let set1 = Set(words1)
        let set2 = Set(words2)
        
        // Overlap coefficient: intersection / min(|A|, |B|)
        let intersection = set1.intersection(set2).count
        let minSize = min(set1.count, set2.count)
        
        return Double(intersection) / Double(minSize)
    }
}
