import Foundation
import SwiftData

/// Hybrid store: Uses SwiftData for persistence, POCOs for UI binding
/// This gives us database persistence with fast UI performance
@MainActor
public final class PodcastLibraryStore: ObservableObject {
    // MARK: - Published State (POCOs for UI binding)
    
    @Published public private(set) var podcasts: [PodcastPOCO] = []
    @Published public private(set) var episodes: [String: [EpisodePOCO]] = [:] // keyed by podcast ID
    
    // SwiftData context for persistence
    private var context: ModelContext?
    
    public init() {}
    
    // MARK: - Errors
    
    public enum StoreError: Error {
        case contextNotSet
        case podcastNotFound
        case episodeNotFound
    }
    
    // MARK: - Initialization
    
    /// Load initial data from SwiftData and convert to POCOs
    public func loadInitialData(context: ModelContext) throws {
        self.context = context
        try refreshPodcasts()
    }
    
    // MARK: - Podcast Management
    
    /// Refresh podcasts from SwiftData
    @discardableResult
    public func refreshPodcasts() throws -> [PodcastPOCO] {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\Podcast.createdAt, order: .reverse)])
        let fetched = try context.fetch(descriptor)
        
        // Convert SwiftData models to POCOs
        podcasts = fetched.map { podcast in
            convertToPOCO(podcast: podcast)
        }
        return podcasts
    }
    
    /// Add a new podcast (persists to SwiftData and updates POCO list)
    public func addPodcast(_ poco: PodcastPOCO) throws {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        // Create SwiftData model
        let podcast = Podcast(
            name: poco.name,
            podcastDescription: poco.podcastDescription,
            artworkData: poco.artworkData,
            defaultOverlayData: poco.defaultOverlayData,
            defaultFontName: poco.defaultFontName,
            defaultFontSize: poco.defaultFontSize,
            defaultTextPositionX: poco.defaultTextPositionX,
            defaultTextPositionY: poco.defaultTextPositionY,
            defaultHorizontalPadding: poco.defaultHorizontalPadding,
            defaultVerticalPadding: poco.defaultVerticalPadding,
            defaultCanvasWidth: poco.defaultCanvasWidth,
            defaultCanvasHeight: poco.defaultCanvasHeight,
            defaultBackgroundScaling: poco.defaultBackgroundScaling,
            defaultFontColorHex: poco.defaultFontColorHex,
            defaultOutlineEnabled: poco.defaultOutlineEnabled,
            defaultOutlineColorHex: poco.defaultOutlineColorHex
        )
        podcast.id = poco.id
        podcast.createdAt = poco.createdAt
        
        context.insert(podcast)
        try context.save()
        
        // Add to POCO list
        podcasts.append(poco)
        try refreshPodcasts() // Re-sort
    }
    
    /// Update a podcast (updates both SwiftData and POCO)
    public func updatePodcast(_ poco: PodcastPOCO) throws {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        // Find and update SwiftData model
        let podcastID = poco.id
        let predicate = #Predicate<Podcast> { $0.id == podcastID }
        var descriptor = FetchDescriptor<Podcast>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        guard let podcast = try context.fetch(descriptor).first else {
            throw StoreError.podcastNotFound
        }
        
        // Update properties
        podcast.name = poco.name
        podcast.podcastDescription = poco.podcastDescription
        podcast.artworkData = poco.artworkData
        podcast.defaultOverlayData = poco.defaultOverlayData
        podcast.defaultFontName = poco.defaultFontName
        podcast.defaultFontSize = poco.defaultFontSize
        podcast.defaultTextPositionX = poco.defaultTextPositionX
        podcast.defaultTextPositionY = poco.defaultTextPositionY
        podcast.defaultHorizontalPadding = poco.defaultHorizontalPadding
        podcast.defaultVerticalPadding = poco.defaultVerticalPadding
        podcast.defaultCanvasWidth = poco.defaultCanvasWidth
        podcast.defaultCanvasHeight = poco.defaultCanvasHeight
        podcast.defaultBackgroundScaling = poco.defaultBackgroundScaling
        podcast.defaultFontColorHex = poco.defaultFontColorHex
        podcast.defaultOutlineEnabled = poco.defaultOutlineEnabled
        podcast.defaultOutlineColorHex = poco.defaultOutlineColorHex
        
        try context.save()
        
        // Update POCO list - reassign array to trigger @Published
        if let index = podcasts.firstIndex(where: { $0.id == poco.id }) {
            var updated = podcasts
            updated[index] = poco
            podcasts = updated
        }
    }
    
    /// Delete a podcast (removes from both SwiftData and POCO)
    public func deletePodcast(_ poco: PodcastPOCO) throws {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        // Find and delete SwiftData model
        let podcastID = poco.id
        let predicate = #Predicate<Podcast> { $0.id == podcastID }
        var descriptor = FetchDescriptor<Podcast>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        guard let podcast = try context.fetch(descriptor).first else {
            throw StoreError.podcastNotFound
        }
        
        context.delete(podcast)
        try context.save()
        
        // Remove from POCO list
        podcasts.removeAll { $0.id == poco.id }
        episodes.removeValue(forKey: poco.id)
    }
    
    public func getPodcast(with id: String) -> PodcastPOCO? {
        podcasts.first { $0.id == id }
    }
    
    // MARK: - Episode Management
    
    /// Refresh episodes for a podcast from SwiftData
    @discardableResult
    public func refreshEpisodes(for podcastID: String) throws -> [EpisodePOCO] {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        let predicate = #Predicate<Episode> { $0.podcast?.id == podcastID }
        let descriptor = FetchDescriptor<Episode>(predicate: predicate, sortBy: [SortDescriptor(\Episode.publishDate, order: .reverse)])
        
        let fetched = try context.fetch(descriptor)
        
        // Convert to POCOs
        let pocos = fetched.map { episode in
            convertToPOCO(episode: episode, podcastID: podcastID)
        }
        
        episodes[podcastID] = pocos
        return pocos
    }
    
    /// Ensure episodes are loaded for a podcast (lazy loading)
    public func ensureEpisodes(for podcastID: String) throws {
        if episodes[podcastID] == nil {
            try refreshEpisodes(for: podcastID)
        }
    }
    
    /// Search episodes within a podcast
    public func searchEpisodes(in podcastID: String, query: String) -> [EpisodePOCO] {
        guard let allEpisodes = episodes[podcastID] else {
            return []
        }
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return allEpisodes
        }
        
        let normalized = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return allEpisodes.filter { episode in
            let searchableTitle = episode.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return searchableTitle.contains(normalized)
        }
    }
    
    /// Add a new episode (persists to SwiftData and updates POCO list)
    public func addEpisode(_ poco: EpisodePOCO, to podcast: PodcastPOCO) throws {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        // Find podcast model
        let podcastID = podcast.id
        let podcastPredicate = #Predicate<Podcast> { $0.id == podcastID }
        var podcastDescriptor = FetchDescriptor<Podcast>(predicate: podcastPredicate)
        podcastDescriptor.fetchLimit = 1
        
        guard let podcastModel = try context.fetch(podcastDescriptor).first else {
            throw StoreError.podcastNotFound
        }
        
        // Create episode model
        let episode = Episode(title: poco.title, episodeNumber: poco.episodeNumber, podcast: podcastModel)
        episode.id = poco.id
        episode.episodeDescription = poco.episodeDescription
        episode.publishDate = poco.publishDate
        episode.transcriptInputText = poco.transcriptInputText
        episode.srtOutputText = poco.srtOutputText
        episode.thumbnailBackgroundData = poco.thumbnailBackgroundData
        episode.thumbnailOverlayData = poco.thumbnailOverlayData
        episode.thumbnailOutputData = poco.thumbnailOutputData
        episode.fontName = poco.fontName
        episode.fontSize = poco.fontSize
        episode.textPositionX = poco.textPositionX
        episode.textPositionY = poco.textPositionY
        episode.horizontalPadding = poco.horizontalPadding
        episode.verticalPadding = poco.verticalPadding
        episode.canvasWidth = poco.canvasWidth
        episode.canvasHeight = poco.canvasHeight
        episode.backgroundScaling = poco.backgroundScaling
        episode.fontColorHex = poco.fontColorHex
        episode.outlineEnabled = poco.outlineEnabled
        episode.outlineColorHex = poco.outlineColorHex
        
        context.insert(episode)
        try context.save()
        
        // Add to POCO list
        if episodes[podcast.id] == nil {
            episodes[podcast.id] = []
        }
        episodes[podcast.id]?.append(poco)
        try refreshEpisodes(for: podcast.id) // Re-sort
    }
    
    /// Update an episode (updates both SwiftData and POCO)
    public func updateEpisode(_ poco: EpisodePOCO) throws {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        // Find and update SwiftData model
        let episodeID = poco.id
        let predicate = #Predicate<Episode> { $0.id == episodeID }
        var descriptor = FetchDescriptor<Episode>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        guard let episode = try context.fetch(descriptor).first else {
            throw StoreError.episodeNotFound
        }
        
        // Update properties
        episode.title = poco.title
        episode.episodeNumber = poco.episodeNumber
        episode.episodeDescription = poco.episodeDescription
        episode.publishDate = poco.publishDate
        episode.transcriptInputText = poco.transcriptInputText
        episode.srtOutputText = poco.srtOutputText
        episode.thumbnailBackgroundData = poco.thumbnailBackgroundData
        episode.thumbnailOverlayData = poco.thumbnailOverlayData
        episode.thumbnailOutputData = poco.thumbnailOutputData
        episode.fontName = poco.fontName
        episode.fontSize = poco.fontSize
        episode.textPositionX = poco.textPositionX
        episode.textPositionY = poco.textPositionY
        episode.horizontalPadding = poco.horizontalPadding
        episode.verticalPadding = poco.verticalPadding
        episode.canvasWidth = poco.canvasWidth
        episode.canvasHeight = poco.canvasHeight
        episode.backgroundScaling = poco.backgroundScaling
        episode.fontColorHex = poco.fontColorHex
        episode.outlineEnabled = poco.outlineEnabled
        episode.outlineColorHex = poco.outlineColorHex
        
        try context.save()
        
        // Update POCO list - reassign array to trigger @Published
        let podcastID = poco.podcastID
        if var podcastEpisodes = episodes[podcastID],
           let episodeIndex = podcastEpisodes.firstIndex(where: { $0.id == poco.id }) {
            podcastEpisodes[episodeIndex] = poco
            episodes[podcastID] = podcastEpisodes
        }
    }
    
    /// Delete an episode (removes from both SwiftData and POCO)
    public func deleteEpisode(_ poco: EpisodePOCO) throws {
        guard let context = context else {
            throw StoreError.contextNotSet
        }
        
        // Find and delete SwiftData model
        let episodeID = poco.id
        let predicate = #Predicate<Episode> { $0.id == episodeID }
        var descriptor = FetchDescriptor<Episode>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        guard let episode = try context.fetch(descriptor).first else {
            throw StoreError.episodeNotFound
        }
        
        context.delete(episode)
        try context.save()
        
        // Remove from POCO list
        let podcastID = poco.podcastID
        episodes[podcastID]?.removeAll { $0.id == poco.id }
    }
    
    public func getEpisode(with id: String, in podcastID: String) -> EpisodePOCO? {
        episodes[podcastID]?.first { $0.id == id }
    }
    
    public func getEpisodes(for podcastID: String) -> [EpisodePOCO] {
        episodes[podcastID] ?? []
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToPOCO(podcast: Podcast) -> PodcastPOCO {
        PodcastPOCO(
            id: podcast.id,
            name: podcast.name,
            podcastDescription: podcast.podcastDescription,
            artworkData: podcast.artworkData,
            defaultOverlayData: podcast.defaultOverlayData,
            defaultFontName: podcast.defaultFontName,
            defaultFontSize: podcast.defaultFontSize,
            defaultTextPositionX: podcast.defaultTextPositionX,
            defaultTextPositionY: podcast.defaultTextPositionY,
            defaultHorizontalPadding: podcast.defaultHorizontalPadding,
            defaultVerticalPadding: podcast.defaultVerticalPadding,
            defaultCanvasWidth: podcast.defaultCanvasWidth,
            defaultCanvasHeight: podcast.defaultCanvasHeight,
            defaultBackgroundScaling: podcast.defaultBackgroundScaling,
            defaultFontColorHex: podcast.defaultFontColorHex,
            defaultOutlineEnabled: podcast.defaultOutlineEnabled,
            defaultOutlineColorHex: podcast.defaultOutlineColorHex,
            createdAt: podcast.createdAt
        )
    }
    
    private func convertToPOCO(episode: Episode, podcastID: String) -> EpisodePOCO {
        EpisodePOCO(
            id: episode.id,
            podcastID: podcastID,
            title: episode.title,
            episodeNumber: episode.episodeNumber,
            podcast: nil,
            episodeDescription: episode.episodeDescription,
            transcriptInputText: episode.transcriptInputText,
            srtOutputText: episode.srtOutputText,
            createdAt: episode.createdAt,
            publishDate: episode.publishDate,
            thumbnailBackgroundData: episode.thumbnailBackgroundData,
            thumbnailOverlayData: episode.thumbnailOverlayData,
            thumbnailOutputData: episode.thumbnailOutputData,
            fontName: episode.fontName,
            fontSize: episode.fontSize,
            textPositionX: episode.textPositionX,
            textPositionY: episode.textPositionY,
            horizontalPadding: episode.horizontalPadding,
            verticalPadding: episode.verticalPadding,
            canvasWidth: episode.canvasWidth,
            canvasHeight: episode.canvasHeight,
            backgroundScaling: episode.backgroundScaling,
            fontColorHex: episode.fontColorHex,
            outlineEnabled: episode.outlineEnabled,
            outlineColorHex: episode.outlineColorHex
        )
    }
}
