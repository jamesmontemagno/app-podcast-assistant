import SwiftUI
import SwiftData
import AppKit

/// Inline view for viewing and editing episode details
public struct EpisodeDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    let episode: Episode
    
    @State private var title: String = ""
    @State private var episodeNumber: Int = 1
    @State private var description: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingSaveConfirmation: Bool = false
    
    public init(episode: Episode) {
        self.episode = episode
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Episode Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Edit episode details and metadata")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                
                // Episode Title
                VStack(alignment: .leading, spacing: 8) {
                    Label("Episode Title", systemImage: "textformat")
                        .font(.headline)
                    
                    TextField("Enter episode title", text: $title, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .onChange(of: title) { _, _ in
                            hasUnsavedChanges = true
                        }
                }
                
                Divider()
                
                // Episode Number
                VStack(alignment: .leading, spacing: 8) {
                    Label("Episode Number", systemImage: "number")
                        .font(.headline)
                    
                    HStack {
                        TextField("Number", value: $episodeNumber, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: episodeNumber) { _, _ in
                                hasUnsavedChanges = true
                            }
                        
                        Stepper("", value: $episodeNumber, in: 1...9999)
                            .labelsHidden()
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Episode Description
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Description", systemImage: "doc.text")
                            .font(.headline)
                        
                        Spacer()
                        
                        if let desc = episode.episodeDescription, !desc.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(desc.split(separator: " ").count) words")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    TextEditor(text: $description)
                        .font(.body)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .onChange(of: description) { _, _ in
                            hasUnsavedChanges = true
                        }
                    
                    if description.isEmpty {
                        Text("Add a description for this episode. You can also generate one using AI Ideas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                if #available(macOS 26.0, *) {
                    EpisodeMetadataTranslationSection(title: $title, description: $description)
                    Divider()
                }

                // Podcast Association
                if let podcast = episode.podcast {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Podcast", systemImage: "mic")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            if let artworkData = podcast.artworkData,
                               let image = ImageUtilities.loadImage(from: artworkData) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(podcast.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                if let podcastDescription = podcast.podcastDescription {
                                    Text(podcastDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Label("Metadata", systemImage: "info.circle")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Created:")
                                .foregroundStyle(.secondary)
                            Text(episode.createdAt, style: .date)
                            Text(episode.createdAt, style: .time)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Has Transcript:")
                                .foregroundStyle(.secondary)
                            Image(systemName: episode.transcriptInputText != nil ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.transcriptInputText != nil ? .green : .secondary)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Has Thumbnail:")
                                .foregroundStyle(.secondary)
                            Image(systemName: episode.thumbnailOutputData != nil ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.thumbnailOutputData != nil ? .green : .secondary)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Has AI Description:")
                                .foregroundStyle(.secondary)
                            Image(systemName: episode.episodeDescription != nil ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.episodeDescription != nil ? .green : .secondary)
                        }
                        .font(.caption)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Save confirmation
                if showingSaveConfirmation {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Changes saved")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem {
                    Button(action: revertChanges) {
                        Label("Revert", systemImage: "arrow.uturn.backward.circle")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .help("Discard changes")
                }
                
                ToolbarItem {
                    Button(action: saveChanges) {
                        Label("Save Changes", systemImage: "checkmark.circle.fill")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .help("Save episode details")
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            loadEpisodeData()
        }
    }
    
    // MARK: - Data Management
    
    private func loadEpisodeData() {
        title = episode.title
        episodeNumber = Int(episode.episodeNumber)
        description = episode.episodeDescription ?? ""
        hasUnsavedChanges = false
    }
    
    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        episode.title = trimmedTitle
        episode.episodeNumber = Int32(episodeNumber)
        episode.episodeDescription = description.isEmpty ? nil : description
        
        do {
            try modelContext.save()
            hasUnsavedChanges = false
            
            // Show save confirmation
            showingSaveConfirmation = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                showingSaveConfirmation = false
            }
        } catch {
            print("Error saving episode: \(error)")
        }
    }
    
    private func revertChanges() {
        loadEpisodeData()
    }
}

    @available(macOS 26.0, *)
    private struct EpisodeMetadataTranslationSection: View {
        @Binding var title: String
        @Binding var description: String
        @StateObject private var viewModel = EpisodeTranslationViewModel()
        @State private var showingPreview: Bool = false
    
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Label("Translate Episode Text", systemImage: "globe")
                    .font(.headline)
            
                Text("Preview a translated title and description without saving changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            
                if viewModel.isLoadingLanguages {
                    ProgressView("Loading languages...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.availableLanguages.isEmpty {
                    Text("No translation languages available. Install translation packs in System Settings > General > Language & Region > Translation Languages, then restart Podcast Assistant.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        Text("Select a language...").tag(nil as AvailableLanguage?)
                        ForEach(viewModel.availableLanguages) { language in
                            Text(language.localizedName)
                                .tag(Optional(language))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                
                    if let language = viewModel.selectedLanguage, !language.isInstalled {
                        Text("Download the translation packs for both your source language (usually English) and \(language.localizedName). Restart Podcast Assistant after installation so the language appears here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            
                HStack(spacing: 12) {
                    Button("Translate Title & Description") {
                        viewModel.clearResults()
                        Task { @MainActor in
                            await viewModel.translateEpisode(title: title, description: description)
                            if viewModel.errorMessage == nil {
                                showingPreview = true
                            }
                        }
                    }
                    .disabled(viewModel.isLoadingLanguages || viewModel.isTranslating)
                    .buttonStyle(.glassProminent)
                
                    if viewModel.isTranslating {
                        ProgressView()
                    }
                }
            
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
            .sheet(isPresented: $showingPreview) {
                EpisodeTranslationPreviewSheet(viewModel: viewModel)
            }
            .alert("Translation Error", isPresented: $viewModel.isShowingErrorAlert, actions: {
                Button("OK", role: .cancel) {
                    viewModel.isShowingErrorAlert = false
                }
                if let message = viewModel.errorMessage,
                   message.contains("Translation Languages") {
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
                            NSWorkspace.shared.open(url)
                        }
                        viewModel.isShowingErrorAlert = false
                    }
                }
            }, message: {
                if let message = viewModel.errorMessage {
                    Text(message)
                }
            })
        }
    }

    @available(macOS 26.0, *)
    private struct EpisodeTranslationPreviewSheet: View {
        @ObservedObject var viewModel: EpisodeTranslationViewModel
        @Environment(\.dismiss) private var dismiss
    
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                    Text("Translated Episode Text")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    if let languageName = viewModel.selectedLanguage?.localizedName {
                        Text(languageName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Title")
                            .font(.headline)
                        Spacer()
                        Button("Copy") {
                            copyToClipboard(viewModel.translatedTitle)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.translatedTitle.isEmpty)
                    }
                    ScrollView {
                        Text(viewModel.translatedTitle.isEmpty ? "Translation pending" : viewModel.translatedTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                    .frame(minHeight: 80, maxHeight: 120)
                }
            
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Description")
                            .font(.headline)
                        Spacer()
                        Button("Copy") {
                            copyToClipboard(viewModel.translatedDescription)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.translatedDescription.isEmpty)
                    }
                    ScrollView {
                        if viewModel.translatedDescription.isEmpty {
                            Text("No description translated.")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        } else {
                            Text(viewModel.translatedDescription)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 200)
                }
            
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 480)
        }
    
        private func copyToClipboard(_ text: String) {
            guard !text.isEmpty else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }
