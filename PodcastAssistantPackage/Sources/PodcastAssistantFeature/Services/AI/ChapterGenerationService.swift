import Foundation
import FoundationModels

/// Service for generating podcast chapter markers using Apple Intelligence
@available(macOS 26.0, *)
@MainActor
public class ChapterGenerationService {
    // MARK: - Types
    
    public struct ChapterMarker {
        public let timestamp: String
        public let title: String
        public let summary: String
        
        public init(timestamp: String, title: String, summary: String) {
            self.timestamp = timestamp
            self.title = title
            self.summary = summary
        }
    }
    
    private struct TranscriptSegment {
        let startTime: String
        let endTime: String
        let summary: String
    }
    
    private struct TranscriptChunk {
        let text: String
        let startTime: String
        let endTime: String
    }
    
    // MARK: - Dependencies
    
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Chapter Generation
    
    /// Generates chapter markers based on the episode transcript using a two-pass approach
    /// Pass 1: Chunk and summarize transcript segments
    /// Pass 2: Identify topic shifts from summaries to create chapters
    /// - Parameter transcript: The episode transcript text
    /// - Returns: Array of 5-10 chapter markers
    /// - Throws: Error if generation fails
    public func generateChapters(from transcript: String) async throws -> [ChapterMarker] {
        // Use cleanForChapters to preserve timecodes while removing speaker names
        let cleanedTranscript = transcriptCleaner.cleanForChapters(transcript)
        
        // Pass 1: Chunk and summarize transcript segments
        let segments = try await summarizeTranscriptSegments(cleanedTranscript)
        
        // Pass 2: Identify topic shifts and create chapters from summaries
        let chapters = try await identifyChaptersFromSummaries(segments)
        
        return chapters
    }
    
    // MARK: - Private Methods - Pass 1: Segment Summarization
    
    /// Pass 1: Processes transcript using sliding windows with overlap to preserve context
    /// This reduces transcript length while maintaining temporal structure for chapter detection
    private func summarizeTranscriptSegments(_ transcript: String) async throws -> [TranscriptSegment] {
        print("🔍 [ChapterGen] Starting Pass 1: Transcript Condensation")
        print("📊 [ChapterGen] Original transcript length: \(transcript.count) characters")
        
        // Create sliding windows with 20% overlap for better context
        let windows = createSlidingWindows(transcript, windowSize: 6000, overlapPercentage: 0.2)
        print("📦 [ChapterGen] Created \(windows.count) sliding windows with 20% overlap")
        
        var windowSummaries: [String] = []
        
        for (index, window) in windows.enumerated() {
            let windowNumber = index + 1
            let totalWindows = windows.count
            
            print("⏳ [ChapterGen] Processing window \(windowNumber)/\(totalWindows) - Size: \(window.count) chars")
            
            // Create a fresh session for each window to avoid context buildup
            let session = LanguageModelSession(
                instructions: """
                You are a podcast transcript condenser. Your job is to shorten transcripts while ALWAYS preserving timecodes.
                
                CRITICAL: Every timecode must be preserved - they are used to create chapter markers.
                
                Key Rules:
                1. NEVER remove or skip timecodes - keep them ALL exactly as they appear
                2. Merge adjacent entries discussing the same topic, keeping the earliest timecode
                3. Condense dialogue into brief summaries
                4. Focus on what's being discussed, not who said it
                5. Keep timecodes in chronological order
                
                Goal: Reduce length by 50-70% while keeping EVERY timecode.
                """
            )
            
            let prompt = """
            Condense this transcript segment while PRESERVING ALL TIMECODES.
            
            Rules:
            1. Keep EVERY timecode exactly as it appears - DO NOT skip any
            2. For adjacent timecodes on the same topic, merge them but keep the first timecode
            3. Summarize long discussions briefly
            4. Maintain chronological order
            
            Output format:
            [TIMECODE] Brief summary of topic discussed
            
            IMPORTANT: Every timecode in the input MUST appear in your output.
            
            This is window \(windowNumber) of \(totalWindows).
            
            Transcript segment:
            \(window)
            """
            
            print("📤 [ChapterGen] Sending prompt - Total size: \(prompt.count) chars")
            
            let response = try await session.respond(
                to: prompt,
                generating: SegmentSummaryPOCO.self
            )
            
            let summaryLength = response.content.summary.count
            let reductionPercent = Int(100.0 - (Double(summaryLength) / Double(window.count) * 100.0))
            print("✅ [ChapterGen] Window \(windowNumber) condensed: \(window.count) → \(summaryLength) chars (\(reductionPercent)% reduction)")
            
            windowSummaries.append(response.content.summary)
        }
        
        // Merge overlapping windows, keeping content from the window with most context
        print("🔗 [ChapterGen] Merging \(windowSummaries.count) window summaries...")
        let mergedSummary = mergeOverlappingWindows(windowSummaries, overlapPercentage: 0.2)
        
        let totalReduction = Int(100.0 - (Double(mergedSummary.count) / Double(transcript.count) * 100.0))
        print("✨ [ChapterGen] Pass 1 Complete - Final: \(transcript.count) → \(mergedSummary.count) chars (\(totalReduction)% reduction)")
        
        // Return as single segment since we've already merged everything
        return [TranscriptSegment(
            startTime: "00:00",
            endTime: estimateEndTime(transcript),
            summary: mergedSummary
        )]
    }
    
