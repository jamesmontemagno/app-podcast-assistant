import Foundation

/// Simple POCO (Plain Old Class Object) for Episode - no SwiftData, just pure Swift
public final class EpisodePOCO: Identifiable, Hashable {
    public let id: String
    public let podcastID: String // Store podcast ID instead of weak reference
    public var title: String
    public var episodeNumber: Int32
    public var episodeDescription: String?
    public var transcriptInputText: String?
    public var srtOutputText: String?
    public var thumbnailBackgroundData: Data?
    public var thumbnailOverlayData: Data?
    public var thumbnailOutputData: Data?
    public var fontName: String?
    public var fontSize: Double
    public var textPositionX: Double
    public var textPositionY: Double
    public var horizontalPadding: Double
    public var verticalPadding: Double
    public var canvasWidth: Double
    public var canvasHeight: Double
    public var backgroundScaling: String
    public var fontColorHex: String?
    public var outlineEnabled: Bool
    public var outlineColorHex: String?
    public var createdAt: Date
    public var publishDate: Date
    
    // Computed properties for flags
    public var hasTranscriptData: Bool {
        transcriptInputText?.isEmpty == false
    }
    
    public var hasThumbnailOutput: Bool {
        thumbnailOutputData != nil
    }
    
    public init(
        id: String = UUID().uuidString,
        podcastID: String,
        title: String,
        episodeNumber: Int32,
        podcast: PodcastPOCO? = nil,
        episodeDescription: String? = nil,
        transcriptInputText: String? = nil,
        srtOutputText: String? = nil,
        createdAt: Date = Date(),
        publishDate: Date = Date(),
        thumbnailBackgroundData: Data? = nil,
        thumbnailOverlayData: Data? = nil,
        thumbnailOutputData: Data? = nil,
        fontName: String? = nil,
        fontSize: Double? = nil,
        textPositionX: Double? = nil,
        textPositionY: Double? = nil,
        horizontalPadding: Double? = nil,
        verticalPadding: Double? = nil,
        canvasWidth: Double? = nil,
        canvasHeight: Double? = nil,
        backgroundScaling: String? = nil,
        fontColorHex: String? = nil,
        outlineEnabled: Bool? = nil,
        outlineColorHex: String? = nil
    ) {
        self.id = id
        self.podcastID = podcastID
        self.title = title
        self.episodeNumber = episodeNumber
        self.episodeDescription = episodeDescription
        self.transcriptInputText = transcriptInputText
        self.srtOutputText = srtOutputText
        self.createdAt = createdAt
        self.publishDate = publishDate
        self.thumbnailBackgroundData = thumbnailBackgroundData
        self.thumbnailOverlayData = thumbnailOverlayData
        self.thumbnailOutputData = thumbnailOutputData
        
        // Use provided values or copy defaults from parent podcast or use fallbacks
        if let podcast = podcast {
            self.fontName = fontName ?? podcast.defaultFontName
            self.fontSize = fontSize ?? podcast.defaultFontSize
            self.textPositionX = textPositionX ?? podcast.defaultTextPositionX
            self.textPositionY = textPositionY ?? podcast.defaultTextPositionY
            self.horizontalPadding = horizontalPadding ?? podcast.defaultHorizontalPadding
            self.verticalPadding = verticalPadding ?? podcast.defaultVerticalPadding
            self.canvasWidth = canvasWidth ?? podcast.defaultCanvasWidth
            self.canvasHeight = canvasHeight ?? podcast.defaultCanvasHeight
            self.backgroundScaling = backgroundScaling ?? podcast.defaultBackgroundScaling
            self.fontColorHex = fontColorHex ?? podcast.defaultFontColorHex
            self.outlineEnabled = outlineEnabled ?? podcast.defaultOutlineEnabled
            self.outlineColorHex = outlineColorHex ?? podcast.defaultOutlineColorHex
            if self.thumbnailOverlayData == nil {
                self.thumbnailOverlayData = podcast.defaultOverlayData
            }
        } else {
            // Fallback defaults
            self.fontName = fontName
            self.fontSize = fontSize ?? 72.0
            self.textPositionX = textPositionX ?? 0.5
            self.textPositionY = textPositionY ?? 0.5
            self.horizontalPadding = horizontalPadding ?? 40.0
            self.verticalPadding = verticalPadding ?? 40.0
            self.canvasWidth = canvasWidth ?? 1920.0
            self.canvasHeight = canvasHeight ?? 1080.0
            self.backgroundScaling = backgroundScaling ?? "Aspect Fill (Crop)"
            self.fontColorHex = fontColorHex ?? "#FFFFFF"
            self.outlineEnabled = outlineEnabled ?? true
            self.outlineColorHex = outlineColorHex ?? "#000000"
        }
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: EpisodePOCO, rhs: EpisodePOCO) -> Bool {
        lhs.id == rhs.id
    }
}
