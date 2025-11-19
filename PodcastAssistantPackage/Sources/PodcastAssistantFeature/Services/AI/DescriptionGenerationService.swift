import Foundation
import FoundationModels

/// Service for generating podcast episode descriptions using Apple Intelligence
@available(macOS 26.0, *)
@MainActor
public class DescriptionGenerationService {
    // MARK: - Types
    
    public enum DescriptionLength: String, CaseIterable {
        case short = "Short"
        case medium = "Medium"
        case long = "Long"
        
        var lengthGuidance: String {
            switch self {
            case .short:
                return "in 2-3 sentences (50-75 words)"
            case .medium:
                return "in 1-2 paragraphs (100-150 words)"
            case .long:
                return "in 3-4 paragraphs (200-300 words)"
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Description Generation
    
    /// Generates an episode description based on the transcript
    /// - Parameters:
    ///   - transcript: The episode transcript text
    ///   - title: The episode title
    ///   - length: Desired description length
    /// - Returns: Generated description text
    /// - Throws: Error if generation fails
    public func generateDescription(
        from transcript: String,
        title: String,
        length: DescriptionLength
    ) async throws -> String {
        let session = LanguageModelSession(
            instructions: "You are a podcast producer who writes compelling episode descriptions."
        )
        
        let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
        let truncatedTranscript = String(cleanedTranscript.prefix(12000))
        
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
        \(truncatedTranscript)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: EpisodeDescriptionResponsePOCO.self
        )
        
        return response.content.description
    }
}

// MARK: - Generable Structs for LLM Structured Output

@Generable
private struct EpisodeDescriptionResponsePOCO {
    @Guide(description: "A compelling episode description")
    var description: String
}
