import Foundation
import FoundationModels

/// Service for generating podcast episode titles using Apple Intelligence
@available(macOS 26.0, *)
@MainActor
public class TitleGenerationService {
    // MARK: - Dependencies
    
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Title Generation
    
    /// Generates 5 creative title suggestions based on the episode transcript
    /// - Parameter transcript: The episode transcript text
    /// - Returns: Array of 5 title suggestions
    /// - Throws: Error if generation fails
    public func generateTitles(from transcript: String) async throws -> [String] {
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
        
        return response.content.titles
    }
}

// MARK: - Generable Structs for LLM Structured Output

@Generable
private struct TitleSuggestionsPOCO {
    @Guide(description: "Five creative, concise podcast episode titles", .count(5))
    var titles: [String]
}
