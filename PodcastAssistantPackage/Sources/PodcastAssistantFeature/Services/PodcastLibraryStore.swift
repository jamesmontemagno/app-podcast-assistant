import Foundation
import SwiftData

/// Provides cached, value-type summaries of podcasts and episodes to keep SwiftUI view updates light.
@MainActor
public final class PodcastLibraryStore: ObservableObject {
    // MARK: - Nested Types
    
    public struct PodcastSummary: Identifiable, Hashable {
        public let id: String
        public let name: String
        public let podcastDescription: String?
        public let createdAt: Date
        public let hasArtwork: Bool
        let searchableName: String
        public let episodeCount: Int
        
        init(podcast: Podcast) {
            id = podcast.id
            name = podcast.name
            podcastDescription = podcast.podcastDescription
            createdAt = podcast.createdAt
            hasArtwork = podcast.artworkData != nil
            searchableName = podcast.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            episodeCount = podcast.episodes.count
        }
    }
    
    public struct EpisodeSummary: Identifiable, Hashable {
        public let id: String
        public let title: String
        public let episodeNumber: Int32
        public let publishDate: Date
        public let hasTranscript: Bool
        public let hasThumbnail: Bool
        let searchableTitle: String
        
        init(episode: Episode) {
            id = episode.id
            title = episode.title
            episodeNumber = episode.episodeNumber
            publishDate = episode.publishDate
            hasTranscript = episode.transcriptInputText != nil
            hasThumbnail = episode.thumbnailOutputData != nil
            searchableTitle = episode.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
    }
    
    // MARK: - Published State
    
    @Published public private(set) var podcasts: [PodcastSummary] = []
    private var episodesCache: [String: [EpisodeSummary]] = [:]
    
    public init() {}
    
    // MARK: - Loading & Refreshing
    
    public func loadInitialData(context: ModelContext) throws {
        try refreshPodcasts(context: context)
    }
    
    @discardableResult
    public func refreshPodcasts(context: ModelContext) throws -> [PodcastSummary] {
        let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\Podcast.createdAt, order: .reverse)])
        let fetched = try context.fetch(descriptor)
        let summaries = fetched.map(PodcastSummary.init)
        podcasts = summaries
        pruneOrphanedEpisodeCaches()
        return summaries
    }
    
    public func ensureEpisodes(for podcastID: String, context: ModelContext) throws {
        if episodesCache[podcastID] == nil {
            try refreshEpisodes(for: podcastID, context: context)
        }
    }
    
    @discardableResult
    public func refreshEpisodes(for podcastID: String, context: ModelContext) throws -> [EpisodeSummary] {
        let predicate = #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        }
        var descriptor = FetchDescriptor<Episode>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\Episode.publishDate, order: .reverse)]
        let fetched = try context.fetch(descriptor)
        let summaries = fetched.map(EpisodeSummary.init)
        episodesCache[podcastID] = summaries
        return summaries
    }
    
    public func episodes(for podcastID: String) -> [EpisodeSummary] {
        episodesCache[podcastID] ?? []
    }
    
    public func podcastSummary(with id: String) -> PodcastSummary? {
        podcasts.first { $0.id == id }
    }
    
    // MARK: - Direct Model Fetching
    
    public func fetchPodcastModel(with id: String, context: ModelContext) throws -> Podcast? {
        let predicate = #Predicate<Podcast> { podcast in
            podcast.id == id
        }
        var descriptor = FetchDescriptor<Podcast>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
    
    public func fetchEpisodeModel(with id: String, context: ModelContext) throws -> Episode? {
        let predicate = #Predicate<Episode> { episode in
            episode.id == id
        }
        var descriptor = FetchDescriptor<Episode>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Helpers
    
    private func pruneOrphanedEpisodeCaches() {
        let validIDs = Set(podcasts.map(\ .id))
        episodesCache = episodesCache.filter { validIDs.contains($0.key) }
    }
}
