import Foundation
import SwiftData

/// Episode model representing a podcast episode metadata (lightweight for list views)
/// Heavy content (transcripts, images) stored in separate EpisodeContent relationship
@Model
public final class Episode {
    @Attribute(.unique) public var id: String
    public var title: String
    public var episodeNumber: Int32
    public var episodeDescription: String?
    
    /// Cached flag indicating if transcript data exists
    public var hasTranscriptData: Bool = false
    
    /// Cached flag indicating if thumbnail output exists
    public var hasThumbnailOutput: Bool = false
    
    public var fontName: String?
    public var fontSize: Double
    public var textPositionX: Double
    public var textPositionY: Double
    public var horizontalPadding: Double
    public var verticalPadding: Double
    public var canvasWidth: Double
    public var canvasHeight: Double
    public var backgroundScaling: String // BackgroundScaling enum raw value
    public var fontColorHex: String? // e.g. "#FFFFFF"
    public var outlineEnabled: Bool
    public var outlineColorHex: String? // e.g. "#000000"
    public var createdAt: Date
    public var publishDate: Date
    
    // Relationships
    public var podcast: Podcast?
    
    @Relationship(deleteRule: .cascade, inverse: \EpisodeContent.episode)
    public var content: EpisodeContent?
    
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
        self.publishDate = Date()
        self.podcast = podcast
        
        // Copy defaults from parent podcast if available
        if let podcast = podcast {
            self.fontName = podcast.defaultFontName
            self.fontSize = podcast.defaultFontSize
            self.textPositionX = podcast.defaultTextPositionX
            self.textPositionY = podcast.defaultTextPositionY
            self.horizontalPadding = podcast.defaultHorizontalPadding
            self.verticalPadding = podcast.defaultVerticalPadding
            self.canvasWidth = podcast.defaultCanvasWidth
            self.canvasHeight = podcast.defaultCanvasHeight
            self.backgroundScaling = podcast.defaultBackgroundScaling
            self.fontColorHex = podcast.defaultFontColorHex
            self.outlineEnabled = podcast.defaultOutlineEnabled
            self.outlineColorHex = podcast.defaultOutlineColorHex
        } else {
            // Fallback defaults
            self.fontSize = 72.0
            self.textPositionX = 0.5
            self.textPositionY = 0.5
            self.horizontalPadding = 40.0
            self.verticalPadding = 40.0
            self.canvasWidth = 1920.0
            self.canvasHeight = 1080.0
            self.backgroundScaling = "Aspect Fill (Crop)"
            self.fontColorHex = "#FFFFFF"
            self.outlineEnabled = true
            self.outlineColorHex = "#000000"
        }
        
        // Create empty content relationship
        self.content = EpisodeContent()
    }
    
    // MARK: - Convenience Accessors
    
    /// Access transcript input text from content relationship
    public var transcriptInputText: String? {
        get { content?.transcriptInputText }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.transcriptInputText = newValue
            hasTranscriptData = newValue?.isEmpty == false
        }
    }
    
    /// Access SRT output text from content relationship
    public var srtOutputText: String? {
        get { content?.srtOutputText }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.srtOutputText = newValue
        }
    }
    
    /// Access thumbnail background data from content relationship
    public var thumbnailBackgroundData: Data? {
        get { content?.thumbnailBackgroundData }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.thumbnailBackgroundData = newValue
        }
    }
    
    /// Access thumbnail overlay data from content relationship
    public var thumbnailOverlayData: Data? {
        get { content?.thumbnailOverlayData }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.thumbnailOverlayData = newValue
        }
    }
    
    /// Access thumbnail output data from content relationship
    public var thumbnailOutputData: Data? {
        get { content?.thumbnailOutputData }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.thumbnailOutputData = newValue
            hasThumbnailOutput = newValue != nil
        }
    }
}

extension Episode: Identifiable, Hashable {
    public static func == (lhs: Episode, rhs: Episode) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
