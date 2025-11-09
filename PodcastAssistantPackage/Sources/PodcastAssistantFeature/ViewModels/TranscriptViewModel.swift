import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import AppKit

/// ViewModel for transcript conversion functionality
/// Binds directly to SwiftData Episode model
@MainActor
public class TranscriptViewModel: ObservableObject {
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var showingExporter: Bool = false
    @Published public var showingImporter: Bool = false
    @Published public var showingTranslationSheet: Bool = false
    @Published public var selectedLanguage: AvailableLanguage?
    @Published public var availableLanguages: [AvailableLanguage] = []
    @Published public var showingErrorAlert: Bool = false
    @Published public var translationProgress: TranslationProgressUpdate?
    
    private let converter = TranscriptConverter()
    private let translationService: TranslationService?
    
    // SwiftData episode
    public let episode: Episode
    private let context: ModelContext
    
    // Computed properties that read/write to Core Data
    public var inputText: String {
        get { episode.transcriptInputText ?? "" }
        set {
            episode.transcriptInputText = newValue.isEmpty ? nil : newValue
            saveContext()
        }
    }
    
    public var outputSRT: String {
        get { episode.srtOutputText ?? "" }
        set {
            episode.srtOutputText = newValue.isEmpty ? nil : newValue
            saveContext()
        }
    }
    
    public init(episode: Episode, context: ModelContext) {
        self.episode = episode
        self.context = context
        
        // Initialize translation service (macOS 26+)
        if #available(macOS 26.0, *) {
            self.translationService = TranslationService()
            // Load available languages
            Task { @MainActor in
                await loadAvailableLanguages()
            }
        } else {
            self.translationService = nil
        }
    }
    
    /// Loads available translation languages from the system
    @available(macOS 26.0, *)
    private func loadAvailableLanguages() async {
        guard let service = translationService else { return }
        let languages = await service.getAvailableLanguages()
        await MainActor.run {
            availableLanguages = languages
            let installedCount = languages.filter { $0.isInstalled }.count
            print("🌐 Loaded \(languages.count) available languages (\(installedCount) installed)")
            if self.selectedLanguage == nil {
                self.selectedLanguage = languages.first(where: { $0.isInstalled })
            } else if let selected = self.selectedLanguage,
                      let updated = languages.first(where: { $0.id == selected.id }) {
                self.selectedLanguage = updated
            }
        }
    }
    
    /// Returns an SRTDocument for the current output
    public var srtDocument: SRTDocument {
        SRTDocument(text: outputSRT)
    }
    
    /// Save the SwiftData context
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    /// Triggers the file importer
    public func importFile() {
        showingImporter = true
    }
    
    /// Handles the imported file from fileImporter
    public func handleImportedFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Failed to access file: Permission denied"
                return
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                episode.transcriptInputText = content
                saveContext()
                objectWillChange.send()
                errorMessage = nil
                successMessage = "File loaded successfully"
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "Failed to import file: \(error.localizedDescription)"
        }
    }
    
    /// Converts the input text to SRT format
    public func convertToSRT() {
        guard !inputText.isEmpty else {
            errorMessage = "Please provide input text"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        Task { @MainActor in
            do {
                let srt = try converter.convertToSRT(from: inputText)
                self.episode.srtOutputText = srt
                self.saveContext()
                self.objectWillChange.send()
                self.successMessage = "Conversion successful!"
                self.isProcessing = false
            } catch {
                self.errorMessage = "Conversion failed: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    /// Triggers the file exporter
    public func exportSRT() {
        guard !outputSRT.isEmpty else {
            errorMessage = "No SRT content to export"
            return
        }
        showingExporter = true
    }
    
    /// Triggers the translation sheet for language selection
    public func exportTranslated() {
        guard !outputSRT.isEmpty else {
            errorMessage = "No SRT content to export"
            return
        }
        
        guard translationService != nil else {
            errorMessage = "Translation requires macOS 26 or later"
            return
        }
        
        showingTranslationSheet = true
    }
    
    /// Translates and exports SRT in the selected language
    public func translateAndExport() {
        guard let language = selectedLanguage else {
            errorMessage = "Please select a language"
            showingErrorAlert = true
            return
        }
        
        guard language.isInstalled else {
            errorMessage = "Download the translation packs for both your source language (usually English) and \(language.localizedName) in System Settings > General > Language & Region > Translation Languages, then restart Podcast Assistant and try again."
            showingErrorAlert = true
            return
        }

        print("🚀 Starting translation export for \(language.localizedName)")
        
        guard let service = translationService else {
            print("❌ Translation service not available")
            errorMessage = "Translation service not available"
            showingErrorAlert = true
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        translationProgress = nil
        
        Task { @MainActor in
            do {
                print("📄 Output SRT length: \(self.outputSRT.count) characters")
                let translatedSRT = try await service.translateSRT(
                    self.outputSRT,
                    to: language
                ) { [weak self] update in
                    guard let self else { return }
                    self.translationProgress = update
                }
                print("✅ Translation completed, length: \(translatedSRT.count) characters")
                
                // Save to temporary location for export
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("translated_\(language.id).srt")
                
                try translatedSRT.write(to: tempURL, atomically: true, encoding: .utf8)
                print("💾 Saved to temp: \(tempURL.path)")
                
                // Open save panel
                let panel = NSSavePanel()
                if let srtType = UTType(filenameExtension: "srt") {
                    panel.allowedContentTypes = [srtType]
                } else {
                    panel.allowedContentTypes = [.plainText]
                }
                panel.nameFieldStringValue = "transcript_\(language.id).srt"
                panel.canCreateDirectories = true
                
                panel.begin { response in
                    Task { @MainActor in
                        if response == .OK, let url = panel.url {
                            do {
                                try translatedSRT.write(to: url, atomically: true, encoding: .utf8)
                                print("✅ Saved to: \(url.path)")
                                self.successMessage = "Translated SRT saved to \(url.lastPathComponent)"
                                self.showingTranslationSheet = false
                            } catch {
                                print("❌ Save error: \(error)")
                                self.errorMessage = "Failed to save file: \(error.localizedDescription)"
                                self.showingErrorAlert = true
                            }
                        } else {
                            if response == .cancel {
                                print("ℹ️ User cancelled translated export save panel")
                            }
                        }
                        self.translationProgress = nil
                        self.isProcessing = false
                    }
                }
            } catch {
                print("❌ Translation error: \(error)")
                print("   Error type: \(type(of: error))")
                self.errorMessage = error.localizedDescription
                self.showingErrorAlert = true
                self.translationProgress = nil
                self.isProcessing = false
            }
        }
    }
    
    /// Handles the export completion from fileExporter
    public func handleExportCompletion(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            successMessage = "SRT file saved successfully to \(url.lastPathComponent)"
            errorMessage = nil
        case .failure(let error):
            errorMessage = "Failed to save file: \(error.localizedDescription)"
        }
    }
    
    /// Clears all fields
    public func clear() {
        episode.transcriptInputText = nil
        episode.srtOutputText = nil
        saveContext()
        objectWillChange.send()
        errorMessage = nil
        successMessage = nil
    }
}
