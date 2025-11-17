import Foundation
import SwiftUI
import SwiftData

/// ViewModel for transcript shrinking debug UI
@available(macOS 26.0, *)
@MainActor
public class TranscriptShrinkerViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published public var rawTranscript: String = ""
    @Published public var originalSegments: [TranscriptSegmentWithSpeaker] = []
    @Published public var windows: [TranscriptWindow] = []
    @Published public var summarizedSegments: [SummarizedSegment] = []
    
    // Configuration
    @Published public var maxWindowCharacters: Int = 5000
    @Published public var overlap: Double = 0.2
    
    // UI State
    @Published public var isParsing: Bool = false
    @Published public var isSummarizing: Bool = false
    @Published public var summaryProgress: Float = 0.0
    @Published public var processingLog: [String] = []
    @Published public var errorMessage: String?
    
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
    
    public var windowCount: Int {
        windows.count
    }
    
    public var summarizedSegmentCount: Int {
        summarizedSegments.count
    }
    
    public var reductionPercent: String {
        guard originalSegmentCount > 0, summarizedSegmentCount > 0 else { return "0%" }
        let percent = (1.0 - Double(summarizedSegmentCount) / Double(originalSegmentCount)) * 100
        return String(format: "%.1f%%", percent)
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
    
    /// Updates segments and windows based on current transcript
    public func updateSegments(from text: String) {
        originalSegments = parseSegments(from: text)
        windows = createWindows(originalSegments, maxWindowCharCount: maxWindowCharacters, overlap: overlap)
    }
    
    /// Summarizes the transcript using current configuration
    public func summarize() {
        Task {
            summarizedSegments.removeAll()
            
            var count = 0
            isSummarizing = true
            summaryProgress = 0.0
            processingLog = []
            errorMessage = nil
            
            do {
                // Process each window individually to update UI progressively
                let totalWindows = windows.count
                processingLog.append("🚀 Starting summarization of \(totalWindows) windows")
                
                for (index, window) in windows.enumerated() {
                    processingLog.append("⏳ Processing window \(index + 1)/\(totalWindows) (\(window.segments.count) segments)")
                    
                    // Create a temporary service instance for this window
                    let service = TranscriptionShrinkerService()
                    let summarized = try await service.summarizeWindow(window)
                    
                    // Add results immediately to update UI
                    summarizedSegments.append(contentsOf: summarized)
                    
                    // Update progress
                    count += 1
                    summaryProgress = Float(count) / Float(totalWindows)
                    
                    processingLog.append("✅ Window \(index + 1) complete: \(summarized.count) summaries")
                }
                
                let reduction = reductionPercent
                processingLog.append("✨ Complete: \(originalSegmentCount) → \(summarizedSegmentCount) segments (\(reduction) reduction)")
                
            } catch {
                errorMessage = "Summarization failed: \(error.localizedDescription)"
                processingLog.append("❌ Error: \(error.localizedDescription)")
            }
            
            isSummarizing = false
        }
    }
    
    // MARK: - Private Helpers
    
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
}
