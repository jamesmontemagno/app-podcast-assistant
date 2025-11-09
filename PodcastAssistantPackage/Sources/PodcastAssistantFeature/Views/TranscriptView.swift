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
            ToolbarItemGroup(placement: .automatic) {
                // Import and processing actions
                Button(action: viewModel.importFile) {
                    Label("Import", systemImage: "doc.badge.plus")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: true)
                .help("Import transcript file")
                
                Button(action: viewModel.convertToSRT) {
                    Label("Convert", systemImage: "arrow.right.circle.fill")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: true)
                .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                .help("Convert transcript to SRT format")
                
                Button(action: viewModel.exportSRT) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: true)
                .disabled(viewModel.outputSRT.isEmpty)
                .help("Export SRT file")
                
                // Translation export button (macOS 14+)
                if #available(macOS 14.0, *) {
                    Button(action: viewModel.exportTranslated) {
                        Label("Translate", systemImage: "globe")
                    }
                    .labelStyle(.iconOnly)
                    .applyLiquidGlassButtonStyle(prominent: true)
                    .disabled(viewModel.outputSRT.isEmpty)
                    .help("Export translated SRT file")
                }
            }
            
            ToolbarItemGroup(placement: .automatic) {
                // Destructive action
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
                
                Picker("Language", selection: $viewModel.selectedLanguage) {
                    Text("Select a language...").tag(nil as TranslationService.SupportedLanguage?)
                    
                    ForEach(TranslationService.SupportedLanguage.allCases) { language in
                        Text(language.displayName).tag(language as TranslationService.SupportedLanguage?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            if viewModel.isProcessing {
                ProgressView("Translating...")
                    .padding()
            }
            
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Export Translated") {
                    viewModel.translateAndExport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedLanguage == nil || viewModel.isProcessing)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400, height: 300)
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
