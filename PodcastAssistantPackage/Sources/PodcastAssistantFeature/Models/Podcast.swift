import Foundation
import SwiftData

/// Podcast model representing a podcast with its episodes and default settings
@Model
public final class Podcast {
    @Attribute(.unique) public var id: String
    public var name: String
    public var podcastDescription: String?
    public var artworkData: Data?
    public var defaultOverlayData: Data?
    public var defaultFontName: String?
    public var defaultFontSize: Double
    public var defaultTextPositionX: Double
    public var defaultTextPositionY: Double
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
        defaultTextPositionY: Double = 0.5
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
        self.createdAt = Date()
    }
}

extension Podcast: Identifiable {
    
}
