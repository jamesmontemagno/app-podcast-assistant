import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Episode detail view with segmented control for different sections
public struct EpisodeDetailView: View {
    let episode: EpisodePOCO
    let podcast: PodcastPOCO
    @ObservedObject var store: PodcastLibraryStore
    
    @State private var selectedSection: EpisodeSection = .details
    @State private var hasUnsavedChanges: Bool = false
    @State private var detailsViewModel: DetailsViewModel?
    @State private var showingTranslation: Bool = false
    @State private var showingTranscriptTranslation: Bool = false
    @State private var transcriptInputText: String = ""
    @State private var transcriptOutputText: String = ""
    @State private var thumbnailViewModel: ThumbnailViewModel?
    
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
                    DetailsView(
                        episode: episode,
                        podcast: podcast,
                        store: store,
                        hasUnsavedChanges: $hasUnsavedChanges,
                        viewModel: $detailsViewModel
                    )
                case .transcript:
                    TranscriptView(
                        episode: episode,
                        store: store,
                        showingTranslation: $showingTranscriptTranslation,
                        inputText: $transcriptInputText,
                        outputText: $transcriptOutputText
                    )
                case .thumbnail:
                    ThumbnailView(episode: episode, podcast: podcast, store: store, viewModel: $thumbnailViewModel)
                case .aiIdeas:
                    if #available(macOS 26.0, *) {
                        AIIdeasView(episode: episode, podcast: podcast, store: store)
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
}

// MARK: - Thumbnail Toolbar Buttons
private struct ThumbnailToolbarButtons: View {
    @ObservedObject var viewModel: ThumbnailViewModel
    
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
        .help("Save thumbnail to episode")
        .disabled(viewModel.generatedThumbnail == nil)
        
        Button {
            viewModel.exportThumbnail()
        } label: {
            Label("Export", systemImage: "arrow.up.doc")
        }
        .help("Export thumbnail file")
        .disabled(viewModel.generatedThumbnail == nil)
        
        Button {
            viewModel.resetAll()
        } label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
        }
        .help("Reset all settings")
    }
}

