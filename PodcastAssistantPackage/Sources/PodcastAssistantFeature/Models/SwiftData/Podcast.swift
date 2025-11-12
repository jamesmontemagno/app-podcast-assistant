import Foundation
import SwiftData

/// Podcast model representing a podcast with its episodes and default settings
@Model
public final class Podcast {
    @Attribute(.unique) public var id: String
    public var name: String
    public var podcastDescription: String?
    
    @Attribute(.externalStorage)
    public var artworkData: Data?
    
    @Attribute(.externalStorage)
    public var defaultOverlayData: Data?
    
    public var defaultFontName: String?
    public var defaultFontSize: Double
    public var defaultTextPositionX: Double
    public var defaultTextPositionY: Double
    public var defaultHorizontalPadding: Double
    public var defaultVerticalPadding: Double
    public var defaultCanvasWidth: Double
    public var defaultCanvasHeight: Double
    public var defaultBackgroundScaling: String
    public var defaultFontColorHex: String? // e.g. "#FFFFFF"
    public var defaultOutlineEnabled: Bool
    public var defaultOutlineColorHex: String? // e.g. "#000000"
    public var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Episode.podcast)
    public var episodes: [Episode] = []
    
    // MARK: - Initialization
    
    public init(
        name: String,
        podcastDescription: String? = nil,
        artworkData: Data? = nil,
        defaultOverlayData: Data? = nil,
        defaultFontName: String? = nil,
        defaultFontSize: Double = 72.0,
        defaultTextPositionX: Double = 0.5,
        defaultTextPositionY: Double = 0.5,
        defaultHorizontalPadding: Double = 40.0,
        defaultVerticalPadding: Double = 40.0,
        defaultCanvasWidth: Double = 1920.0,
        defaultCanvasHeight: Double = 1080.0,
        defaultBackgroundScaling: String = "Aspect Fill (Crop)",
        defaultFontColorHex: String? = "#FFFFFF",
        defaultOutlineEnabled: Bool = true,
        defaultOutlineColorHex: String? = "#000000"
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.podcastDescription = podcastDescription
        self.artworkData = artworkData
        self.defaultOverlayData = defaultOverlayData
        self.defaultFontName = defaultFontName
        self.defaultFontSize = defaultFontSize
        self.defaultTextPositionX = defaultTextPositionX
        self.defaultTextPositionY = defaultTextPositionY
        self.defaultHorizontalPadding = defaultHorizontalPadding
        self.defaultVerticalPadding = defaultVerticalPadding
        self.defaultCanvasWidth = defaultCanvasWidth
        self.defaultCanvasHeight = defaultCanvasHeight
        self.defaultBackgroundScaling = defaultBackgroundScaling
        self.defaultFontColorHex = defaultFontColorHex
        self.defaultOutlineEnabled = defaultOutlineEnabled
        self.defaultOutlineColorHex = defaultOutlineColorHex
        self.createdAt = Date()
    }
}

extension Podcast: Identifiable, Hashable {
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
