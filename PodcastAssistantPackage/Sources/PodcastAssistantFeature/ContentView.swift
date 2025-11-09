import SwiftUI
import SwiftData
import AppKit

/// Main navigation view with two-column layout: Sidebar (podcast selector + episodes) → Episode detail
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [SortDescriptor(\Podcast.createdAt)])
    private var podcasts: [Podcast]
    
    @State private var selectedPodcastID: String?
    @State private var selectedEpisode: Episode?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingPodcastForm = false
    @State private var showingEpisodeForm = false
    @State private var editingPodcast: Podcast?
    @State private var editingEpisode: Episode?
    @State private var showingEpisodeDetailEdit = false
    @State private var selectedDetailTab: DetailTab = .details
    @State private var showingSettings = false
    
    @AppStorage("lastSelectedPodcastID") private var lastSelectedPodcastID: String = ""
    
    private var selectedPodcast: Podcast? {
        guard let id = selectedPodcastID else { return nil }
        return podcasts.first { $0.id == id }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: - Sidebar: Podcast Selector + Episode List
            VStack(spacing: 0) {
                // Podcast selector and management
                VStack(spacing: 12) {
                    HStack {
                        Text("Podcast")
                            .font(.headline)
                        Spacer()
                        
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.glass)
                        .help("App settings")
                        
                        Button {
                            showingPodcastForm = true
                        } label: {
                            Label("New Podcast", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.glass)
                        .help("Create new podcast")
                        
                        if selectedPodcast != nil {
                            Menu {
                                Button("Edit Podcast") {
                                    editingPodcast = selectedPodcast
                                }
                                Divider()
                                Button("Delete Podcast", role: .destructive) {
                                    if let podcast = selectedPodcast {
                                        deletePodcast(podcast)
                                    }
                                }
                            } label: {
                                Label("Podcast Options", systemImage: "ellipsis.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.glass)
                            .help("Podcast options")
                        }
                    }
                    
                    if podcasts.isEmpty {
                        Text("No podcasts")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Picker("Select Podcast", selection: $selectedPodcastID) {
                            Text("Select a podcast...").tag(nil as String?)
                            ForEach(podcasts) { podcast in
                                HStack {
                                    if let artworkData = podcast.artworkData,
                                       let image = ImageUtilities.loadImage(from: artworkData) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Text(podcast.name)
                                }
                                .tag(podcast.id as String?)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Episode list
                if let podcast = selectedPodcast {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Episodes")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingEpisodeForm = true
                            } label: {
                                Label("New Episode", systemImage: "plus.circle.fill")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.glass)
                            .help("Create new episode")
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        if podcast.episodes.isEmpty {
                            ContentUnavailableView(
                                "No Episodes",
                                systemImage: "waveform.slash",
                                description: Text("Create an episode for this podcast")
                            )
                        } else {
                            List(selection: $selectedEpisode) {
                                ForEach(podcast.episodes.sorted(by: { $0.createdAt < $1.createdAt })) { episode in
                                    EpisodeRow(episode: episode)
                                        .tag(episode)
                                        .contextMenu {
                                            Button("Edit") {
                                                editingEpisode = episode
                                            }
                                            Button("Delete", role: .destructive) {
                                                deleteEpisode(episode)
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .sheet(isPresented: $showingEpisodeForm) {
                        EpisodeFormView(podcast: podcast)
                    }
                    .sheet(item: $editingEpisode) { episode in
                        EpisodeFormView(podcast: podcast, episode: episode)
                    }
                } else {
                    ContentUnavailableView(
                        "Select a Podcast",
                        systemImage: "mic.slash",
                        description: Text("Choose a podcast from the dropdown above")
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
            .sheet(isPresented: $showingPodcastForm) {
                PodcastFormView()
            }
            .sheet(item: $editingPodcast) { podcast in
                PodcastFormView(podcast: podcast)
            }
        } detail: {
            // MARK: - Detail Pane: Episode Detail
            if let episode = selectedEpisode {
                EpisodeDetailView(
                    episode: episode,
                    selectedTab: $selectedDetailTab,
                    showingEpisodeDetailEdit: $showingEpisodeDetailEdit
                )
                .sheet(isPresented: $showingEpisodeDetailEdit) {
                    if let selectedEpisode = selectedEpisode {
                        EpisodeDetailEditView(episode: selectedEpisode)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select an Episode",
                    systemImage: "waveform",
                    description: Text("Choose an episode from the sidebar to view its details")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 700)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            restoreLastSelectedPodcast()
            registerImportedFonts()
            applyStoredTheme()
        }
        .onChange(of: selectedPodcastID) { _, newPodcastID in
            if let id = newPodcastID {
                lastSelectedPodcastID = id
                // Clear episode selection when podcast changes
                selectedEpisode = nil
            }
        }
    }
    
    // MARK: - Podcast Selection
    
    private func restoreLastSelectedPodcast() {
        guard selectedPodcastID == nil else { return }
        
        // Try to restore last selected podcast
        if !lastSelectedPodcastID.isEmpty,
           podcasts.contains(where: { $0.id == lastSelectedPodcastID }) {
            selectedPodcastID = lastSelectedPodcastID
            return
        }
        
        // Fallback to first podcast
        selectedPodcastID = podcasts.first?.id
    }
    
    private func registerImportedFonts() {
        let fontManager = FontManager()
        do {
            try fontManager.registerImportedFonts()
        } catch {
            print("Error registering imported fonts: \(error)")
        }
    }
    
    private func applyStoredTheme() {
        let descriptor = FetchDescriptor<AppSettings>()
        do {
            let allSettings = try modelContext.fetch(descriptor)
            if let settings = allSettings.first {
                let theme = settings.appTheme
                switch theme {
                case .system:
                    NSApp.appearance = nil
                case .light:
                    NSApp.appearance = NSAppearance(named: .aqua)
                case .dark:
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }
        } catch {
            print("Error loading theme preference: \(error)")
        }
    }
    
    // MARK: - Delete Actions
    
    private func deletePodcast(_ podcast: Podcast) {
        modelContext.delete(podcast)
        
        do {
            try modelContext.save()
            // Clear selection if deleted podcast was selected
            if selectedPodcastID == podcast.id {
                selectedPodcastID = nil
                selectedEpisode = nil
            }
        } catch {
            print("Error deleting podcast: \(error)")
        }
    }
    
    private func deleteEpisode(_ episode: Episode) {
        modelContext.delete(episode)
        
        do {
            try modelContext.save()
            // Clear selection if deleted episode was selected
            if selectedEpisode?.id == episode.id {
                selectedEpisode = nil
            }
        } catch {
            print("Error deleting episode: \(error)")
        }
    }
}

// MARK: - Supporting Views

/// Row view for displaying an episode in the sidebar
private struct EpisodeRow: View {
    let episode: Episode
    
    var body: some View {
        HStack(spacing: 12) {
            // Episode number badge
            Text("\(episode.episodeNumber)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if episode.transcriptInputText != nil {
                        Label("Transcript", systemImage: "doc.text.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if episode.thumbnailOutputData != nil {
                        Label("Thumbnail", systemImage: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Detail view for an episode with split view: Episode info + selector on left, content on right
private struct EpisodeDetailView: View {
    let episode: Episode
    @Binding var selectedTab: DetailTab
    @Binding var showingEpisodeDetailEdit: Bool
    
    var body: some View {
        HSplitView {
            // Left side: Episode details and section selector
            VStack(alignment: .leading, spacing: 0) {
                // Episode information
                VStack(alignment: .leading, spacing: 12) {
                    Text(episode.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Episode \(episode.episodeNumber)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    if let podcast = episode.podcast {
                        HStack(spacing: 8) {
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
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let description = podcast.podcastDescription {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Status indicators
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: episode.transcriptInputText != nil ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(episode.transcriptInputText != nil ? .green : .secondary)
                            Text("Transcript")
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: episode.thumbnailOutputData != nil ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(episode.thumbnailOutputData != nil ? .blue : .secondary)
                            Text("Thumbnail")
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: episode.episodeDescription != nil ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(episode.episodeDescription != nil ? .purple : .secondary)
                            Text("AI Ideas")
                            Spacer()
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                
                Divider()
                
                // Section selector
                VStack(spacing: 0) {
                    Text("Work On")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 1) {
                        Button {
                            selectedTab = .details
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("Details")
                                Spacer()
                                if selectedTab == .details {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(selectedTab == .details ? Color.accentColor.opacity(0.1) : Color.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            selectedTab = .transcript
                        } label: {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Transcript")
                                Spacer()
                                if selectedTab == .transcript {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(selectedTab == .transcript ? Color.accentColor.opacity(0.1) : Color.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            selectedTab = .thumbnail
                        } label: {
                            HStack {
                                Image(systemName: "photo")
                                Text("Thumbnail")
                                Spacer()
                                if selectedTab == .thumbnail {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(selectedTab == .thumbnail ? Color.accentColor.opacity(0.1) : Color.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            selectedTab = .aiIdeas
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("AI Ideas")
                                Spacer()
                                if selectedTab == .aiIdeas {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(selectedTab == .aiIdeas ? Color.accentColor.opacity(0.1) : Color.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                Spacer()
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Right side: Selected content view
            Group {
                switch selectedTab {
                case .details:
                    EpisodeDetailsView(episode: episode)
                case .transcript:
                    TranscriptView(episode: episode)
                case .thumbnail:
                    ThumbnailView(episode: episode)
                case .aiIdeas:
                    AIIdeasView(episode: episode)
                }
            }
            .frame(minWidth: 400, idealWidth: 800, maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEpisodeDetailEdit = true
                } label: {
                    Label("Edit Details", systemImage: "pencil.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .help("Edit episode details and settings")
            }
        }
    }
}

/// Enum for detail pane tabs
private enum DetailTab: Hashable {
    case details
    case transcript
    case thumbnail
    case aiIdeas
}