    /// Creates sliding windows of text with specified overlap
    private func createSlidingWindows(_ text: String, windowSize: Int, overlapPercentage: Double) -> [String] {
        guard !text.isEmpty else { return [] }
        
        print("🪟 [ChapterGen] Creating sliding windows - Window size: \(windowSize), Overlap: \(Int(overlapPercentage * 100))%")
        
        let overlapSize = Int(Double(windowSize) * overlapPercentage)
        let stepSize = windowSize - overlapSize
        
        print("📏 [ChapterGen] Step size: \(stepSize) chars (window advances by this amount)")
        
        var windows: [String] = []
        var startIndex = text.startIndex
        
        while startIndex < text.endIndex {
            // Calculate end of current window
            let remainingDistance = text.distance(from: startIndex, to: text.endIndex)
            let currentWindowSize = min(windowSize, remainingDistance)
            
            guard let endIndex = text.index(startIndex, offsetBy: currentWindowSize, limitedBy: text.endIndex) else {
                break
            }
            
            // Extract window text
            let windowText = String(text[startIndex..<endIndex])
            
            // Try to break at a paragraph boundary if we're not at the end
            if endIndex < text.endIndex {
                if let lastNewlineRange = windowText.range(of: "\n\n", options: .backwards) {
                    let adjustedEnd = text.index(startIndex, offsetBy: windowText.distance(from: windowText.startIndex, to: lastNewlineRange.lowerBound))
                    windows.append(String(text[startIndex..<adjustedEnd]))
                    
                    // Move start forward by step size
                    if let nextStart = text.index(startIndex, offsetBy: stepSize, limitedBy: text.endIndex) {
                        startIndex = nextStart
                    } else {
                        break
                    }
                } else {
                    windows.append(windowText)
                    
                    // Move start forward by step size
                    if let nextStart = text.index(startIndex, offsetBy: stepSize, limitedBy: text.endIndex) {
                        startIndex = nextStart
                    } else {
                        break
                    }
                }
            } else {
                // Last window - include everything remaining
                windows.append(windowText)
                break
            }
        }
        
        return windows
    }
    
    /// Merges overlapping window summaries, preferring content from windows with more context
    private func mergeOverlappingWindows(_ summaries: [String], overlapPercentage: Double) -> String {
        guard !summaries.isEmpty else { return "" }
        guard summaries.count > 1 else { return summaries[0] }
        
        var merged = ""
        
        for (index, summary) in summaries.enumerated() {
            if index == 0 {
                // First window - take everything
                merged = summary
            } else {
                // Subsequent windows - skip the overlapping portion (first ~20%)
                let lines = summary.components(separatedBy: .newlines)
                let skipLines = Int(Double(lines.count) * overlapPercentage)
                let uniqueLines = Array(lines.dropFirst(skipLines))
                
                // Add the unique portion
                if !uniqueLines.isEmpty {
                    merged += "\n\n" + uniqueLines.joined(separator: "\n")
                }
            }
        }
        
        return merged
    }
    
    /// Estimates the end time of the transcript
    private func estimateEndTime(_ transcript: String) -> String {
        // Try to find the last timestamp in the transcript
        let timestampPattern = #/\b(\d{1,2}):(\d{2})(?::(\d{2}))?\b/#
        let matches = transcript.matches(of: timestampPattern)
        
        if let lastMatch = matches.last {
            return String(lastMatch.output.0)
        }
        
        // Fallback to estimated duration
        return "60:00"
    }
    
    // MARK: - Private Methods - Pass 2: Chapter Identification
    
