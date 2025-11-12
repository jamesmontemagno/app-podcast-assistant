import Foundation
import FoundationModels

/// Service for condensing large timestamped transcripts into smaller refined segments
/// Uses multi-pass LLM approach with configurable windowing and similarity-based merging
@available(macOS 26.0, *)
@MainActor
public class TranscriptionShrinkerService {
    // MARK: - Configuration
    
    public struct ShrinkConfig {
        /// Maximum characters per window (estimated JSON size for LLM context)
        public var maxWindowCharacters: Int
        /// Overlap size in characters for context preservation
        public var overlapCharacters: Int
        public var targetSegmentCount: Int
        public var minSecondsBetweenSegments: Double
        public var similarityThreshold: Double
        
        public init(
            maxWindowCharacters: Int = 5000,
            overlapCharacters: Int = 1000,
            targetSegmentCount: Int = 25,
            minSecondsBetweenSegments: Double = 20,
            similarityThreshold: Double = 0.6
        ) {
            self.maxWindowCharacters = maxWindowCharacters
            self.overlapCharacters = overlapCharacters
            self.targetSegmentCount = targetSegmentCount
            self.minSecondsBetweenSegments = minSecondsBetweenSegments
            self.similarityThreshold = similarityThreshold
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
    ///   - transcript: Raw transcript with timestamps
    ///   - config: Configuration for windowing and merging
    /// - Returns: Array of refined segments covering the entire transcript
    public func shrinkTranscript(
        _ transcript: String,
        config: ShrinkConfig = .default
    ) async throws -> [RefinedSegment] {
        log("📝 [Shrinker] Starting transcript shrinking process")
        
        // Pass 1: Parse transcript into structured segments
        let segments = parseTranscriptIntoSegments(transcript)
        log("📊 [Shrinker] Parsed \(segments.count) segments from transcript")
        
        guard !segments.isEmpty else {
            throw ShrinkError.noSegmentsFound
        }
        
        // Pass 2: Condense segments using sliding windows
        let condensedSegments = try await condenseSegmentsWithSlidingWindows(
            segments,
            config: config
        )
        
        // Pass 3: Deduplicate and merge to target count
        let refinedSegments = deduplicateAndMergeSegments(
            condensedSegments,
            originalSegments: segments,
            config: config
        )
        
        log("✨ [Shrinker] Complete: \(segments.count) → \(refinedSegments.count) segments (\(reductionPercent(from: segments.count, to: refinedSegments.count))% reduction)")
        
        return refinedSegments
    }
    
    // MARK: - Pass 1: Parse Segments
    
    private func parseTranscriptIntoSegments(_ transcript: String) -> [TranscriptSegment] {
        let cleanedTranscript = transcriptCleaner.cleanForChapters(transcript)
        var segments: [TranscriptSegment] = []
        let lines = cleanedTranscript.components(separatedBy: .newlines)
        
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
                    segments.append(TranscriptSegment(
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
            segments.append(TranscriptSegment(
                timestamp: timestamp,
                text: currentText.trimmingCharacters(in: .whitespaces)
            ))
        }
        
        return segments
    }
    
    // MARK: - Pass 2: Condense with Sliding Windows
    
    private func condenseSegmentsWithSlidingWindows(
        _ segments: [TranscriptSegment],
        config: ShrinkConfig
    ) async throws -> [CondensedSegment] {
        log("🔍 [Shrinker] Starting condensation with sliding windows")
        log("📊 [Shrinker] Config: maxChars=\(config.maxWindowCharacters), overlapChars=\(config.overlapCharacters), target=\(config.targetSegmentCount)")
        
        let windows = createSegmentWindows(
            segments,
            maxWindowCharacters: config.maxWindowCharacters,
            overlapCharacters: config.overlapCharacters
        )
        
        log("📦 [Shrinker] Created \(windows.count) windows")
        
        var allCondensedSegments: [[CondensedSegment]] = []
        
        for (index, window) in windows.enumerated() {
            let windowNumber = index + 1
            log("⏳ [Shrinker] Processing window \(windowNumber)/\(windows.count) - \(window.count) segments (~\(estimateCharCount(window)) chars)")
            
            let condensedWindow = try await condenseSegmentWindow(
                window,
                windowNumber: windowNumber,
                totalWindows: windows.count
            )
            
            log("✅ [Shrinker] Window \(windowNumber) condensed: \(window.count) → \(condensedWindow.count) segments")
            allCondensedSegments.append(condensedWindow)
        }
        
        let merged = mergeCondensedWindows(allCondensedSegments, overlapCharacters: config.overlapCharacters)
        log("🧩 [Shrinker] Merged windows: \(merged.count) condensed segments")
        
        return merged
    }
    
    /// Estimate character count for a window (timestamp + text + JSON overhead)
    private func estimateCharCount(_ segments: [TranscriptSegment]) -> Int {
        segments.reduce(0) { sum, segment in
            // Estimate: timestamp (10) + text + JSON overhead (50)
            sum + segment.timestamp.count + segment.text.count + 60
        } + 20 // Window overhead
    }
    
    /// Create windows based on character count instead of fixed segment count
    /// More adaptive to variable-length content (follows TranscriptSummarizer pattern)
    private func createSegmentWindows(
        _ segments: [TranscriptSegment],
        maxWindowCharacters: Int,
        overlapCharacters: Int
    ) -> [[TranscriptSegment]] {
        guard !segments.isEmpty else { return [] }
        
        var windows: [[TranscriptSegment]] = []
        var currentWindow: [TranscriptSegment] = []
        var currentCharCount = 0
        var nextSegmentIndex = 0
        
        while nextSegmentIndex < segments.count {
            let segment = segments[nextSegmentIndex]
            let segmentCharCount = segment.timestamp.count + segment.text.count + 60
            
            currentWindow.append(segment)
            currentCharCount += segmentCharCount
            nextSegmentIndex += 1
            
            // Check if window is full
            if currentCharCount >= maxWindowCharacters {
                windows.append(currentWindow)
                
                // Create overlap by backfilling segments from previous window
                var newWindow: [TranscriptSegment] = []
                var overlapCount = 0
                var backIndex = nextSegmentIndex - 1
                
                while overlapCount < overlapCharacters && backIndex >= 0 {
                    let overlapSegment = currentWindow[currentWindow.count - (nextSegmentIndex - backIndex)]
                    let overlapCharCount = overlapSegment.timestamp.count + overlapSegment.text.count + 60
                    
                    newWindow.insert(overlapSegment, at: 0)
                    overlapCount += overlapCharCount
                    backIndex -= 1
                    
                    if backIndex < 0 || (nextSegmentIndex - backIndex - 1) >= currentWindow.count {
                        break
                    }
                }
                
                currentWindow = newWindow
                currentCharCount = overlapCount
            }
        }
        
        // Add final window if it has content
        if !currentWindow.isEmpty {
            windows.append(currentWindow)
        }
        
        return windows
    }
    
    private func condenseSegmentWindow(
        _ segments: [TranscriptSegment],
        windowNumber: Int,
        totalWindows: Int
    ) async throws -> [CondensedSegment] {
        let session = LanguageModelSession(
            instructions: """
            You are an expert at summarizing recorded podcast transcripts.
            
            You will be given transcript segments with timestamps and text. Your goal is to produce a concise summary of the content by identifying key topics and meaningful transitions.
            
            CORE PRINCIPLES:
            1. Focus on substantive content - key points, main ideas, and important details
            2. Completely elide trivial back-and-forth exchanges (greetings, acknowledgments, filler)
            3. Merge related discussions into comprehensive summaries
            4. Only create new segments when the topic SIGNIFICANTLY shifts
            5. Preserve the EARLIEST timestamp when merging segments
            
            EXAMPLE - Trivial exchanges to elide:
            Given:
              00:15:03 "I had a terrible day today. First, I missed my bus."
              00:15:15 "Oh"
              00:15:17 "Yeah"
              00:15:20 "Well that's tough. Anything else happen?"
              00:15:45 "Not really, just one of those days."
            
            Produce:
              {timestamp: "00:15:03", summary: "Discussion about having a rough day, missing the bus."}
            
            EXAMPLE - Long monologues to summarize:
            Given:
              00:30:10 "So, I was thinking about the implications of quantum computing on modern cryptography. As you know, many of our current encryption methods rely on the difficulty of factoring large prime numbers. However, with the advent of quantum algorithms like Shor's algorithm, this could potentially render our existing cryptographic systems obsolete. This means we need to start exploring quantum-resistant algorithms..."
            
            Produce:
              {timestamp: "00:30:10", summary: "Discussion of quantum computing's impact on cryptography, highlighting vulnerabilities in current encryption and the need for quantum-resistant algorithms."}
            
            TARGET: Reduce segment count by 85-90% through aggressive merging of related content.
            """
        )
        
        let segmentsText = segments.map { "\($0.timestamp) \($0.text)" }.joined(separator: "\n")
        
        let prompt = """
        Summarize these timestamped transcript segments following the principles above.
        
        This is window \(windowNumber) of \(totalWindows).
        
        For each condensed segment provide:
        - timestamp: The EARLIEST timestamp from merged segments
        - summary: Concise summary capturing key points (1-2 sentences max)
        
        Remember:
        - Completely elide trivial exchanges and filler
        - Merge related topics aggressively
        - Only create new segments for MAJOR topic shifts
        - Target 85-90% reduction
        
        Transcript segments to summarize:
        \(segmentsText)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: CondensedSegmentsPOCO.self
        )
        
        return response.content.segments.map { segment in
            CondensedSegment(
                timestamp: segment.timestamp,
                summary: segment.summary
            )
        }
    }
    
    /// Merge overlapping windows by removing duplicate segments from overlap regions
    /// Uses character-based overlap estimation
    private func mergeCondensedWindows(
        _ windows: [[CondensedSegment]],
        overlapCharacters: Int
    ) -> [CondensedSegment] {
        guard !windows.isEmpty else { return [] }
        guard windows.count > 1 else { return windows[0] }
        
        var merged: [CondensedSegment] = []
        
        for (index, window) in windows.enumerated() {
            if index == 0 {
                // First window - take all segments
                merged.append(contentsOf: window)
            } else {
                // Subsequent windows - skip overlap portion
                // Estimate overlap in segments by character count
                var overlapCharsSkipped = 0
                var skipCount = 0
                
                for segment in window {
                    let segmentChars = segment.timestamp.count + segment.summary.count + 60
                    if overlapCharsSkipped < overlapCharacters {
                        overlapCharsSkipped += segmentChars
                        skipCount += 1
                    } else {
                        break
                    }
                }
                
                let uniqueSegments = Array(window.dropFirst(skipCount))
                merged.append(contentsOf: uniqueSegments)
            }
        }
        
        return merged
    }
    
    // MARK: - Pass 3: Deduplicate and Merge
    
    private func deduplicateAndMergeSegments(
        _ condensedSegments: [CondensedSegment],
        originalSegments: [TranscriptSegment],
        config: ShrinkConfig
    ) -> [RefinedSegment] {
        log("🧩 [Shrinker] Starting deduplication and merging to target \(config.targetSegmentCount)")
        
        // Step 1: Remove duplicates based on similarity
        let deduplicated = removeDuplicates(
            condensedSegments,
            similarityThreshold: config.similarityThreshold
        )
        log("🔍 [Shrinker] After deduplication: \(deduplicated.count) segments")
        
        // Step 2: First pass - merge very similar adjacent segments
        var merged = mergeAdjacentSegments(deduplicated, threshold: 0.4)
        log("🔗 [Shrinker] After first merge pass: \(merged.count) segments")
        
        // Step 3: Second pass - more aggressive merging if still above target
        if merged.count > config.targetSegmentCount * 2 {
            merged = mergeAdjacentSegments(merged, threshold: 0.3)
            log("🔗 [Shrinker] After second merge pass: \(merged.count) segments")
        }
        
        // Step 4: Final aggressive merge to hit target
        var iterations = 0
        while merged.count > config.targetSegmentCount && iterations < 10 {
            let beforeCount = merged.count
            merged = mergeAdjacentSegments(merged, threshold: 0.25)
            iterations += 1
            
            // If we're not making progress, break
            if merged.count == beforeCount {
                break
            }
            
            log("🔗 [Shrinker] Iteration \(iterations): \(merged.count) segments")
        }
        
        // Step 5: If still over target, merge by time gaps
        if merged.count > config.targetSegmentCount {
            merged = mergeByTimeProximity(merged, targetCount: config.targetSegmentCount)
            log("⏰ [Shrinker] After time-based merging: \(merged.count) segments")
        }
        
        log("✅ [Shrinker] Final count: \(merged.count) segments")
        
        // Step 6: Convert to RefinedSegments with time ranges
        let refined = convertToRefinedSegments(
            merged,
            originalSegments: originalSegments
        )
        
        return refined
    }
    
    private func removeDuplicates(
        _ segments: [CondensedSegment],
        similarityThreshold: Double
    ) -> [CondensedSegment] {
        var result: [CondensedSegment] = []
        
        for segment in segments {
            // Check if similar to any existing segment
            let isDuplicate = result.contains { existing in
                let similarity = segment.summary.similarityScore(to: existing.summary)
                
                // Also check timestamp proximity
                let timeDiff = abs(
                    segment.timestamp.timestampToSeconds() -
                    existing.timestamp.timestampToSeconds()
                )
                
                return similarity >= similarityThreshold && timeDiff < 30
            }
            
            if !isDuplicate {
                result.append(segment)
            }
        }
        
        return result
    }
    
    private func mergeAdjacentSegments(_ segments: [CondensedSegment], threshold: Double = 0.4) -> [CondensedSegment] {
        guard segments.count > 1 else { return segments }
        
        var result: [CondensedSegment] = []
        var i = 0
        
        while i < segments.count {
            if i == segments.count - 1 {
                // Last segment, just add it
                result.append(segments[i])
                break
            }
            
            let current = segments[i]
            let next = segments[i + 1]
            
            // Check if segments are similar enough to merge
            let similarity = current.summary.similarityScore(to: next.summary)
            
            if similarity >= threshold {
                // Merge the two segments
                let merged = CondensedSegment(
                    timestamp: current.timestamp, // Keep earlier timestamp
                    summary: "\(current.summary) \(next.summary)"
                )
                result.append(merged)
                i += 2 // Skip next since we merged it
            } else {
                result.append(current)
                i += 1
            }
        }
        
        return result
    }
    
    private func mergeByTimeProximity(_ segments: [CondensedSegment], targetCount: Int) -> [CondensedSegment] {
        guard segments.count > targetCount else { return segments }
        
        var sorted = segments.sorted { $0.timestamp.timestampToSeconds() < $1.timestamp.timestampToSeconds() }
        
        while sorted.count > targetCount {
            // Find the pair with the smallest time gap
            var minGapIndex = 0
            var minGap = Double.infinity
            
            for i in 0..<(sorted.count - 1) {
                let gap = sorted[i + 1].timestamp.timestampToSeconds() - sorted[i].timestamp.timestampToSeconds()
                if gap < minGap {
                    minGap = gap
                    minGapIndex = i
                }
            }
            
            // Merge the pair with smallest gap
            let merged = CondensedSegment(
                timestamp: sorted[minGapIndex].timestamp,
                summary: "\(sorted[minGapIndex].summary) \(sorted[minGapIndex + 1].summary)"
            )
            
            sorted.remove(at: minGapIndex + 1)
            sorted[minGapIndex] = merged
        }
        
        return sorted
    }
    
    private func convertToRefinedSegments(
        _ condensed: [CondensedSegment],
        originalSegments: [TranscriptSegment]
    ) -> [RefinedSegment] {
        var refined: [RefinedSegment] = []
        
        for (index, segment) in condensed.enumerated() {
            let startTimestamp = segment.timestamp
            
            // End timestamp is the start of next segment, or last original segment
            let endTimestamp: String
            if index < condensed.count - 1 {
                endTimestamp = condensed[index + 1].timestamp
            } else {
                endTimestamp = originalSegments.last?.timestamp ?? startTimestamp
            }
            
            // Find which original segments this covers
            let startSeconds = startTimestamp.timestampToSeconds()
            let endSeconds = endTimestamp.timestampToSeconds()
            
            let coveredIndices = originalSegments.enumerated()
                .filter { (_, seg) in
                    let segSeconds = seg.timestamp.timestampToSeconds()
                    return segSeconds >= startSeconds && segSeconds < endSeconds
                }
                .map { $0.offset }
            
            // Only include segments that cover at least one original segment
            // and have valid timestamps
            guard !coveredIndices.isEmpty,
                  startSeconds >= 0,
                  endSeconds >= startSeconds else {
                continue
            }
            
            refined.append(RefinedSegment(
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp,
                summary: segment.summary,
                originalSegmentIndices: coveredIndices
            ))
        }
        
        return refined
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
    
    // MARK: - Internal Types
    
    private struct CondensedSegment {
        let timestamp: String
        let summary: String
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

// MARK: - Generable POCOs

@Generable
private struct CondensedSegmentsPOCO {
    @Guide(description: "Array of condensed segments with timestamps and summaries")
    var segments: [Segment]
    
    @Generable
    struct Segment {
        @Guide(description: "Timestamp in MM:SS or HH:MM:SS format (earliest from merged segments)")
        var timestamp: String
        
        @Guide(description: "One-sentence summary of the topic discussed in this segment")
        var summary: String
    }
}
