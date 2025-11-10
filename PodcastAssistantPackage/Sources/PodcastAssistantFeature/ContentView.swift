import SwiftUI
import SwiftData
import AppKit

/// Main navigation view with two-column layout: Sidebar (podcast selector + episodes) → Episode detail
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var libraryStore = PodcastLibraryStore()
    @State private var selectedPodcastID: String?
    @State private var selectedEpisodeID: String?
    @State private var selectedEpisodeModel: Episode?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingPodcastForm = false
    @State private var showingEpisodeForm = false
    @State private var editingPodcast: Podcast?
    @State private var showingEpisodeDetailEdit = false
    @State private var selectedDetailTab: DetailTab = .details
    @State private var showingSettings = false
    @State private var episodeSearchText = ""
    @State private var episodeSortOption: EpisodeSortOption = .numberAscending
    @State private var filteredEpisodes: [PodcastLibraryStore.EpisodeSummary] = []
    @State private var didPerformInitialSetup = false
    @State private var searchDebounceTask: Task<Void, Never>?
    
    @AppStorage("lastSelectedPodcastID") private var lastSelectedPodcastID: String = ""
    
    private var podcasts: [PodcastLibraryStore.PodcastSummary] {
        libraryStore.podcasts
    }
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 800, minHeight: 700)
        .focusedSceneValue(\.selectedEpisode, selectedEpisodeModel)
        .focusedSceneValue(\.podcastActions, PodcastActions(
            createPodcast: { showingPodcastForm = true }
        ))
        .focusedSceneValue(\.episodeActions, EpisodeActions(
            createEpisode: { 
                if selectedPodcastID != nil {
                    showingEpisodeForm = true
                }
            },
            editEpisode: { 
                if selectedEpisodeModel != nil {
                    showingEpisodeDetailEdit = true
                }
            },
            deleteEpisode: { 
                if let episode = selectedEpisodeModel {
                    deleteEpisode(episode)
                }
            },
            showDetails: { selectedDetailTab = .details },
            showTranscript: { selectedDetailTab = .transcript },
            showThumbnail: { selectedDetailTab = .thumbnail },
            showAIIdeas: { selectedDetailTab = .aiIdeas }
        ))
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingEpisodeDetailEdit) {
            if let selectedEpisode = selectedEpisodeModel {
                EpisodeDetailEditView(episode: selectedEpisode)
            }
        }
        .onAppear {
            guard didPerformInitialSetup == false else { return }
            didPerformInitialSetup = true
            loadInitialData()
            restoreLastSelectedPodcast()
            updateFilteredEpisodes()
            registerImportedFonts()
            applyStoredTheme()
        }
        .onDisappear {
            searchDebounceTask?.cancel()
            searchDebounceTask = nil
        }
        .onChange(of: selectedPodcastID) { _, newPodcastID in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let id = newPodcastID {
                    lastSelectedPodcastID = id
                }
                // Clear episode selection when podcast changes
                selectedEpisodeID = nil
                selectedEpisodeModel = nil
                updateFilteredEpisodes()
            }
        }
        .onChange(of: selectedEpisodeID) { _, newEpisodeID in
            guard let newEpisodeID else {
                selectedEpisodeModel = nil
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let model = loadEpisodeModel(with: newEpisodeID), !model.isDeleted {
                    selectedEpisodeModel = model
                } else {
                    selectedEpisodeID = nil
                    selectedEpisodeModel = nil
                }
            }
        }
        .onChange(of: selectedEpisodeModel) { _, _ in
            // Reset to details tab when episode changes
            selectedDetailTab = .details
        }
        .onChange(of: episodeSearchText) { _, _ in
            scheduleEpisodeFilterUpdate()
        }
        .onChange(of: episodeSortOption) { _, _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                updateFilteredEpisodes()
            }
        }
        .onChange(of: columnVisibility) { _, _ in
            // Prevent view rebuilds during drawer animation
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                // No action needed, just suppress animations
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var sidebarContent: some View {
            VStack(spacing: 0) {
                // Step 1: Podcast header
                VStack(spacing: 12) {
                    HStack {
                        Text("Podcast")
                            .font(.headline)
                        Spacer()
                        
                        Button {
                            showingPodcastForm = true
                        } label: {
                            Label("New Podcast", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.glass)
                        .help("Create new podcast")
                    }
                    
                    // Step 2: Podcast picker
                    if podcasts.isEmpty {
                        Text("No podcasts")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: 8) {
                            Picker("Select Podcast", selection: $selectedPodcastID) {
                                Text("Select a podcast...").tag(nil as String?)
                                ForEach(podcasts) { podcast in
                                    Text(podcast.name).tag(podcast.id as String?)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .id("podcast-picker")
                            
                            if let podcastID = selectedPodcastID {
                                Menu {
                                    Button("Edit Podcast") {
                                        editingPodcast = loadPodcastModel(with: podcastID)
                                    }
                                    Divider()
                                    Button("Delete Podcast", role: .destructive) {
                                        if let podcast = loadPodcastModel(with: podcastID) {
                                            deletePodcast(podcast)
                                        }
                                    }
                                } label: {
                                    Label("Podcast Options", systemImage: "ellipsis.circle")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.borderless)
                                .help("Podcast options")
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .animation(nil, value: selectedPodcastID)
                
                Divider()
                
                // Step 3: Episode list header
                if selectedPodcastID != nil {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Episodes")
                                .font(.headline)
                            Spacer()
                            
                            // Sort menu
                            Menu {
                                Button {
                                    episodeSortOption = .numberAscending
                                } label: {
                                    Label("Number (Low to High)", systemImage: episodeSortOption == .numberAscending ? "checkmark" : "")
                                }
                                Button {
                                    episodeSortOption = .numberDescending
                                } label: {
                                    Label("Number (High to Low)", systemImage: episodeSortOption == .numberDescending ? "checkmark" : "")
                                }
                                Divider()
                                Button {
                                    episodeSortOption = .titleAscending
                                } label: {
                                    Label("Title (A to Z)", systemImage: episodeSortOption == .titleAscending ? "checkmark" : "")
                                }
                                Button {
                                    episodeSortOption = .titleDescending
                                } label: {
                                    Label("Title (Z to A)", systemImage: episodeSortOption == .titleDescending ? "checkmark" : "")
                                }
                                Divider()
                                Button {
                                    episodeSortOption = .dateAscending
                                } label: {
                                    Label("Date (Oldest First)", systemImage: episodeSortOption == .dateAscending ? "checkmark" : "")
                                }
                                Button {
                                    episodeSortOption = .dateDescending
                                } label: {
                                    Label("Date (Newest First)", systemImage: episodeSortOption == .dateDescending ? "checkmark" : "")
                                }
                            } label: {
                                Label("Sort", systemImage: "arrow.up.arrow.down")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.glass)
                            .help("Sort episodes")
                            
                            Button {
                                showingEpisodeForm = true
                            } label: {
                                Label("New Episode", systemImage: "plus.circle.fill")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.glass)
                            .help("Create new episode")
                        }
                        
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search episodes...", text: $episodeSearchText)
                                .textFieldStyle(.plain)
                            if !episodeSearchText.isEmpty {
                                Button {
                                    episodeSearchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .padding()
                    .animation(nil, value: episodeSearchText)
                    .animation(nil, value: episodeSortOption)
                    
                    Divider()
                    
                    // Step 4: Episode list
                    List(filteredEpisodes, id: \.id) { summary in
                        EpisodeRowContent(
                            episode: summary,
                            isSelected: selectedEpisodeID == summary.id
                        )
                        .onTapGesture {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                selectedEpisodeID = summary.id
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .environment(\.defaultMinListRowHeight, 50)
                    .id("episode-list")
                    .animation(nil, value: selectedEpisodeID)
                }
                
                Spacer()
                
                // Step 5: Settings button at bottom
                Divider()
                
                Button {
                    showingSettings = true
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open settings")
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
            .sheet(isPresented: $showingPodcastForm, onDismiss: {
                refreshPodcasts()
                if !podcasts.isEmpty && selectedPodcastID == nil {
                    selectedPodcastID = podcasts.first?.id
                }
            }) {
                PodcastFormView()
            }
            .sheet(item: $editingPodcast, onDismiss: {
                refreshPodcasts()
            }) { podcast in
                PodcastFormView(podcast: podcast)
            }
            .sheet(isPresented: $showingEpisodeForm, onDismiss: {
                refreshEpisodesForSelection()
            }) {
                if let podcastID = selectedPodcastID,
                   let podcast = loadPodcastModel(with: podcastID) {
                    EpisodeFormView(podcast: podcast)
                } else {
                    ContentUnavailableView(
                        "Select a Podcast",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Choose a podcast before creating an episode")
                    )
                }
            }
    }
    

    
    @ViewBuilder
    private var detailContent: some View {
        if let episode = selectedEpisodeModel, !episode.isDeleted {
            EpisodeDetailView(
                episode: episode,
                selectedTab: $selectedDetailTab,
                showingEpisodeDetailEdit: $showingEpisodeDetailEdit
            )
            .id("episode-\(episode.id)") // Stable ID prevents recreation on column visibility changes
        } else {
            ContentUnavailableView(
                "Select an Episode",
                systemImage: "waveform",
                description: Text("Choose an episode from the sidebar to view its details")
            )
        }
    }
    
    // MARK: - Podcast & Episode Selection
    
    private func loadInitialData() {
        do {
            try libraryStore.loadInitialData(context: modelContext)
        } catch {
            print("Error loading podcasts: \(error)")
        }
    }
    
    private func restoreLastSelectedPodcast() {
        guard selectedPodcastID == nil else { return }
        guard !podcasts.isEmpty else { return }
        if let last = podcasts.first(where: { $0.id == lastSelectedPodcastID }) {
            selectedPodcastID = last.id
        } else {
            selectedPodcastID = podcasts.first?.id
        }
    }
    
    private func updateFilteredEpisodes() {
        guard let podcastID = selectedPodcastID else {
            filteredEpisodes = []
            return
        }
        do {
            try libraryStore.ensureEpisodes(for: podcastID, context: modelContext)
            let source = libraryStore.episodes(for: podcastID)
            let normalizedQuery = episodeSearchText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            var working = source
            if !normalizedQuery.isEmpty {
                working = working.filter { $0.searchableTitle.contains(normalizedQuery) }
            }
            filteredEpisodes = sortEpisodes(working)
            if let selectedID = selectedEpisodeID,
               filteredEpisodes.contains(where: { $0.id == selectedID }) == false {
                selectedEpisodeID = nil
                selectedEpisodeModel = nil
            }
        } catch {
            print("Error updating episodes: \(error)")
            filteredEpisodes = []
        }
    }
    
    private func sortEpisodes(_ episodes: [PodcastLibraryStore.EpisodeSummary]) -> [PodcastLibraryStore.EpisodeSummary] {
        episodes.sorted { lhs, rhs in
            switch episodeSortOption {
            case .numberAscending:
                return lhs.episodeNumber < rhs.episodeNumber
            case .numberDescending:
                return lhs.episodeNumber > rhs.episodeNumber
            case .titleAscending:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .titleDescending:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
            case .dateAscending:
                return lhs.publishDate < rhs.publishDate
            case .dateDescending:
                return lhs.publishDate > rhs.publishDate
            }
        }
    }
    
    private func refreshEpisodesForSelection() {
        guard let podcastID = selectedPodcastID else {
            filteredEpisodes = []
            return
        }
        do {
            try libraryStore.refreshEpisodes(for: podcastID, context: modelContext)
            updateFilteredEpisodes()
        } catch {
            print("Error refreshing episodes: \(error)")
        }
    }
    
    private func refreshPodcasts() {
        do {
            try libraryStore.refreshPodcasts(context: modelContext)
            validateSelectionsAfterPodcastRefresh()
            updateFilteredEpisodes()
        } catch {
            print("Error refreshing podcasts: \(error)")
        }
    }
    
    private func validateSelectionsAfterPodcastRefresh() {
        guard !podcasts.isEmpty else {
            selectedPodcastID = nil
            selectedEpisodeID = nil
            selectedEpisodeModel = nil
            filteredEpisodes = []
            return
        }
        if let currentID = selectedPodcastID,
           podcasts.contains(where: { $0.id == currentID }) == false {
            selectedPodcastID = podcasts.first?.id
        } else if selectedPodcastID == nil {
            selectedPodcastID = podcasts.first?.id
        }
    }
    
    private func loadPodcastModel(with id: String) -> Podcast? {
        do {
            return try libraryStore.fetchPodcastModel(with: id, context: modelContext)
        } catch {
            print("Error loading podcast model: \(error)")
            return nil
        }
    }
    
    private func loadEpisodeModel(with id: String) -> Episode? {
        do {
            return try libraryStore.fetchEpisodeModel(with: id, context: modelContext)
        } catch {
            print("Error loading episode model: \(error)")
            return nil
        }
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
    
    private func scheduleEpisodeFilterUpdate() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch is CancellationError {
                return
            } catch {
                print("Unexpected error during Task.sleep: \(error)")
                return
            }
            guard !Task.isCancelled else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                updateFilteredEpisodes()
            }
            searchDebounceTask = nil
        }
    }

    // MARK: - Delete Actions
    
    private func deletePodcast(_ podcast: Podcast) {
        modelContext.delete(podcast)
        
        do {
            try modelContext.save()
            refreshPodcasts()
            if selectedPodcastID == podcast.id {
                selectedPodcastID = nil
                selectedEpisodeID = nil
                selectedEpisodeModel = nil
                filteredEpisodes = []
            }
        } catch {
            print("Error deleting podcast: \(error)")
        }
    }
    
    private func deleteEpisode(_ episode: Episode) {
        modelContext.delete(episode)
        
        do {
            try modelContext.save()
            if selectedEpisodeID == episode.id {
                selectedEpisodeID = nil
                selectedEpisodeModel = nil
            }
            refreshEpisodesForSelection()
        } catch {
            print("Error deleting episode: \(error)")
        }
    }
}

/// Detail view for an episode with split view: Episode info + selector on left, content on right
private struct EpisodeDetailView: View {
    let episode: Episode
    @Binding var selectedTab: DetailTab
    @Binding var showingEpisodeDetailEdit: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side: Episode details and section selector
            VStack(alignment: .leading, spacing: 0) {
                // Episode information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Episode Info")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            showingEpisodeDetailEdit = true
                        } label: {
                            Label("Edit Details", systemImage: "square.and.pencil")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .help("Edit episode details and settings")
                    }
                    
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
                                Image(systemName: episode.hasTranscriptData ? "checkmark.circle.fill" : "doc.text")
                                    .foregroundStyle(episode.hasTranscriptData ? .green : .primary)
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
                                Image(systemName: episode.hasThumbnailOutput ? "checkmark.circle.fill" : "photo")
                                    .foregroundStyle(episode.hasThumbnailOutput ? .blue : .primary)
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
                                Image(systemName: episode.episodeDescription != nil ? "checkmark.circle.fill" : "sparkles")
                                    .foregroundStyle(episode.episodeDescription != nil ? .purple : .primary)
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
            .frame(minWidth: 220, idealWidth: 220, maxWidth: 220)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Right side: Selected content view
            Group {
                switch selectedTab {
                case .details:
                    EpisodeDetailsView(episode: episode)
                        .id("details-\(episode.id)")
                case .transcript:
                    TranscriptView(episode: episode)
                        .id("transcript-\(episode.id)")
                case .thumbnail:
                    ThumbnailView(episode: episode)
                        .id("thumbnail-\(episode.id)")
                case .aiIdeas:
                    AIIdeasView(episode: episode)
                        .id("aiideas-\(episode.id)")
                }
            }
            .frame(minWidth: 500, idealWidth: 800, maxWidth: .infinity)
        }
    }
}

/// Sort options for episode list
private enum EpisodeSortOption: String, Hashable {
    case numberAscending
    case numberDescending
    case titleAscending
    case titleDescending
    case dateAscending
    case dateDescending
}

/// Enum for detail pane tabs
private enum DetailTab: Hashable {
    case details
    case transcript
    case thumbnail
    case aiIdeas
}

/// Episode row button for sidebar list
private struct EpisodeRowContent: View {
    let episode: PodcastLibraryStore.EpisodeSummary
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Episode number badge
            Text("\(episode.episodeNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(2)
                
                Text(episode.publishDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if episode.hasTranscript || episode.hasThumbnail {
                    HStack(spacing: 8) {
                        if episode.hasTranscript {
                            Label("Transcript", systemImage: "doc.text.fill")
                                .labelStyle(.iconOnly)
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        if episode.hasThumbnail {
                            Label("Thumbnail", systemImage: "photo.fill")
                                .labelStyle(.iconOnly)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(Color.accentColor)
                    .imageScale(.small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