    /// Pass 2: Analyzes condensed transcript summaries to identify topic shifts and create chapter markers
    private func identifyChaptersFromSummaries(_ segments: [TranscriptSegment]) async throws -> [ChapterMarker] {
        print("🔍 [ChapterGen] Starting Pass 2: Chapter Identification")
        
        let session = LanguageModelSession(
            instructions: """
            You are a podcast editor who creates chapter markers based on topic transitions.
            You must use the ACTUAL TIMECODES from the transcript where topics shift.
            """
        )
        
        // Combine all condensed summaries (each already has timecodes embedded)
        let condensedTranscript = segments.map { $0.summary }.joined(separator: "\n\n")
        print("📊 [ChapterGen] Condensed transcript length: \(condensedTranscript.count) chars")
        
        let prompt = """
        Create chapter markers for this podcast episode.
        
        The transcript contains timecodes in [TIMECODE] format. When you identify a topic shift,
        use the EXACT TIMECODE from the transcript where that new topic begins.
        
        Guidelines:
        - Create 5-10 chapters total
        - First chapter MUST start at 00:00 (or the first timecode if different)
        - For each chapter after the first, use the ACTUAL TIMECODE where the new topic starts
        - DO NOT make up or estimate timecodes - only use timecodes that appear in the transcript
        - Only create a new chapter when the topic significantly changes
        - Create descriptive titles (under 8 words)
        - Provide a one-sentence summary per chapter
        - Look for natural topic transitions, not arbitrary time intervals
        
        CRITICAL: Chapter timestamps must be EXACT timecodes from the transcript below.
        
        Condensed Transcript with Timecodes:
        \(condensedTranscript)
        """
        
        print("📤 [ChapterGen] Sending Pass 2 prompt - Total size: \(prompt.count) chars")
        
        let response = try await session.respond(
            to: prompt,
            generating: ChapterMarkersResponsePOCO.self
        )
        
        print("✅ [ChapterGen] Pass 2 Complete - Generated \(response.content.chapters.count) chapters")
        
        return response.content.chapters.map {
            ChapterMarker(
                timestamp: $0.timestamp,
                title: $0.title,
                summary: $0.summary
            )
        }
    }
    
    // MARK: - Private Methods - Chunking & Utilities
    
    /// Splits transcript into roughly equal chunks while preserving sentence boundaries
    private func chunkTranscript(_ transcript: String, targetChunkSize: Int) -> [TranscriptChunk] {
        var chunks: [TranscriptChunk] = []
        let lines = transcript.components(separatedBy: .newlines)
        var currentChunk = ""
        var chunkStartLine = 0
        
        for (index, line) in lines.enumerated() {
            currentChunk += line + "\n"
            
            // Check if we've reached target size and we're at a paragraph break
            if currentChunk.count >= targetChunkSize && line.trimmingCharacters(in: .whitespaces).isEmpty {
                let startTime = estimateTimestamp(fromLineIndex: chunkStartLine, totalLines: lines.count)
                let endTime = estimateTimestamp(fromLineIndex: index, totalLines: lines.count)
                
                chunks.append(TranscriptChunk(
                    text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTime: startTime,
                    endTime: endTime
                ))
                
                currentChunk = ""
                chunkStartLine = index + 1
            }
        }
        
        // Add final chunk if any content remains
        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let startTime = estimateTimestamp(fromLineIndex: chunkStartLine, totalLines: lines.count)
            let endTime = estimateTimestamp(fromLineIndex: lines.count - 1, totalLines: lines.count)
            
            chunks.append(TranscriptChunk(
                text: currentChunk.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: startTime,
                endTime: endTime
            ))
        }
        
        return chunks
    }
    
    /// Estimates timestamp based on position in transcript (assumes proportional distribution)
    private func estimateTimestamp(fromLineIndex lineIndex: Int, totalLines: Int) -> String {
        guard totalLines > 0 else { return "00:00" }
        
        // Rough estimation: assume average podcast is 60 minutes and estimate position
        let estimatedMinutes = Int((Double(lineIndex) / Double(totalLines)) * 60.0)
        let hours = estimatedMinutes / 60
        let minutes = estimatedMinutes % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:00", hours, minutes)
        } else {
            return String(format: "%02d:00", minutes)
        }
    }
    
    /// Formats chapter markers as YouTube-style chapter list
    /// - Parameter chapters: Array of chapter markers
    /// - Returns: Formatted string with timestamps and titles
    public func formatAsYouTube(_ chapters: [ChapterMarker]) -> String {
        var output = ""
        for marker in chapters {
            output += "\(marker.timestamp) - \(marker.title)\n"
        }
        return output
    }
}

// MARK: - Generable Structs for LLM Structured Output

@Generable
private struct SegmentSummaryPOCO {
    @Guide(description: "Condensed transcript with preserved timecodes. Format: [TIMECODE] Summary text. Merge adjacent timecodes on same topic. Reduce length by 50-70%.")
    var summary: String
}

@Generable
private struct ChapterMarkersResponsePOCO {
    @Guide(description: "Chapter markers with timestamps and titles")
    var chapters: [Chapter]
    
    @Generable
    struct Chapter {
        @Guide(description: "Timestamp in MM:SS or HH:MM:SS format")
        var timestamp: String
        
        @Guide(description: "Short, descriptive chapter title (under 8 words)")
        var title: String
        
        @Guide(description: "One-sentence summary of this chapter")
        var summary: String
    }
}
