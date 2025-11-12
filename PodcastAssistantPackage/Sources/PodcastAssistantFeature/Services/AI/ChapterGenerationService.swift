import Foundation
import FoundationModels

/// Service for generating podcast chapter markers using Apple Intelligence
@available(macOS 26.0, *)
@MainActor
public class ChapterGenerationService {
    // MARK: - Types
    
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
    
    // MARK: - Dependencies
    
    private let transcriptCleaner = TranscriptCleaner()
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Chapter Generation
    
    /// Generates chapter markers based on the episode transcript
    /// - Parameter transcript: The episode transcript text
    /// - Returns: Array of 5-10 chapter markers
    /// - Throws: Error if generation fails
    public func generateChapters(from transcript: String) async throws -> [ChapterMarker] {
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
        
        return response.content.chapters.map {
            ChapterMarker(
                timestamp: $0.timestamp,
                title: $0.title,
                summary: $0.summary
            )
        }
    }
    
    /// Formats chapter markers as YouTube-style chapter list
    /// - Parameter chapters: Array of chapter markers
    /// - Returns: Formatted string with timestamps and titles
    public func formatAsYouTube(_ chapters: [ChapterMarker]) -> String {
        var output = ""
        for marker in chapters {
            output += "\(marker.timestamp) - \(marker.title)\n"
        }
        return output
    }
}

// MARK: - Generable Structs for LLM Structured Output

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
