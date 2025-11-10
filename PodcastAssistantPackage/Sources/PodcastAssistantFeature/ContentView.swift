import SwiftUI
import SwiftData
import AppKit

/// Main navigation view with two-column layout: Sidebar (podcast selector + episodes) → Episode detail
/// HYBRID ARCHITECTURE: SwiftData for persistence, POCOs for UI binding (best performance)
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var libraryStore = PodcastLibraryStore()
    @State private var selectedPodcastID: String?
    @State private var selectedEpisodeID: String?
    @State private var selectedEpisodeModel: EpisodePOCO?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedDetailTab: DetailTab = .details
    @State private var episodeSearchText = ""
    @State private var episodeSortOption: EpisodeSortOption = .numberAscending
    @State private var filteredEpisodes: [EpisodePOCO] = []
    @State private var didPerformInitialSetup = false
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var showingPodcastForm = false
    @State private var showingEpisodeForm = false
    @State private var editingPodcast: PodcastPOCO?
    @State private var editingEpisode: EpisodePOCO?
    @State private var showingSettings = false
    
    @AppStorage("lastSelectedPodcastID") private var lastSelectedPodcastID: String = ""
    
    private var podcasts: [PodcastPOCO] {
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
        .sheet(isPresented: $showingPodcastForm, onDismiss: {
            Task { @MainActor in
                refreshPodcasts()
            }
        }) {
            PodcastFormView(store: libraryStore)
        }
        .sheet(item: $editingPodcast, onDismiss: {
            Task { @MainActor in
                refreshPodcasts()
            }
        }) { podcast in
            PodcastFormView(podcast: podcast, store: libraryStore)
        }
        .sheet(isPresented: $showingEpisodeForm, onDismiss: {
            refreshEpisodesForSelection()
        }) {
            if let podcastID = selectedPodcastID,
               let podcast = libraryStore.getPodcast(with: podcastID) {
                EpisodeFormView(podcast: podcast, store: libraryStore)
            } else {
                ContentUnavailableView(
                    "Select a Podcast",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Choose a podcast before creating an episode")
                )
            }
        }
        .sheet(item: $editingEpisode, onDismiss: {
            refreshEpisodesForSelection()
        }) { episode in
            if let podcast = libraryStore.getPodcast(with: episode.podcastID) {
                EpisodeFormView(episode: episode, podcast: podcast, store: libraryStore)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            guard didPerformInitialSetup == false else { return }
            didPerformInitialSetup = true
            loadInitialData()
            restoreLastSelectedPodcast()
            updateFilteredEpisodes()
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
                if let podcastID = selectedPodcastID,
                   let model = libraryStore.getEpisode(with: newEpisodeID, in: podcastID) {
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
                        .id(podcasts.map { $0.name + $0.id }.joined())
                        
                        if selectedPodcastID != nil {
                            Menu {
                                Button("Edit Podcast") {
                                    if let podcastID = selectedPodcastID,
                                       let podcast = libraryStore.getPodcast(with: podcastID) {
                                        editingPodcast = podcast
                                    }
                                }
                                Divider()
                                Button("Delete Podcast", role: .destructive) {
                                    if let podcastID = selectedPodcastID,
                                       let podcast = libraryStore.getPodcast(with: podcastID) {
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
                        Text("Episodes (\(filteredEpisodes.count))")
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
                    .contextMenu {
                        Button("Edit Episode") {
                            editingEpisode = summary
                        }
                        Divider()
                        Button("Delete Episode", role: .destructive) {
                            deleteEpisode(summary)
                        }
                    }
                }
                .listStyle(.sidebar)
                .environment(\.defaultMinListRowHeight, 50)
                .id(filteredEpisodes.map { $0.title + $0.id + "\($0.episodeNumber)" + $0.publishDate.description }.joined())
                .animation(nil, value: selectedEpisodeID)
            }
            
            Spacer()
            
            // Settings button at bottom
            Divider()
            
            Button {
                showingSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
    }
    
    @ViewBuilder
    private var detailContent: some View {
        if let episode = selectedEpisodeModel,
           let podcast = libraryStore.getPodcast(with: episode.podcastID) {
            EpisodeDetailView(episode: episode, podcast: podcast, store: libraryStore)
                .id("episode-\(episode.id)")
        } else {
            ContentUnavailableView(
                "Select an Episode",
                systemImage: "waveform",
                description: Text("Choose an episode from the sidebar to view its details")
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadInitialData() {
        do {
            try libraryStore.loadInitialData(context: modelContext)
        } catch {
            print("Error loading podcasts: \(error)")
        }
    }
    
    private func refreshPodcasts() {
        do {
            try libraryStore.refreshPodcasts()
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
    
    private func refreshEpisodesForSelection() {
        guard let podcastID = selectedPodcastID else {
            filteredEpisodes = []
            return
        }
        do {
            try libraryStore.refreshEpisodes(for: podcastID)
            updateFilteredEpisodes()
        } catch {
            print("Error refreshing episodes: \(error)")
        }
    }
    
    private func deletePodcast(_ podcast: PodcastPOCO) {
        do {
            try libraryStore.deletePodcast(podcast)
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
    
    private func deleteEpisode(_ episode: EpisodePOCO) {
        do {
            try libraryStore.deleteEpisode(episode)
            if selectedEpisodeID == episode.id {
                selectedEpisodeID = nil
                selectedEpisodeModel = nil
            }
            refreshEpisodesForSelection()
        } catch {
            print("Error deleting episode: \(error)")
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
            try libraryStore.ensureEpisodes(for: podcastID)
        } catch {
            print("Error ensuring episodes: \(error)")
        }
        
        let source = libraryStore.searchEpisodes(in: podcastID, query: episodeSearchText)
        filteredEpisodes = sortEpisodes(source)
        
        if let selectedID = selectedEpisodeID,
           filteredEpisodes.contains(where: { $0.id == selectedID }) == false {
            selectedEpisodeID = nil
            selectedEpisodeModel = nil
        }
    }
    
    private func sortEpisodes(_ episodes: [EpisodePOCO]) -> [EpisodePOCO] {
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
    let episode: EpisodePOCO
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
                
                if episode.hasTranscriptData || episode.hasThumbnailOutput {
                    HStack(spacing: 8) {
                        if episode.hasTranscriptData {
                            Label("Transcript", systemImage: "doc.text.fill")
                                .labelStyle(.iconOnly)
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        if episode.hasThumbnailOutput {
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
