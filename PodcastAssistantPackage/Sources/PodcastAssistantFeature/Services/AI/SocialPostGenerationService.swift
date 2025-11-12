import Foundation
import FoundationModels

/// Service for generating social media posts using Apple Intelligence
@available(macOS 26.0, *)
@MainActor
public class SocialPostGenerationService {
    // MARK: - Types
    
    public struct SocialPost {
        public let platform: SocialPlatform
        public let content: String
        
        public init(platform: SocialPlatform, content: String) {
            self.platform = platform
            self.content = content
        }
    }
    
    public enum SocialPlatform: String, CaseIterable {
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
    
    // MARK: - Dependencies
    
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Social Post Generation
    
    /// Generates platform-specific social media posts based on the episode transcript
    /// - Parameters:
    ///   - transcript: The episode transcript text
    ///   - title: The episode title
    /// - Returns: Array of social posts for different platforms
    /// - Throws: Error if generation fails
    public func generateSocialPosts(
        from transcript: String,
        title: String
    ) async throws -> [SocialPost] {
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
        
        Episode title: \(title)
        
        Episode Transcript:
        \(truncatedTranscript)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: SocialPostsResponsePOCO.self
        )
        
        return [
            SocialPost(platform: .twitter, content: response.content.twitter),
            SocialPost(platform: .linkedin, content: response.content.linkedin),
            SocialPost(platform: .threads, content: response.content.threads)
        ]
    }
}

// MARK: - Generable Structs for LLM Structured Output

@Generable
private struct SocialPostsResponsePOCO {
    @Guide(description: "Twitter post (max 280 characters)")
    var twitter: String
    
    @Guide(description: "LinkedIn post (professional tone, 150-200 words)")
    var linkedin: String
    
    @Guide(description: "Threads post (casual tone, 2-3 paragraphs)")
    var threads: String
}
