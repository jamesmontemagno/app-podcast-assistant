import SwiftUI
import SwiftData

/// Dedicated view for displaying filtered/sorted episode list for a podcast
/// Uses @Query for reactive SwiftData binding
public struct EpisodeListView: View {
    let podcast: Podcast
    @Binding var selectedEpisode: Episode?
    @Binding var editingEpisode: Episode?
    @Binding var sortOption: EpisodeSortOption
    
    @Query private var episodes: [Episode]
    @State private var searchText = ""
    
    public init(
        podcast: Podcast,
        selectedEpisode: Binding<Episode?>,
        editingEpisode: Binding<Episode?>,
        sortOption: Binding<EpisodeSortOption>
    ) {
        self.podcast = podcast
        self._selectedEpisode = selectedEpisode
        self._editingEpisode = editingEpisode
        self._sortOption = sortOption
        
        // Dynamic query filtering by podcast ID
        let podcastID = podcast.id
        let predicate = #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        }
        
        // Apply sort order based on sort option
        let sortBy: SortDescriptor<Episode>
        switch sortOption.wrappedValue {
        case .numberAscending:
            sortBy = SortDescriptor(\Episode.episodeNumber, order: .forward)
        case .numberDescending:
            sortBy = SortDescriptor(\Episode.episodeNumber, order: .reverse)
        case .titleAscending:
            sortBy = SortDescriptor(\Episode.title, order: .forward)
        case .titleDescending:
            sortBy = SortDescriptor(\Episode.title, order: .reverse)
        case .dateAscending:
            sortBy = SortDescriptor(\Episode.publishDate, order: .forward)
        case .dateDescending:
            sortBy = SortDescriptor(\Episode.publishDate, order: .reverse)
        }
        
        _episodes = Query(
            filter: predicate,
            sort: [sortBy]
        )
    }
    
    private var filteredEpisodes: [Episode] {
        guard !searchText.isEmpty else { return episodes }
        return episodes.filter { episode in
            episode.title.localizedStandardContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search episodes...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
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
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Episode list
            List(filteredEpisodes, selection: $selectedEpisode) { episode in
                EpisodeRow(episode: episode)
                    .tag(episode)
                    .contextMenu {
                        Button("Edit Episode") {
                            editingEpisode = episode
                        }
                        Divider()
                        Button("Delete Episode", role: .destructive) {
                            deleteEpisode(episode)
                        }
                    }
            }
            .listStyle(.sidebar)
            .environment(\.defaultMinListRowHeight, 50)
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func deleteEpisode(_ episode: Episode) {
        modelContext.delete(episode)
        if selectedEpisode?.id == episode.id {
            selectedEpisode = nil
        }
    }
}

/// Episode row component for list display
private struct EpisodeRow: View {
    let episode: Episode
    
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
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Sort options for episode list
public enum EpisodeSortOption: String, Hashable, CaseIterable {
    case numberAscending
    case numberDescending
    case titleAscending
    case titleDescending
    case dateAscending
    case dateDescending
    
    public var displayName: String {
        switch self {
        case .numberAscending: return "Number (Low to High)"
        case .numberDescending: return "Number (High to Low)"
        case .titleAscending: return "Title (A to Z)"
        case .titleDescending: return "Title (Z to A)"
        case .dateAscending: return "Date (Oldest First)"
        case .dateDescending: return "Date (Newest First)"
        }
    }
    
    public var icon: String {
        "checkmark"
    }
}
