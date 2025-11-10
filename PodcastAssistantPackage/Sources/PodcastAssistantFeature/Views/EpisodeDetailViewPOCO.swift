import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Episode detail view with segmented control for different sections (POCO-based)
public struct EpisodeDetailViewPOCO: View {
    let episode: EpisodePOCO
    let podcast: PodcastPOCO
    let store: PodcastLibraryStore
    
    @State private var selectedSection: EpisodeSection = .details
    @State private var hasUnsavedChanges: Bool = false
    @State private var detailsViewModel: DetailsViewModel?
    @State private var showingTranslation: Bool = false
    @State private var showingTranscriptTranslation: Bool = false
    @State private var transcriptInputText: String = ""
    @State private var transcriptOutputText: String = ""
    
    public init(episode: EpisodePOCO, podcast: PodcastPOCO, store: PodcastLibraryStore) {
        self.episode = episode
        self.podcast = podcast
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with episode title
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Episode #\(episode.episodeNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Segmented control
            Picker("Section", selection: $selectedSection) {
                Text("Details").tag(EpisodeSection.details)
                Text("Transcript").tag(EpisodeSection.transcript)
                Text("Thumbnail").tag(EpisodeSection.thumbnail)
                Text("AI Ideas").tag(EpisodeSection.aiIdeas)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content area
            Group {
                switch selectedSection {
                case .details:
                    DetailsSection(
                        episode: episode,
                        podcast: podcast,
                        store: store,
                        hasUnsavedChanges: $hasUnsavedChanges,
                        viewModel: $detailsViewModel
                    )
                case .transcript:
                    TranscriptSection(
                        episode: episode,
                        store: store,
                        showingTranslation: $showingTranscriptTranslation,
                        inputText: $transcriptInputText,
                        outputText: $transcriptOutputText
                    )
                case .thumbnail:
                    PlaceholderSection(title: "Thumbnail", icon: "photo")
                case .aiIdeas:
                    AIIdeasSectionPOCO(episode: episode, podcast: podcast, store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .focusedValue(\.selectedEpisodeSection, selectedSection)
        .focusedValue(\.episodeDetailActions, EpisodeDetailActions(
            save: { detailsViewModel?.save() },
            revert: { detailsViewModel?.revert() },
            translate: { showingTranslation = true }
        ))
        .toolbar {
            // Details tab toolbar
            if selectedSection == .details {
                // First group: Translate button
                if #available(macOS 26.0, *) {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingTranslation = true
                        } label: {
                            Label("Translate", systemImage: "globe")
                        }
                        .help("Translate episode metadata")
                    }
                }
                
                // Second group: Save/Revert buttons (when dirty)
                if hasUnsavedChanges {
                    ToolbarItemGroup(placement: .automatic) {
                        Button {
                            detailsViewModel?.revert()
                        } label: {
                            Label("Revert", systemImage: "arrow.uturn.backward")
                        }
                        .help("Discard unsaved changes")
                        
                        Button {
                            detailsViewModel?.save()
                        } label: {
                            Label("Save", systemImage: "checkmark")
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        .help("Save changes (⌘S)")
                    }
                }
            }
            
            // Transcript tab toolbar
            if selectedSection == .transcript {
                // Group 1: Import
                ToolbarItem(placement: .automatic) {
                    Button {
                        importTranscriptFile()
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .help("Import transcript file")
                }
                
                // Group 2: Convert, Export, Clear
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        convertTranscriptToSRT()
                    } label: {
                        Label("Convert", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help("Convert to SRT format")
                    .disabled(transcriptInputText.isEmpty)
                    
                    Button {
                        exportTranscriptFile()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .help("Export SRT file")
                    .disabled(transcriptOutputText.isEmpty)
                    
                    Button {
                        clearTranscriptAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .help("Clear all transcript data")
                }
                
                // Group 3: Translate
                if #available(macOS 26.0, *) {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingTranscriptTranslation = true
                        } label: {
                            Label("Translate", systemImage: "globe")
                        }
                        .help("Translate transcript")
                        .disabled(transcriptOutputText.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTranslation) {
            if #available(macOS 26.0, *) {
                EpisodeTranslationSheet(
                    title: episode.title,
                    description: episode.episodeDescription ?? ""
                )
            }
        }
        .sheet(isPresented: $showingTranscriptTranslation) {
            if #available(macOS 26.0, *) {
                TranscriptTranslationSheet(srtText: transcriptOutputText)
            }
        }
    }
    
    // MARK: - Transcript Helper Functions
    
    private func importTranscriptFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    transcriptInputText = content
                    episode.transcriptInputText = content
                } catch {
                    print("Failed to import file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func convertTranscriptToSRT() {
        guard !transcriptInputText.isEmpty else { return }
        
        do {
            let converter = TranscriptConverter()
            let srtOutput = try converter.convertToSRT(from: transcriptInputText)
            transcriptOutputText = srtOutput
            episode.srtOutputText = srtOutput
        } catch {
            print("Conversion error: \(error.localizedDescription)")
        }
    }
    
    private func exportTranscriptFile() {
        guard !transcriptOutputText.isEmpty else { return }
        
        let panel = NSSavePanel()
        if let srtType = UTType(filenameExtension: "srt") {
            panel.allowedContentTypes = [srtType]
        } else {
            panel.allowedContentTypes = [.plainText]
        }
        panel.nameFieldStringValue = "\(episode.title).srt"
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try transcriptOutputText.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func clearTranscriptAll() {
        transcriptInputText = ""
        transcriptOutputText = ""
        episode.transcriptInputText = nil
        episode.srtOutputText = nil
    }
}

// MARK: - Detail Sections

// Removed - now using EpisodeSection from MenuActions.swift

// MARK: - Details Section

// Simple class to expose save/revert methods to parent
class DetailsViewModel {
    var save: () -> Void = {}
    var revert: () -> Void = {}
}

private struct DetailsSection: View {
    let episode: EpisodePOCO
    let podcast: PodcastPOCO
    let store: PodcastLibraryStore
    @Binding var hasUnsavedChanges: Bool
    @Binding var viewModel: DetailsViewModel?
    
    @State private var title: String = ""
    @State private var episodeNumber: String = ""
    @State private var description: String = ""
    @State private var publishDate: Date = Date()
    @State private var showingSaveConfirmation: Bool = false
    @State private var isInitialLoad: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Episode Title
                VStack(alignment: .leading, spacing: 8) {
                    Label("Episode Title", systemImage: "textformat")
                        .font(.headline)
                    
                        TextField("Enter episode title", text: $title, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .onChange(of: title) { oldValue, newValue in
                            if isInitialLoad { return }
                            hasUnsavedChanges = true
                        }
                }
                
                Divider()
                
                // Episode Number
                VStack(alignment: .leading, spacing: 8) {
                    Label("Episode Number", systemImage: "number")
                        .font(.headline)
                    
                    HStack {
                        TextField("Number", text: $episodeNumber)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: episodeNumber) { _, _ in
                                if isInitialLoad { return }
                                hasUnsavedChanges = true
                            }
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Release Date
                VStack(alignment: .leading, spacing: 8) {
                    Label("Release Date", systemImage: "calendar")
                        .font(.headline)
                    
                    DatePicker("Release Date", selection: $publishDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: publishDate) { _, _ in
                            if isInitialLoad { return }
                            hasUnsavedChanges = true
                        }
                }
                
                Divider()
                
                // Episode Description
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Description", systemImage: "doc.text")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !description.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(description.split(separator: " ").count) words")
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
                            if isInitialLoad { return }
                            hasUnsavedChanges = true
                        }
                    
                    if description.isEmpty {
                        Text("Add a description for this episode. You can also generate one using AI Ideas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Podcast Association
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
                            Image(systemName: episode.hasTranscriptData ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.hasTranscriptData ? .green : .secondary)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Has Thumbnail:")
                                .foregroundStyle(.secondary)
                            Image(systemName: episode.hasThumbnailOutput ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.hasThumbnailOutput ? .green : .secondary)
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
                            .foregroundStyle(.green)
                        Text("Changes saved successfully")
                            .font(.subheadline)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .onAppear {
            loadEpisodeData()
            
            // Register save/revert handlers with parent
            let vm = DetailsViewModel()
            vm.save = saveChanges
            vm.revert = revertChanges
            viewModel = vm
        }
    }
    
    // MARK: - Data Management
    
    private func loadEpisodeData() {
        isInitialLoad = true
        title = episode.title
        episodeNumber = "\(episode.episodeNumber)"
        description = episode.episodeDescription ?? ""
        publishDate = episode.publishDate
        hasUnsavedChanges = false
        
        // Small delay to ensure state is settled before tracking changes
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isInitialLoad = false
        }
    }
    
    func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        guard let number = Int32(episodeNumber) else {
            return
        }
        
        // Update episode (it's a class, so we can modify directly)
        episode.title = trimmedTitle
        episode.episodeNumber = number
        episode.episodeDescription = description.isEmpty ? nil : description
        episode.publishDate = publishDate
        
        do {
            try store.updateEpisode(episode)
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
    
    func revertChanges() {
        loadEpisodeData()
    }
}

// MARK: - Transcript Section

private struct TranscriptSection: View {
    let episode: EpisodePOCO
    let store: PodcastLibraryStore
    @Binding var showingTranslation: Bool
    @Binding var inputText: String
    @Binding var outputText: String
    
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let converter = TranscriptConverter()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left pane: Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Transcript")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollView {
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onChange(of: inputText) { _, newValue in
                                episode.transcriptInputText = newValue.isEmpty ? nil : newValue
                            }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .frame(width: geometry.size.width / 2)
                
                Divider()
                
                // Right pane: Output
                VStack(alignment: .leading, spacing: 8) {
                    Text("SRT Output")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    ScrollView {
                        TextEditor(text: $outputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .frame(width: geometry.size.width / 2)
            }
        }
        .onAppear {
            inputText = episode.transcriptInputText ?? ""
            outputText = episode.srtOutputText ?? ""
        }
    }
}

// MARK: - Placeholder Section

private struct PlaceholderSection: View {
    let title: String
    let icon: String
    
    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: icon,
            description: Text("This section is coming soon")
        )
    }
}

// MARK: - AI Ideas Section (POCO)

@available(macOS 26.0, *)
private struct AIIdeasSectionPOCO: View {
    let episode: EpisodePOCO
    let podcast: PodcastPOCO
    let store: PodcastLibraryStore
    @StateObject private var viewModel: AIIdeasViewModelPOCO
    
    init(episode: EpisodePOCO, podcast: PodcastPOCO, store: PodcastLibraryStore) {
        self.episode = episode
        self.podcast = podcast
        self.store = store
        _viewModel = StateObject(wrappedValue: AIIdeasViewModelPOCO(episode: episode, store: store))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.modelAvailable {
                unavailableView
            } else if !episode.hasTranscriptData {
                ContentUnavailableView(
                    "No Transcript Available",
                    systemImage: "doc.text.fill.badge.questionmark",
                    description: Text("Add a transcript to this episode first to generate AI content ideas.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        titleSuggestionsSection
                        Divider()
                        descriptionSection
                        Divider()
                        socialPostsSection
                        Divider()
                        chaptersSection
                    }
                    .padding()
                }
                
                if let error = viewModel.errorMessage {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                }
            }
        }
    }
    
    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Apple Intelligence Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 12) {
                Text("AI Ideas requires Apple Intelligence (macOS 26+)")
                    .foregroundStyle(.secondary)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var titleSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Title Suggestions", systemImage: "textformat.size")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.generateTitles() }
                } label: {
                    if viewModel.isGeneratingTitles {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingTitles || viewModel.isGeneratingAll)
            }
            
            if viewModel.titleSuggestions.isEmpty {
                Text("Generate 5 creative title suggestions for this episode")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.titleSuggestions.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 12) {
                            Text("\(index + 1).")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            
                            Text(title)
                                .font(.body)
                            
                            Spacer()
                            
                            Button {
                                viewModel.applyTitle(title)
                            } label: {
                                Label("Apply", systemImage: "checkmark.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)
                            .help("Apply this title to episode")
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Episode Description", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                Picker("Length", selection: $viewModel.descriptionLength) {
                    ForEach(AIIdeasViewModelPOCO.DescriptionLength.allCases, id: \.self) { length in
                        Text(length.rawValue).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Button {
                    Task { await viewModel.generateDescription() }
                } label: {
                    if viewModel.isGeneratingDescription {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingDescription || viewModel.isGeneratingAll)
            }
            
            if viewModel.generatedDescription.isEmpty {
                Text("Generate a compelling episode description")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        Text(viewModel.generatedDescription)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    
                    HStack {
                        Button {
                            viewModel.copyToClipboard(viewModel.generatedDescription)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            viewModel.applyDescription()
                        } label: {
                            Label("Apply to Episode", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
    
    private var socialPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Social Media Posts", systemImage: "megaphone")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.generateSocialPosts() }
                } label: {
                    if viewModel.isGeneratingSocial {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingSocial || viewModel.isGeneratingAll)
            }
            
            if viewModel.socialPosts.isEmpty {
                Text("Generate platform-specific social media posts")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.socialPosts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(post.platform.rawValue, systemImage: post.platform.icon)
                                    .font(.subheadline.bold())
                                
                                Spacer()
                                
                                Text("\(post.content.count) chars")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    viewModel.copySocialPost(post)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.bordered)
                                .help("Copy to clipboard")
                            }
                            
                            Text(post.content)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Chapter Markers", systemImage: "list.number")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.generateChapters() }
                } label: {
                    if viewModel.isGeneratingChapters {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingChapters || viewModel.isGeneratingAll)
            }
            
            if viewModel.chapterMarkers.isEmpty {
                Text("Auto-detect chapter breaks with timestamps and descriptions")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.chapterMarkers) { chapter in
                        HStack(alignment: .top, spacing: 12) {
                            Text(chapter.timestamp)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.body.bold())
                                Text(chapter.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    
                    Button {
                        viewModel.copyChaptersAsYouTube()
                    } label: {
                        Label("Copy as YouTube Chapters", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
