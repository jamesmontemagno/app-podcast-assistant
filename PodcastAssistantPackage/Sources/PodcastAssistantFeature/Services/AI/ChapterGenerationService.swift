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
    
    /// Represents a single timestamped segment from the transcript
    private struct TimestampedSegment {
        let timestamp: String
        let text: String
    }
    
    // MARK: - Dependencies
    
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Chapter Generation
    
    /// Generates chapter markers based on the episode transcript using a segment-based approach
    /// Step 1: Parse transcript into structured timestamped segments
    /// Step 2: Create sliding windows over segments and condense them
    /// Step 3: Merge all condensed segments into final list
    /// Step 4: Analyze segments to identify topic shifts and create chapters
    /// - Parameter transcript: The episode transcript text
    /// - Returns: Array of 5-10 chapter markers
    /// - Throws: Error if generation fails
    public func generateChapters(from transcript: String) async throws -> [ChapterMarker] {
        // Use cleanForChapters to preserve timecodes while removing speaker names
        let cleanedTranscript = transcriptCleaner.cleanForChapters(transcript)
        
        // Step 1: Parse transcript into structured segments
        let initialSegments = parseTranscriptIntoSegments(cleanedTranscript)
        print("📝 [ChapterGen] Parsed \(initialSegments.count) initial segments from transcript")
        
        // Step 2-3: Condense segments using sliding windows
        let condensedSegments = try await condenseSegmentsWithSlidingWindows(initialSegments)
        
        // Step 4: Identify topic shifts and create chapters from condensed segments
        let chapters = try await identifyChaptersFromSegments(condensedSegments)
        
        return chapters
    }
    
    // MARK: - Step 1: Parse Transcript into Segments
    
    /// Parses transcript into structured timestamped segments
    private func parseTranscriptIntoSegments(_ transcript: String) -> [TimestampedSegment] {
        var segments: [TimestampedSegment] = []
        let lines = transcript.components(separatedBy: .newlines)
        
        var currentTimestamp: String?
        var currentText = ""
        
        // Regex to match various timestamp formats
        let timestampPattern = #/^(\d{1,2}:\d{2}(?::\d{2})?(?:\.\d{2})?)\s*(.*)$/#
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            
            // Check if line starts with a timestamp
            if let match = try? timestampPattern.firstMatch(in: trimmedLine) {
                // Save previous segment if exists
                if let timestamp = currentTimestamp, !currentText.isEmpty {
                    segments.append(TimestampedSegment(
                        timestamp: timestamp,
                        text: currentText.trimmingCharacters(in: .whitespaces)
                    ))
                }
                
                // Start new segment
                currentTimestamp = String(match.output.1)
                currentText = String(match.output.2)
            } else if currentTimestamp != nil {
                // Continuation of current segment
                currentText += " " + trimmedLine
            } else {
                // No timestamp yet, treat as first segment with 00:00
                if currentTimestamp == nil {
                    currentTimestamp = "00:00"
                    currentText = trimmedLine
                } else {
                    currentText += " " + trimmedLine
                }
            }
        }
        
        // Add final segment
        if let timestamp = currentTimestamp, !currentText.isEmpty {
            segments.append(TimestampedSegment(
                timestamp: timestamp,
                text: currentText.trimmingCharacters(in: .whitespaces)
            ))
        }
        
        return segments
    }
    
    // MARK: - Step 2-3: Condense Segments with Sliding Windows
    
    /// Condenses segments using sliding windows with overlap
    private func condenseSegmentsWithSlidingWindows(_ segments: [TimestampedSegment]) async throws -> [TimestampedSegment] {
        print("🔍 [ChapterGen] Starting segment condensation with sliding windows")
        print("📊 [ChapterGen] Input: \(segments.count) segments")
        
        // Create sliding windows over segments (e.g., 50 segments per window with 20% overlap)
        let windowSize = 50
        let overlapPercentage = 0.2
        let windows = createSegmentWindows(segments, windowSize: windowSize, overlapPercentage: overlapPercentage)
        
        print("📦 [ChapterGen] Created \(windows.count) segment windows (size: \(windowSize), overlap: \(Int(overlapPercentage * 100))%)")
        
        var allCondensedSegments: [[TimestampedSegment]] = []
        
        for (index, window) in windows.enumerated() {
            let windowNumber = index + 1
            let totalWindows = windows.count
            
            print("⏳ [ChapterGen] Processing window \(windowNumber)/\(totalWindows) - \(window.count) segments")
            
            // Condense this window of segments
            let condensedWindow = try await condenseSegmentWindow(window, windowNumber: windowNumber, totalWindows: totalWindows)
            
            print("✅ [ChapterGen] Window \(windowNumber) condensed: \(window.count) → \(condensedWindow.count) segments")
            
            allCondensedSegments.append(condensedWindow)
        }
        
        // Merge overlapping windows
        let finalSegments = mergeSegmentWindows(allCondensedSegments, overlapPercentage: overlapPercentage)
        
        print("✨ [ChapterGen] Condensation complete: \(segments.count) → \(finalSegments.count) segments")
        
        return finalSegments
    }
    
    /// Creates sliding windows over segments
    private func createSegmentWindows(_ segments: [TimestampedSegment], windowSize: Int, overlapPercentage: Double) -> [[TimestampedSegment]] {
        guard !segments.isEmpty else { return [] }
        guard segments.count > windowSize else { return [segments] }
        
        let overlapSize = Int(Double(windowSize) * overlapPercentage)
        let stepSize = windowSize - overlapSize
        
        var windows: [[TimestampedSegment]] = []
        var startIndex = 0
        
        while startIndex < segments.count {
            let endIndex = min(startIndex + windowSize, segments.count)
            let window = Array(segments[startIndex..<endIndex])
            windows.append(window)
            
            startIndex += stepSize
            
            // Stop if we've reached the end
            if endIndex == segments.count {
                break
            }
        }
        
        return windows
    }
    
    /// Condenses a single window of segments using AI
    private func condenseSegmentWindow(_ segments: [TimestampedSegment], windowNumber: Int, totalWindows: Int) async throws -> [TimestampedSegment] {
        // Create a fresh session for each window
        let session = LanguageModelSession(
            instructions: """
            You are a podcast transcript condenser. Extract the key segments with their timecodes.
            
            CRITICAL: Preserve timecodes for important topic points.
            
            Rules:
            1. Keep timecodes for significant topic shifts or key points
            2. Merge adjacent segments on the same topic, keeping the earliest timecode
            3. Create concise one-sentence summaries for each segment
            4. Aim to reduce segment count by 50-70%
            
            Output: Array of condensed segments with timestamp and summary.
            """
        )
        
        // Format segments for the prompt
        let segmentsText = segments.map { "\($0.timestamp) \($0.text)" }.joined(separator: "\n")
        
        let prompt = """
        Condense these timestamped transcript segments while preserving key timecodes.
        
        Extract the most important segments that represent topic shifts or key discussion points.
        For each segment you keep, provide:
        - timestamp: The exact timecode from the original segment
        - summary: A brief one-sentence summary of what's discussed
        
        Merge adjacent segments discussing the same topic, keeping the earliest timestamp.
        
        This is window \(windowNumber) of \(totalWindows).
        
        Segments:
        \(segmentsText)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: SegmentListPOCO.self
        )
        
        // Convert response to TimestampedSegment array
        return response.content.segments.map { segment in
            TimestampedSegment(timestamp: segment.timestamp, text: segment.summary)
        }
    }
    
    /// Merges overlapping segment windows
    private func mergeSegmentWindows(_ windows: [[TimestampedSegment]], overlapPercentage: Double) -> [TimestampedSegment] {
        guard !windows.isEmpty else { return [] }
        guard windows.count > 1 else { return windows[0] }
        
        var merged: [TimestampedSegment] = []
        
        for (index, window) in windows.enumerated() {
            if index == 0 {
                // First window - take everything
                merged.append(contentsOf: window)
            } else {
                // Subsequent windows - skip the overlapping portion
                let skipCount = Int(Double(window.count) * overlapPercentage)
                let uniqueSegments = Array(window.dropFirst(skipCount))
                merged.append(contentsOf: uniqueSegments)
            }
        }
        
        return merged
    }
    
    // MARK: - Step 4: Chapter Identification
    
    /// Analyzes condensed segments to identify topic shifts and create chapter markers
    private func identifyChaptersFromSegments(_ segments: [TimestampedSegment]) async throws -> [ChapterMarker] {
        print("🔍 [ChapterGen] Starting chapter identification from \(segments.count) segments")
        
        // Calculate ideal chapters per window based on total segments
        // Target: 6 average chapters, max 10 total
        let targetTotalChapters = 6
        let maxTotalChapters = 10
        
        // If segments fit in one window, process directly
        let maxSegmentsPerWindow = 25
        if segments.count <= maxSegmentsPerWindow {
            return try await identifySingleWindowChapters(
                segments, 
                windowNumber: 1, 
                totalWindows: 1,
                targetChapters: targetTotalChapters,
                maxChapters: maxTotalChapters
            )
        }
        
        // Otherwise, use sliding windows
        let windowSize = 25
        let overlapPercentage = 0.3 // Higher overlap for chapter detection to ensure continuity
        let windows = createSegmentWindows(segments, windowSize: windowSize, overlapPercentage: overlapPercentage)
        
        // Calculate chapters per window to hit our target
        let chaptersPerWindow = max(2, targetTotalChapters / windows.count)
        
        print("📦 [ChapterGen] Processing chapter identification in \(windows.count) windows (size: \(windowSize), overlap: \(Int(overlapPercentage * 100))%)")
        print("🎯 [ChapterGen] Target: ~\(chaptersPerWindow) chapters per window, \(targetTotalChapters) total (max \(maxTotalChapters))")
        
        var allChapters: [ChapterMarker] = []
        
        for (index, window) in windows.enumerated() {
            let windowNumber = index + 1
            let totalWindows = windows.count
            
            print("⏳ [ChapterGen] Analyzing window \(windowNumber)/\(totalWindows) - \(window.count) segments")
            
            let windowChapters = try await identifySingleWindowChapters(
                window, 
                windowNumber: windowNumber, 
                totalWindows: totalWindows,
                targetChapters: chaptersPerWindow,
                maxChapters: chaptersPerWindow + 1
            )
            
            print("✅ [ChapterGen] Window \(windowNumber) identified \(windowChapters.count) chapters")
            
            allChapters.append(contentsOf: windowChapters)
        }
        
        // Merge and deduplicate chapters from all windows
        var finalChapters = mergeChapters(allChapters)
        
        // If we still have too many chapters, intelligently reduce to max 10
        if finalChapters.count > maxTotalChapters {
            finalChapters = reduceToTargetChapters(finalChapters, target: maxTotalChapters)
        }
        
        print("✨ [ChapterGen] Final chapter count: \(finalChapters.count)")
        
        return finalChapters
    }
    
    /// Identifies chapters from a single window of segments
    private func identifySingleWindowChapters(
        _ segments: [TimestampedSegment], 
        windowNumber: Int, 
        totalWindows: Int,
        targetChapters: Int,
        maxChapters: Int
    ) async throws -> [ChapterMarker] {
        let session = LanguageModelSession(
            instructions: """
            You are a podcast editor who creates chapter markers based on topic transitions.
            You must use the ACTUAL TIMECODES from segments where topics shift.
            """
        )
        
        // Format segments for analysis
        let segmentsText = segments.map { "\($0.timestamp) \($0.text)" }.joined(separator: "\n")
        
        let windowContext = totalWindows > 1 ? "This is window \(windowNumber) of \(totalWindows). " : ""
        let chapterGuidance = windowNumber == 1 ? 
            "- First chapter MUST start at 00:00 (or the first timecode if different)\n" : 
            "- Focus on major topic shifts within this segment range\n"
        
        let prompt = """
        Create chapter markers for this podcast episode from these condensed segments.
        
        \(windowContext)Each line shows a timestamp followed by a summary of that segment.
        Identify where major topic shifts occur and use those EXACT timecodes for chapters.
        
        Guidelines:
        - Create \(targetChapters)-\(maxChapters) chapters for this segment window
        - Focus on MAJOR topic shifts only - be selective
        \(chapterGuidance)- For each chapter, use the ACTUAL TIMECODE where the new topic starts
        - DO NOT make up timecodes - only use timecodes from the segments below
        - Only create a new chapter when the topic significantly changes
        - Create descriptive titles (under 8 words)
        - Provide a one-sentence summary per chapter
        
        CRITICAL: Chapter timestamps must be EXACT timecodes from the segments below.
        
        Condensed Segments:
        \(segmentsText)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: ChapterMarkersResponsePOCO.self
        )
        
        return response.content.chapters.map {
            ChapterMarker(
                timestamp: $0.timestamp,
                title: $0.title,
                summary: $0.summary
            )
        }
    }
    
    /// Merges chapters from multiple windows, removing duplicates and overlaps
    private func mergeChapters(_ chapters: [ChapterMarker]) -> [ChapterMarker] {
        guard !chapters.isEmpty else { return [] }
        
        // Sort by timestamp
        let sorted = chapters.sorted { timestampToSeconds($0.timestamp) < timestampToSeconds($1.timestamp) }
        
        var merged: [ChapterMarker] = []
        var seenTimestamps = Set<String>()
        
        for chapter in sorted {
            // Skip exact duplicate timestamps
            if seenTimestamps.contains(chapter.timestamp) {
                continue
            }
            
            // Skip if too close to previous chapter (within 30 seconds)
            if let lastChapter = merged.last {
                let lastSeconds = timestampToSeconds(lastChapter.timestamp)
                let currentSeconds = timestampToSeconds(chapter.timestamp)
                if currentSeconds - lastSeconds < 30 {
                    continue
                }
            }
            
            merged.append(chapter)
            seenTimestamps.insert(chapter.timestamp)
        }
        
        return merged
    }
    
    /// Converts timestamp string to seconds for comparison
    private func timestampToSeconds(_ timestamp: String) -> Double {
        let parts = timestamp.components(separatedBy: ":")
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
    
    /// Reduces chapters to target count by keeping most significant topic shifts
    private func reduceToTargetChapters(_ chapters: [ChapterMarker], target: Int) -> [ChapterMarker] {
        guard chapters.count > target else { return chapters }
        
        print("🎯 [ChapterGen] Reducing \(chapters.count) chapters to \(target)")
        
        // Always keep the first chapter (00:00 or earliest)
        var kept: [ChapterMarker] = [chapters[0]]
        var remaining = Array(chapters.dropFirst())
        
        // Calculate ideal spacing between chapters
        if let lastChapter = chapters.last {
            let totalSeconds = timestampToSeconds(lastChapter.timestamp)
            let idealSpacing = totalSeconds / Double(target - 1) // -1 because we already have first chapter
            
            // Keep chapters that are spaced well apart
            for chapter in remaining {
                if kept.count >= target { break }
                
                let chapterSeconds = timestampToSeconds(chapter.timestamp)
                let lastKeptSeconds = timestampToSeconds(kept.last!.timestamp)
                
                // Keep if it's far enough from the last kept chapter
                if chapterSeconds - lastKeptSeconds >= idealSpacing * 0.7 { // 70% of ideal spacing
                    kept.append(chapter)
                }
            }
        }
        
        // If we still don't have enough, fill in the gaps
        while kept.count < target && !remaining.isEmpty {
            // Find the largest gap between kept chapters
            var largestGapIndex = 0
            var largestGap: Double = 0
            
            for i in 0..<(kept.count - 1) {
                let gap = timestampToSeconds(kept[i + 1].timestamp) - timestampToSeconds(kept[i].timestamp)
                if gap > largestGap {
                    largestGap = gap
                    largestGapIndex = i
                }
            }
            
            // Find a chapter from remaining that fits in this gap
            let gapStart = timestampToSeconds(kept[largestGapIndex].timestamp)
            let gapEnd = timestampToSeconds(kept[largestGapIndex + 1].timestamp)
            
            if let bestFit = remaining.first(where: { chapter in
                let seconds = timestampToSeconds(chapter.timestamp)
                return seconds > gapStart && seconds < gapEnd
            }) {
                kept.insert(bestFit, at: largestGapIndex + 1)
                remaining.removeAll { $0.timestamp == bestFit.timestamp }
            } else {
                break // No more chapters fit
            }
        }
        
        print("✅ [ChapterGen] Reduced to \(kept.count) chapters")
        return kept
    }
    
    // MARK: - Private Methods - Chunking & Utilities (Deprecated - kept for reference)
    
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
private struct SegmentListPOCO {
    @Guide(description: "List of condensed segments with timestamps and summaries")
    var segments: [Segment]
    
    @Generable
    struct Segment {
        @Guide(description: "Timestamp in MM:SS or HH:MM:SS format")
        var timestamp: String
        
        @Guide(description: "One-sentence summary of this segment")
        var summary: String
    }
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
