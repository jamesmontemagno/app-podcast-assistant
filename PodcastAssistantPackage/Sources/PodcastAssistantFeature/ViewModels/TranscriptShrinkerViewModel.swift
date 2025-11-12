import Foundation
import SwiftUI
import SwiftData

/// ViewModel for transcript shrinking debug UI
@available(macOS 26.0, *)
@MainActor
public class TranscriptShrinkerViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published public var rawTranscript: String = ""
    @Published public var originalSegments: [TranscriptSegment] = []
    @Published public var refinedSegments: [RefinedSegment] = []
    
    // Configuration
    @Published public var windowSize: Double = 40
    @Published public var overlapPercent: Double = 40
    @Published public var targetCount: Double = 25
    @Published public var similarityThreshold: Double = 0.7
    
    // UI State
    @Published public var isParsing: Bool = false
    @Published public var isShrinking: Bool = false
    @Published public var processingLog: [String] = []
    @Published public var errorMessage: String?
    @Published public var stats: ShrinkStats?
    
    // MARK: - Dependencies
    
    public let episode: Episode
    public var modelContext: ModelContext?
    
    private let shrinkerService = TranscriptionShrinkerService()
    
    // MARK: - Computed Properties
    
    public var hasTranscript: Bool {
        !rawTranscript.isEmpty
    }
    
    public var originalSegmentCount: Int {
        originalSegments.count
    }
    
    public var refinedSegmentCount: Int {
        refinedSegments.count
    }
    
    public var rawTranscriptLength: Int {
        rawTranscript.count
    }
    
    public var rawTranscriptLines: Int {
        rawTranscript.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }
    
    public var rawWordCount: Int {
        rawTranscript.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    public var totalDuration: String {
        guard let lastSegment = originalSegments.last else { return "0:00" }
        let seconds = lastSegment.timestamp.timestampToSeconds()
        return formatDuration(seconds)
    }
    
    public var estimatedWordCount: Int {
        originalSegments.reduce(0) { sum, segment in
            sum + segment.text.components(separatedBy: .whitespaces).count
        }
    }
    
    // MARK: - Initialization
    
    public init(episode: Episode, modelContext: ModelContext? = nil) {
        self.episode = episode
        self.modelContext = modelContext
        self.rawTranscript = episode.transcriptInputText ?? ""
        
        // Set up log handler
        shrinkerService.logHandler = { [weak self] message in
            Task { @MainActor in
                self?.processingLog.append(message)
            }
        }
    }
    
    // MARK: - Actions
    
    /// Parses the transcript into segments
    public func parseTranscript() async {
        guard !rawTranscript.isEmpty else {
            errorMessage = "No transcript available"
            return
        }
        
        isParsing = true
        errorMessage = nil
        processingLog = []
        originalSegments = []
        
        addLog("📝 Starting transcript parsing...")
        addLog("📊 Raw transcript: \(rawTranscriptLength) characters, \(rawTranscriptLines) lines")
        
        // Parse with progress updates
        await Task { @MainActor in
            addLog("🔍 Detecting timestamp format...")
            originalSegments = parseTranscriptIntoSegments(rawTranscript)
            addLog("✅ Parsed \(originalSegments.count) segments")
            
            if originalSegments.isEmpty {
                errorMessage = "No timestamped segments found. Check transcript format."
                addLog("⚠️ No segments found - transcript may not contain timestamps")
            } else {
                addLog("⏱️ Duration: \(totalDuration)")
                addLog("📝 Words: ~\(estimatedWordCount)")
            }
        }.value
        
        isParsing = false
    }
    
    /// Shrinks the transcript using current configuration
    public func shrinkTranscript() async {
        guard !originalSegments.isEmpty else {
            errorMessage = "Parse transcript first"
            return
        }
        
        isShrinking = true
        errorMessage = nil
        processingLog = []
        stats = nil
        refinedSegments = []
        
        let startTime = Date()
        
        do {
            let config = TranscriptionShrinkerService.ShrinkConfig(
                windowSize: Int(windowSize),
                overlapPercentage: overlapPercent / 100.0,
                targetSegmentCount: Int(targetCount),
                minSecondsBetweenSegments: 20,
                similarityThreshold: similarityThreshold
            )
            
            guard let transcript = episode.transcriptInputText else {
                throw NSError(domain: "TranscriptShrinker", code: 1, userInfo: [NSLocalizedDescriptionKey: "No transcript"])
            }
            
            refinedSegments = try await shrinkerService.shrinkTranscript(
                transcript,
                config: config
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            stats = ShrinkStats(
                originalCount: originalSegments.count,
                refinedCount: refinedSegments.count,
                reductionPercent: calculateReductionPercent(),
                processingTimeSeconds: processingTime,
                windowsProcessed: calculateWindowCount()
            )
            
        } catch {
            errorMessage = "Shrinking failed: \(error.localizedDescription)"
            processingLog.append("❌ Error: \(error.localizedDescription)")
        }
        
        isShrinking = false
    }
    
    /// Exports refined segments to a text file
    public func exportRefinedSegments() {
        guard !refinedSegments.isEmpty else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(episode.title)-refined.txt"
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let content = self.formatRefinedSegmentsForExport()
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    self.errorMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func addLog(_ message: String) {
        processingLog.append(message)
    }
    
    private func parseTranscriptIntoSegments(_ transcript: String) -> [TranscriptSegment] {
        let transcriptCleaner = TranscriptCleaner()
        let cleanedTranscript = transcriptCleaner.cleanForChapters(transcript)
        var segments: [TranscriptSegment] = []
        let lines = cleanedTranscript.components(separatedBy: .newlines)
        
        var currentTimestamp: String?
        var currentText = ""
        
        let timestampPattern = #/^(\d{1,2}:\d{2}(?::\d{2})?(?:\.\d{2})?)\s*(.*)$/#
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            
            if let match = try? timestampPattern.firstMatch(in: trimmedLine) {
                if let timestamp = currentTimestamp, !currentText.isEmpty {
                    segments.append(TranscriptSegment(
                        timestamp: timestamp,
                        text: currentText.trimmingCharacters(in: .whitespaces)
                    ))
                }
                
                currentTimestamp = String(match.output.1)
                currentText = String(match.output.2)
            } else if currentTimestamp != nil {
                currentText += " " + trimmedLine
            } else {
                if currentTimestamp == nil {
                    currentTimestamp = "00:00"
                    currentText = trimmedLine
                } else {
                    currentText += " " + trimmedLine
                }
            }
        }
        
        if let timestamp = currentTimestamp, !currentText.isEmpty {
            segments.append(TranscriptSegment(
                timestamp: timestamp,
                text: currentText.trimmingCharacters(in: .whitespaces)
            ))
        }
        
        return segments
    }
    
    private func calculateReductionPercent() -> Double {
        guard originalSegments.count > 0 else { return 0 }
        return (1.0 - Double(refinedSegments.count) / Double(originalSegments.count)) * 100
    }
    
    private func calculateWindowCount() -> Int {
        let windowSize = Int(self.windowSize)
        let overlapSize = Int(Double(windowSize) * (overlapPercent / 100.0))
        let stepSize = windowSize - overlapSize
        
        guard originalSegments.count > windowSize else { return 1 }
        
        var count = 0
        var startIndex = 0
        
        while startIndex < originalSegments.count {
            count += 1
            startIndex += stepSize
            
            if startIndex >= originalSegments.count {
                break
            }
        }
        
        return count
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatRefinedSegmentsForExport() -> String {
        var output = "# Refined Transcript Segments\n"
        output += "# Episode: \(episode.title)\n"
        output += "# Original segments: \(originalSegments.count)\n"
        output += "# Refined segments: \(refinedSegments.count)\n"
        output += "# Reduction: \(String(format: "%.1f", calculateReductionPercent()))%\n\n"
        
        for segment in refinedSegments {
            output += "[\(segment.timeRange)] \(segment.summary)\n"
            output += "  (Covers \(segment.segmentsCovered) original segments)\n\n"
        }
        
        return output
    }
}

// MARK: - Supporting Types

@available(macOS 26.0, *)
public extension TranscriptShrinkerViewModel {
    struct ShrinkStats {
        public let originalCount: Int
        public let refinedCount: Int
        public let reductionPercent: Double
        public let processingTimeSeconds: Double
        public let windowsProcessed: Int
        
        public var processingTimeFormatted: String {
            String(format: "%.1fs", processingTimeSeconds)
        }
        
        public var reductionPercentFormatted: String {
            String(format: "%.1f%%", reductionPercent)
        }
    }
}
