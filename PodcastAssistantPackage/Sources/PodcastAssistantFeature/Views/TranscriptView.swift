import SwiftUI
import UniformTypeIdentifiers
import SwiftData

/// View for converting transcript text files to SRT format
public struct TranscriptView: View {
    @Environment(\.modelContext) private var modelContext
    let episode: Episode
    @StateObject private var viewModel: TranscriptViewModel
    
    public init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: TranscriptViewModel(
            episode: episode,
            context: PersistenceController.shared.container.mainContext
        ))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Content - Side by Side Layout with proportional sizing
                VStack(spacing: 0) {
                    // Side-by-side editors
                    HStack(spacing: 1) {
                        // Input Section (50% width)
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack {
                                Text("Input Transcript")
                                    .font(.headline)
                                Spacer()
                                if !viewModel.inputText.isEmpty {
                                    Text("\(viewModel.inputText.split(separator: "\n").count) lines")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            // Editor
                            TextEditor(text: Binding(
                                get: { viewModel.inputText },
                                set: { viewModel.inputText = $0 }
                            ))
                            .font(.system(size: 13, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                        }
                        .frame(width: geometry.size.width / 2 - 0.5)
                        
                        Divider()
                        
                        // Output Section (50% width)
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack {
                                Text("SRT Output")
                                    .font(.headline)
                                Spacer()
                                if !viewModel.outputSRT.isEmpty {
                                    Text("\(viewModel.outputSRT.split(separator: "\n").count) lines")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            // Editor (read-only)
                            TextEditor(text: .constant(viewModel.outputSRT))
                                .font(.system(size: 13, design: .monospaced))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .scrollContentBackground(.hidden)
                                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                                .disabled(true)
                        }
                        .frame(width: geometry.size.width / 2 - 0.5)
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Messages at bottom (compact)
                    if let error = viewModel.errorMessage {
                        Divider()
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                    }
                    
                    if let success = viewModel.successMessage {
                        Divider()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(success)
                                .font(.callout)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingImporter,
            allowedContentTypes: [.plainText, .text],
            onCompletion: viewModel.handleImportedFile
        )
        .fileExporter(
            isPresented: $viewModel.showingExporter,
            document: viewModel.srtDocument,
            contentType: UTType(filenameExtension: "srt") ?? .plainText,
            defaultFilename: "transcript.srt",
            onCompletion: viewModel.handleExportCompletion
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.importFile) {
                    Label("Import", systemImage: "arrow.down.doc")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: false)
                .help("Import transcript file")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Spacer()
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.convertToSRT) {
                    Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: false)
                .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                .help("Convert transcript to SRT format")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Spacer()
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.exportSRT) {
                    Label("Export", systemImage: "arrow.up.doc")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: false)
                .disabled(viewModel.outputSRT.isEmpty)
                .help("Export SRT file")
            }
            
            // Translation export button (macOS 14+)
            if #available(macOS 14.0, *) {
                ToolbarItem(placement: .primaryAction) {
                    Spacer()
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.exportTranslated) {
                        Label("Translate", systemImage: "character.book.closed")
                    }
                    .labelStyle(.iconOnly)
                    .applyLiquidGlassButtonStyle(prominent: false)
                    .disabled(viewModel.outputSRT.isEmpty)
                    .help("Export translated SRT file")
                    }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Spacer()
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.clear) {
                    Label("Clear", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: false)
                .help("Clear all content")
            }
        }
        .sheet(isPresented: $viewModel.showingTranslationSheet) {
            TranslationLanguageSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") {
                viewModel.showingErrorAlert = false
            }
            if let error = viewModel.errorMessage,
               error.contains("Language pack") {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
                        NSWorkspace.shared.open(url)
                    }
                    viewModel.showingErrorAlert = false
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

/// Sheet view for selecting translation language
@available(macOS 14.0, *)
private struct TranslationLanguageSheet: View {
    @ObservedObject var viewModel: TranscriptViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .font(.title)
                    .foregroundColor(.blue)
                Text("Export Translated SRT")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top)
            
            Text("Select a language to translate the subtitles")
                .font(.callout)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Language selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Target Language")
                    .font(.headline)
                
                if viewModel.availableLanguages.isEmpty {
                    ProgressView("Loading languages...")
                        .frame(maxWidth: .infinity)
                } else {
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        Text("Select a language...").tag(nil as AvailableLanguage?)
                        
                        ForEach(viewModel.availableLanguages) { language in
                            HStack {
                                Text(language.localizedName)
                                if !language.isInstalled {
                                    Text("(Download required)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(language as AvailableLanguage?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let language = viewModel.selectedLanguage, !language.isInstalled {
                            Text("Download the translation packs for both your source language (usually English) and \(language.localizedName) in System Settings > General > Language & Region > Translation Languages. Restart Podcast Assistant after installing.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Tip: Keep both the source language and your selected target language downloaded. If you add new packs, restart Podcast Assistant so they appear here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal)
            
            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    if let progress = viewModel.translationProgress {
                        ProgressView(value: Double(progress.completedEntries), total: Double(progress.totalEntries))
                            .frame(maxWidth: .infinity)
                        Text("Translating entry \(progress.currentEntry) of \(progress.totalEntries)")
                            .font(.subheadline)
                        if !progress.timecode.isEmpty {
                            Text("Timecode: \(progress.timecode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !progress.preview.isEmpty {
                            Text(progress.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ProgressView("Preparing translation...")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal)
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.translationProgress = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Export Translated") {
                    viewModel.translateAndExport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    viewModel.selectedLanguage == nil ||
                    viewModel.isProcessing ||
                    (viewModel.selectedLanguage?.isInstalled == false)
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 460, height: 320)
    }
}

private extension View {
    @ViewBuilder
    func applyLiquidGlassButtonStyle(prominent: Bool) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
}
