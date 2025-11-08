import Foundation
import CoreData

extension Episode {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Episode> {
        return NSFetchRequest<Episode>(entityName: "Episode")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var episodeNumber: Int32
    @NSManaged public var transcriptInputText: String?
    @NSManaged public var srtOutputText: String?
    @NSManaged public var thumbnailBackgroundData: Data?
    @NSManaged public var thumbnailOverlayData: Data?
    @NSManaged public var thumbnailOutputData: Data?
    @NSManaged public var fontName: String?
    @NSManaged public var fontSize: Double
    @NSManaged public var textPositionX: Double
    @NSManaged public var textPositionY: Double
    @NSManaged public var createdAt: Date
    @NSManaged public var podcast: Podcast?
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
        
        // Copy defaults from parent podcast if available
        if let podcast = podcast {
            setPrimitiveValue(podcast.defaultFontName, forKey: "fontName")
            setPrimitiveValue(podcast.defaultFontSize, forKey: "fontSize")
            setPrimitiveValue(podcast.defaultTextPositionX, forKey: "textPositionX")
            setPrimitiveValue(podcast.defaultTextPositionY, forKey: "textPositionY")
            setPrimitiveValue(podcast.defaultOverlayData, forKey: "thumbnailOverlayData")
        } else {
            // Fallback defaults
            setPrimitiveValue(72.0, forKey: "fontSize")
            setPrimitiveValue(0.5, forKey: "textPositionX")
            setPrimitiveValue(0.5, forKey: "textPositionY")
        }
    }
}

extension Episode: Identifiable {
    
}
