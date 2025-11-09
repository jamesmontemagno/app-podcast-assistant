import Foundation
import SwiftUI
import SwiftData
import FoundationModels
import AppKit

/// ViewModel for AI-powered content generation from episode transcripts
@MainActor
public class AIIdeasViewModel: ObservableObject {
    // MARK: - Published State (In-Memory Only)
    
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
    
    public let episode: Episode
    private let context: ModelContext
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init(episode: Episode, context: ModelContext) {
        self.episode = episode
        self.context = context
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
    
    // MARK: - Generation Methods
    
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
            
            // Clean transcript to maximize content in context window
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
                generating: TitleSuggestions.self
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
            
            // Clean transcript to maximize content in context window
            let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
            let truncatedTranscript = String(cleanedTranscript.prefix(12000))
            
            let prompt = """
            You are writing a description for a podcast episode based on its transcript.
            
            Analyze the transcript and identify what topics are discussed the most.
            Structure your description to:
            1. Lead with the main topics that dominate the conversation (the majority of episode time)
            2. Highlight key insights, takeaways, or interesting points from these main topics
            3. Briefly mention secondary topics or tangents toward the end
            
            Write a compelling episode description \(lengthGuidance).
            Make it engaging, informative, and enticing for potential listeners.
            Focus on what they'll actually spend most of their time hearing about.
            
            Episode Transcript:
            \(truncatedTranscript)
            """
            
            let response = try await session.respond(
                to: prompt,
                generating: EpisodeDescriptionResponse.self
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
            
            // Clean transcript to maximize content in context window
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
                generating: SocialPostsResponse.self
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
            // Check if transcript fits in context window
            if transcript.count <= 12000 {
                // Process in single request
                chapterMarkers = try await generateChaptersForChunk(
                    transcript,
                    chunkIndex: 0,
                    totalChunks: 1,
                    previousChapters: []
                )
            } else {
                // Split into chunks and process separately
                let chunks = transcriptCleaner.chunkForChapterGeneration(transcript, maxChunkSize: 12000)
                var allChapters: [ChapterMarker] = []
                
                for (index, chunk) in chunks.enumerated() {
                    // Pass previous chapters to maintain continuity
                    let chunkChapters = try await generateChaptersForChunk(
                        chunk.text,
                        chunkIndex: index,
                        totalChunks: chunks.count,
                        previousChapters: allChapters
                    )
                    allChapters.append(contentsOf: chunkChapters)
                }
                
                // Remove duplicate chapters at chunk boundaries
                chapterMarkers = deduplicateChapters(allChapters)
            }
        } catch let error as LanguageModelSession.GenerationError {
            // Handle context window exceeded error
            if case .exceededContextWindowSize = error {
                // Retry with smaller chunks if context window was exceeded
                await retryChaptersWithSmallerChunks(transcript)
            } else {
                errorMessage = "Failed to generate chapters: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Failed to generate chapters: \(error.localizedDescription)"
        }
        
        isGeneratingChapters = false
    }
    
    private func retryChaptersWithSmallerChunks(_ transcript: String) async {
        do {
            // Try with half the chunk size
            let chunks = transcriptCleaner.chunkForChapterGeneration(transcript, maxChunkSize: 6000)
            var allChapters: [ChapterMarker] = []
            
            for (index, chunk) in chunks.enumerated() {
                let chunkChapters = try await generateChaptersForChunk(
                    chunk.text,
                    chunkIndex: index,
                    totalChunks: chunks.count,
                    previousChapters: allChapters
                )
                allChapters.append(contentsOf: chunkChapters)
            }
            
            chapterMarkers = deduplicateChapters(allChapters)
        } catch {
            errorMessage = "Failed to generate chapters even with smaller chunks: \(error.localizedDescription)"
        }
    }
    
    private func generateChaptersForChunk(
        _ chunkText: String,
        chunkIndex: Int,
        totalChunks: Int,
        previousChapters: [ChapterMarker]
    ) async throws -> [ChapterMarker] {
        let session = LanguageModelSession(
            instructions: """
            You are a podcast editor who identifies topic changes and creates chapter markers.
            Analyze the transcript and find major topic transitions.
            Follow strict spacing rules: no more than 10 chapters per hour, minimum 3 minutes between chapters.
            """
        )
        
        let chapterCount = totalChunks == 1 ? "5-8" : "2-4"
        
        // Build context about previous chapters if any
        var previousChaptersContext = ""
        if !previousChapters.isEmpty {
            let lastChapter = previousChapters.last!
            previousChaptersContext = """
            
            Previous chapters already identified:
            \(previousChapters.map { "- \($0.timestamp): \($0.title)" }.joined(separator: "\n"))
            
            Continue from where these left off and avoid duplicating these topics.
            IMPORTANT: Your first chapter must be at least 3 minutes after \(lastChapter.timestamp).
            """
        }
        
        let prompt = """
        You are creating chapter markers for a podcast episode based on its transcript.
        
        Analyze the transcript and identify \(chapterCount) major topic changes or transitions.
        Each chapter should represent a distinct segment where the conversation shifts to a new subject.
        
        CRITICAL SPACING REQUIREMENTS:
        - Maximum 10 chapters per hour of content (aim for 6-10 chapters total for typical episodes)
        - Each chapter must be at least 3 minutes (180 seconds) apart from the previous one
        - Chapters should mark MAJOR topic shifts, not minor tangents or sub-topics
        - Better to have fewer, well-spaced chapters than many close together
        
        For each chapter:
        - Extract the exact timestamp from the transcript (format: MM:SS or HH:MM:SS)
        - If no timestamps are visible, estimate based on content progression
        - Create a clear, descriptive title (under 8 words) that tells listeners what this segment covers
        - Write a one-sentence summary of what's discussed in this chapter
        - Ensure at least 3 minutes gap from the previous chapter
        
        Focus on meaningful topic shifts, not minor tangents.
        \(totalChunks > 1 ? "Note: This is section \(chunkIndex + 1) of \(totalChunks) from the full episode. Focus on major topics in this section." : "")\(previousChaptersContext)
        
        Episode Transcript:
        \(chunkText)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: ChapterMarkersResponse.self
        )
        
        return response.content.chapters.map { chapter in
            ChapterMarker(
                timestamp: chapter.timestamp,
                title: chapter.title,
                summary: chapter.summary
            )
        }
    }
    
    private func deduplicateChapters(_ chapters: [ChapterMarker]) -> [ChapterMarker] {
        var uniqueChapters: [ChapterMarker] = []
        var seenTimestamps: Set<String> = []
        
        for chapter in chapters {
            // Use timestamp as uniqueness key
            if !seenTimestamps.contains(chapter.timestamp) {
                uniqueChapters.append(chapter)
                seenTimestamps.insert(chapter.timestamp)
            }
        }
        
        // Sort by timestamp
        let sortedChapters = uniqueChapters.sorted { timestamp1, timestamp2 in
            compareTimestamps(timestamp1.timestamp, timestamp2.timestamp)
        }
        
        // Enforce 3-minute minimum spacing
        return enforceMinimumSpacing(sortedChapters, minimumGapSeconds: 180)
    }
    
    /// Filters chapters to ensure minimum spacing between them
    private func enforceMinimumSpacing(_ chapters: [ChapterMarker], minimumGapSeconds: Int) -> [ChapterMarker] {
        guard !chapters.isEmpty else { return [] }
        
        var filteredChapters: [ChapterMarker] = [chapters[0]] // Always keep first chapter
        
        for chapter in chapters.dropFirst() {
            let previousTimestamp = filteredChapters.last!.timestamp
            let currentSeconds = timestampToSeconds(chapter.timestamp)
            let previousSeconds = timestampToSeconds(previousTimestamp)
            
            // Only add if it's at least minimumGapSeconds after the previous chapter
            if currentSeconds - previousSeconds >= minimumGapSeconds {
                filteredChapters.append(chapter)
            }
        }
        
        return filteredChapters
    }
    
    private func compareTimestamps(_ ts1: String, _ ts2: String) -> Bool {
        // Convert timestamps to seconds for comparison
        let seconds1 = timestampToSeconds(ts1)
        let seconds2 = timestampToSeconds(ts2)
        return seconds1 < seconds2
    }
    
    private func timestampToSeconds(_ timestamp: String) -> Int {
        // Parse MM:SS or HH:MM:SS format
        let components = timestamp.components(separatedBy: ":")
        
        if components.count == 2 {
            // MM:SS
            let minutes = Int(components[0]) ?? 0
            let seconds = Int(components[1]) ?? 0
            return minutes * 60 + seconds
        } else if components.count == 3 {
            // HH:MM:SS
            let hours = Int(components[0]) ?? 0
            let minutes = Int(components[1]) ?? 0
            let seconds = Int(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        }
        
        return 0
    }
    
    public func generateAll() async {
        isGeneratingAll = true
        
        await generateTitles()
        await generateDescription()
        await generateSocialPosts()
        await generateChapters()
        
        isGeneratingAll = false
    }
    
    // MARK: - Apply to Episode Actions
    
    public func applyTitle(_ title: String) {
        episode.title = title
        saveContext()
    }
    
    public func applyDescription() {
        episode.episodeDescription = generatedDescription
        saveContext()
    }
    
    public func applySocialPost(_ post: SocialPost) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(post.content, forType: .string)
        #endif
    }
    
    public func applyChaptersToDescription() {
        var description = episode.episodeDescription ?? generatedDescription
        
        // Append chapters in YouTube format
        description += "\n\n## Chapters\n"
        for marker in chapterMarkers {
            description += "\(marker.timestamp) - \(marker.title)\n"
        }
        
        episode.episodeDescription = description
        saveContext()
    }
    
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
            }
        }
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

// MARK: - Generable Structs for LLM Structured Output

@Generable
struct TitleSuggestions {
    @Guide(description: "Five creative, concise podcast episode titles", .count(5))
    var titles: [String]
}

@Generable
struct EpisodeDescriptionResponse {
    @Guide(description: "A compelling episode description")
    var description: String
}

@Generable
struct SocialPostsResponse {
    @Guide(description: "Twitter post (max 280 characters)")
    var twitter: String
    
    @Guide(description: "LinkedIn post (professional tone, 150-200 words)")
    var linkedin: String
    
    @Guide(description: "Threads post (casual tone, 2-3 paragraphs)")
    var threads: String
}

@Generable
struct ChapterMarkersResponse {
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
