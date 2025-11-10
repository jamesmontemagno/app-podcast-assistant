import SwiftUI

/// Global app state for menu commands and UI coordination
@MainActor
public class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var selectedEpisodeSection: EpisodeSection?
    @Published public var episodeDetailActions: EpisodeDetailActions?
    @Published public var transcriptActions: TranscriptActions?
    @Published public var transcriptCapabilities: TranscriptActionCapabilities?
    @Published public var thumbnailActions: ThumbnailActions?
    @Published public var thumbnailCapabilities: ThumbnailActionCapabilities?
    
    private init() {}
}
