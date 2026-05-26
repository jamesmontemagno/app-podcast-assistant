import Foundation
import FoundationModels
import SwiftIntelligence

/// OpenAI-backed content generation using SwiftIntelligence
@available(macOS 26.0, *)
@MainActor
public final class OpenAIContentService: Sendable {
    private let transcriptCleaner = TranscriptCleaner()
    private let modelName: String
    
    public init(modelName: String = "gpt-5-mini") {
        self.modelName = modelName
    }
    
    private func makeSession(instructions: String, apiKey: String) -> IntelligenceSession {
        IntelligenceModel.openAIApiKey = apiKey
        return IntelligenceSession(model: .openAI(model: modelName)) {
            instructions
        }
    }
    
    public func generateTitles(
        from transcript: String,
        style: TitleStyle = .default,
        apiKey: String
    ) async throws -> [String] {
        let session = makeSession(
            instructions: "You are a creative podcast producer who writes engaging, concise episode titles.",
            apiKey: apiKey
        )
        let processedTranscript = transcriptCleaner.cleanForAI(transcript)
        let prompt = Self.buildTitlePrompt(
            processedTranscript: processedTranscript,
            styleGuidance: style.promptGuidance
        )
        let result: TitleSuggestionsPOCO = try await session.respond(to: prompt, generating: TitleSuggestionsPOCO.self)
        return result.titles
    }

    static func buildTitlePrompt(processedTranscript: String, styleGuidance: String) -> String {
        """
        You are generating titles for a podcast episode based on its transcript.
        
        Analyze the transcript and identify the topics that are discussed the most.
        Focus primarily on the main topics that take up the majority of the conversation.
        The title should reflect what listeners will spend most of their time hearing about.
        You can mention secondary topics briefly, but prioritize the core subject matter.
        
        Generate 5 creative, concise titles for this podcast episode.
        Keep titles under 10 words each.
        Make them engaging, descriptive, and SEO-friendly.
        Style preference: \(styleGuidance)
        
        Episode Transcript:
        \(processedTranscript)
        """
    }
    
    public func generateDescription(
        from transcript: String,
        title: String,
        length: DescriptionGenerationService.DescriptionLength,
        apiKey: String
    ) async throws -> String {
        let session = makeSession(
            instructions: "You are a podcast producer who writes compelling episode descriptions.",
            apiKey: apiKey
        )
        let processedTranscript = transcriptCleaner.cleanForAI(transcript)
        let prompt = """
        You are writing a compelling podcast episode description based on its transcript.
        
        Analyze the transcript carefully and identify:
        - The main topics that dominate the conversation (what takes up most of the time)
        - Key insights, valuable takeaways, or unique perspectives shared
        - The overall narrative or flow of the discussion
        
        Write a description \(length.lengthGuidance) that:
        - Focuses primarily on the main topics discussed
        - Highlights the value and key takeaways for listeners
        - Uses engaging, conversational language
        - Captures what makes this episode worth listening to
        
        Episode title: \(title)
        
        Episode Transcript:
        \(processedTranscript)
        """
        let result: EpisodeDescriptionResponsePOCO = try await session.respond(to: prompt, generating: EpisodeDescriptionResponsePOCO.self)
        return result.description
    }
    
    public func generateSocialPosts(
        from transcript: String,
        title: String,
        apiKey: String
    ) async throws -> [SocialPostGenerationService.SocialPost] {
        let session = makeSession(
            instructions: "You are a social media expert who creates engaging posts for different platforms.",
            apiKey: apiKey
        )
        let processedTranscript = transcriptCleaner.cleanForAI(transcript)
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
        
        Episode title: \(title)
        
        Episode Transcript:
        \(processedTranscript)
        """
        let result: SocialPostsResponsePOCO = try await session.respond(to: prompt, generating: SocialPostsResponsePOCO.self)
        return [
            SocialPostGenerationService.SocialPost(platform: .twitter, content: result.twitter),
            SocialPostGenerationService.SocialPost(platform: .linkedin, content: result.linkedin),
            SocialPostGenerationService.SocialPost(platform: .threads, content: result.threads)
        ]
    }
    
    public func generateChapters(
        from transcript: String,
        apiKey: String
    ) async throws -> [ChapterMarker] {
        let session = makeSession(
            instructions: "You are a podcast editor who creates chapter markers based on topic transitions.",
            apiKey: apiKey
        )
        let processedTranscript = transcriptCleaner.cleanForAI(transcript)
        let prompt = """
        Create chapter markers for this podcast episode from the full transcript.
        
        Analyze the transcript and identify where MAJOR topic shifts occur.
        Be VERY selective - only create chapters for significant topic changes.
        Think of chapters as major sections viewers would skip to, not every minor topic.
        
        Guidelines:
        - Create chapters depending on episode length (aim for one chapter every 5-10 minutes)
        - Ensure you cover the entire transcript.
        - Only mark MAJOR topic transitions - ignore minor shifts
        - First chapter MUST start at 00:00:00 or 00:00 based on the length of the episode
        - Extract or estimate timestamps where topics shift (format: HH:MM:SS or MM:SS)
        - Distribute chapters evenly; avoid gaps > 10 minutes
        - Create descriptive titles (under 8 words)
        - Provide a one-sentence summary per chapter
        
        Full Transcript:
        \(processedTranscript)
        """
        let result: ChapterMarkersResponsePOCO = try await session.respond(to: prompt, generating: ChapterMarkersResponsePOCO.self)
        return result.chapters.map { chapter in
            ChapterMarker(
                timestamp: normalizeTimestamp(chapter.timestamp),
                title: chapter.title,
                summary: chapter.summary
            )
        }
    }
    
    // MARK: - Chapter Marker Type
    
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
    
    // MARK: - Helpers
    
    private func normalizeTimestamp(_ timestamp: String) -> String {
        let totalSeconds = timestampToSeconds(timestamp)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func timestampToSeconds(_ timestamp: String) -> Double {
        let parts = timestamp.components(separatedBy: ":")
        guard !parts.isEmpty else { return 0 }
        
        var seconds: Double = 0
        
        if parts.count == 2 {
            if let minutes = Double(parts[0]), let secs = Double(parts[1]) {
                seconds = minutes * 60 + secs
            }
        } else if parts.count == 3 {
            if let hours = Double(parts[0]), let minutes = Double(parts[1]), let secs = Double(parts[2]) {
                seconds = hours * 3600 + minutes * 60 + secs
            }
        }
        
        return seconds
    }
}

// MARK: - Generable response shapes

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
