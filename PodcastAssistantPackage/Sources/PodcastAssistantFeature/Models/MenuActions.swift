import SwiftUI

// MARK: - Focused Values

public struct SelectedEpisodeKey: FocusedValueKey {
    public typealias Value = Episode
}

public struct TranscriptActionsKey: FocusedValueKey {
    public typealias Value = TranscriptActions
}

public struct ThumbnailActionsKey: FocusedValueKey {
    public typealias Value = ThumbnailActions
}

public struct AIActionsKey: FocusedValueKey {
    public typealias Value = AIActions
}

public struct PodcastActionsKey: FocusedValueKey {
    public typealias Value = PodcastActions
}

public struct EpisodeActionsKey: FocusedValueKey {
    public typealias Value = EpisodeActions
}

public struct TranscriptActionCapabilitiesKey: FocusedValueKey {
    public typealias Value = TranscriptActionCapabilities
}

public struct ThumbnailActionCapabilitiesKey: FocusedValueKey {
    public typealias Value = ThumbnailActionCapabilities
}

extension FocusedValues {
    public var selectedEpisode: SelectedEpisodeKey.Value? {
        get { self[SelectedEpisodeKey.self] }
        set { self[SelectedEpisodeKey.self] = newValue }
    }
    
    public var transcriptActions: TranscriptActionsKey.Value? {
        get { self[TranscriptActionsKey.self] }
        set { self[TranscriptActionsKey.self] = newValue }
    }
    
    public var thumbnailActions: ThumbnailActionsKey.Value? {
        get { self[ThumbnailActionsKey.self] }
        set { self[ThumbnailActionsKey.self] = newValue }
    }
    
    public var aiActions: AIActionsKey.Value? {
        get { self[AIActionsKey.self] }
        set { self[AIActionsKey.self] = newValue }
    }
    
    public var podcastActions: PodcastActionsKey.Value? {
        get { self[PodcastActionsKey.self] }
        set { self[PodcastActionsKey.self] = newValue }
    }
    
    public var episodeActions: EpisodeActionsKey.Value? {
        get { self[EpisodeActionsKey.self] }
        set { self[EpisodeActionsKey.self] = newValue }
    }
    
    public var canPerformTranscriptActions: TranscriptActionCapabilitiesKey.Value? {
        get { self[TranscriptActionCapabilitiesKey.self] }
        set { self[TranscriptActionCapabilitiesKey.self] = newValue }
    }
    
    public var canPerformThumbnailActions: ThumbnailActionCapabilitiesKey.Value? {
        get { self[ThumbnailActionCapabilitiesKey.self] }
        set { self[ThumbnailActionCapabilitiesKey.self] = newValue }
    }
}

// MARK: - Action Protocols

public struct TranscriptActions {
    public let importTranscript: () -> Void
    public let convertToSRT: () -> Void
    public let exportSRT: () -> Void
    public let exportTranslated: () -> Void
    public let clearTranscript: () -> Void
    
    public init(
        importTranscript: @escaping () -> Void,
        convertToSRT: @escaping () -> Void,
        exportSRT: @escaping () -> Void,
        exportTranslated: @escaping () -> Void,
        clearTranscript: @escaping () -> Void
    ) {
        self.importTranscript = importTranscript
        self.convertToSRT = convertToSRT
        self.exportSRT = exportSRT
        self.exportTranslated = exportTranslated
        self.clearTranscript = clearTranscript
    }
}

public struct ThumbnailActions {
    public let importBackground: () -> Void
    public let importOverlay: () -> Void
    public let pasteBackground: () -> Void
    public let pasteOverlay: () -> Void
    public let generateThumbnail: () -> Void
    public let exportThumbnail: () -> Void
    public let clearThumbnail: () -> Void
    
    public init(
        importBackground: @escaping () -> Void,
        importOverlay: @escaping () -> Void,
        pasteBackground: @escaping () -> Void,
        pasteOverlay: @escaping () -> Void,
        generateThumbnail: @escaping () -> Void,
        exportThumbnail: @escaping () -> Void,
        clearThumbnail: @escaping () -> Void
    ) {
        self.importBackground = importBackground
        self.importOverlay = importOverlay
        self.pasteBackground = pasteBackground
        self.pasteOverlay = pasteOverlay
        self.generateThumbnail = generateThumbnail
        self.exportThumbnail = exportThumbnail
        self.clearThumbnail = clearThumbnail
    }
}

public struct AIActions {
    public let generateAll: () async -> Void
    
    public init(generateAll: @escaping () async -> Void) {
        self.generateAll = generateAll
    }
}

public struct PodcastActions {
    public let createPodcast: () -> Void
    
    public init(createPodcast: @escaping () -> Void) {
        self.createPodcast = createPodcast
    }
}

public struct EpisodeActions {
    public let createEpisode: () -> Void
    public let editEpisode: () -> Void
    public let deleteEpisode: () -> Void
    public let showDetails: () -> Void
    public let showTranscript: () -> Void
    public let showThumbnail: () -> Void
    public let showAIIdeas: () -> Void
    
    public init(
        createEpisode: @escaping () -> Void,
        editEpisode: @escaping () -> Void,
        deleteEpisode: @escaping () -> Void,
        showDetails: @escaping () -> Void,
        showTranscript: @escaping () -> Void,
        showThumbnail: @escaping () -> Void,
        showAIIdeas: @escaping () -> Void
    ) {
        self.createEpisode = createEpisode
        self.editEpisode = editEpisode
        self.deleteEpisode = deleteEpisode
        self.showDetails = showDetails
        self.showTranscript = showTranscript
        self.showThumbnail = showThumbnail
        self.showAIIdeas = showAIIdeas
    }
}

public struct TranscriptActionCapabilities {
    public let canConvert: Bool
    public let canExport: Bool
    public let canClear: Bool
    
    public init(canConvert: Bool, canExport: Bool, canClear: Bool) {
        self.canConvert = canConvert
        self.canExport = canExport
        self.canClear = canClear
    }
}

public struct ThumbnailActionCapabilities {
    public let canGenerate: Bool
    public let canExport: Bool
    public let canClear: Bool
    
    public init(canGenerate: Bool, canExport: Bool, canClear: Bool) {
        self.canGenerate = canGenerate
        self.canExport = canExport
        self.canClear = canClear
    }
}
