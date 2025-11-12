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
    
    @Published public var isGeneratingTitles: Bool = false
    @Published public var isGeneratingDescription: Bool = false
    @Published public var isGeneratingSocial: Bool = false
    @Published public var isGeneratingChapters: Bool = false
    @Published public var isGeneratingAll: Bool = false
    
    @Published public var errorMessage: String?
    @Published public var modelAvailable: Bool = false
    
    // MARK: - Dependencies
    
    public let episode: Episode
    public var modelContext: ModelContext?
    
    private let titleService = TitleGenerationService()
    private let descriptionService = DescriptionGenerationService()
    private let socialService = SocialPostGenerationService()
    private let chapterService = ChapterGenerationService()
    private let transcriptCleaner = TranscriptCleaner()
    
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
    
    // MARK: - Content Generation
    
    public func generateTitles() async {
        guard modelAvailable else { return }
        guard let transcript = episode.transcriptInputText, !transcript.isEmpty else {
            errorMessage = "No transcript available. Add a transcript first."
            return
        }
        
        isGeneratingTitles = true
        errorMessage = nil
        
        do {
            titleSuggestions = try await titleService.generateTitles(from: transcript)
        } catch {
            errorMessage = "Failed to generate titles: \(error.localizedDescription)"
        }
        
        isGeneratingTitles = false
    }
    
    public func generateDescription() async {
        guard modelAvailable else { return }
        guard let transcript = episode.transcriptInputText, !transcript.isEmpty else {
            errorMessage = "No transcript available. Add a transcript first."
            return
        }
        
        isGeneratingDescription = true
        errorMessage = nil
        
        do {
            generatedDescription = try await descriptionService.generateDescription(
                from: transcript,
                title: episode.title,
                length: descriptionLength
            )
        } catch {
            errorMessage = "Failed to generate description: \(error.localizedDescription)"
        }
        
        isGeneratingDescription = false
    }
    
    public func generateSocialPosts() async {
        guard modelAvailable else { return }
        guard let transcript = episode.transcriptInputText, !transcript.isEmpty else {
            errorMessage = "No transcript available. Add a transcript first."
            return
        }
        
        isGeneratingSocial = true
        errorMessage = nil
        
        do {
            let posts = try await socialService.generateSocialPosts(
                from: transcript,
                title: episode.title
            )
            
            socialPosts = posts.map {
                SocialPost(platform: SocialPlatform(rawValue: $0.platform.rawValue) ?? .twitter, content: $0.content)
            }
        } catch {
            errorMessage = "Failed to generate social posts: \(error.localizedDescription)"
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
        
        do {
            let chapters = try await chapterService.generateChapters(from: transcript)
            
            chapterMarkers = chapters.map {
                ChapterMarker(
                    timestamp: $0.timestamp,
                    title: $0.title,
                    summary: $0.summary
                )
            }
        } catch {
            errorMessage = "Failed to generate chapters: \(error.localizedDescription)"
        }
        
        isGeneratingChapters = false
    }
    
    public func generateAll() async {
        isGeneratingAll = true
        
        await generateTitles()
        await generateDescription()
        await generateSocialPosts()
        await generateChapters()
        
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
