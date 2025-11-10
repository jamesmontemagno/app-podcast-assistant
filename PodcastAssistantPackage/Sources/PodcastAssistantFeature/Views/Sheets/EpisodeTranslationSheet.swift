import SwiftUI
import AppKit

/// Sheet for translating episode metadata (title and description)
@available(macOS 26.0, *)
public struct EpisodeTranslationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EpisodeTranslationViewModel()
    
    let title: String
    let description: String
    
    public init(title: String, description: String) {
        self.title = title
        self.description = description
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Translate Episode")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                Text("Translate episode title and description to another language")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
            
                // Language selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Language")
                        .font(.headline)
                    
                    if viewModel.isLoadingLanguages {
                    ProgressView("Loading languages...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.availableLanguages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No translation languages available")
                            .foregroundStyle(.secondary)
                        Text("Install translation packs in System Settings > General > Language & Region > Translation Languages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                }
                
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
            }
            
                    Divider()
                    
                    // Translate/Cancel buttons
                    HStack {
                        Spacer()
                        if viewModel.isTranslating {
                            ProgressView()
                                .controlSize(.small)
                            Button {
                                viewModel.cancel()
                            } label: {
                                Text("Cancel")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                Task {
                                    await viewModel.translateEpisode(title: title, description: description)
                                }
                            } label: {
                                Text("Translate")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.selectedLanguage == nil || viewModel.selectedLanguage?.isInstalled == false)
                        }
                    }
                    
                    Divider()
            
                    // Results
                    if !viewModel.translatedTitle.isEmpty || !viewModel.translatedDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        // Translated title
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Translated Title")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    copyToClipboard(viewModel.translatedTitle)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.translatedTitle.isEmpty)
                            }
                            
                            if viewModel.translatedTitle.isEmpty {
                                Text("No title translated")
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            } else {
                                Text(viewModel.translatedTitle)
                                    .textSelection(.enabled)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                        }
                        
                        // Translated description
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Translated Description")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    copyToClipboard(viewModel.translatedDescription)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.translatedDescription.isEmpty)
                            }
                            
                            if viewModel.translatedDescription.isEmpty {
                                Text("No description translated")
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            } else {
                                Text(viewModel.translatedDescription)
                                    .textSelection(.enabled)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                            }
                        }
                        }
                    }
                    
                    // Error message
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.callout)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    Spacer()
                }
                .padding(20)
            
            // Close button at bottom
            Divider()
            
            HStack {
                Spacer()
                Button(!viewModel.translatedTitle.isEmpty || !viewModel.translatedDescription.isEmpty ? "Done" : "Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isTranslating)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 600, height: 550)
    }
    
    private func copyToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
