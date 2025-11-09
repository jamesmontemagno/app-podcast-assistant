import Foundation
import Translation

/// Represents a language available for translation
public struct AvailableLanguage: Identifiable, Hashable {
    public let id: String
    public let language: Locale.Language
    public let localizedName: String
    public let code: String
    public let status: LanguageAvailability.Status
    
    public var isInstalled: Bool { status == .installed }
    
    public init(language: Locale.Language, status: LanguageAvailability.Status) {
        self.language = language
        let identifier = language.bcp47Identifier
        self.id = identifier
        self.code = identifier
        self.status = status
        
        if let localized = Locale.current.localizedString(forIdentifier: identifier) {
            self.localizedName = localized
        } else if let code = language.languageCode?.identifier,
                  let fallback = Locale.current.localizedString(forLanguageCode: code) {
            self.localizedName = fallback
        } else {
            self.localizedName = identifier
        }
    }
}

/// Progress update emitted while translating an SRT document
public struct TranslationProgressUpdate: Sendable {
    public let currentEntry: Int
    public let totalEntries: Int
    public let timecode: String
    public let preview: String

    public init(currentEntry: Int, totalEntries: Int, timecode: String, preview: String) {
        self.currentEntry = currentEntry
        self.totalEntries = totalEntries
        self.timecode = timecode
        self.preview = preview
    }

    /// Number of entries that have completed translation prior to the current one.
    public var completedEntries: Int {
        max(0, currentEntry - 1)
    }

    /// Fractional progress for use with progress indicators.
    public var fractionCompleted: Double {
        guard totalEntries > 0 else { return 0 }
        return Double(completedEntries) / Double(totalEntries)
    }
}

/// Service responsible for translating SRT subtitle text using macOS Translation API
@available(macOS 26.0, *)
public final class TranslationService: Sendable {
    private let sourceLanguage: Locale.Language
    
    public init() {
        self.sourceLanguage = Locale.current.language
    }
    
    /// Gets all available translation languages with their installation status
    public func getAvailableLanguages() async -> [AvailableLanguage] {
        print("🌐 === Querying all supported languages ===")
        let availability = LanguageAvailability()
        let languages = await availability.supportedLanguages
        
        print("🌐 Total supported languages: \(languages.count)")
        print("🌐 Source language for checks: \(sourceLanguage.bcp47Identifier)")
        let sourceStatus = await availability.status(from: sourceLanguage, to: sourceLanguage)
        print("🌐 Source language status: \(sourceStatus)")
        var languageMap: [String: AvailableLanguage] = [:]
        
        for (index, language) in languages.enumerated() {
            // Skip English (source language)
            if language.languageCode?.identifier == "en" {
                continue
            }
            
            let status = await availability.status(from: sourceLanguage, to: language)
            let availableLang = AvailableLanguage(language: language, status: status)
            let statusSymbol = availableLang.isInstalled ? "✅" : "⚠️"
            
            print("🌐 [\(index + 1)] \(statusSymbol) \(availableLang.localizedName) - Identifier: \(availableLang.code) - Status: \(status)")
            
            // Keep the most installed variant if duplicates exist
            if let existing = languageMap[availableLang.id] {
                if existing.isInstalled { continue }
            }
            languageMap[availableLang.id] = availableLang
        }
        
        print("🌐 === End of supported languages ===")
        
        let availableLanguages = Array(languageMap.values)
        
        // Sort: installed first, then alphabetically by localized name
        return availableLanguages.sorted { lhs, rhs in
            if lhs.isInstalled != rhs.isInstalled {
                return lhs.isInstalled
            }
            return lhs.localizedName < rhs.localizedName
        }
    }
    
    /// Translates SRT content to the specified target language
    /// - Parameters:
    ///   - srtContent: The SRT content to translate
    ///   - targetLanguage: The target language
    /// - Returns: Translated SRT content with preserved timestamps and structure
    /// - Throws: TranslationError if translation fails
    public func translateSRT(
        _ srtContent: String,
        to targetLanguage: AvailableLanguage,
        progressHandler: (@MainActor (_ update: TranslationProgressUpdate) -> Void)? = nil
    ) async throws -> String {
        print("🌐 Starting SRT translation to \(targetLanguage.localizedName)")
        
        // Check if language is installed
        if !targetLanguage.isInstalled {
            print("❌ Language pack not installed for \(targetLanguage.localizedName)")
            throw TranslationError.languagePackNotInstalled(targetLanguage.localizedName)
        }
        
        // Parse SRT into entries
        let entries = try parseSRT(srtContent)
        print("📝 Parsed \(entries.count) SRT entries")
        
        // Translate each entry's text
        var translatedEntries: [(index: Int, timestamp: String, text: String)] = []
        
        for (idx, entry) in entries.enumerated() {
            print("  Translating entry \(idx + 1)/\(entries.count)...")
            if let handler = progressHandler {
                let preview = entry.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let truncated = String(preview.prefix(80))
                let update = TranslationProgressUpdate(
                    currentEntry: idx + 1,
                    totalEntries: entries.count,
                    timecode: entry.timestamp,
                    preview: truncated
                )
                await handler(update)
            }
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
        
        print("✅ Translation complete")
        // Reconstruct SRT format
        return reconstructSRT(from: translatedEntries)
    }
    
    /// Translates a single text string to the target language
    /// Requires languages to be pre-installed via System Settings
    private func translateText(
        _ text: String,
        to targetLanguage: AvailableLanguage
    ) async throws -> String {
        // Create translation session with source (English) and target language
        let targetLang = targetLanguage.language
        
        print("    🔄 Creating translation session:")
        print("      Source: \(sourceLanguage)")
        print("      Target: \(targetLang) (\(targetLanguage.localizedName))")
        print("      Text preview: \(String(text.prefix(50)))\(text.count > 50 ? "..." : "")")
        
        do {
            // Use installedSource init - requires languages to be pre-installed
            let session = TranslationSession(installedSource: sourceLanguage, target: targetLang)
            print("      ✅ Session created successfully")
            
            let response = try await session.translate(text)
            print("      ✅ Translation successful")
            return response.targetText
        } catch let error as NSError {
            print("      ❌ Translation error:")
            print("         Domain: \(error.domain)")
            print("         Code: \(error.code)")
            print("         Description: \(error.localizedDescription)")
            print("         User Info: \(error.userInfo)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("         Underlying error: \(underlyingError)")
            }
            throw TranslationError.translationFailed("\(error.localizedDescription) (Domain: \(error.domain), Code: \(error.code))")
        } catch {
            print("      ❌ Unknown error type: \(error)")
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
        case languagePackNotInstalled(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidSRTFormat:
                return "Invalid SRT format. Cannot parse subtitle entries."
            case .translationFailed(let details):
                return "Translation failed: \(details)"
            case .unsupportedLanguage:
                return "The selected language is not supported."
            case .languagePackNotInstalled(let languageName):
                return """
                Language pack for \(languageName) is not installed.
                
                To download:
                1. Open System Settings
                2. Go to General > Language & Region
                3. Click Translation Languages
                4. Download the language packs for both your source language (typically English) and \(languageName)
                5. Restart Podcast Assistant after installing the packs
                """
            }
        }
    }
    
}

private extension Locale.Language {
    var bcp47Identifier: String {
        var components: [String] = []
        if let code = languageCode?.identifier { components.append(code) }
        if let scriptCode = script?.identifier { components.append(scriptCode) }
        if let regionCode = region?.identifier { components.append(regionCode) }
        if components.isEmpty { return "und" }
        return components.joined(separator: "-")
    }
}
