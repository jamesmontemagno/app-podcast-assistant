import Foundation
import FoundationModels

/// Service for condensing large timestamped transcripts into smaller refined segments
/// Based on TranscriptSummarizer implementation by Frank A. Krueger
@available(macOS 26.0, *)
@MainActor
public class TranscriptionShrinkerService {
    // MARK: - Configuration
    
    public struct ShrinkConfig {
        /// Maximum characters per window (estimated JSON size for LLM context)
        public var maxWindowCharacters: Int
        /// Overlap as a percentage (0.0 to 1.0) of the max window size
        public var overlap: Double
        
        public init(
            maxWindowCharacters: Int = 5000,
            overlap: Double = 0.2
        ) {
            self.maxWindowCharacters = maxWindowCharacters
            self.overlap = overlap
        }
        
        public static var `default`: ShrinkConfig {
            ShrinkConfig()
        }
    }
    
    // MARK: - Public Properties
    
    public var logHandler: ((String) -> Void)?
    
    // MARK: - Dependencies
    
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public API
    
    /// Shrinks a large timestamped transcript into refined segments
    /// - Parameters:
    ///   - transcript: Raw transcript with timestamps (format: timestamp\nspeaker\ntext\n\n...)
    ///   - config: Configuration for windowing
    /// - Returns: Array of summarized segments
    public func shrinkTranscript(
        _ transcript: String,
        config: ShrinkConfig = .default
    ) async throws -> [SummarizedSegment] {
        log("📝 [Shrinker] Starting transcript shrinking process")
        
        // Parse transcript into structured segments
        let segments = parseSegments(from: transcript)
        log("📊 [Shrinker] Parsed \(segments.count) segments from transcript")
        
        guard !segments.isEmpty else {
            throw ShrinkError.noSegmentsFound
        }
        
        // Create windows with overlap
        let windows = createWindows(segments, maxWindowCharCount: config.maxWindowCharacters, overlap: config.overlap)
        log("📦 [Shrinker] Created \(windows.count) windows")
        
        // Summarize each window
        var allSummarizedSegments: [SummarizedSegment] = []
        
        for (index, window) in windows.enumerated() {
            log("⏳ [Shrinker] Processing window \(index + 1)/\(windows.count) - \(window.segments.count) segments")
            
            let summarized = try await summarize(window: window)
            allSummarizedSegments.append(contentsOf: summarized)
            
            log("✅ [Shrinker] Window \(index + 1) complete: \(summarized.count) summaries")
        }
        
        log("✨ [Shrinker] Complete: \(segments.count) → \(allSummarizedSegments.count) segments (\(reductionPercent(from: segments.count, to: allSummarizedSegments.count))% reduction)")
        
        return allSummarizedSegments
    }
    
    // MARK: - Parsing
    
