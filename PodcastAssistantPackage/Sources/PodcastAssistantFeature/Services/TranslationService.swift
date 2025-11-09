import Foundation
import Translation

/// Service responsible for translating SRT subtitle text using macOS Translation API
@available(macOS 12.0, *)
public class TranslationService {
    
    public init() {}
    
    /// Common YouTube-supported languages
    public enum SupportedLanguage: String, CaseIterable, Identifiable {
        case spanish = "es"
        case french = "fr"
        case german = "de"
        case italian = "it"
        case portuguese = "pt"
        case japanese = "ja"
        case korean = "ko"
        case chinese = "zh-Hans"
        case dutch = "nl"
        case russian = "ru"
        case arabic = "ar"
        case hindi = "hi"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .spanish: return "Spanish (Español)"
            case .french: return "French (Français)"
            case .german: return "German (Deutsch)"
            case .italian: return "Italian (Italiano)"
            case .portuguese: return "Portuguese (Português)"
            case .japanese: return "Japanese (日本語)"
            case .korean: return "Korean (한국어)"
            case .chinese: return "Chinese Simplified (中文)"
            case .dutch: return "Dutch (Nederlands)"
            case .russian: return "Russian (Русский)"
            case .arabic: return "Arabic (العربية)"
            case .hindi: return "Hindi (हिन्दी)"
            }
        }
        
        public var locale: Locale {
            return Locale(identifier: rawValue)
        }
    }
    
    /// Translates SRT content to the specified target language
    /// - Parameters:
    ///   - srtContent: The SRT content to translate
    ///   - targetLanguage: The target language code
    /// - Returns: Translated SRT content with preserved timestamps and structure
    /// - Throws: TranslationError if translation fails
    public func translateSRT(
        _ srtContent: String,
        to targetLanguage: SupportedLanguage
    ) async throws -> String {
        // Parse SRT into entries
        let entries = try parseSRT(srtContent)
        
        // Translate each entry's text
        var translatedEntries: [(index: Int, timestamp: String, text: String)] = []
        
        for entry in entries {
            let translatedText = try await translateText(
                entry.text,
                to: targetLanguage
            )
            translatedEntries.append((
                index: entry.index,
                timestamp: entry.timestamp,
                text: translatedText
            ))
        }
        
        // Reconstruct SRT format
        return reconstructSRT(from: translatedEntries)
    }
    
    /// Translates a single text string to the target language
    private func translateText(
        _ text: String,
        to targetLanguage: SupportedLanguage
    ) async throws -> String {
        // Create translation session
        let configuration = TranslationSession.Configuration(
            target: targetLanguage.locale
        )
        
        let session = TranslationSession(configuration: configuration)
        
        do {
            // Prepare translation request
            let request = TranslationSession.Request(
                sourceText: text,
                clientIdentifier: "com.refractored.PodcastAssistant.translation"
            )
            
            // Perform translation
            let response = try await session.translate(request)
            
            return response.targetText
        } catch {
            throw TranslationError.translationFailed(error.localizedDescription)
        }
    }
    
    /// Parses SRT content into structured entries
    private func parseSRT(_ srtContent: String) throws -> [(index: Int, timestamp: String, text: String)] {
        var entries: [(index: Int, timestamp: String, text: String)] = []
        
        let blocks = srtContent.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for block in blocks {
            let lines = block.components(separatedBy: .newlines)
            
            guard lines.count >= 3,
                  let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else {
                continue
            }
            
            let timestamp = lines[1].trimmingCharacters(in: .whitespaces)
            let text = lines[2...].joined(separator: "\n")
            
            entries.append((index: index, timestamp: timestamp, text: text))
        }
        
        if entries.isEmpty {
            throw TranslationError.invalidSRTFormat
        }
        
        return entries
    }
    
    /// Reconstructs SRT content from translated entries
    private func reconstructSRT(
        from entries: [(index: Int, timestamp: String, text: String)]
    ) -> String {
        var output = ""
        
        for entry in entries {
            output += "\(entry.index)\n"
            output += "\(entry.timestamp)\n"
            output += "\(entry.text)\n\n"
        }
        
        return output
    }
    
    public enum TranslationError: LocalizedError {
        case invalidSRTFormat
        case translationFailed(String)
        case unsupportedLanguage
        
        public var errorDescription: String? {
            switch self {
            case .invalidSRTFormat:
                return "Invalid SRT format. Cannot parse subtitle entries."
            case .translationFailed(let details):
                return "Translation failed: \(details)"
            case .unsupportedLanguage:
                return "The selected language is not supported."
            }
        }
    }
}
