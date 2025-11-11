import SwiftUI
import SwiftData
import AppKit

/// Main navigation view using direct SwiftData @Query binding
/// Three-column layout: Podcasts → Episodes → Episode Detail
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Direct SwiftData queries - no PodcastLibraryStore needed for reads!
    @Query(sort: \Podcast.createdAt, order: .reverse) 
    private var podcasts: [Podcast]
    
    @StateObject private var appState = AppState.shared
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisode: Episode?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selectedDetailTab: DetailTab = .details
    @State private var episodeSortOption: EpisodeSortOption = .numberDescending
    
    // Form/sheet states
    @State private var showingPodcastForm = false
    @State private var showingEpisodeForm = false
    @State private var editingPodcast: Podcast?
    @State private var editingEpisode: Episode?
    @State private var showingSettings = false
    
    @AppStorage("lastSelectedPodcastID") private var lastSelectedPodcastID: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } content: {
            middleContent
        } detail: {
            detailContent
        }
        .onChange(of: selectedDetailTab) { _, _ in
            appState.selectedEpisodeSection = selectedEpisode != nil ? episodeSectionBinding.wrappedValue : nil
        }
        .onChange(of: selectedEpisode) { _, _ in
            appState.selectedEpisodeSection = selectedEpisode != nil ? episodeSectionBinding.wrappedValue : nil
            selectedDetailTab = .details
        }
        .frame(minWidth: 800, minHeight: 700)
        .sheet(isPresented: $showingPodcastForm) {
            PodcastFormView()
        }
        .sheet(item: $editingPodcast) { podcast in
            PodcastFormView(podcast: podcast)
        }
        .sheet(isPresented: $showingEpisodeForm) {
            if let podcast = selectedPodcast {
                EpisodeFormView(podcast: podcast)
            }
        }
        .sheet(item: $editingEpisode) { episode in
            if let podcast = episode.podcast {
                EpisodeFormView(episode: episode, podcast: podcast)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            restoreLastSelectedPodcast()
        }
        .onChange(of: selectedPodcast) { _, newPodcast in
            if let id = newPodcast?.id {
                lastSelectedPodcastID = id
            }
            // Clear episode selection when podcast changes
            selectedEpisode = nil
        }
    }
    
    // MARK: - Sidebar (Podcast List)
    
    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Podcast header
            VStack(spacing: 12) {
                HStack {
                    Text("Podcasts")
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
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Podcast list
            if podcasts.isEmpty {
                ContentUnavailableView(
                    "No Podcasts",
                    systemImage: "mic.slash",
                    description: Text("Create your first podcast to get started")
                )
            } else {
                List(podcasts, selection: $selectedPodcast) { podcast in
                    PodcastRow(podcast: podcast)
                        .tag(podcast)
                        .contextMenu {
                            Button("Edit Podcast") {
                                editingPodcast = podcast
                            }
                            Divider()
                            Button("Delete Podcast", role: .destructive) {
                                deletePodcast(podcast)
                            }
                        }
                }
                .listStyle(.sidebar)
            }
            
            Spacer()
            
            // Settings button
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
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
    }
    
    // MARK: - Middle Content (Episode List)
    
    @ViewBuilder
    private var middleContent: some View {
        if let podcast = selectedPodcast {
            VStack(spacing: 0) {
                // Episode header
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
                    
                    // Sort menu
                    Menu {
                        ForEach(EpisodeSortOption.allCases, id: \.self) { option in
                            Button {
                                episodeSortOption = option
                            } label: {
                                Label(option.displayName, systemImage: episodeSortOption == option ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.glass)
                    .help("Sort episodes")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Episode list with dynamic @Query
                EpisodeListView(
                    podcast: podcast,
                    selectedEpisode: $selectedEpisode,
                    editingEpisode: $editingEpisode,
                    sortOption: $episodeSortOption
                )
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
        } else {
            ContentUnavailableView(
                "Select a Podcast",
                systemImage: "mic",
                description: Text("Choose a podcast to view its episodes")
            )
        }
    }
    
    // MARK: - Detail Content
    
    @ViewBuilder
    private var detailContent: some View {
        if let episode = selectedEpisode,
           let podcast = episode.podcast {
            EpisodeDetailView(
                episode: episode,
                podcast: podcast,
                selectedSection: episodeSectionBinding
            )
            .id("episode-\(episode.id)")
        } else {
            ContentUnavailableView(
                "Select an Episode",
                systemImage: "waveform",
                description: Text("Choose an episode from the sidebar to view its details")
            )
        }
    }
    
    // Convert DetailTab to EpisodeSection for focused values
    private var episodeSectionBinding: Binding<EpisodeSection> {
        Binding(
            get: {
                switch selectedDetailTab {
                case .details: return .details
                case .transcript: return .transcript
                case .thumbnail: return .thumbnail
                case .aiIdeas: return .aiIdeas
                }
            },
            set: { newValue in
                switch newValue {
                case .details: selectedDetailTab = .details
                case .transcript: selectedDetailTab = .transcript
                case .thumbnail: selectedDetailTab = .thumbnail
                case .aiIdeas: selectedDetailTab = .aiIdeas
                }
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func deletePodcast(_ podcast: Podcast) {
        if selectedPodcast?.id == podcast.id {
            selectedPodcast = nil
            selectedEpisode = nil
        }
        modelContext.delete(podcast)
    }
    
    private func restoreLastSelectedPodcast() {
        guard selectedPodcast == nil, !podcasts.isEmpty else { return }
        if let last = podcasts.first(where: { $0.id == lastSelectedPodcastID }) {
            selectedPodcast = last
        } else {
            selectedPodcast = podcasts.first
        }
    }
}

/// Podcast row component for sidebar list
private struct PodcastRow: View {
    let podcast: Podcast
    
    var body: some View {
        HStack(spacing: 12) {
            // Podcast artwork or placeholder
            if let artworkData = podcast.artworkData,
               let nsImage = NSImage(data: artworkData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text("\(podcast.episodes.count) episodes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Enum for detail pane tabs
private enum DetailTab: Hashable {
    case details
    case transcript
    case thumbnail
    case aiIdeas
}
