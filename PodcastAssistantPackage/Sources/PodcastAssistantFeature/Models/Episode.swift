import Foundation
import SwiftData

/// Episode model representing a podcast episode with transcript and thumbnail data
@Model
public final class Episode {
    @Attribute(.unique) public var id: String
    public var title: String
    public var episodeNumber: Int32
    public var transcriptInputText: String?
    public var srtOutputText: String?
    public var thumbnailBackgroundData: Data?
    public var thumbnailOverlayData: Data?
    public var thumbnailOutputData: Data?
    public var fontName: String?
    public var fontSize: Double
    public var textPositionX: Double
    public var textPositionY: Double
    public var createdAt: Date
    
    public var podcast: Podcast?
    
    // MARK: - Initialization
    
    /// Initialize a new episode
    /// - Parameters:
    ///   - title: Episode title
    ///   - episodeNumber: Episode number
    ///   - podcast: Parent podcast (optional, but recommended to copy defaults)
    public init(
        title: String,
        episodeNumber: Int32,
        podcast: Podcast? = nil
    ) {
        self.id = UUID().uuidString
        self.title = title
        self.episodeNumber = episodeNumber
        self.createdAt = Date()
        self.podcast = podcast
        
        // Copy defaults from parent podcast if available
        if let podcast = podcast {
            self.fontName = podcast.defaultFontName
            self.fontSize = podcast.defaultFontSize
            self.textPositionX = podcast.defaultTextPositionX
            self.textPositionY = podcast.defaultTextPositionY
            self.thumbnailOverlayData = podcast.defaultOverlayData
        } else {
            // Fallback defaults
            self.fontSize = 72.0
            self.textPositionX = 0.5
            self.textPositionY = 0.5
        }
    }
}

extension Episode: Identifiable {
    
}
