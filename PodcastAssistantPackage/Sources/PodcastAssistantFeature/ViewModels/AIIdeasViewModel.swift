import Foundation
import SwiftUI
import SwiftData
import FoundationModels
import AppKit

/// ViewModel for AI-powered content generation from episode transcripts
@available(macOS 26.0, *)
@MainActor
public class AIIdeasViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published public var titleSuggestions: [String] = []
    @Published public var generatedDescription: String = ""
    @Published public var descriptionLength: DescriptionGenerationService.DescriptionLength = .medium
    @Published public var socialPosts: [SocialPost] = []
    @Published public var chapterMarkers: [ChapterMarker] = []
    
    @Published public var shrunkTranscript: String = ""
    @Published public var isGeneratingShrunkTranscript: Bool = false
    @Published public var originalSegmentCount: Int = 0
    @Published public var shrunkSegmentCount: Int = 0
    @Published public var usedShrunkTranscript: Bool = false
    @Published public var shrunkTranscriptCharCount: Int = 0
    @Published public var shrunkTranscriptStrippedCharCount: Int = 0
    @Published public var shrunkTranscriptCleanedCharCount: Int = 0
    private var cachedShrunkSegments: [SummarizedSegment] = []
    
    @Published public var isGeneratingTitles: Bool = false
    @Published public var isGeneratingDescription: Bool = false
    @Published public var isGeneratingSocial: Bool = false
    @Published public var isGeneratingChapters: Bool = false
    @Published public var isGeneratingAll: Bool = false
    
    @Published public var errorMessage: String?
    @Published public var modelAvailable: Bool = false
    @Published public var statusMessage: String = ""
    @Published public var progressDetails: String = ""
    
    // MARK: - Dependencies
    
    public let episode: Episode
    public var modelContext: ModelContext?
    
    private let titleService = TitleGenerationService()
    private let descriptionService = DescriptionGenerationService()
    private let socialService = SocialPostGenerationService()
    private let chapterService = ChapterGenerationService()
    private let transcriptCleaner = TranscriptCleaner()
    private let shrinkerService = TranscriptionShrinkerService()
    
    // MARK: - Settings
    
    @AppStorage("transcriptShrinkerMaxWindowCharacters") private var maxWindowChars: Int = 5000
    @AppStorage("transcriptShrinkerOverlap") private var overlap: Double = 0.2
    @AppStorage("transcriptShrinkerFallbackOnError") private var fallbackOnError: Bool = true
    
    // MARK: - Computed Properties
    
    public var transcriptLength: Int {
        episode.transcriptInputText?.count ?? 0
    }
    
    public var cleanedTranscriptLength: Int {
        guard let transcript = episode.transcriptInputText else { return 0 }
        return transcriptCleaner.cleanForAI(transcript).count
    }
    
    public var transcriptLengthFormatted: String {
        formatCharacterCount(transcriptLength)
    }
    
    public var cleanedTranscriptLengthFormatted: String {
        formatCharacterCount(cleanedTranscriptLength)
    }
    
    public var reductionPercentage: Int {
        guard originalSegmentCount > 0 else { return 0 }
        return Int((1.0 - Double(shrunkSegmentCount) / Double(originalSegmentCount)) * 100)
    }
    
    public var shrunkTranscriptCharCountFormatted: String {
        formatCharacterCount(shrunkTranscriptCharCount)
    }
    
    public var shrunkTranscriptStrippedCharCountFormatted: String {
        formatCharacterCount(shrunkTranscriptStrippedCharCount)
    }
    
    public var shrunkTranscriptCleanedCharCountFormatted: String {
        formatCharacterCount(shrunkTranscriptCleanedCharCount)
    }
    
    private func formatCharacterCount(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fK", thousands)
        }
        return "\(count)"
    }
    
    // MARK: - Initialization
    
    public init(episode: Episode, modelContext: ModelContext? = nil) {
        self.episode = episode
        self.modelContext = modelContext
        checkModelAvailability()
        loadShrunkTranscriptIfExists()
    }
    
    // MARK: - Model Availability
    
    private func checkModelAvailability() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            modelAvailable = true
            errorMessage = nil
        case .unavailable(let reason):
            modelAvailable = false
            errorMessage = "Apple Intelligence unavailable: \(String(describing: reason))"
        }
    }
    
    // MARK: - Load Existing Data
    
    private func loadShrunkTranscriptIfExists() {
        guard let saved = episode.shrunkTranscript, !saved.isEmpty else { return }
        
        // Load the shrunk transcript for display
        shrunkTranscript = saved
        
        // Parse to get segment counts for stats
        let segments = saved.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        shrunkSegmentCount = segments.count
        
        // Estimate original segment count from original transcript if available
        if let original = episode.transcriptInputText {
            originalSegmentCount = original.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        }
        
        // Calculate character counts for stats
        shrunkTranscriptCharCount = saved.count
        let stripped = stripTimestampsAndSpeakers(saved)
        shrunkTranscriptStrippedCharCount = stripped.count
        shrunkTranscriptCleanedCharCount = transcriptCleaner.cleanForAI(stripped).count
    }
    
    // MARK: - Content Generation
    
    /// Prepare transcript for AI generation - uses shrunk version if available, otherwise original
    private func prepareTranscriptForAI() async -> (text: String, isShrunk: Bool) {
        // Check if shrunk transcript exists and is not empty
        if let shrunk = episode.shrunkTranscript, !shrunk.isEmpty {
            usedShrunkTranscript = true
            return (stripTimestampsAndSpeakers(shrunk), true)
        }
        
        // Try to generate shrunk transcript
        if let original = episode.transcriptInputText, !original.isEmpty {
            await generateShrunkTranscript()
            
            // Check if generation succeeded
            if let shrunk = episode.shrunkTranscript, !shrunk.isEmpty {
                usedShrunkTranscript = true
                return (stripTimestampsAndSpeakers(shrunk), true)
            }
            
            // Fall back to original if shrinking failed and fallback is enabled
            if fallbackOnError {
                usedShrunkTranscript = false
                return (original, false)
            }
        }
        
        // Default fallback
        usedShrunkTranscript = false
        return (episode.transcriptInputText ?? "", false)
    }
    
    public func generateTitles() async {
        guard modelAvailable else { return }
        
        isGeneratingTitles = true
        errorMessage = nil
        statusMessage = "Analyzing transcript for title ideas..."
        
        do {
            let (transcript, isShrunk) = await prepareTranscriptForAI()
            guard !transcript.isEmpty else {
                errorMessage = "No transcript available. Add a transcript first."
                isGeneratingTitles = false
                return
            }
            
            titleSuggestions = try await titleService.generateTitles(from: transcript, isShrunkTranscript: isShrunk)
            statusMessage = "Generated \(titleSuggestions.count) title suggestions"
        } catch {
            errorMessage = "Failed to generate titles: \(error.localizedDescription)"
            statusMessage = ""
        }
        
        isGeneratingTitles = false
    }
    
    public func generateDescription() async {
        guard modelAvailable else { return }
        
        isGeneratingDescription = true
        errorMessage = nil
        statusMessage = "Creating \(descriptionLength.rawValue) description..."
        
        do {
            let (transcript, isShrunk) = await prepareTranscriptForAI()
            guard !transcript.isEmpty else {
                errorMessage = "No transcript available. Add a transcript first."
                isGeneratingDescription = false
                return
            }
            
            generatedDescription = try await descriptionService.generateDescription(
                from: transcript,
                title: episode.title,
                length: descriptionLength,
                isShrunkTranscript: isShrunk
            )
            statusMessage = "Description generated (\(generatedDescription.count) characters)"
        } catch {
            errorMessage = "Failed to generate description: \(error.localizedDescription)"
            statusMessage = ""
        }
        
        isGeneratingDescription = false
    }
    
    public func generateSocialPosts() async {
        guard modelAvailable else { return }
        
        isGeneratingSocial = true
        errorMessage = nil
        statusMessage = "Generating social media posts..."
        
        do {
            let (transcript, isShrunk) = await prepareTranscriptForAI()
            guard !transcript.isEmpty else {
                errorMessage = "No transcript available. Add a transcript first."
                isGeneratingSocial = false
                return
            }
            
            let posts = try await socialService.generateSocialPosts(
                from: transcript,
                title: episode.title,
                isShrunkTranscript: isShrunk
            )
            
            socialPosts = posts.map {
                SocialPost(platform: SocialPlatform(rawValue: $0.platform.rawValue) ?? .twitter, content: $0.content)
            }
            statusMessage = "Generated \(socialPosts.count) social posts"
        } catch {
            errorMessage = "Failed to generate social posts: \(error.localizedDescription)"
            statusMessage = ""
        }
        
        isGeneratingSocial = false
    }
    
    public func generateChapters() async {
        guard modelAvailable else { return }
        guard let transcript = episode.transcriptInputText, !transcript.isEmpty else {
            errorMessage = "No transcript available. Add a transcript first."
            return
        }
        
        isGeneratingChapters = true
        errorMessage = nil
        
        // Check if we have pre-shrunk segments to reuse
        let preShrunkSegments = cachedShrunkSegments.isEmpty ? nil : cachedShrunkSegments
        
        if preShrunkSegments != nil {
            statusMessage = "Using condensed transcript to generate chapters..."
        } else {
            statusMessage = "Condensing transcript into segments..."
        }
        
        progressDetails = ""
        
        do {
            let chapters = try await chapterService.generateChapters(
                from: transcript,
                preShrunkSegments: preShrunkSegments,
                progressHandler: { [weak self] message in
                    Task { @MainActor in
                        self?.progressDetails = message
                    }
                }
            )
            
            chapterMarkers = chapters.map {
                ChapterMarker(
                    timestamp: $0.timestamp,
                    title: $0.title,
                    summary: $0.summary
                )
            }
            statusMessage = "Generated \(chapterMarkers.count) chapter markers"
            progressDetails = ""
        } catch {
            errorMessage = "Failed to generate chapters: \(error.localizedDescription)"
            statusMessage = ""
            progressDetails = ""
        }
        
        isGeneratingChapters = false
    }
    
    public func generateShrunkTranscript() async {
        guard modelAvailable else { return }
        guard let transcript = episode.transcriptInputText, !transcript.isEmpty else {
            errorMessage = "No transcript available. Add a transcript first."
            return
        }
        
        isGeneratingShrunkTranscript = true
        errorMessage = nil
        statusMessage = "Condensing transcript..."
        progressDetails = ""
        
        // Set up progress handler
        shrinkerService.logHandler = { [weak self] message in
            Task { @MainActor in
                self?.progressDetails = message
            }
        }
        
        do {
            let config = TranscriptionShrinkerService.ShrinkConfig(
                maxWindowCharacters: maxWindowChars,
                overlap: overlap
            )
            
            let segments = try await shrinkerService.shrinkTranscript(transcript, config: config)
            
            // Cache segments for chapter generation
            cachedShrunkSegments = segments
            
            // Store segment counts for reduction stats
            shrunkSegmentCount = segments.count
            // Parse original to get count (rough estimate from double newlines)
            originalSegmentCount = transcript.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            
            // Format segments as readable text with timestamps
            shrunkTranscript = segments.map { segment in
                "[\(segment.firstSegmentTimestamp)]\n\(segment.summary)"
            }.joined(separator: "\n\n")
            
            // Calculate character counts for stats
            shrunkTranscriptCharCount = shrunkTranscript.count
            let stripped = stripTimestampsAndSpeakers(shrunkTranscript)
            shrunkTranscriptStrippedCharCount = stripped.count
            shrunkTranscriptCleanedCharCount = transcriptCleaner.cleanForAI(stripped).count
            
            statusMessage = "Shrunk transcript generated: \(originalSegmentCount) → \(shrunkSegmentCount) segments (\(reductionPercentage)% reduction)"
            progressDetails = ""
            
            // Automatically save to episode
            applyShrunkTranscript()
        } catch {
            if fallbackOnError {
                errorMessage = "Failed to shrink transcript (will use original): \(error.localizedDescription)"
            } else {
                errorMessage = "Failed to shrink transcript: \(error.localizedDescription)"
            }
            statusMessage = ""
            progressDetails = ""
        }
        
        isGeneratingShrunkTranscript = false
    }
    
    public func applyShrunkTranscript() {
        episode.shrunkTranscript = shrunkTranscript
        saveEpisode()
    }
    
    private func stripTimestampsAndSpeakers(_ text: String) -> String {
        // Remove [HH:MM:SS] or [MM:SS] timestamp patterns
        var result = text.replacingOccurrences(
            of: #"\[\d{1,2}:\d{2}(?::\d{2})?\]"#,
            with: "",
            options: .regularExpression
        )
        
        // Clean up extra whitespace
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func generateAll() async {
        isGeneratingAll = true
        statusMessage = "Starting comprehensive AI generation..."
        
        // Generate shrunk transcript first if it doesn't exist
        if episode.shrunkTranscript?.isEmpty ?? true {
            await generateShrunkTranscript()
        }
        
        await generateTitles()
        await generateDescription()
        await generateSocialPosts()
        await generateChapters()
        
        statusMessage = "All AI content generated successfully"
        isGeneratingAll = false
    }
    
    // MARK: - Apply Actions
    
    public func applyTitle(_ title: String) {
        episode.title = title
        saveEpisode()
    }
    
    public func applyDescription() {
        episode.episodeDescription = generatedDescription
        saveEpisode()
    }
    
    private func saveEpisode() {
        do {
            try modelContext?.save()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }
    
    public func copySocialPost(_ post: SocialPost) {
        copyToClipboard(post.content)
    }
    
    public func copyChaptersAsYouTube() {
        let output = chapterService.formatAsYouTube(
            chapterMarkers.map {
                ChapterGenerationService.ChapterMarker(
                    timestamp: $0.timestamp,
                    title: $0.title,
                    summary: $0.summary
                )
            }
        )
        copyToClipboard(output)
    }
    
    public func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Supporting Types

public extension AIIdeasViewModel {
    struct ChapterMarker: Identifiable {
        public let id = UUID()
        public var timestamp: String
        public var title: String
        public var summary: String
    }
    
    struct SocialPost: Identifiable {
        public let id = UUID()
        public var platform: SocialPlatform
        public var content: String
    }
    
    enum SocialPlatform: String, CaseIterable {
        case twitter = "Twitter/X"
        case linkedin = "LinkedIn"
        case threads = "Threads"
        
        public var icon: String {
            switch self {
            case .twitter: return "at.circle.fill"
            case .linkedin: return "briefcase.circle.fill"
            case .threads: return "text.bubble.fill"
            }
        }
    }
}
