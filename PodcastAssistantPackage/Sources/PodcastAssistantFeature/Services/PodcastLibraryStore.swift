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
        
        init(podcast: Podcast) {
            id = podcast.id
            name = podcast.name
            podcastDescription = podcast.podcastDescription
            createdAt = podcast.createdAt
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
            hasTranscript = episode.hasTranscriptData
            hasThumbnail = episode.hasThumbnailOutput
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
        var descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\Podcast.createdAt, order: .reverse)])
        descriptor.propertiesToFetch = [
            \Podcast.id,
            \Podcast.name,
            \Podcast.podcastDescription,
            \Podcast.createdAt
        ]
        let fetched = try context.fetch(descriptor)
        let summaries = fetched.map(PodcastSummary.init)
        if podcasts != summaries {
            podcasts = summaries
        }
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
        // Fetch only the lightweight properties and cached flags
        descriptor.propertiesToFetch = [
            \Episode.id,
            \Episode.title,
            \Episode.episodeNumber,
            \Episode.publishDate,
            \Episode.hasTranscriptData,
            \Episode.hasThumbnailOutput
        ]
        let fetched = try context.fetch(descriptor)
        
        // Validate and update flags if needed (handles cases where didSet wasn't called)
        var needsSave = false
        for episode in fetched {
            // Only validate if we suspect the flag might be wrong
            if episode.hasTranscriptData == false {
                // Fault in the property to check (unavoidable for validation)
                let actuallyHasTranscript = episode.transcriptInputText?.isEmpty == false
                if actuallyHasTranscript != episode.hasTranscriptData {
                    episode.hasTranscriptData = actuallyHasTranscript
                    needsSave = true
                }
            }
            if episode.hasThumbnailOutput == false {
                // Fault in the property to check (unavoidable for validation)
                let actuallyHasThumbnail = episode.thumbnailOutputData != nil
                if actuallyHasThumbnail != episode.hasThumbnailOutput {
                    episode.hasThumbnailOutput = actuallyHasThumbnail
                    needsSave = true
                }
            }
        }
        
        if needsSave {
            try context.save()
        }
        
        let summaries = fetched.map(EpisodeSummary.init)
        if episodesCache[podcastID] != summaries {
            episodesCache[podcastID] = summaries
        }
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
        let validIDs = Set(podcasts.map(\.id))
        episodesCache = episodesCache.filter { validIDs.contains($0.key) }
    }
}
