import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Sheet for translating SRT transcripts using the TranslationService
@available(macOS 26.0, *)
public struct TranscriptTranslationSheet: View {
    let srtText: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TranscriptTranslationViewModel
    
    public init(srtText: String) {
        self.srtText = srtText
        _viewModel = StateObject(wrappedValue: TranscriptTranslationViewModel(srtText: srtText))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Translate Transcript")
                    .font(.title2)
                    .fontWeight(.semibold)
            
            // Language selection
            HStack {
                Text("Target Language:")
                
                if viewModel.availableLanguages.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        ForEach(viewModel.availableLanguages) { language in
                            HStack {
                                Text(language.localizedName)
                                if language.isInstalled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .tag(language as AvailableLanguage?)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 250)
                }
            }
            
            // Warning if language not installed
            if let language = viewModel.selectedLanguage, !language.isInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Language pack not installed. Download it from System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
            
            // Translate/Cancel buttons
            HStack(spacing: 12) {
                if viewModel.isTranslating {
                    Button {
                        viewModel.cancel()
                    } label: {
                        Text("Cancel")
                            .frame(width: 100)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        viewModel.translate()
                    } label: {
                        Text("Translate")
                            .frame(width: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedLanguage == nil)
                }
            }
            
            // Progress indicator
            if let progress = viewModel.progressUpdate {
                VStack(spacing: 8) {
                    ProgressView(value: progress.fractionCompleted) {
                        HStack {
                            Text("Translating entry \(progress.currentEntry) of \(progress.totalEntries)")
                                .font(.caption)
                            Spacer()
                            Text("\(Int(progress.fractionCompleted * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(progress.timecode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospaced()
                        Text(progress.preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Results
            if let translatedText = viewModel.translatedText {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Translated SRT")
                            .font(.headline)
                        Spacer()
                        Button("Save to File") {
                            saveToFile(translatedText)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    ScrollView {
                        TextEditor(text: .constant(translatedText))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 300)
                    .background(Color(nsColor: .textBackgroundColor))
                    .border(Color.gray.opacity(0.3))
                }
            }
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
            
            // Close/Done button
            HStack {
                Spacer()
                Button(viewModel.translatedText != nil ? "Done" : "Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isTranslating)
            }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(16)
        }
        .frame(width: 600, height: 550)
    }
    
    private func saveToFile(_ text: String) {
        let panel = NSSavePanel()
        if let srtType = UTType(filenameExtension: "srt") {
            panel.allowedContentTypes = [srtType]
        } else {
            panel.allowedContentTypes = [.plainText]
        }
        panel.nameFieldStringValue = "translated_transcript.srt"
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    viewModel.errorMessage = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
    }
}

@available(macOS 26.0, *)
@MainActor
public class TranscriptTranslationViewModel: ObservableObject {
    let srtText: String
    @Published public var selectedLanguage: AvailableLanguage?
    @Published public var availableLanguages: [AvailableLanguage] = []
    @Published public var translatedText: String?
    @Published public var isTranslating = false
    @Published public var errorMessage: String?
    @Published public var progressUpdate: TranslationProgressUpdate?
    
    private let translationService: TranslationService?
    private var translationTask: Task<Void, Never>?
    
    public init(srtText: String) {
        self.srtText = srtText
        self.translationService = TranslationService()
        
        Task { @MainActor in
            await loadLanguages()
        }
    }
    
    private func loadLanguages() async {
        guard let service = translationService else { return }
        availableLanguages = await service.getAvailableLanguages()
        // Select first installed language, or first available
        selectedLanguage = availableLanguages.first(where: { $0.isInstalled }) ?? availableLanguages.first
    }
    
    public func translate() {
        guard !srtText.isEmpty else {
            errorMessage = "No text to translate"
            return
        }
        
        guard let service = translationService else {
            errorMessage = "Translation requires macOS 26 or later"
            return
        }
        
        guard let language = selectedLanguage else {
            errorMessage = "Select a language before translating"
            return
        }
        
        isTranslating = true
        errorMessage = nil
        progressUpdate = nil
        
        translationTask = Task {
            do {
                // Use the TranslationService's built-in SRT translation with progress tracking
                let result = try await service.translateSRT(srtText, to: language) { [weak self] update in
                    self?.progressUpdate = update
                }
                
                guard !Task.isCancelled else {
                    isTranslating = false
                    progressUpdate = nil
                    errorMessage = "Translation cancelled"
                    return
                }
                
                translatedText = result
                progressUpdate = nil
                isTranslating = false
                
            } catch let error as TranslationService.TranslationError {
                guard !Task.isCancelled else {
                    isTranslating = false
                    progressUpdate = nil
                    errorMessage = "Translation cancelled"
                    return
                }
                errorMessage = error.localizedDescription
                progressUpdate = nil
                isTranslating = false
            } catch {
                guard !Task.isCancelled else {
                    isTranslating = false
                    progressUpdate = nil
                    errorMessage = "Translation cancelled"
                    return
                }
                errorMessage = "Translation failed: \(error.localizedDescription)"
                progressUpdate = nil
                isTranslating = false
            }
        }
    }
    
    public func cancel() {
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
        progressUpdate = nil
        errorMessage = "Translation cancelled"
    }
}
