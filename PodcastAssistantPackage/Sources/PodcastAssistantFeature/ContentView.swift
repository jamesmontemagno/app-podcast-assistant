import SwiftUI
import SwiftData
import AppKit

/// Main navigation view with two-column layout: Sidebar (podcast selector + episodes) → Episode detail
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Optimized: Sort podcasts by creation date
    @Query(sort: [SortDescriptor(\Podcast.createdAt)])
    private var _podcasts: [Podcast]
    
    @State private var selectedPodcastID: String?
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisode: Episode?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingPodcastForm = false
    @State private var showingEpisodeForm = false
    @State private var editingPodcast: Podcast?
    @State private var editingEpisode: Episode?
    @State private var showingEpisodeDetailEdit = false
    @State private var selectedDetailTab: DetailTab = .details
    @State private var showingSettings = false
    @State private var episodeSearchText = ""
    @State private var episodeSortOption: EpisodeSortOption = .numberAscending
    @State private var filteredEpisodes: [Episode] = []
    
    // Cache for podcasts to avoid repeated SwiftData fetches
    @State private var cachedPodcasts: [Podcast] = []
    // Cache for episodes to avoid repeated SwiftData fetches
    @State private var cachedEpisodes: [Episode] = []
    
    @AppStorage("lastSelectedPodcastID") private var lastSelectedPodcastID: String = ""
    
    // Computed property that uses cache
    private var podcasts: [Podcast] {
        cachedPodcasts.isEmpty ? _podcasts : cachedPodcasts
    }
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 800, minHeight: 700)
        .focusedSceneValue(\.selectedEpisode, selectedEpisode)
        .focusedSceneValue(\.podcastActions, PodcastActions(
            createPodcast: { showingPodcastForm = true }
        ))
        .focusedSceneValue(\.episodeActions, EpisodeActions(
            createEpisode: { 
                if selectedPodcast != nil {
                    showingEpisodeForm = true
                }
            },
            editEpisode: { 
                if selectedEpisode != nil {
                    showingEpisodeDetailEdit = true
                }
            },
            deleteEpisode: { 
                if let episode = selectedEpisode {
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
            if let selectedEpisode = selectedEpisode {
                EpisodeDetailEditView(episode: selectedEpisode)
            }
        }
        .onAppear {
            initializeCaches()
            restoreLastSelectedPodcast()
            registerImportedFonts()
            applyStoredTheme()
        }
        .onChange(of: selectedPodcastID) { _, newPodcastID in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedPodcast = podcasts.first { $0.id == newPodcastID }
                if let id = newPodcastID {
                    lastSelectedPodcastID = id
                }
                // Clear episode selection when podcast changes
                selectedEpisode = nil
                updateFilteredEpisodes()
            }
        }
        .onChange(of: selectedEpisode) { _, _ in
            // Reset to details tab when episode changes
            selectedDetailTab = .details
        }
        .onChange(of: episodeSearchText) { _, _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                updateFilteredEpisodes()
            }
        }
        .onChange(of: episodeSortOption) { _, _ in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                updateFilteredEpisodes()
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
                if selectedPodcast != nil {
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
                    List(filteredEpisodes, id: \.id) { episode in
                        EpisodeRowContent(
                            episode: episode,
                            isSelected: selectedEpisode?.id == episode.id
                        )
                        .onTapGesture {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                selectedEpisode = episode
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .environment(\.defaultMinListRowHeight, 50)
                    .id("episode-list")
                    .animation(nil, value: selectedEpisode?.id)
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
                // Refresh podcast cache when form dismisses
                refreshPodcastCache()
                
                // Auto-select first podcast if none selected
                if !podcasts.isEmpty && selectedPodcastID == nil {
                    selectedPodcastID = podcasts.first?.id
                }
            }) {
                PodcastFormView()
            }
            .sheet(item: $editingPodcast, onDismiss: {
                // Refresh podcast cache when editing dismisses
                refreshPodcastCache()
            }) { podcast in
                PodcastFormView(podcast: podcast)
            }
            .sheet(isPresented: $showingEpisodeForm, onDismiss: {
                // Refresh episode cache when form dismisses
                refreshEpisodeCache()
            }) {
                if let podcast = selectedPodcast {
                    EpisodeFormView(podcast: podcast)
                }
            }
            .sheet(item: $editingEpisode, onDismiss: {
                // Refresh episode cache when form dismisses
                refreshEpisodeCache()
            }) { episode in
                if let podcast = selectedPodcast {
                    EpisodeFormView(podcast: podcast, episode: episode)
                }
            }
    }
    

    
    @ViewBuilder
    private var detailContent: some View {
        if let episode = selectedEpisode {
            EpisodeDetailView(
                episode: episode,
                selectedTab: $selectedDetailTab,
                showingEpisodeDetailEdit: $showingEpisodeDetailEdit
            )
            .id(episode.id) // Force view recreation when episode changes
        } else {
            ContentUnavailableView(
                "Select an Episode",
                systemImage: "waveform",
                description: Text("Choose an episode from the sidebar to view its details")
            )
        }
    }
    
    // MARK: - Podcast Selection
    
    private func restoreLastSelectedPodcast() {
        guard selectedPodcastID == nil else { return }
        
        // Try to restore last selected podcast
        if !lastSelectedPodcastID.isEmpty,
           podcasts.contains(where: { $0.id == lastSelectedPodcastID }) {
            selectedPodcastID = lastSelectedPodcastID
            selectedPodcast = podcasts.first { $0.id == lastSelectedPodcastID }
        } else {
            // Fallback to first podcast
            selectedPodcastID = podcasts.first?.id
            selectedPodcast = podcasts.first
        }
        updateFilteredEpisodes()
    }
    
    private func updateFilteredEpisodes() {
        guard let podcast = selectedPodcast else {
            filteredEpisodes = []
            cachedEpisodes = []
            return
        }
        
        // Only fetch from SwiftData if cache is empty or podcast changed
        if cachedEpisodes.isEmpty || cachedEpisodes.first?.podcast?.id != podcast.id {
            cachedEpisodes = Array(podcast.episodes)
        }
        
        filteredEpisodes = filterAndSortEpisodes(cachedEpisodes)
    }
    
    /// Force refresh the episode cache from SwiftData
    private func refreshEpisodeCache() {
        guard let podcast = selectedPodcast else {
            cachedEpisodes = []
            return
        }
        cachedEpisodes = Array(podcast.episodes)
        updateFilteredEpisodes()
    }
    
    /// Initialize all caches on app launch
    private func initializeCaches() {
        // Cache podcasts
        cachedPodcasts = _podcasts
        
        // If there's a selected podcast, cache its episodes
        if let podcast = selectedPodcast {
            cachedEpisodes = Array(podcast.episodes)
            updateFilteredEpisodes()
        }
    }
    
    /// Refresh podcast cache from SwiftData
    private func refreshPodcastCache() {
        cachedPodcasts = _podcasts
        
        // Update selected podcast reference if it exists
        if let currentID = selectedPodcastID {
            selectedPodcast = cachedPodcasts.first { $0.id == currentID }
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
    
    // MARK: - Episode Filtering and Sorting
    
    private func filterAndSortEpisodes(_ episodes: [Episode]) -> [Episode] {
        var filtered = episodes
        
        // Apply search filter
        if !episodeSearchText.isEmpty {
            filtered = filtered.filter { episode in
                episode.title.localizedCaseInsensitiveContains(episodeSearchText)
            }
        }
        
        // Apply sorting
        return filtered.sorted { episode1, episode2 in
            switch episodeSortOption {
            case .numberAscending:
                return episode1.episodeNumber < episode2.episodeNumber
            case .numberDescending:
                return episode1.episodeNumber > episode2.episodeNumber
            case .titleAscending:
                return episode1.title.localizedCaseInsensitiveCompare(episode2.title) == .orderedAscending
            case .titleDescending:
                return episode1.title.localizedCaseInsensitiveCompare(episode2.title) == .orderedDescending
            case .dateAscending:
                return episode1.publishDate < episode2.publishDate
            case .dateDescending:
                return episode1.publishDate > episode2.publishDate
            }
        }
    }
    
    // MARK: - Delete Actions
    
    private func deletePodcast(_ podcast: Podcast) {
        modelContext.delete(podcast)
        
        do {
            try modelContext.save()
            // Refresh podcast cache
            refreshPodcastCache()
            
            // Clear selection if deleted podcast was selected
            if selectedPodcastID == podcast.id {
                selectedPodcastID = nil
                selectedPodcast = nil
                selectedEpisode = nil
                filteredEpisodes = []
                cachedEpisodes = []
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
            // Refresh cache to reflect deletion
            refreshEpisodeCache()
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
                                Image(systemName: episode.transcriptInputText != nil ? "checkmark.circle.fill" : "doc.text")
                                    .foregroundStyle(episode.transcriptInputText != nil ? .green : .primary)
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
                                Image(systemName: episode.thumbnailOutputData != nil ? "checkmark.circle.fill" : "photo")
                                    .foregroundStyle(episode.thumbnailOutputData != nil ? .blue : .primary)
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
                case .transcript:
                    TranscriptView(episode: episode)
                case .thumbnail:
                    ThumbnailView(episode: episode)
                case .aiIdeas:
                    AIIdeasView(episode: episode)
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
    let episode: Episode
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
                
                Text(episode.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
