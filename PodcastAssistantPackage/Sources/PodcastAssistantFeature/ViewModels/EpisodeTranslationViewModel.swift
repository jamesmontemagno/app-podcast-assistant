import Foundation
import SwiftUI

@MainActor
@available(macOS 26.0, *)
public final class EpisodeTranslationViewModel: ObservableObject {
    @Published public var availableLanguages: [AvailableLanguage] = []
    @Published public var selectedLanguage: AvailableLanguage?
    @Published public var isLoadingLanguages: Bool = false
    @Published public var isTranslating: Bool = false
    @Published public var translatedTitle: String = ""
    @Published public var translatedDescription: String = ""
    @Published public var errorMessage: String?
    @Published public var isShowingErrorAlert: Bool = false
    
    private let translationService: TranslationService?
    
    public init() {
        self.translationService = TranslationService()
        Task { @MainActor in
            await loadLanguages()
        }
    }
    
    public func loadLanguages() async {
        guard let service = translationService else { return }
        isLoadingLanguages = true
        defer { isLoadingLanguages = false }
        let languages = await service.getAvailableLanguages()
        availableLanguages = languages
        if let selected = selectedLanguage,
           let updated = languages.first(where: { $0.id == selected.id }) {
            selectedLanguage = updated
        } else if selectedLanguage == nil {
            selectedLanguage = languages.first(where: { $0.isInstalled }) ?? languages.first
        }
    }
    
    public func translateEpisode(title: String, description: String?) async {
        guard let service = translationService else {
            errorMessage = "Translation requires macOS 26 or later."
            isShowingErrorAlert = true
            return
        }
        guard let language = selectedLanguage else {
            errorMessage = "Select a language before translating."
            isShowingErrorAlert = true
            return
        }
        guard language.isInstalled else {
            errorMessage = "Download the translation packs for both your source language (usually English) and \(language.localizedName) in System Settings > General > Language & Region > Translation Languages. Restart Podcast Assistant afterward."
            isShowingErrorAlert = true
            return
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add a title before translating."
            isShowingErrorAlert = true
            return
        }
        isTranslating = true
        errorMessage = nil
        defer { isTranslating = false }
        do {
            translatedTitle = try await service.translateTextBlock(title, to: language)
            if let desc = description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                translatedDescription = try await service.translateTextBlock(desc, to: language)
            } else {
                translatedDescription = ""
            }
            isShowingErrorAlert = false
        } catch {
            errorMessage = error.localizedDescription
            isShowingErrorAlert = true
        }
    }
    
    public func clearResults() {
        translatedTitle = ""
        translatedDescription = ""
    }
}