    /// Parse transcript into segments
    /// Format: timestamp\nspeaker\ntext\n\n (double newline separates segments)
    private func parseSegments(from text: String) -> [TranscriptSegmentWithSpeaker] {
        let parts = text.split(separator: "\n\n")
        return parts.compactMap { part in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = trimmed.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
            if lines.count >= 3 {
                let timestamp = String(lines[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let speaker = String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                let segmentText = String(lines[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                return TranscriptSegmentWithSpeaker(timestamp: timestamp, speaker: speaker, text: segmentText)
            } else {
                return nil
            }
        }
    }
    
    // MARK: - Windowing
    
    /// Create windows from segments based on character count with overlap
    private func createWindows(_ originalSegments: [TranscriptSegmentWithSpeaker], maxWindowCharCount: Int, overlap: Double) -> [TranscriptWindow] {
        var windows: [TranscriptWindow] = []
        var window: TranscriptWindow = TranscriptWindow(segments: [])
        
        for seg in originalSegments {
            window.segments.append(seg)
            
            if window.jsonCharCount >= maxWindowCharCount {
                windows.append(window)
                var newWindow = TranscriptWindow(segments: [])
                // Add some overlap
                let overlapChars = Int(Double(maxWindowCharCount) * overlap)
                var nextSegIndex = window.segments.count - 1
                while newWindow.jsonCharCount < overlapChars, nextSegIndex >= 0 {
                    newWindow.segments.insert(window.segments[nextSegIndex], at: 0)
                    nextSegIndex -= 1
                }
                window = newWindow
            }
        }
        
        if !window.segments.isEmpty {
            windows.append(window)
        }
        
        return windows
    }
    
    // MARK: - Summarization
    
    /// Summarize a window of transcript segments
    private func summarize(window: TranscriptWindow) async throws -> [SummarizedSegment] {
        let session = LanguageModelSession {
            """
You are an expert at summarizing recorded transcripts of podcast conversations.

You will be given a series of transcript segments, each with a timestamp, speaker name, and text and your goal is to produce a concise summary of the content.

Focus on the key points, main ideas, and important details discussed in the segments. Avoid including trivial or repetitive information.

When summarizing, you can complete elide short back-and-forth exchanges that do not add significant value to the overall content.

For example, given the following transcript segments:
"""
            TranscriptWindow(segments: [
                TranscriptSegmentWithSpeaker(timestamp: "00:15:03", speaker: "Alice", text: "I had a terrible day today. First, I missed my bus, then I spilled coffee all over my new shirt."),
                TranscriptSegmentWithSpeaker(timestamp: "00:15:15", speaker: "Bob", text: "Oh"),
                TranscriptSegmentWithSpeaker(timestamp: "00:15:17", speaker: "Alice", text: "Yeah"),
                TranscriptSegmentWithSpeaker(timestamp: "00:15:20", speaker: "Bob", text: "Well that's tough. Anything else happen?"),
                TranscriptSegmentWithSpeaker(timestamp: "00:15:45", speaker: "Alice", text: "Not really, just one of those days."),
            ])
"""
You might produce the summary:
"""
            [
                SummarizedSegment(firstSegmentTimestamp: "00:15:03", summary: "Alice had a rough day, missing her bus and spilling coffee on her shirt.")
            ]
"""
Long monologues or detailed explanations should be summarized to capture the essence without losing important context. For example, given the following transcript segments:
"""
            TranscriptWindow(segments: [
                TranscriptSegmentWithSpeaker(timestamp: "00:30:10", speaker: "Charlie", text: "So, I was thinking about the implications of quantum computing on modern cryptography. As you know, many of our current encryption methods rely on the difficulty of factoring large prime numbers. However, with the advent of quantum algorithms like Shor's algorithm, this could potentially render our existing cryptographic systems obsolete. This means we need to start exploring quantum-resistant algorithms to ensure data security in the future."),
            ])
"""
You might produce the summary:
"""
            [SummarizedSegment(firstSegmentTimestamp: "00:30:10", summary: "Charlie discussed the impact of quantum computing on cryptography, highlighting the need for quantum-resistant algorithms due to vulnerabilities in current encryption methods.")]
"""
        }
        
        let prompt = Prompt {
"""
Here are the transcript segments to summarize:
"""
            window
        }
        
        let response = try await session.respond(to: prompt, generating: [SummarizedSegment].self)
        return response.content
    }
    
    // MARK: - Helpers
    
    private func log(_ message: String) {
        logHandler?(message)
        print(message)
    }
    
    private func reductionPercent(from original: Int, to refined: Int) -> Int {
        guard original > 0 else { return 0 }
        return Int((1.0 - Double(refined) / Double(original)) * 100)
    }
    
    // MARK: - Errors
    
    public enum ShrinkError: LocalizedError {
        case noSegmentsFound
        case condensationFailed
        
        public var errorDescription: String? {
            switch self {
            case .noSegmentsFound:
                return "No timestamped segments found in transcript"
            case .condensationFailed:
                return "Failed to condense transcript segments"
            }
        }
    }
}

// MARK: - Internal Types

/// Segment with speaker information (used for parsing)
@Generable(description: "A piece of dialog from a recorded transcript.")
struct TranscriptSegmentWithSpeaker: Identifiable {
    var id: String { timestamp }
    let timestamp: String
    let speaker: String
    let text: String
    
    var jsonCharCount: Int {
        timestamp.count + speaker.count + text.count + 50
    }
}

/// A window of segments to be processed together
@Generable(description: "A contiguous section of a recorded transcript.")
struct TranscriptWindow: Identifiable {
    var id: String { segments.first?.timestamp ?? "0" }
    var segments: [TranscriptSegmentWithSpeaker]
    
    var jsonCharCount: Int {
        segments.reduce(0) { $0 + $1.jsonCharCount } + 20
    }
}

/// A summary of one or more segments of a recorded transcript
@Generable(description: "A summary of one or more segments of a recorded transcript.")
public struct SummarizedSegment: Codable, Sendable, Identifiable {
    public var id: String { firstSegmentTimestamp }
    
    @Guide(description: "The timestamp of the first segment summarized.")
    public let firstSegmentTimestamp: String
    
    @Guide(description: "The summary of one or more transcript segments (starting at `firstSegmentTimestamp`.")
    public let summary: String
}
