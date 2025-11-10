import Foundation
import SwiftUI
import FoundationModels
import AppKit

/// ViewModel for AI-powered content generation from episode transcripts
@available(macOS 26.0, *)
@MainActor
public class AIIdeasViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published public var titleSuggestions: [String] = []
    @Published public var generatedDescription: String = ""
    @Published public var descriptionLength: DescriptionLength = .medium
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
    
    public let episode: EpisodePOCO
    private let store: PodcastLibraryStore
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init(episode: EpisodePOCO, store: PodcastLibraryStore) {
        self.episode = episode
        self.store = store
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
            let session = LanguageModelSession(
                instructions: "You are a creative podcast producer who writes engaging, concise episode titles."
            )
            
            let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
            let truncatedTranscript = String(cleanedTranscript.prefix(12000))
            
            let prompt = """
            You are generating titles for a podcast episode based on its transcript.
            
            Analyze the transcript and identify the topics that are discussed the most.
            Focus primarily on the main topics that take up the majority of the conversation.
            The title should reflect what listeners will spend most of their time hearing about.
            You can mention secondary topics briefly, but prioritize the core subject matter.
            
            Generate 5 creative, concise titles for this podcast episode.
            Keep titles under 10 words each.
            Make them engaging, descriptive, and SEO-friendly.
            
            Episode Transcript:
            \(truncatedTranscript)
            """
            
            let response = try await session.respond(
                to: prompt,
                generating: TitleSuggestionsPOCO.self
            )
            
            titleSuggestions = response.content.titles
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
            let session = LanguageModelSession(
                instructions: "You are a podcast producer who writes compelling episode descriptions."
            )
            
            let lengthGuidance: String
            switch descriptionLength {
            case .short:
                lengthGuidance = "in 2-3 sentences (50-75 words)"
            case .medium:
                lengthGuidance = "in 1-2 paragraphs (100-150 words)"
            case .long:
                lengthGuidance = "in 3-4 paragraphs (200-300 words)"
            }
            
            let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
            let truncatedTranscript = String(cleanedTranscript.prefix(12000))
            
            let prompt = """
            You are writing a compelling podcast episode description based on its transcript.
            
            Analyze the transcript carefully and identify:
            - The main topics that dominate the conversation (what takes up most of the time)
            - Key insights, valuable takeaways, or unique perspectives shared
            - The overall narrative or flow of the discussion
            
            Write a description \(lengthGuidance) that:
            - Focuses primarily on the main topics discussed
            - Highlights the value and key takeaways for listeners
            - Uses engaging, conversational language
            - Captures what makes this episode worth listening to
            
            Episode title: \(episode.title)
            
            Episode Transcript:
            \(truncatedTranscript)
            """
            
            let response = try await session.respond(
                to: prompt,
                generating: EpisodeDescriptionResponsePOCO.self
            )
            
            generatedDescription = response.content.description
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
            let session = LanguageModelSession(
                instructions: "You are a social media expert who creates engaging posts for different platforms."
            )
            
            let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
            let truncatedTranscript = String(cleanedTranscript.prefix(10000))
            
            let prompt = """
            You are creating social media posts to promote a podcast episode based on its transcript.
            
            First, analyze the transcript and identify:
            - The main topics that dominate the conversation (what listeners will spend most time hearing)
            - Key insights, interesting quotes, or takeaways from these main topics
            - Secondary topics that can be mentioned briefly as hooks
            
            Create 3 platform-specific social media posts:
            
            1. **Twitter/X** (max 280 characters):
               - Use 2-3 relevant emojis to make it eye-catching
               - Lead with the main topic or a compelling hook
               - Conversational and engaging tone
               - Include a call-to-action (implied: listen to episode)
            
            2. **LinkedIn** (150-200 words):
               - Professional but approachable tone
               - Start with the main topic/insight that professionals would find valuable
               - Include 1-2 relevant emojis (sparingly, professionally)
               - Focus on business value, learning outcomes, or industry insights
               - End with what listeners will gain from the episode
            
            3. **Threads** (2-3 short paragraphs):
               - Casual and conversational tone
               - Use 3-5 emojis throughout to add personality
               - Start with a hook about the main topic
               - Share an interesting detail or quote from the episode
               - Create curiosity about secondary topics without spoiling everything
            
            Episode title: \(episode.title)
            
            Episode Transcript:
            \(truncatedTranscript)
            """
            
            let response = try await session.respond(
                to: prompt,
                generating: SocialPostsResponsePOCO.self
            )
            
            socialPosts = [
                SocialPost(platform: .twitter, content: response.content.twitter),
                SocialPost(platform: .linkedin, content: response.content.linkedin),
                SocialPost(platform: .threads, content: response.content.threads)
            ]
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
            let session = LanguageModelSession(
                instructions: "You are a podcast editor who creates chapter markers for episodes."
            )
            
            let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
            let truncatedTranscript = String(cleanedTranscript.prefix(15000))
            
            let prompt = """
            You are creating chapter markers for a podcast episode based on its transcript.
            
            Analyze the transcript and identify natural topic shifts or major discussion points.
            Create 5-10 chapter markers that help listeners navigate the episode.
            
            For each chapter:
            - Provide a timestamp in MM:SS or HH:MM:SS format
            - Create a short, descriptive title (under 8 words)
            - Write a one-sentence summary
            
            Start the first chapter at 00:00.
            Space chapters evenly throughout the episode.
            Focus on major topics or discussion shifts.
            
            Episode Transcript:
            \(truncatedTranscript)
            """
            
            let response = try await session.respond(
                to: prompt,
                generating: ChapterMarkersResponsePOCO.self
            )
            
            chapterMarkers = response.content.chapters.map {
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
            try store.updateEpisode(episode)
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }
    
    public func copySocialPost(_ post: SocialPost) {
        copyToClipboard(post.content)
    }
    
    public func copyChaptersAsYouTube() {
        var output = ""
        for marker in chapterMarkers {
            output += "\(marker.timestamp) - \(marker.title)\n"
        }
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
    enum DescriptionLength: String, CaseIterable {
        case short = "Short"
        case medium = "Medium"
        case long = "Long"
    }
    
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

// MARK: - Generable Structs for LLM Structured Output (Private to avoid conflicts)

@Generable
private struct TitleSuggestionsPOCO {
    @Guide(description: "Five creative, concise podcast episode titles", .count(5))
    var titles: [String]
}

@Generable
private struct EpisodeDescriptionResponsePOCO {
    @Guide(description: "A compelling episode description")
    var description: String
}

@Generable
private struct SocialPostsResponsePOCO {
    @Guide(description: "Twitter post (max 280 characters)")
    var twitter: String
    
    @Guide(description: "LinkedIn post (professional tone, 150-200 words)")
    var linkedin: String
    
    @Guide(description: "Threads post (casual tone, 2-3 paragraphs)")
    var threads: String
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
