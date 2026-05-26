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
    /// - Parameters:
    ///   - transcript: The episode transcript text
    ///   - isShrunkTranscript: Whether the transcript is a shrunk/condensed version
    ///   - style: Desired writing style for generated titles
    /// - Returns: Array of 5 title suggestions
    /// - Throws: Error if generation fails
    public func generateTitles(
        from transcript: String,
        isShrunkTranscript: Bool = false,
        style: TitleStyle = .default
    ) async throws -> [String] {
        let session = LanguageModelSession(
            instructions: "You are a creative podcast producer who writes engaging, concise episode titles."
        )
        
        let processedTranscript: String
        if isShrunkTranscript {
            // Clean timestamps and extra whitespace from shrunk transcript
            processedTranscript = transcriptCleaner.cleanForAI(transcript)
        } else {
            let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
            processedTranscript = String(cleanedTranscript.prefix(12000))
        }
        
        let transcriptNote = isShrunkTranscript
            ? "Note: This is a condensed AI-generated summary of the full episode transcript.\n\n"
            : ""
        let styleGuidance = style.promptGuidance
        
        let prompt = Self.buildTitlePrompt(
            processedTranscript: processedTranscript,
            transcriptNote: transcriptNote,
            styleGuidance: styleGuidance
        )
        
        let response = try await session.respond(
            to: prompt,
            generating: TitleSuggestionsPOCO.self
        )
        
        return response.content.titles
    }

    static func buildTitlePrompt(
        processedTranscript: String,
        transcriptNote: String,
        styleGuidance: String
    ) -> String {
        """
        \(transcriptNote)You are generating titles for a podcast episode based on its transcript.
        
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
}

public enum TitleStyle: String, CaseIterable, Codable, Sendable {
    case `default` = "default"
    case professional = "professional"
    case clickbait = "clickbait"
    case educational = "educational"
    case conversational = "conversational"

    public var displayName: String {
        switch self {
        case .default:
            return "Default"
        case .professional:
            return "Professional"
        case .clickbait:
            return "Clickbait"
        case .educational:
            return "Educational"
        case .conversational:
            return "Conversational"
        }
    }

    static func fromPersisted(_ value: String) -> TitleStyle? {
        if let style = TitleStyle(rawValue: value) {
            return style
        }

        switch value.lowercased() {
        case "default":
            return .default
        case "professional":
            return .professional
        case "clickbait":
            return .clickbait
        case "educational":
            return .educational
        case "conversational":
            return .conversational
        default:
            return nil
        }
    }

    public var promptGuidance: String {
        switch self {
        case .default:
            return "Balanced, clear, and engaging for a broad audience."
        case .professional:
            return "Professional, credible, and polished; avoid hype and slang."
        case .clickbait:
            return "High-curiosity and punchy while staying truthful to the content."
        case .educational:
            return "Informative and value-focused, emphasizing what listeners will learn."
        case .conversational:
            return "Friendly, human, and approachable with natural language."
        }
    }
}

// MARK: - Generable Structs for LLM Structured Output

@Generable
private struct TitleSuggestionsPOCO {
    @Guide(description: "Five creative, concise podcast episode titles", .count(5))
    var titles: [String]
}
