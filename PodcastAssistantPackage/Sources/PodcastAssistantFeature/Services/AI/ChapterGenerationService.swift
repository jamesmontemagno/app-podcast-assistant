import Foundation
import FoundationModels

/// Service for generating podcast chapter markers using Apple Intelligence
/// Focuses solely on analyzing refined segments to create chapter markers
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
    
    // MARK: - Dependencies
    
    private let shrinkerService = TranscriptionShrinkerService()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Chapter Generation
    
    /// Generates chapter markers based on the episode transcript
    /// Step 1: Use TranscriptionShrinkerService to condense transcript into refined segments (or use pre-shrunk if provided)
    /// Step 2: Analyze refined segments to identify topic shifts and create chapters
    /// - Parameters:
    ///   - transcript: The episode transcript text
    ///   - preShrunkSegments: Optional pre-shrunk segments to avoid re-processing
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Array of 5-10 chapter markers
    /// - Throws: Error if generation fails
    public func generateChapters(
        from transcript: String,
        preShrunkSegments: [SummarizedSegment]? = nil,
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> [ChapterMarker] {
        print("📝 [ChapterGen] Starting chapter generation")
        
        let summarizedSegments: [SummarizedSegment]
        
        // Use pre-shrunk segments if available, otherwise shrink now
        if let preProcessed = preShrunkSegments {
            print("📦 [ChapterGen] Using pre-shrunk transcript (\(preProcessed.count) segments)")
            summarizedSegments = preProcessed
        } else {
            print("⚙️ [ChapterGen] Shrinking transcript...")
            // Step 1: Shrink transcript using TranscriptionShrinkerService
            // Configure for chapter generation: larger windows for chapter context
            let shrinkConfig = TranscriptionShrinkerService.ShrinkConfig(
                maxWindowCharacters: 6000,    // Larger windows for chapter context
                overlap: 0.15                  // More overlap for topic continuity
            )
            
            // Hook up progress handler to shrinker
            shrinkerService.logHandler = { message in
                // Extract useful progress info from log messages
                if message.contains("Parsed") {
                    progressHandler?(message.replacingOccurrences(of: "📊 [Shrinker] ", with: ""))
                } else if message.contains("Processing window") {
                    progressHandler?(message.replacingOccurrences(of: "⏳ [Shrinker] ", with: ""))
                } else if message.contains("Complete") {
                    progressHandler?(message.replacingOccurrences(of: "✨ [Shrinker] ", with: ""))
                }
            }
            
            summarizedSegments = try await shrinkerService.shrinkTranscript(
                transcript,
                config: shrinkConfig
            )
            
            // Clear handler
            shrinkerService.logHandler = nil
        }
        
        // Convert SummarizedSegments to RefinedSegments for chapter identification
        let refinedSegments = convertToRefinedSegments(summarizedSegments)
        let totalDurationSeconds = refinedSegments.last?.endTimestamp.timestampToSeconds() ?? 0
        
        print("📊 [ChapterGen] Received \(refinedSegments.count) refined segments")
        
        // Step 2: Identify topic shifts and create chapters from refined segments
        let chapters = try await identifyChaptersFromSegments(
            refinedSegments,
            totalDurationSeconds: totalDurationSeconds
        )
        
        return chapters
    }
    
    // MARK: - Conversion Helpers
    
    /// Converts SummarizedSegments from the transcript shrinker to RefinedSegments for chapter identification
    private func convertToRefinedSegments(_ summarizedSegments: [SummarizedSegment]) -> [RefinedSegment] {
        // Start with start timestamps; we'll backfill end timestamps using the next segment's start
        var refined = summarizedSegments.enumerated().map { index, segment in
            RefinedSegment(
                startTimestamp: segment.firstSegmentTimestamp,
                endTimestamp: segment.firstSegmentTimestamp,
                summary: segment.summary,
                originalSegmentIndices: [index]
            )
        }
        // Use the next segment's start time as this segment's end time for better ranges
        if refined.count > 1 {
            for idx in 0..<(refined.count - 1) {
                let nextStart = refined[idx + 1].startTimestamp
                let current = refined[idx]
                refined[idx] = RefinedSegment(
                    id: current.id,
                    startTimestamp: current.startTimestamp,
                    endTimestamp: nextStart,
                    summary: current.summary,
                    originalSegmentIndices: current.originalSegmentIndices
                )
            }
        }
        return refined
    }
    
    // MARK: - Chapter Identification
    
    /// Analyzes refined segments to identify topic shifts and create chapter markers
    private func identifyChaptersFromSegments(
        _ segments: [RefinedSegment],
        totalDurationSeconds: Double
    ) async throws -> [ChapterMarker] {
        print("🔍 [ChapterGen] Starting chapter identification from \(segments.count) segments")
        
        // Calculate duration from passed total seconds
        let durationSeconds = max(0, totalDurationSeconds)
        let durationMinutes = durationSeconds / 60.0
        
        // Target: 5 chapters per 30 minutes of content
        // For a 60 minute episode: ~10 chapters
        // For a 30 minute episode: ~5 chapters
        // Minimum: 3 chapters, Maximum: 12 chapters
        let calculatedTarget = max(3, min(12, Int((durationMinutes / 30.0) * 5)))
        let targetTotalChapters = calculatedTarget
        let maxTotalChapters = calculatedTarget + 2  // Allow slightly more if needed
        
        print("⏱️ [ChapterGen] Episode duration: \(String(format: "%.1f", durationMinutes)) minutes")
        print("🎯 [ChapterGen] Target chapters: \(targetTotalChapters) (max: \(maxTotalChapters))")
        
        // If segments fit in one window, process directly
        let maxSegmentsPerWindow = 25
        if segments.count <= maxSegmentsPerWindow {
            return try await identifySingleWindowChapters(
                segments, 
                windowNumber: 1, 
                totalWindows: 1,
                targetChapters: targetTotalChapters,
                maxChapters: maxTotalChapters,
                totalDurationSeconds: durationSeconds
            )
        }
        
        // Otherwise, use sliding windows for large segment sets
        let windowSize = 15  // Smaller windows since segments are already refined
        let windows = stride(from: 0, to: segments.count, by: windowSize).map { startIndex in
            let endIndex = min(startIndex + windowSize, segments.count)
            return Array(segments[startIndex..<endIndex])
        }
        
        // Calculate chapters per window to hit our target
        let chaptersPerWindow = max(1, targetTotalChapters / windows.count)
        
        print("📦 [ChapterGen] Processing chapter identification in \(windows.count) windows (size: \(windowSize))")
        print("🎯 [ChapterGen] Target: ~\(chaptersPerWindow) chapters per window")
        
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
                maxChapters: chaptersPerWindow + 1,
                totalDurationSeconds: durationSeconds
            )
            
            print("✅ [ChapterGen] Window \(windowNumber) identified \(windowChapters.count) chapters")
            
            allChapters.append(contentsOf: windowChapters)
        }
        
        // Merge and deduplicate chapters from all windows
        var finalChapters = mergeChapters(allChapters)
        finalChapters = validateAndNormalizeChapters(finalChapters, totalDurationSeconds: durationSeconds)
        finalChapters = fillLargeGaps(
            finalChapters,
            segments: segments,
            maxGapSeconds: 10 * 60,
            hardCap: maxTotalChapters
        )
        
        // If we have too many chapters, reduce to target
        if finalChapters.count > maxTotalChapters {
            finalChapters = reduceToTargetChapters(finalChapters, target: targetTotalChapters)
        }
        
        print("✨ [ChapterGen] Final chapter count: \(finalChapters.count)")
        
        return finalChapters
    }
    
    /// Identifies chapters from a single window of refined segments
    private func identifySingleWindowChapters(
        _ segments: [RefinedSegment], 
        windowNumber: Int, 
        totalWindows: Int,
        targetChapters: Int,
        maxChapters: Int,
        totalDurationSeconds: Double
    ) async throws -> [ChapterMarker] {
        let session = LanguageModelSession(
            instructions: """
            You are a podcast editor who creates chapter markers based on topic transitions.
            You must use the ACTUAL TIMECODES from segments where topics shift.
            """
        )
        
        // Format segments for analysis - use the time range and summary
        let maxSummaryLength = 220
        let segmentsText = segments.map { segment in
            let summary = segment.summary.count > maxSummaryLength
                ? String(segment.summary.prefix(maxSummaryLength)) + "…"
                : segment.summary
            return "[\(segment.timeRange)] \(summary)"
        }.joined(separator: "\n")
        
        let windowContext = totalWindows > 1 ? "This is window \(windowNumber) of \(totalWindows). " : ""
        let chapterGuidance = windowNumber == 1 ? 
            "- First chapter MUST start at 00:00:00 (or the first timecode if different)\n" : 
            "- Focus on major topic shifts within this segment range\n"
        let durationGuidance = "- Episode duration is about \(String(format: "%.0f", totalDurationSeconds)) seconds; do not emit timestamps beyond that\n"
        
        let prompt = """
        Create chapter markers for this podcast episode from these refined segments.
        
        \(windowContext)Each line shows a time range followed by a summary of that segment.
        Identify where MAJOR topic shifts occur and create chapters at those points.
        
        IMPORTANT: Be VERY selective - only create chapters for significant topic changes.
        Think of chapters as major sections viewers would skip to, not every minor topic.
        
        Guidelines:
        - Target approximately \(targetChapters) chapters (up to \(maxChapters) maximum if needed)
        - Only mark MAJOR topic transitions - ignore minor shifts
        - Each chapter should represent 5-10+ minutes of distinct content
        \(chapterGuidance)- For each chapter, extract the start timestamp from the time range
        - Use timestamps that align with where topics actually shift in the segments below
        - Format timestamps as MM:SS or HH:MM:SS (will be normalized automatically)
        \(durationGuidance)
        - Distribute chapters reasonably across this window; avoid any gap > 10 minutes
        - Create descriptive titles (under 8 words)
        - Provide a one-sentence summary per chapter
        
        CRITICAL: Extract chapter timestamps from the time ranges shown below.
        
        Refined Segments:
        \(segmentsText)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: ChapterMarkersResponsePOCO.self
        )
        
        // Normalize all timestamps to HH:MM:SS format
        var normalizedChapters = response.content.chapters.map { chapter in
            ChapterMarker(
                timestamp: normalizeTimestamp(chapter.timestamp),
                title: chapter.title,
                summary: chapter.summary
            )
        }
        
        // Ensure first chapter starts at 00:00:00 if this is the first window
        if windowNumber == 1, let firstChapter = normalizedChapters.first {
            normalizedChapters[0] = ChapterMarker(
                timestamp: "00:00:00",
                title: firstChapter.title,
                summary: firstChapter.summary
            )
        }
        
        return normalizedChapters
    }

    /// Ensures timestamps are monotonic, within duration, and normalized
    private func validateAndNormalizeChapters(_ chapters: [ChapterMarker], totalDurationSeconds: Double) -> [ChapterMarker] {
        guard !chapters.isEmpty else { return [] }
        let maxSeconds = max(0, totalDurationSeconds)
        let minSpacing: Double = 90 // keep at least 1.5 minutes between chapters
        let sorted = chapters.sorted { timestampToSeconds($0.timestamp) < timestampToSeconds($1.timestamp) }
        var sanitized: [ChapterMarker] = []
        for chapter in sorted {
            var seconds = timestampToSeconds(chapter.timestamp)
            if seconds.isNaN { continue }
            seconds = max(0, min(maxSeconds, seconds))
            if let last = sanitized.last, seconds - timestampToSeconds(last.timestamp) < minSpacing { continue }
            sanitized.append(
                ChapterMarker(
                    timestamp: secondsToTimestamp(seconds),
                    title: chapter.title,
                    summary: chapter.summary
                )
            )
        }
        // Ensure the first chapter starts at 00:00:00 if present
        if let first = sanitized.first {
            sanitized[0] = ChapterMarker(
                timestamp: "00:00:00",
                title: first.title,
                summary: first.summary
            )
        }
        return sanitized
    }

    /// Fills large gaps between chapters by inserting chapters at segment boundaries
    private func fillLargeGaps(
        _ chapters: [ChapterMarker],
        segments: [RefinedSegment],
        maxGapSeconds: Double,
        hardCap: Int
    ) -> [ChapterMarker] {
        guard !chapters.isEmpty, !segments.isEmpty else { return chapters }
        var filled: [ChapterMarker] = []
        let clampedMaxGap = max(60, maxGapSeconds)
        let sortedChapters = chapters.sorted { timestampToSeconds($0.timestamp) < timestampToSeconds($1.timestamp) }
        let segmentStarts = segments.sorted { $0.startTimestamp.timestampToSeconds() < $1.startTimestamp.timestampToSeconds() }
        
        func makeChapter(from segment: RefinedSegment) -> ChapterMarker {
            let seconds = segment.startTimestamp.timestampToSeconds()
            let title = segment.summary.split(separator: " ").prefix(8).joined(separator: " ")
            return ChapterMarker(
                timestamp: secondsToTimestamp(seconds),
                title: title.isEmpty ? "Topic Shift" : String(title),
                summary: segment.summary
            )
        }
        
        var remainingCap = max(0, hardCap)
        for (idx, chapter) in sortedChapters.enumerated() {
            filled.append(chapter)
            remainingCap = max(0, remainingCap - 1)
            guard remainingCap > 0 else { continue }
            let currentSeconds = timestampToSeconds(chapter.timestamp)
            let nextSeconds: Double
            if idx + 1 < sortedChapters.count {
                nextSeconds = timestampToSeconds(sortedChapters[idx + 1].timestamp)
            } else {
                nextSeconds = segments.last?.endTimestamp.timestampToSeconds() ?? currentSeconds
            }
            let gap = nextSeconds - currentSeconds
            if gap <= clampedMaxGap { continue }
            // Find a segment start within the gap, prefer one near the midpoint
            let midpoint = currentSeconds + gap / 2
            let candidates = segmentStarts.filter { start in
                let ts = start.startTimestamp.timestampToSeconds()
                return ts > currentSeconds + 30 && ts < nextSeconds - 30
            }
            guard let candidate = candidates.min(by: { abs($0.startTimestamp.timestampToSeconds() - midpoint) < abs($1.startTimestamp.timestampToSeconds() - midpoint) }) else {
                continue
            }
            filled.append(makeChapter(from: candidate))
            remainingCap = max(0, remainingCap - 1)
        }
        // Resort after inserts
        return filled.sorted { timestampToSeconds($0.timestamp) < timestampToSeconds($1.timestamp) }
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
            
            // Skip if too close to previous chapter
            // Minimum 3 minutes (180 seconds) between chapters for better spacing
            if let lastChapter = merged.last {
                let lastSeconds = timestampToSeconds(lastChapter.timestamp)
                let currentSeconds = timestampToSeconds(chapter.timestamp)
                if currentSeconds - lastSeconds < 180 {
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

    /// Converts seconds to HH:MM:SS
    private func secondsToTimestamp(_ seconds: Double) -> String {
        let totalSeconds = max(0, seconds)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let secs = Int(totalSeconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    /// Normalizes a timestamp to HH:MM:SS format (no fractional seconds)
    /// Handles various input formats: MM:SS, MM:SS.ss, HH:MM:SS, HH:MM:SS.ss
    private func normalizeTimestamp(_ timestamp: String) -> String {
        // Convert to seconds first
        let totalSeconds = timestampToSeconds(timestamp)
        
        // Extract hours, minutes, seconds
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        
        // Format as HH:MM:SS
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
    
    // MARK: - Utilities
    
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
