import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Episode detail view with segmented control for different sections
public struct EpisodeDetailView: View {
    let episode: Episode
    let podcast: Podcast
    @Binding var selectedSection: EpisodeSection
    @StateObject private var appState = AppState.shared
    
    @State private var hasUnsavedChanges: Bool = false
    @State private var detailsViewModel: DetailsViewModel?
    @State private var showingTranslation: Bool = false
    @State private var showingTranscriptTranslation: Bool = false
    @State private var transcriptInputText: String = ""
    @State private var transcriptOutputText: String = ""
    @State private var thumbnailViewModel: ThumbnailViewModel?
    
    public init(episode: Episode, podcast: Podcast, selectedSection: Binding<EpisodeSection>) {
        self.episode = episode
        self.podcast = podcast
        self._selectedSection = selectedSection
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with episode title
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .id("title-\(episode.title)") // Force update when title changes
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
                    Text("Details view - TODO: Update for SwiftData")
                        .padding()
                    // DetailsView(
                    //     episode: episode,
                    //     podcast: podcast,
                    //     hasUnsavedChanges: $hasUnsavedChanges,
                    //     viewModel: $detailsViewModel
                    // )
                case .transcript:
                    Text("Transcript view - TODO: Update for SwiftData")
                        .padding()
                    // TranscriptView(
                    //     episode: episode,
                    //     showingTranslation: $showingTranscriptTranslation,
                    //     inputText: $transcriptInputText,
                    //     outputText: $transcriptOutputText
                    // )
                case .thumbnail:
                    Text("Thumbnail view - TODO: Update for SwiftData")
                        .padding()
                    // ThumbnailView(episode: episode, podcast: podcast, viewModel: $thumbnailViewModel)
                case .aiIdeas:
                    if #available(macOS 26.0, *) {
                        Text("AI Ideas view - TODO: Update for SwiftData")
                            .padding()
                        // AIIdeasView(episode: episode, podcast: podcast)
                    } else {
                        ContentUnavailableView(
                            "AI Ideas Unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Requires macOS 26 or later")
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id("section-\(selectedSection)")
        .onChange(of: selectedSection) { _, _ in
            updateAppState()
        }
        .onChange(of: transcriptInputText) { _, _ in
            updateAppState()
        }
        .onChange(of: transcriptOutputText) { _, _ in
            updateAppState()
        }
        .onChange(of: thumbnailViewModel?.generatedThumbnail) { _, _ in
            updateAppState()
        }
        .onChange(of: thumbnailViewModel?.hasUnsavedChanges) { _, _ in
            updateAppState()
        }
        .onAppear {
            updateAppState()
        }
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
            
            // Thumbnail tab toolbar
            if selectedSection == .thumbnail, let vm = thumbnailViewModel {
                ToolbarItemGroup(placement: .automatic) {
                    ThumbnailToolbarButtons(viewModel: vm)
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
    
    // MARK: - Focused Value Helpers
    
    private func makeEpisodeDetailActions() -> EpisodeDetailActions {
        EpisodeDetailActions(
            save: selectedSection == .details ? { detailsViewModel?.save() } : nil,
            revert: selectedSection == .details ? { detailsViewModel?.revert() } : nil,
            translate: selectedSection == .details ? { showingTranslation = true } : nil
        )
    }
    
    private func makeTranscriptActions() -> TranscriptActions? {
        guard selectedSection == .transcript else { return nil }
        
        return TranscriptActions(
            importTranscript: { importTranscriptFile() },
            convertToSRT: { convertTranscriptToSRT() },
            exportSRT: { exportTranscriptFile() },
            exportTranslated: { showingTranscriptTranslation = true },
            clearTranscript: { clearTranscriptAll() }
        )
    }
    
    private func makeTranscriptCapabilities() -> TranscriptActionCapabilities? {
        guard selectedSection == .transcript else { return nil }
        
        return TranscriptActionCapabilities(
            canConvert: !transcriptInputText.isEmpty,
            canExport: !transcriptOutputText.isEmpty,
            canClear: !transcriptInputText.isEmpty || !transcriptOutputText.isEmpty
        )
    }
    
    private func makeThumbnailActions() -> ThumbnailActions? {
        guard selectedSection == .thumbnail, let vm = thumbnailViewModel else { return nil }
        
        return ThumbnailActions(
            importBackground: { vm.importBackgroundImage() },
            importOverlay: { vm.importOverlayImage() },
            pasteBackground: { vm.pasteBackgroundFromClipboard() },
            pasteOverlay: { vm.pasteOverlayFromClipboard() },
            generateThumbnail: { vm.generateThumbnail() },
            saveThumbnail: { vm.saveToEpisode() },
            exportThumbnail: { vm.exportThumbnail() },
            clearThumbnail: { vm.resetAll() }
        )
    }
    
    private func makeThumbnailCapabilities() -> ThumbnailActionCapabilities? {
        guard selectedSection == .thumbnail, let vm = thumbnailViewModel else { return nil }
        
        return ThumbnailActionCapabilities(
            canGenerate: vm.backgroundImage != nil && !vm.isLoading,
            canSave: vm.generatedThumbnail != nil && vm.hasUnsavedChanges,
            canExport: vm.generatedThumbnail != nil,
            canClear: vm.backgroundImage != nil || vm.overlayImage != nil
        )
    }
    
    // Update AppState with current actions and capabilities
    private func updateAppState() {
        appState.episodeDetailActions = makeEpisodeDetailActions()
        appState.transcriptActions = makeTranscriptActions()
        appState.transcriptCapabilities = makeTranscriptCapabilities()
        appState.thumbnailActions = makeThumbnailActions()
        appState.thumbnailCapabilities = makeThumbnailCapabilities()
    }
}

// MARK: - Thumbnail Toolbar Buttons
private struct ThumbnailToolbarButtons: View {
    @ObservedObject var viewModel: ThumbnailViewModel
    @State private var showResetConfirmation = false
    
    var body: some View {
        Button {
            viewModel.undo()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .help("Undo last change")
        .disabled(!viewModel.canUndo)
        
        Button {
            viewModel.generateThumbnail()
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Generate", systemImage: "wand.and.stars")
            }
        }
        .help("Generate thumbnail")
        .disabled(viewModel.backgroundImage == nil || viewModel.isLoading)
        
        Button {
            viewModel.saveToEpisode()
        } label: {
            Label("Save", systemImage: "square.and.arrow.down")
        }
        .keyboardShortcut("s", modifiers: .command)
        .help("Save thumbnail to episode (⌘S)")
        .disabled(viewModel.generatedThumbnail == nil || !viewModel.hasUnsavedChanges)
        
        Button {
            viewModel.exportThumbnail()
        } label: {
            Label("Export", systemImage: "arrow.up.doc")
        }
        .help("Export thumbnail file")
        .disabled(viewModel.generatedThumbnail == nil)
        
        Button {
            showResetConfirmation = true
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
        }
        .help("Reset all settings")
        .confirmationDialog(
            "Are you sure you want to reset all thumbnail settings to defaults?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All Settings", role: .destructive) {
                viewModel.resetAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear all images, colors, fonts, and other settings. This action cannot be undone.")
        }
    }
}

